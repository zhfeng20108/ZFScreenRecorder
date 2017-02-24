//
//  ZFWindow.m
//  ZFScreenRecording
//
//  Created by haha on 2017/2/16.
//  Copyright © 2017年 haha. All rights reserved.
//

#import "ZFRecordEventWindow.h"

@implementation ZFRecordEventWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *view in self.subviews) {
        for (UIView *subView in view.subviews) {
            if (subView.tag >= kRecordEventViewMinTag && subView.tag <= kRecordEventViewMaxTag) {
                if(CGRectContainsPoint(subView.frame, point) && !view.hidden) {
                    return subView;
                }
            }
        }
    }
    return nil;
}

@end
