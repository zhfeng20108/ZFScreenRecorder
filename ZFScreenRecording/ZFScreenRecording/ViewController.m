//
//  ViewController.m
//  Screencast
//
//  Created by haha on 2017/2/6.
//  Copyright © 2017年 haha. All rights reserved.
//

#import "ViewController.h"
#import "ZFScreenRecorder.h"
#import "AppDelegate.h"
#import <SceneKit/SceneKit.h>
#import <ReplayKit/ReplayKit.h>
#import "ZFHiddenStatusBarViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "ZFRecordEventWindow.h"
@interface ViewController ()<RPPreviewViewControllerDelegate,RPScreenRecorderDelegate>

@property (nonatomic, strong) ZFScreenRecorder *screenRecorder;
///粒子系统对象
@property (nonatomic, strong) SCNView *scnView;
@property (nonatomic, strong) SCNNode *node;

@property (nonatomic, strong) UIView *movieView;

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

///在其上放不录制的视图
@property (nonatomic, strong) UIWindow *otherViewWindow;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    SCNView *scnView  = [[SCNView alloc]initWithFrame:self.view.bounds];
    scnView.backgroundColor = [UIColor grayColor];
    scnView.scene = [SCNScene scene];
    scnView.allowsCameraControl = YES;
    [self.view addSubview:scnView];
    self.scnView = scnView;
    
    UIView *testView = [UIView new];
    testView.frame = CGRectMake(100, 30, 50, 50);
    testView.backgroundColor = [UIColor redColor];
    [self.view addSubview:testView];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(100, 200, 90, 90)];
    [imageView setAnimationImages:@[[UIImage imageNamed:@"spark"],[UIImage imageNamed:@"smoke"],[UIImage imageNamed:@"star"]]];
    [self.view addSubview:imageView];
    imageView.animationDuration = 1;
    [imageView startAnimating];
    
    
    //创建摄像头
    SCNCamera *camera = [SCNCamera camera];
    SCNNode *cameraNode = [SCNNode node];
    cameraNode.camera = camera;
    camera.automaticallyAdjustsZRange = YES;
    cameraNode.position = SCNVector3Make(0, 0, 50);
    [scnView.scene.rootNode addChildNode:cameraNode];
    
    _movieView = [UIView new];
    _movieView.frame = CGRectMake(100, 100, 100, 100);
    _movieView.backgroundColor = [UIColor yellowColor];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    label.text = @"来拖拽我呀";
    [_movieView addSubview:label];
    [self.view addSubview:_movieView];
    
    [self addButtons];
    
//    [self playMusic];
}

- (void)addButtons {
    self.otherViewWindow = [[ZFRecordEventWindow alloc] initWithFrame:self.view.bounds];
    self.otherViewWindow.rootViewController = [ZFHiddenStatusBarViewController new];
    [self.otherViewWindow makeKeyAndVisible];
    
    NSArray *title = @[@"火",@"散景",@"雨",@"烟",@"星"];
    for (NSUInteger i=0; i<title.count; ++i) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(5, 40+i*80, 70, 70);
        button.backgroundColor = [UIColor redColor];
        button.clipsToBounds = YES;
        button.layer.cornerRadius = 35.0;
        [button setTitle:title[i] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(buttonTouched:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = kRecordEventViewMinTag + i;
        [self.otherViewWindow.rootViewController.view addSubview:button];
    }
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, self.view.frame.size.height - 78, 70, 70);
    button.center = CGPointMake(self.view.center.x, button.center.y);
    button.backgroundColor = [UIColor greenColor];
    button.clipsToBounds = YES;
    button.layer.cornerRadius = 35.0;
    [button setTitle:@"Record" forState:UIControlStateNormal];
    [button setTitle:@"Stop" forState:UIControlStateSelected];
    [button addTarget:self action:@selector(recordButtonTouched:) forControlEvents:UIControlEventTouchUpInside];
    button.tag = kRecordEventViewMinTag + 50;
    [self.otherViewWindow.rootViewController.view addSubview:button];

    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0, self.view.frame.size.height - 78, 70, 70);
        button.center = CGPointMake(self.view.center.x+70, button.center.y);
        button.backgroundColor = [UIColor blueColor];
        button.clipsToBounds = YES;
        button.layer.cornerRadius = 35.0;
        [button setTitle:@"Pause" forState:UIControlStateNormal];
        [button setTitle:@"Resume" forState:UIControlStateSelected];
        [button addTarget:self action:@selector(pauseButtonTouched:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = kRecordEventViewMinTag + 51;
        [self.otherViewWindow.rootViewController.view addSubview:button];
    }
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0, self.view.frame.size.height - 78, 70, 70);
        button.center = CGPointMake(self.view.center.x+140, button.center.y);
        button.backgroundColor = [UIColor orangeColor];
        button.clipsToBounds = YES;
        button.layer.cornerRadius = 35.0;
        [button setTitle:@"Cancel" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(cancelButtonTouched:) forControlEvents:UIControlEventTouchUpInside];
        button.tag = kRecordEventViewMinTag + 52;
        [self.otherViewWindow.rootViewController.view addSubview:button];
    }
    
}

