//
//  ZFGPUImagePicture.m
//  ZFScreenRecording
//
//  Created by haha on 2017/2/8.
//  Copyright © 2017年 haha. All rights reserved.
//

#import "ZFScreenVideoCamera.h"

#define INITIALFRAMESTOIGNOREFORBENCHMARK 5

// 获取view的截图图片
void ZFSnapshotViewInRect(UIView *view, CGRect rect,CGImageRef *imageRef)
{
    UIGraphicsBeginImageContextWithOptions(rect.size, YES,  [[UIScreen mainScreen] scale]);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        imageRef = nil;
    }
    [view drawViewHierarchyInRect:rect afterScreenUpdates:FALSE];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    *imageRef = image.CGImage;
}

// 图片转换成视频流对象
void ZFImageCreateResizedSampleBuffer(CGImageRef imageRef,CMSampleBufferRef *sampleBuffer,CMTime frameTime)
{
    CVPixelBufferRef pixel_buffer = NULL;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    // 获取图片的大小
    CGFloat frameWidth = CGImageGetWidth(imageRef);
    CGFloat frameHeight = CGImageGetHeight(imageRef);
    // 转流设置
    CVPixelBufferCreate(kCFAllocatorDefault,
                        frameWidth,
                        frameHeight,
                        kCVPixelFormatType_32BGRA,
                        (__bridge CFDictionaryRef) options,
                        &pixel_buffer);
    CVPixelBufferLockBaseAddress(pixel_buffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pixel_buffer);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    //如果想要转成yuv420，则还需要加上kCGBitmapByteOrder32Little
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pixel_buffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedFirst | (CGBitmapInfo)kCGBitmapByteOrder32Little);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           frameWidth,
                                           frameHeight),
                       imageRef);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixel_buffer, &videoInfo);
    CMSampleTimingInfo timing = {frameTime, frameTime, kCMTimeInvalid};
    
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixel_buffer, YES, NULL, NULL, videoInfo, &timing, sampleBuffer);
    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
    CFRelease(videoInfo);
    CVPixelBufferRelease(pixel_buffer);
}


@interface ZFScreenVideoCamera ()<AVCaptureAudioDataOutputSampleBufferDelegate> {
    
    NSUInteger numberOfFramesCaptured;
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_microphone;
    AVCaptureDeviceInput *audioInput;
    AVCaptureAudioDataOutput *audioOutput;
    BOOL capturePaused;
    dispatch_queue_t cameraProcessingQueue, audioProcessingQueue;
    
    BOOL addedAudioInputsDueToEncodingTarget;
    
    dispatch_semaphore_t frameRenderingSemaphore;
    
    NSDate *startingCaptureTime;

    const GLfloat *_preferredConversion;
    
    GPUImageRotationMode outputRotation, internalRotation;

    CGFloat totalFrameTimeDuringCapture;
    CMTime videoFrameTime;

}

@property (nonatomic, strong) CADisplayLink *dlink;
@property (nonatomic , strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) UIView *screenView;
@property (nonatomic, assign) CGRect screenRect;
@end
@implementation ZFScreenVideoCamera

- (void)dealloc
{
    [self stopCameraCapture];
    [audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    [self removeAudioInputsAndOutputs];
    
    // ARC forbids explicit message send of 'release'; since iOS 6 even for dispatch_release() calls: stripping it out in that case is required.
#if !OS_OBJECT_USE_OBJC
    if (frameRenderingSemaphore != NULL)
    {
        dispatch_release(frameRenderingSemaphore);
    }
#endif
}

- (void)stopCameraCapture;
{
    if ([_captureSession isRunning])
    {
        [_captureSession stopRunning];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self loadInitializationData];
    }
    return self;
}

- (instancetype)initWithView:(UIView *)view inRect:(CGRect)rect
{
    self = [super init];
    if (self) {
        [self loadInitializationData];
        self.screenView = view;
        self.screenRect = rect;
    }
    return self;
}

- (void)loadInitializationData {
    cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
    audioProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0);
    _captureSession = [[AVCaptureSession alloc] init];
    _preferredConversion = kColorConversion709;
    outputRotation = kGPUImageNoRotation;
    internalRotation = kGPUImageNoRotation;
    _runBenchmark = NO;
    capturePaused = NO;
    frameRenderingSemaphore = dispatch_semaphore_create(1);
    videoFrameTime = kCMTimeInvalid;
}

