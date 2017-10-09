//
//  UIView+VideoCoverCache.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "UIView+VideoCoverCache.h"

#import <objc/runtime.h>

#import "UIView+VideoCoverCacheOperation.h"

static char vcImageURLKey;

@implementation UIView (VideoCoverCache)

- (NSURL *)vc_imageURL
{
    return objc_getAssociatedObject(self, &vcImageURLKey);
}

- (void)vc_internalSetImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder operationKey:(NSString *)operationKey setImageBlock:(VCSetImageBlock)setImageBlock completed:(VCExternalCompletionBlock)completedBlock
{
    NSString *validOperationKey=operationKey?:NSStringFromClass([self class]);
    
    [self vc_cancelImageLoadOperationWithKey:validOperationKey];
    
    objc_setAssociatedObject(self, &vcImageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    dispatch_main_custom_async_safe(^{
        
        [self vc_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock];
        
    });
    
    if (url)
    {
        __weak __typeof(self)wself = self;
        
        id<VideoCoverImageOperation> operation=[VideoCoverImageManager.sharedManager loadImageWithURL:url completed:^(UIImage *image, NSData *data, NSError *error,VideoCoverImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            
            __strong __typeof(wself) sself = wself;
            
            if (!sself)
            {
                return ;
            }
            
            dispatch_main_custom_async_safe(^{
               
                if (!sself)
                {
                    return ;
                }
                
                if (image&&completedBlock)
                {
                    completedBlock(image,error,url);
                    
                    return;
                }
                else if (image)
                {
                    [sself vc_setImage:image imageData:data basedOnClassOrViaCustomSetImageBlock:setImageBlock];
                    
                    [sself vc_setNeedsLayout];
                }
                else
                {
                    
                }
                
                if (completedBlock&&finished)
                {
                    completedBlock(image,error,url);
                }
                
            });
            
        }];
        
        [self vc_setImageLoadOperation:operation forKey:validOperationKey];
    }
    else
    {
        dispatch_main_custom_async_safe(^{
            
            if (completedBlock)
            {
                NSError *error =[NSError errorWithDomain:VCWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Trying to load a nil url"}];
                
                completedBlock(nil,error,url);
            }
            
        });
    }
}

- (void)vc_cancelCurrentImageLoad
{
    [self vc_cancelImageLoadOperationWithKey:NSStringFromClass([self class])];
}

- (void)vc_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(VCSetImageBlock)setImageBlock
{
    if (setImageBlock)
    {
        setImageBlock(image,imageData);
        
        return;
    }
    
    if ([self isKindOfClass:[UIImageView class]])
    {
        UIImageView *imageView=(UIImageView *)self;
        
        imageView.image=image;
    }
    
    if ([self isKindOfClass:[UIButton class]])
    {
        UIButton *button=(UIButton *)self;
        
        [button setImage:image forState:UIControlStateNormal];
    }
}

- (void)vc_setNeedsLayout
{
    [self setNeedsLayout];
}

@end







