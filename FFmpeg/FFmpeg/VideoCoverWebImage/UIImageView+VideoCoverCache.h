//
//  UIImageView+VideoCoverCache.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoCoverImageManager.h"

@interface UIImageView (VideoCoverCache)



- (void)vc_setImageWithURL:(NSURL *)url;

- (void)vc_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeHolder;

- (void)vc_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeHolder completed:(VCExternalCompletionBlock)completedBlock;

@end