- (void)startScreenCapture {
    if (!self.microphoneEnabled) {
        videoFrameTime = CMTimeMake(1, 20);
    }
    __weak __typeof(self) wself = self;
    dispatch_async(cameraProcessingQueue, ^{
        [NSThread currentThread].name = @"截屏线程";
        [NSThread currentThread].threadPriority = 1.0;
        wself.dlink = [CADisplayLink displayLinkWithTarget:wself selector:@selector(timerAction)];
        if ([[[UIDevice currentDevice] systemVersion] floatValue] < 10.0) {
            wself.dlink.frameInterval = 2;
        } else {
            wself.dlink.preferredFramesPerSecond = 30;
        }
        //将定时器添加到runloop中
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [wself.dlink addToRunLoop:runloop forMode:NSDefaultRunLoopMode];
        [wself.dlink setPaused:NO];
        [runloop run];
    });
    if (![_captureSession isRunning])
    {
        startingCaptureTime = [NSDate date];
        [_captureSession startRunning];
    };

}

- (void)stopScreenCapture;
 {
     if (self.dlink) {
         [self.dlink invalidate];
         self.dlink = nil;
     }
     if ([_captureSession isRunning])
     {
        [_captureSession stopRunning];
    }
     videoFrameTime = kCMTimeInvalid;
}

///暂停屏幕录制
- (void)pauseScreenCapture {
    capturePaused = YES;
}

///继续屏幕录制
- (void)resumeScreenCapture {
    capturePaused = NO;
}

- (void)timerAction {
    _isRecording = YES;
    if (capturePaused)
    {
        return;
    }
    if (CMTIME_IS_INVALID(videoFrameTime)) {
        return;
    }
    UIView *view = self.screenView;
    if (!view) {
        view = [[[UIApplication sharedApplication] delegate] window];
    }
    CGRect rect = self.screenRect;
    if (CGRectEqualToRect(self.screenRect, CGRectZero)) {
        rect = view.bounds;
    }
    @autoreleasepool {
        CGImageRef imageRef = NULL;
        ZFSnapshotViewInRect(view, rect, &imageRef);
        //处理视频流
        CMSampleBufferRef sampleBuffer = NULL;
        ZFImageCreateResizedSampleBuffer(imageRef, &sampleBuffer,videoFrameTime);
        if (!self.microphoneEnabled) {
            ++videoFrameTime.value;
        } else {
//            videoFrameTime.value += 16666667;
            videoFrameTime.value += 33333333;
//            videoFrameTime.value += 55555555;
        }

        if (dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
        {
            CFRelease(sampleBuffer);
            return;
        }
        __weak typeof(self) wself = self;
        runAsynchronouslyOnVideoProcessingQueue(^{
            //Feature Detection Hook.
            if (wself.delegate)
            {
                [wself.delegate willOutputScreenSampleBuffer:sampleBuffer];
            }
            [wself processVideoSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
            dispatch_semaphore_signal(frameRenderingSemaphore);
        });
    }
}

- (void)updateTargetsForVideoCameraUsingCacheTextureAtWidth:(int)bufferWidth height:(int)bufferHeight time:(CMTime)currentTime;
{
    // First, update all the framebuffers in the targets
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if (currentTarget != self.targetToIgnoreForUpdates)
            {
                [currentTarget setInputRotation:outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:textureIndexOfTarget];
                
                [currentTarget setCurrentlyReceivingMonochromeInput:NO];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            }
            else
            {
                [currentTarget setInputRotation:outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            }
        }
    }
    
    // Then release our hold on the local framebuffer to send it back to the cache as soon as it's no longer needed
    [outputFramebuffer unlock];
    outputFramebuffer = nil;
    
    // Finally, trigger rendering as needed
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if (currentTarget != self.targetToIgnoreForUpdates)
            {
                [currentTarget newFrameReadyAtTime:currentTime atIndex:textureIndexOfTarget];
            }
        }
    }
}



- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
{
    if (capturePaused)
    {
        return;
    }
    if (!_isRecording)
    {
        return;
    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferHeight = (int) CVPixelBufferGetHeight(cameraFrame);
    CFTypeRef colorAttachments = CVBufferGetAttachment(cameraFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL)
    {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
        {
             _preferredConversion = kColorConversion601;
        }
        else
        {
            _preferredConversion = kColorConversion709;
        }
    }
    else
    {
        _preferredConversion = kColorConversion601;
    }
    
    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    NSLog(@"%@",sampleBuffer);
    NSLog(@"\n\n视频的;;;;;;\n%zd\n%zd\n%zd\n%zd\n\n",currentTime.value, currentTime.timescale,currentTime.flags,currentTime.epoch);
    [GPUImageContext useImageProcessingContext];
    

    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    
    int bytesPerRow = (int) CVPixelBufferGetBytesPerRow(cameraFrame);
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bytesPerRow / 4, bufferHeight) onlyTexture:YES];
    [outputFramebuffer activateFramebuffer];
    
    glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
    
    //        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
    
    // Using BGRA extension to pull in video frame data directly
    // The use of bytesPerRow / 4 accounts for a display glitch present in preview video frames when using the photo preset on the camera
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bytesPerRow / 4, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
    
    [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:bytesPerRow / 4 height:bufferHeight time:currentTime];
    
    CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    
    if (_runBenchmark)
    {
        numberOfFramesCaptured++;
        if (numberOfFramesCaptured > INITIALFRAMESTOIGNOREFORBENCHMARK)
        {
            CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
            totalFrameTimeDuringCapture += currentFrameTime;
            NSLog(@"Average frame time : %f ms", [self averageFrameDurationDuringCapture]);
            NSLog(@"Current frame time : %f ms", 1000.0 * currentFrameTime);
        }
    }
}


#pragma mark -
#pragma mark Accessors

- (void)setAudioEncodingTarget:(GPUImageMovieWriter *)newValue;
{
    if (newValue) {
        /* Add audio inputs and outputs, if necessary */
        addedAudioInputsDueToEncodingTarget |= [self addAudioInputsAndOutputs];
    } else if (addedAudioInputsDueToEncodingTarget) {
        /* Remove audio inputs and outputs, if they were added by previously setting the audio encoding target */
        [self removeAudioInputsAndOutputs];
        addedAudioInputsDueToEncodingTarget = NO;
    }
    
    [super setAudioEncodingTarget:newValue];
}

#pragma mark -
#pragma mark Benchmarking

- (CGFloat)averageFrameDurationDuringCapture;
{
    return (totalFrameTimeDuringCapture / (CGFloat)(numberOfFramesCaptured - INITIALFRAMESTOIGNOREFORBENCHMARK)) * 1000.0;
}

- (void)resetBenchmarkAverage;
{
    numberOfFramesCaptured = 0;
    totalFrameTimeDuringCapture = 0.0;
}


#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (capturePaused) {
        return;
    }
    if (!_captureSession.isRunning)
    {
        return;
    }
    else if (captureOutput == audioOutput)
    {
        [self processAudioSampleBuffer:sampleBuffer];
    }
}

- (void)processAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;
{
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
    if (CMTIME_IS_INVALID(videoFrameTime)) {
        videoFrameTime = currentSampleTime;
    }
    [self.audioEncodingTarget processAudioBuffer:sampleBuffer];
}

- (BOOL)addAudioInputsAndOutputs {
    if (audioOutput)
        return NO;
    
    [_captureSession beginConfiguration];
    
    _microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    audioInput = [AVCaptureDeviceInput deviceInputWithDevice:_microphone error:nil];
    if ([_captureSession canAddInput:audioInput])
    {
        [_captureSession addInput:audioInput];
    }
    audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    if ([_captureSession canAddOutput:audioOutput])
    {
        [_captureSession addOutput:audioOutput];
    }
    else
    {
        NSLog(@"Couldn't add audio output");
    }
    [audioOutput setSampleBufferDelegate:self queue:audioProcessingQueue];
    
    [_captureSession commitConfiguration];
    return YES;
}

- (BOOL)removeAudioInputsAndOutputs
{
    if (!audioOutput)
        return NO;
    
    [_captureSession beginConfiguration];
    [_captureSession removeInput:audioInput];
    [_captureSession removeOutput:audioOutput];
    audioInput = nil;
    audioOutput = nil;
    _microphone = nil;
    [_captureSession commitConfiguration];
    return YES;
}



@end