- (void)playMusic {
    //方式一：
//    // 1.获取要播放音频文件的URL
//    NSURL *fileURL = [[NSBundle mainBundle]URLForResource:@"zhangsheng" withExtension:@"mp3"];
//    // 2.创建 AVAudioPlayer 对象
//    self.audioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:fileURL error:nil];
//    // 3.打印歌曲信息
//    NSString *msg = [NSString stringWithFormat:@"音频文件声道数:%ld\n 音频文件持续时间:%g",self.audioPlayer.numberOfChannels,self.audioPlayer.duration];
//    NSLog(@"%@",msg);
//    // 4.设置循环播放
//    self.audioPlayer.numberOfLoops = -1;
//    // 5.开始播放
//    [self.audioPlayer play];
    
    //方式二：
    SystemSoundID ditaVoice;
    // 1. 定义要播放的音频文件的URL
    NSURL *voiceURL = [[NSBundle mainBundle]URLForResource:@"zhangsheng" withExtension:@"mp3"];
    // 2. 注册音频文件（第一个参数是音频文件的URL 第二个参数是音频文件的SystemSoundID）
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)(voiceURL),&ditaVoice);
    // 3. 为crash播放完成绑定回调函数
    AudioServicesAddSystemSoundCompletion(ditaVoice,NULL,NULL,(void*)completionCallback,NULL);
    // 4. 播放 ditaVoice 注册的音频 并控制手机震动
    AudioServicesPlayAlertSound(ditaVoice);
//        AudioServicesPlaySystemSound(ditaVoice);
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate); // 控制手机振动
}
static void completionCallback(SystemSoundID mySSID)
{
    // Play again after sound play completion
    AudioServicesPlaySystemSound(mySSID);
}

