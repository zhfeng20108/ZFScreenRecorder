//
//  ZFScreenRecorder.m
//  ZFScreenRecording
//
//  Created by haha on 2017/2/7.
//  Copyright © 2017年 haha. All rights reserved.
//

#import "ScreenRecorderDemo.h"
#import "ZFScreenRecorder.h"

@interface ScreenRecorderDemo ()
@property (nonatomic , strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic , strong) ZFScreenVideoCamera *videoCamera;
@property(nonatomic, copy) void(^errorCallback)(NSError * __nullable error);
@end
@implementation ScreenRecorderDemo

+ (ScreenRecorderDemo * __nullable)recorder {
    ScreenRecorderDemo *sharedInstance;
    sharedInstance = [[ScreenRecorderDemo alloc] init];
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _moviePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.mp4"];
        __weak typeof(self) wself = self;
        //程序进入了后台处理
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification * _Nonnull note) {
            if (wself) {
                [wself.videoCamera stopScreenCapture];
                [wself.movieWriter cancelRecording];
                if (wself.errorCallback) {
                    wself.errorCallback([NSError errorWithDomain:@"程序进入了后台处理" code:ZFScreenRecorderErrorCodeWillResignActive userInfo:nil]);
                }
            }
        }];
        
        //打断处理
        [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionWasInterruptedNotification object:nil queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification * _Nonnull note) {
            if (wself) {
                [wself.videoCamera stopScreenCapture];
                [wself.movieWriter cancelRecording];
                if (wself.errorCallback) {
                    wself.errorCallback([NSError errorWithDomain:@"被电话什么的打断了" code:ZFScreenRecorderErrorCodeWasInterrupted userInfo:nil]);
                }
            }
        }];
    }
    return self;
}

- (void)startRecordingWithHandler:(nullable void(^)(NSError * __nullable error))handler {
    [self startRecordingWithMicrophoneEnabled:YES handler:handler];
}

- (void)startRecordingWithMicrophoneEnabled:(BOOL)microphoneEnabled handler:(nullable void(^)(NSError * __nullable error))handler {
    [self startRecordingView:nil inRect:CGRectZero microphoneEnabled:microphoneEnabled handler:handler];
}

- (void)startRecordingView:(UIView * _Nullable)view microphoneEnabled:(BOOL)microphoneEnabled handler:(nullable void(^)(NSError * __nullable error))handler {
    [self startRecordingView:view inRect:view.bounds microphoneEnabled:microphoneEnabled handler:handler];
}

- (void)startRecordingView:(UIView * _Nullable)view inRect:(CGRect)rect microphoneEnabled:(BOOL)microphoneEnabled handler:(nullable void(^)(NSError * __nullable error))handler {
    [self startRecordingView:view inRect:rect microphoneEnabled:microphoneEnabled moviePath:nil handler:handler];
}

- (void)startRecordingView:(UIView * _Nullable)view inRect:(CGRect)rect microphoneEnabled:(BOOL)microphoneEnabled moviePath:(NSString * _Nullable)moviePath handler:(nullable void(^)(NSError * __nullable error))handler {
    self.errorCallback = handler;
    if (microphoneEnabled) {
        AVAuthorizationStatus microphoneAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (microphoneAuthStatus == AVAuthorizationStatusDenied || microphoneAuthStatus == AVAuthorizationStatusRestricted) {
            if (handler) {
                handler([NSError errorWithDomain:@"麦克风没有权限" code:ZFScreenRecorderErrorCodeAudioPermissionDenied userInfo:nil]);
            }
            return;
        }
    }
    if (moviePath.length > 0) {
        _moviePath = moviePath;
    }
    unlink([_moviePath UTF8String]);
    NSURL *movieURL = [NSURL fileURLWithPath:_moviePath];
    UIView *screenView = view;
    if (!screenView) {
        screenView = [[[UIApplication sharedApplication] delegate] window];
    }
    if (CGRectEqualToRect(rect, CGRectZero)) {
        rect = screenView.bounds;
    }
    CGSize finalSize = rect.size;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]){
        finalSize = CGSizeMake(rect.size.width*[UIScreen mainScreen].scale, rect.size.height*[UIScreen mainScreen].scale);
    }
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:finalSize];
    //截屏
    self.videoCamera = [[ZFScreenVideoCamera alloc] initWithView:screenView inRect:rect];
    /* 水印测试代码
     // 滤镜
     GPUImageDissolveBlendFilter *filter = [[GPUImageDissolveBlendFilter alloc] init];
     [(GPUImageDissolveBlendFilter *)filter setMix:0.5];
     // 水印
     UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
     label.text = @"我是会跑的水印";
     label.font = [UIFont systemFontOfSize:30];
     label.textColor = [UIColor redColor];
     [label sizeToFit];
     UIView *subView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, window.bounds.size.width,  window.bounds.size.height)];
     subView.backgroundColor = [UIColor clearColor];
     [subView addSubview:label];
     GPUImageUIElement *uielement = [[GPUImageUIElement alloc] initWithView:subView];
     
     GPUImageFilter* progressFilter = [[GPUImageFilter alloc] init];
     
     [progressFilter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
     CGRect frame = label.frame;
     frame.origin.x += 1;
     frame.origin.y += 1;
     label.frame = frame;
     [uielement updateWithTimestamp:time];
     }];
     [self.videoCamera addTarget:progressFilter];
     [progressFilter addTarget:filter];
     [uielement addTarget:filter];
     [filter addTarget:_movieWriter];
     */
    
    /* 滤镜测试代码
     GPUImageSepiaFilter* filter = [[GPUImageSepiaFilter alloc] init];
     [self.videoCamera addTarget:filter];
     */
    
    ///* 没有效果的测试代码
    self.videoCamera.runBenchmark = YES;
    [self.videoCamera addTarget:_movieWriter];
    //*/
    self.videoCamera.microphoneEnabled = microphoneEnabled;
    if (microphoneEnabled) {
        self.videoCamera.audioEncodingTarget = _movieWriter;
    }
    _movieWriter.encodingLiveVideo = YES;
    //开始录屏
    [self.videoCamera startScreenCapture];
    //视频写文件
    [_movieWriter startRecording];
    if (handler) {
        handler(nil);
    }
}

- (void)stopRecordingWithHandler:(nullable void(^)(NSError * __nullable error))handler {
    self.errorCallback = handler;
    [self.videoCamera stopScreenCapture];
    self.videoCamera = nil;
    [_movieWriter finishRecording];
    if (handler) {
        handler(nil);
    }
}

- (void)pause {
    [self.videoCamera pauseScreenCapture];
}

- (void)resume {
    [self.videoCamera resumeScreenCapture];
}

- (void)cancel {
    [self.videoCamera stopScreenCapture];
    self.videoCamera = nil;
    [self.movieWriter cancelRecording];
}

@end
