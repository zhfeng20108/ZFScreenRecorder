//
//  ZFScreenRecorder.h
//  ZFScreenRecording
//
//  Created by haha on 2017/2/7.
//  Copyright © 2017年 haha. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
typedef NS_ENUM(NSInteger, ZFScreenRecorderErrorCode) {
    ZFScreenRecorderErrorCodeAudioPermissionDenied = 1,//麦克风没有权限
    ZFScreenRecorderErrorCodeWillResignActive = 2,//程序进入了后台处理
    ZFScreenRecorderErrorCodeWasInterrupted = 3,//被打断了
    
};
@interface ScreenRecorderDemo : NSObject
@property(nonatomic, readonly, nonnull) NSString *moviePath;

+ (ScreenRecorderDemo * __nullable)recorder;

///开始录屏
- (void)startRecordingWithHandler:(nullable void(^)(NSError * __nullable error))handler;

///开始录屏,microphoneEnabled是否录音
- (void)startRecordingWithMicrophoneEnabled:(BOOL)microphoneEnabled handler:(nullable void(^)(NSError * __nullable error))handler;

///开始录屏
- (void)startRecordingView:(UIView * _Nullable)view microphoneEnabled:(BOOL)microphoneEnabled handler:(nullable void(^)(NSError * __nullable error))handler;

///开始录屏
- (void)startRecordingView:(UIView * _Nullable)view inRect:(CGRect)rect microphoneEnabled:(BOOL)microphoneEnabled handler:(nullable void(^)(NSError * __nullable error))handler;

///开始录屏,moviePath默认值Documents/Movie.mp4
- (void)startRecordingView:(UIView * _Nullable)view inRect:(CGRect)rect microphoneEnabled:(BOOL)microphoneEnabled moviePath:(NSString * _Nullable)moviePath handler:(nullable void(^)(NSError * __nullable error))handler;

///停止录屏
- (void)stopRecordingWithHandler:(nullable void(^)(NSError * __nullable error))handler;

- (void)pause;

- (void)resume;

- (void)cancel;

@end
