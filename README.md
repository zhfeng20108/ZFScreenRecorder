# ZFScreenRecorder
基于GPUImage实现的录屏，性能很好。

# 安装
```ruby
target 'TargetName' do
pod 'ZFScreenRecorder'
end
```

# 核心思路
ZFScreenVideoCamera是用来采集视频和音频的信息，音频信息直接发送给GPUImageMovieWriter；视频信息传入响应链作为源头，渲染后的视频信息再写入GPUImageMovieWriter，文件保存在沙盒里。
ZFScreenVideoCamera实现灵感来源于GPUImageVideoCamera。
ZFScreenVideoCamera和GPUImageVideoCamera相似，唯一不同的是视频的采集方式。ZFScreenVideoCamera采用截屏方式，GPUImageVideoCamera采用的是摄像头。所以ZFScreenVideoCamera完美兼容GPUImage的所有功能，在视频的处理上节约了大量开发时间。

# 流程图
![image](https://github.com/zhfeng20108/ZFScreenRecorder/raw/master/liuchengtu.png)

# 使用
```objective-c
	_movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:finalSize];
	//截屏
	self.videoCamera = [[ZFScreenVideoCamera alloc] initWithView:screenView inRect:rect];
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
```