- (void)recordButtonTouched:(UIButton *)button {
    if (!self.screenRecorder) {
        self.screenRecorder = [ZFScreenRecorder recorder];
    }
    if (!button.selected) {
        NSString *imageDir = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents"]];
        [[NSFileManager defaultManager] removeItemAtPath:imageDir error:nil];
//        [[ZFScreenRecorder sharedRecorder] startRecordingWithMicrophoneEnabled:YES handler:^(NSError * _Nullable error) {
         [self.screenRecorder startRecordingView:nil inRect:CGRectZero microphoneEnabled:NO handler:^(NSError * _Nullable error) {
            if (!error) {
                button.selected = YES;
            } else {
                button.selected = NO;
                switch ([error code]) {
                    case ZFScreenRecorderErrorCodeAudioPermissionDenied:
                        NSLog(@"麦克风没有权限");
                        break;
                    case ZFScreenRecorderErrorCodeWillResignActive:
                        NSLog(@"程序进入了后台处理");
                        break;
                    case ZFScreenRecorderErrorCodeWasInterrupted:
                        NSLog(@"被打断了");
                        break;
                    default:
                        break;
                }
            }
        }];
    } else {
//        __weak typeof(self) wself = self;
        button.selected = NO;
        [self.screenRecorder stopRecordingWithHandler:^(NSError * _Nullable error) {
//            NSMutableArray *muArr = [NSMutableArray new];
//            for (NSUInteger i=1; i<NSUIntegerMax; ++i) {
//                NSString *pathToPng = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/%zd.png",++i]];
//                if ([[NSFileManager defaultManager] fileExistsAtPath:pathToPng]) {
//                    [muArr addObject:[UIImage imageWithContentsOfFile:pathToPng]];
//                } else {
//                    [wself playTestImages:muArr];
//                    break;
//                }
//            }
        }];
    }
    
}

- (void)pauseButtonTouched:(UIButton *)button {
    if (!button.selected) {
        [self.screenRecorder pause];
    } else {
        [self.screenRecorder resume];
    }
    button.selected = !button.selected;
}

- (void)cancelButtonTouched:(UIButton *)button {
    [self.screenRecorder cancel];
}

- (void)playTestImages:(NSArray *)imagesArr {
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-100, self.view.bounds.size.height-(self.view.bounds.size.height*100/self.view.bounds.size.width), 100, self.view.bounds.size.height*100/self.view.bounds.size.width)];
    [self.view addSubview:imageView];
    imageView.animationImages = imagesArr;
    imageView.animationDuration = 5;
    [imageView startAnimating];
    
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.mp4"];
    NSURL *url=[NSURL fileURLWithPath:pathToMovie];
    MPMoviePlayerViewController *moviePlayerCtrl = [[MPMoviePlayerViewController alloc]initWithContentURL:url];
    moviePlayerCtrl.view.frame = self.view.bounds;
    //设定播放模式
    moviePlayerCtrl.moviePlayer.controlStyle = MPMovieControlStyleFullscreen;
    //控制模式(触摸)
    moviePlayerCtrl.moviePlayer.scalingMode = MPMovieScalingModeAspectFill;
    [moviePlayerCtrl.moviePlayer prepareToPlay];
    moviePlayerCtrl.moviePlayer.shouldAutoplay=YES;
    [self.otherViewWindow.rootViewController presentViewController:moviePlayerCtrl animated:YES completion:nil];
}



- (void)testButtonTouched:(UIButton *)button {
    button.selected = !button.selected;
}

- (void)buttonTouched:(UIButton *)button {
    NSString *name = @"fire";
    switch (button.tag) {
        case (kRecordEventViewMinTag+2):
            name = @"bokeh";
            break;
        case (kRecordEventViewMinTag+3):
            name = @"rain";
            break;
        case (kRecordEventViewMinTag+4):
            name = @"smoke";
            break;
        case (kRecordEventViewMinTag+5):
            name = @"stars";
            break;
        default:
            break;
    }
    // 1.创建粒子系统对象
    SCNParticleSystem *particleSystem = [SCNParticleSystem particleSystemNamed:name inDirectory:nil];
    // 2.创建一个节点添加粒子系统
    if (!self.node) {
        self.node = [SCNNode node];
        self.node.position = SCNVector3Make(0, -1, 0);
        [self.scnView.scene.rootNode addChildNode:self.node];
    }
    [self.node removeAllParticleSystems];
    [self.node addParticleSystem:particleSystem];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    if (touch.view == _movieView) {
        _movieView.center = [touch locationInView:self.view];
    }
}

#pragma mark -- 检测和处理屏幕的旋转
//是否跟随屏幕旋转
-(BOOL)shouldAutorotate{
    return YES;
}
//支持旋转的方向有哪些
-(UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
