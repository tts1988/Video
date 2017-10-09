//
//  UIView+VideoCoverCache.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "VideoCoverImageManager.h"

typedef void(^VCSetImageBlock)(UIImage *imgae,NSData *imageData);

@interface UIView (VideoCoverCache)

- (NSURL *)vc_imageURL;

- (void)vc_internalSetImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder operationKey:(NSString *)operationKey setImageBlock:(VCSetImageBlock)setImageBlock completed:(VCExternalCompletionBlock)completedBlock;

- (void)vc_cancelCurrentImageLoad;

@end
