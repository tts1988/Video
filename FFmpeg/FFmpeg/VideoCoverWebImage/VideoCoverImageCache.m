//
//  VideoCoverImageCache.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "VideoCoverImageCache.h"
#import <CommonCrypto/CommonDigest.h>

@interface VCAutoPurgeCache : NSCache
@end


@implementation VCAutoPurgeCache

- (instancetype)init
{
    self=[super init];
    
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAllObjects) name:UIApplicationDidReceiveMemoryWarningNotification object:self];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


FOUNDATION_STATIC_INLINE NSUInteger VCCacheCostForImage(UIImage *image) {

    return image.size.height * image.size.width * image.scale * image.scale;

}


@interface VideoCoverImageCache ()

@property(nonatomic,strong)NSCache *memCache;

@property(nonatomic,strong)NSString *diskCachePath;

@property(nonatomic,strong)NSMutableArray<NSString *> *customPaths;

@property(nonatomic,VCDispatchQueueSetterSementics)dispatch_queue_t ioQueue;

@end

@implementation VideoCoverImageCache
{
    NSFileManager *_fileManager;
}

+ (instancetype)sharedImageCache
{
    static dispatch_once_t once;
    
    static id instance;
    
    dispatch_once(&once, ^{
        
        instance=[self new];
    });
    
    return instance;
}

- (instancetype)init
{
    return [self initWithNamespace:@"videoCoverDefalut"];
}

- (instancetype)initWithNamespace:(NSString *)ns
{
    NSString *path=[self makeDiskCachePath:ns];
    
    return [self initWithNamespace:ns diskCacheDirectory:path];
}

- (instancetype)initWithNamespace:(NSString *)ns diskCacheDirectory:(NSString *)directory
{
    if ((self=[super init]))
    {
        NSString *fullNamespace=[@"com.BYG.VCImageCache." stringByAppendingString:ns];
        
        _ioQueue=dispatch_queue_create("com.BYG.VCImageCache", DISPATCH_QUEUE_SERIAL);
        
        _config=[[VideoCoverImageCacheConfig alloc]init];
        
        _memCache=[[VCAutoPurgeCache alloc]init];
        
        _memCache.name=fullNamespace;
        
        if (directory!=nil)
        {
            _diskCachePath=[directory stringByAppendingPathComponent:fullNamespace];
        }
        else
        {
            NSString *path=[self makeDiskCachePath:ns];
            
            _diskCachePath=path;
        }
        
        
        dispatch_sync(_ioQueue, ^{
            
            _fileManager=[NSFileManager new];
            
        });
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearMemory) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteOldFiles) name:UIApplicationWillTerminateNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgoundDeleteOldFiles) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
    }
    
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    VCDispatchQueueRelease(_ioqueue);
}


- (void)checkIfQueueIsIOQueue
{
    const char *currentQueueLabel=dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    
    const char *ioQueueLabel=dispatch_queue_get_label(self.ioQueue);
    
    if (strcmp(currentQueueLabel, ioQueueLabel)!=0)
    {
        NSLog(@"This method should be called from the ioQueue");
    }
}


- (void)addReadOnlyCachePath:(NSString *)path
{
    if (!self.customPaths)
    {
        self.customPaths=[NSMutableArray new];
    }
    
    if (![self.customPaths containsObject:path])
    {
        [self.customPaths addObject:path];
    }
}

- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path
{
    NSString *filename=[self cachedFileNameForKey:key];
    
    return [path stringByAppendingPathComponent:filename];
}

- (NSString *)defaultCachePathForKey:(NSString *)key
{
    return [self cachePathForKey:key inPath:self.diskCachePath];
}


- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], [key.pathExtension isEqualToString:@""] ? @"" : [NSString stringWithFormat:@".%@", key.pathExtension]];
    
    return filename;
}

- (NSString *)makeDiskCachePath:(NSString *)fullNamespace
{
    NSString *cacheDirectory=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    
    return [cacheDirectory stringByAppendingPathComponent:fullNamespace];
}

- (void)storeImage:(UIImage *)image forKey:(NSString *)key completion:(VCImageNoParamsBlock)completionBlock
{
    [self storeImage:image forKey:key toDisk:YES completion:completionBlock];
}

- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk completion:(VCImageNoParamsBlock)completionBlock
{
    [self storeImage:image imageData:nil forKey:key toDisk:toDisk completion:completionBlock];
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk completion:(VCImageNoParamsBlock)completionBlock
{
    if (!image||!key)
    {
        if (completionBlock)
        {
            completionBlock();
        }
        
        return;
    }
    
    if (self.config.shouldCacheImagesInMemory)
    {
        NSUInteger cost=VCCacheCostForImage(image);
        
        [self.memCache setObject:image forKey:key cost:cost];
    }
    
    if (toDisk)
    {
        dispatch_async(self.ioQueue, ^{
           
            @autoreleasepool {
                NSData *data=imageData;
                
                if (!data&&image)
                {
                    
                }
                
                [self storeImageDataToDisk:data forKey:key];
            }
            
            if (completionBlock)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    completionBlock();
                    
                });
            }
            
        });
    }
    else
    {
        if (completionBlock)
        {
            completionBlock();
        }
    }
}

- (void)storeImageDataToDisk:(NSData *)imageData forKey:(NSString *)key
{
    if (!imageData||!key)
    {
        return;
    }
    
    [self checkIfQueueIsIOQueue];
    
    if (![_fileManager fileExistsAtPath:_diskCachePath])
    {
        [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    NSString *cachePathForKey=[self defaultCachePathForKey:key];
    
    NSURL *fielURL=[NSURL fileURLWithPath:cachePathForKey];
    
    [_fileManager createFileAtPath:cachePathForKey contents:imageData attributes:nil];
    
    if (self.config.shouldDisableiCoud)
    {
        [fielURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

- (void)diskImageExistsWithKey:(NSString *)key completion:(VCImageCheckCacheCompletionBlock)completionBlock
{
    dispatch_async(_ioQueue, ^{
        
        BOOL exists=[_fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
        
        if (!exists)
        {
            exists=[_fileManager fileExistsAtPath:[self defaultCachePathForKey:key].stringByDeletingPathExtension];
        }
        
        if (completionBlock)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                completionBlock(exists);
                
            });
        }
        
    });
}

- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key
{
    return [self.memCache objectForKey:key];
}

- (UIImage *)imageFromDiskCacheForKey:(NSString *)key
{
    return nil;
}


- (void)deleteOldFiles
{
    
}

@end














