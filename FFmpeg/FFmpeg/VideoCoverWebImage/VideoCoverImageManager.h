//
//  VideoCoverImageManager.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "VideoCoverImageCompat.h"
#import "VideoCoverImageOperation.h"
#import "VideoCoverImageCache.h"
#import "VideoCoverImageDownloader.h"

typedef void(^VCExternalCompletionBlock)(UIImage *image,NSError *error,NSURL *imageURL);

typedef void(^VCInternalCompletionBlock)(UIImage *image,NSData *data,NSError *error,VideoCoverImageCacheType cacheType,BOOL finished,NSURL *imageURL);

typedef NSString *(^VCImageCacheKeyFilterBlock)(NSURL *url);

@interface VideoCoverImageManager : NSObject

@property(nonatomic,strong,readonly)VideoCoverImageCache *imageCache;

@property(nonatomic,strong,readonly)VideoCoverImageDownloader *imageDownloader;

@property(nonatomic,copy)VCImageCacheKeyFilterBlock cacheKeyFilter;

+ (instancetype)sharedManager;

- (instancetype)initWithCache:(VideoCoverImageCache *)cache downloader:(VideoCoverImageDownloader *)downloader;

- (id <VideoCoverImageOperation>)loadImageWithURL:(NSURL *)url completed:(VCInternalCompletionBlock)completedBlock;

- (void)savaImageToCache:(UIImage *)image forURL:(NSURL *)url;

- (void)cancelAll;

- (BOOL)isRunning;

- (void)cachedImageExistsForURL:(NSURL *)url completion:(VCImageCheckCacheCompletionBlock)completionBlock;

- (void)diskImageExistsForURL:(NSURL *)url completion:(VCImageCheckCacheCompletionBlock)completionBlock;

- (NSString *)cacheKeyForURL:(NSURL *)url;

@end








