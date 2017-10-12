//
//  VideoCoverImageCache.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "VideoCoverImageCache.h"
#import <CommonCrypto/CommonDigest.h>
#import "UIImage+GIF.h"
#import "NSData+ImageContentType.h"
#import "NSImage+WebCache.h"
#import "SDWebImageDecoder.h"
#import "UIImage+MultiFormat.h"
#import "SDWebImageCompat.h"

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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundDeleteOldFiles) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
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
                    SDImageFormat imageFormatFromData = [NSData sd_imageFormatForImageData:data];
                    
                    data = [image sd_imageDataAsFormat:imageFormatFromData];
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


- (UIImage *)imageFromCacheForKey:(NSString *)key
{
    return nil;
}


- (NSData *)diskImageDataBySearchingAllPathsForKey:(NSString *)key
{
    NSString *defaultPath=[self defaultCachePathForKey:key];
    
    NSData *data=[NSData dataWithContentsOfFile:defaultPath];
    
    if (data)
    {
        return data;
    }
    
    data=[NSData dataWithContentsOfFile:defaultPath.stringByDeletingPathExtension];
    
    if (data)
    {
        return data;
    }
    
    NSArray <NSString *> *customPaths=[self.customPaths copy];
    
    for (NSString *path in customPaths)
    {
        NSString *filePath=[self cachePathForKey:key inPath:path];
        
        NSData *imageData=[NSData dataWithContentsOfFile:filePath];
        
        if (imageData)
        {
            return imageData;
        }
        
        imageData=[NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension];
        
        if (imageData)
        {
            return imageData;
        }
    }
    
    return nil;
}

- (UIImage *)diskImageForKey:(NSString *)key
{
    NSData *data=[self diskImageDataBySearchingAllPathsForKey:key];
    
    if (data)
    {
        UIImage *image=[UIImage sd_imageWithData:data];
        
        image=[self scaledImageForKey:key image:image];
        
        if (self.config.shouldDecompressImages)
        {
            image=[UIImage decodedImageWithImage:image];
        }
        
        return image;
    }
    else
    {
        return nil;
    }
}


- (UIImage *)scaledImageForKey:(NSString *)key image:(UIImage *)image
{
    return  SDScaledImageForKey(key, image);
}


- (NSOperation *)queryCacheOperationForKey:(NSString *)key done:(VCCacheQueryCompletedBlock)doneBlock
{
    if (!key)
    {
        if (doneBlock)
        {
            doneBlock(nil,nil,VideoCoverImageCacheTypeNone);
        }
        
        return nil;
    }
    
    //从内存中获取图片
    UIImage *image=[self imageFromMemoryCacheForKey:key];
    
    if (image)
    {
        NSData *diskData=nil;
        
        if ([image isGIF])
        {
            diskData=[self diskImageDataBySearchingAllPathsForKey:key];
        }
        
        if (doneBlock)
        {
            doneBlock(image,diskData,VideoCoverImageCacheTypeMemory);
        }
        
        return nil;
    }
    
    //从磁盘获取图片 并将图片存储至内存
    NSOperation *operation=[NSOperation new];
    
    dispatch_sync(self.ioQueue, ^{
        
        if (operation.isCancelled)
        {
            return ;
        }
        
        @autoreleasepool {
            
            NSData *diskData=[self diskImageDataBySearchingAllPathsForKey:key];
            
            UIImage *diskImage=[self diskImageForKey:key];
            
            if (diskImage&&self.config.shouldCacheImagesInMemory)
            {
                NSUInteger cost=VCCacheCostForImage(diskImage);
                
                [self.memCache setObject:diskImage forKey:key cost:cost];
            }
            
            if (doneBlock)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    doneBlock(diskImage,diskData,VideoCoverImageCacheTypeDisk);
                    
                });
            }
            
        }
        
    });
    
    return operation;
}



- (void)removeImageForKey:(NSString *)key withCompletion:(VCImageNoParamsBlock)completion
{
    
}

- (void)removeImageForKey:(NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(VCImageNoParamsBlock)completion
{
    if (key==nil)
    {
        return;
    }
    
    if (self.config.shouldCacheImagesInMemory)
    {
        [self.memCache removeObjectForKey:key];
    }
    
    if (fromDisk)
    {
        dispatch_async(self.ioQueue, ^{
            
            [_fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    completion();
                    
                });
            }
            
        });
    }
    else if (completion)
    {
        completion();
    }
}


- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost
{
    self.memCache.totalCostLimit=maxMemoryCost;
}

- (NSUInteger)maxMemoryCost
{
    return self.memCache.totalCostLimit;
}

- (void)setMaxMemoryCountLimit:(NSUInteger)maxMemoryCountLimit
{
    self.memCache.countLimit=maxMemoryCountLimit;
}

- (NSUInteger)maxMemoryCountLimit
{
    return self.memCache.countLimit;
}


- (void)clearMemory
{
    [self.memCache removeAllObjects];
}


- (void)clearDiskOnCompletion:(VCImageNoParamsBlock)completion
{
    dispatch_async(self.ioQueue, ^{
        
        [_fileManager removeItemAtPath:self.diskCachePath error:nil];
        
        [_fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
        
        if (completion)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                completion();
                
            });
        }
        
    });
}

