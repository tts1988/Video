//
//  UIView+VideoCoverCacheOperation.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "VideoCoverImageManager.h"


@interface UIView (VideoCoverCacheOperation)

- (void)vc_setImageLoadOperation:(nullable id)operation forKey:(nullable NSString *)key;

- (void)vc_cancelImageLoadOperationWithKey:(nullable NSString *)key;

- (void)vc_removeImageLoadOperationWithKey:(nullable NSString *)key;

@end
