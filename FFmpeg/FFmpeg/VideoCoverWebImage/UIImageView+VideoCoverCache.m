//
//  UIImageView+VideoCoverCache.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "UIImageView+VideoCoverCache.h"

@implementation UIImageView (VideoCoverCache)


- (void)vc_setImageWithURL:(NSURL *)url
{
    [self vc_setImageWithURL:url placeholderImage:nil];
}

- (void)vc_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeHolder
{
    [self vc_setImageWithURL:url placeholderImage:placeHolder completed:nil];
}

- (void)vc_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeHolder completed:(VCExternalCompletionBlock)completedBlock
{
    
}

@end
