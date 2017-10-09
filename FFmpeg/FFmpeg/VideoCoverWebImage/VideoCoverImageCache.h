//
//  VideoCoverImageCache.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "VideoCoverImageCompat.h"
#import "VideoCoverImageCacheConfig.h"

typedef NS_ENUM(NSInteger,VideoCoverImageCacheType) {
    
    VideoCoverImageCacheTypeNone,
    
    VideoCoverImageCacheTypeDisk,
    
    VideoCoverImageCacheTypeMemory
    
};

typedef void(^VCCacheQueryCompletedBlock)(UIImage *image,NSData *data,VideoCoverImageCacheType cacheType);

typedef void(^VCImageCheckCacheCompletionBlock)(BOOL isInCache);

typedef void(^VCImageCalculateSizeBlock)(NSUInteger fileCount,NSUInteger totalSize);

@interface VideoCoverImageCache : NSObject

@property(nonatomic,readonly)VideoCoverImageCacheConfig *config;

@property(nonatomic,assign)NSUInteger maxMemoryCost;

@property(nonatomic,assign)NSUInteger maxMemoryCountLimit;


+ (instancetype)sharedImageCache;

- (instancetype)initWithNamespace:(NSString *)ns;

- (instancetype)initWithNamespace:(NSString *)ns diskCacheDirectory:(NSString *)directory;

- (NSString *)makeDiskCachePath:(NSString *)fullNamespace;

- (void)addReadOnlyCachePath:(NSString *)path;



- (void)storeImage:(UIImage *)image forKey:(NSString *)key completion:(VCImageNoParamsBlock)completionBlock;

- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk completion:(VCImageNoParamsBlock)completionBlock;

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk completion:(VCImageNoParamsBlock)completionBlock;

- (void)storeImageDataToDisk:(NSData *)imageData forKey:(NSString *)key;



- (void)diskImageExistsWithKey:(NSString *)key completion:(VCImageCheckCacheCompletionBlock)completionBlock;

- (NSOperation *)queryCacheOperationForKey:(NSString *)key done:(VCCacheQueryCompletedBlock)doneBlock;



- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key;

- (UIImage *)imageFromDiskCacheForKey:(NSString *)key;

- (UIImage *)imageFromCacheForKey:(NSString *)key;



- (void)removeImageForKey:(NSString *)key withCompletion:(VCImageNoParamsBlock)completion;

- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(VCImageNoParamsBlock)completion;


- (void)clearMemory;

- (void)clearDiskOnCompletion:(VCImageNoParamsBlock)completion;

- (void)deleteOldFilesWithCompletionBlock:(VCImageNoParamsBlock)completionBlock;


- (NSUInteger)getSize;

- (NSUInteger)getDiskCount;

- (void)calculateSizeWithCompletionBlock:(VCImageCalculateSizeBlock)completionBlock;

- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path;

- (NSString *)defaultCachePathForKey:(NSString *)key;

@end