- (void)deleteOldFiles
{
    [self deleteOldFilesWithCompletionBlock:nil];
}

- (void)deleteOldFilesWithCompletionBlock:(VCImageNoParamsBlock)completionBlock
{
    dispatch_async(self.ioQueue, ^{
        
        NSURL *diskCacheURL=[NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        
        NSArray<NSString *> *resourceKeys=@[NSURLIsDirectoryKey,NSURLContentModificationDateKey,NSURLTotalFileAllocatedSizeKey];
        
        NSDirectoryEnumerator *fileEnumerator=[_fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:resourceKeys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        
        NSDate *expirationData=[NSDate dateWithTimeIntervalSinceNow:-self.config.maxCacheAge];
        
        NSMutableDictionary<NSURL *,NSDictionary<NSString *,id> *> *cacheFiles=[NSMutableDictionary dictionary];
        
        NSUInteger currentCacheSize=0;
        
        NSMutableArray<NSURL *> *urlsToDelete=[[NSMutableArray alloc]init];
        
        for (NSURL *fileURL in fileEnumerator)
        {
            NSError *error;
            
            NSDictionary<NSString *,id> *resourceValues=[fileURL resourceValuesForKeys:resourceKeys error:&error];
            
            if (error||!resourceKeys||[resourceValues[NSURLIsDirectoryKey] boolValue])
            {
                continue;
            }
            
            NSDate *modificationDate=resourceValues[NSURLContentModificationDateKey];
            
            if ([[modificationDate laterDate:expirationData] isEqualToDate:expirationData])
            {
                [urlsToDelete addObject:fileURL];
                
                continue;
            }
            
            NSNumber *totalAllocatedSize=resourceValues[NSURLTotalFileAllocatedSizeKey];
            
            currentCacheSize+=totalAllocatedSize.unsignedIntegerValue;
            
            cacheFiles[fileURL]=resourceValues;
        }
        
        for (NSURL *fileURL in urlsToDelete)
        {
            [_fileManager removeItemAtURL:fileURL error:nil];
        }
        
        if (self.config.maxCacheSize>0&&currentCacheSize>self.config.maxCacheSize/2)
        {
            const NSUInteger desiredCacheSize=self.config.maxCacheSize/2;
            
            NSArray<NSURL *> *sortedFiles=[cacheFiles keysSortedByValueWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                
                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                
            }];
            
            
            for (NSURL *fileURL in sortedFiles)
            {
                if ([_fileManager removeItemAtURL:fileURL error:nil])
                {
                    NSDictionary<NSString *,id> *resourceValues=cacheFiles[fileURL];
                    
                    NSNumber *totalAllocatedSize=resourceValues[NSURLTotalFileAllocatedSizeKey];
                    
                    currentCacheSize-=totalAllocatedSize.unsignedIntegerValue;
                    
                    if (currentCacheSize<desiredCacheSize)
                    {
                        break;
                    }
                }
            }
        }
        
        if (completionBlock)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                completionBlock();
                
            });
        }
        
    });
}

- (void)backgroundDeleteOldFiles
{
    UIApplication *application=[UIApplication sharedApplication];
    
    __block UIBackgroundTaskIdentifier bgTask=[application beginBackgroundTaskWithExpirationHandler:^{
        
        [application endBackgroundTask:bgTask];
        
        bgTask=UIBackgroundTaskInvalid;
        
    }];
    
    [self deleteOldFilesWithCompletionBlock:^{
        
        [application endBackgroundTask:bgTask];
        
        bgTask=UIBackgroundTaskInvalid;
        
    }];
}

- (NSUInteger)getSize
{
    __block NSUInteger size=0;
    
    dispatch_sync(self.ioQueue, ^{
        
        NSDirectoryEnumerator *fileEnumerator=[_fileManager enumeratorAtPath:self.diskCachePath];
        
        for (NSString *fileName in fileEnumerator)
        {
            NSString *filePath=[self.diskCachePath stringByAppendingPathComponent:fileName];
            
            NSDictionary<NSString *,id> *attrs=[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            
            size+=[attrs fileSize];
        }
        
    });
    
    return size;
}

- (NSUInteger)getDiskCount
{
    __block NSUInteger count=0;
    
    dispatch_async(self.ioQueue, ^{
        
        NSDirectoryEnumerator *fileEnumerator=[_fileManager enumeratorAtPath:self.diskCachePath];
        
        count=fileEnumerator.allObjects.count;
        
    });
    
    return count;
}

- (void)calculateSizeWithCompletionBlock:(VCImageCalculateSizeBlock)completionBlock
{
    NSURL *diskCacheURL=[NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        
        NSUInteger fileCount=0;
        
        NSUInteger totalSize=0;
        
        NSDirectoryEnumerator *fileEnumerator=[_fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:@[NSFileSize] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        
        for (NSURL *fileURL in fileEnumerator)
        {
            NSNumber *fileSize;
            
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            
            totalSize+=fileSize.unsignedIntegerValue;
            
            fileCount++;
            
        }
        
        if (completionBlock)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                completionBlock(fileCount,totalSize);
                
            });
        }
        
    });
}

@end














