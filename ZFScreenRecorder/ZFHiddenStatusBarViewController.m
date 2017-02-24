//
//  HiddenStatusBarViewController.m
//  Screencast
//
//  Created by haha on 2017/2/7.
//  Copyright © 2017年 haha. All rights reserved.
//

#import "ZFHiddenStatusBarViewController.h"

@interface ZFHiddenStatusBarViewController ()

@end

@implementation ZFHiddenStatusBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
