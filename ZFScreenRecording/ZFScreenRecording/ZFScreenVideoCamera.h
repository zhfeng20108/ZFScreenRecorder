//
//  ZFGPUImagePicture.h
//  ZFScreenRecording
//
//  Created by haha on 2017/2/8.
//  Copyright © 2017年 haha. All rights reserved.
//

#import <GPUImage/GPUImage.h>

/// 获取view截图图片
void ZFSnapshotViewInRect(UIView *view, CGRect rect,CGImageRef *imageRef);

/// 图片转换成视频流对象
void ZFImageCreateResizedSampleBuffer(CGImageRef imageRef,CMSampleBufferRef *sampleBuffer,CMTime frameTime);

//Delegate Protocal for Face Detection.
@protocol ZFScreenVideoCameraDelegate <NSObject>

@optional
- (void)willOutputScreenSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

@interface ZFScreenVideoCamera : GPUImageOutput
//runBenchmark--控制台打印current frame，就是视频处理到哪一秒了，只是一个控制台输出，YES就输出，NO就不输出
@property(readwrite, nonatomic) BOOL runBenchmark;

@property(readwrite, nonatomic) BOOL microphoneEnabled;

@property(nonatomic, weak) id<ZFScreenVideoCameraDelegate> delegate;

- (instancetype)initWithView:(UIView *)view inRect:(CGRect)rect;

///开始屏幕录制
- (void)startScreenCapture;

///停止屏幕录制
- (void)stopScreenCapture;

///暂停屏幕录制
- (void)pauseScreenCapture;

///继续屏幕录制
- (void)resumeScreenCapture;

- (void)resetBenchmarkAverage;

@end
