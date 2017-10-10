//
//  VideoCoverImageManager.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "VideoCoverImageManager.h"

@interface VCImageCombinedOperation : NSObject<VideoCoverImageOperation>

@property(nonatomic,assign,getter=isCancelled)BOOL cancelled;

@property(nonatomic,copy)VCImageNoParamsBlock cancelBlock;

@property(nonatomic,strong)NSOperation *cacheOperation;

@end


@interface VideoCoverImageManager ()

@property(nonatomic,strong,readwrite)VideoCoverImageCache *imageCache;

@property(nonatomic,strong,readwrite)VideoCoverImageDownloader *imageDownloader;

@property(nonatomic,strong)NSMutableSet<NSURL *> *failedURLs;

@property(nonatomic,strong)NSMutableArray<VCImageCombinedOperation *> *runningOperations;

@end

@implementation VideoCoverImageManager

+ (instancetype)sharedManager
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
    VideoCoverImageCache *cache=[VideoCoverImageCache sharedImageCache];
    
    VideoCoverImageDownloader *downloader=[VideoCoverImageDownloader sharedDownloader];
    
    return [self initWithCache:cache downloader:downloader];
}

- (instancetype)initWithCache:(VideoCoverImageCache *)cache downloader:(VideoCoverImageDownloader *)downloader
{
    if ((self=[super init]))
    {
        _imageCache=cache;
        
        _imageDownloader=downloader;
        
        _failedURLs=[NSMutableSet set];
        
        _runningOperations=[NSMutableArray new];
    }
    
    return self;
}

- (NSString *)cacheKeyForURL:(NSURL *)url
{
    if (!url)
    {
        return @"";
    }
    
    if (self.cacheKeyFilter)
    {
        return self.cacheKeyFilter(url);
    }
    else
    {
        return [url.absoluteString stringByDeletingPathExtension];
    }
}

- (void)cachedImageExistsForURL:(NSURL *)url completion:(VCImageCheckCacheCompletionBlock)completionBlock
{
    NSString *key=[self cacheKeyForURL:url];
    
    BOOL isInMemoryCache=[self.imageCache imageFromCacheForKey:key]!=nil;
    
    if (isInMemoryCache)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (completionBlock)
            {
                completionBlock(YES);
            }
            
        });
        
        return;
    }
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        
        if (completionBlock)
        {
            completionBlock(isInDiskCache);
        }
        
    }];
    
}

- (void)diskImageExistsForURL:(NSURL *)url completion:(VCImageCheckCacheCompletionBlock)completionBlock
{
    NSString *key=[self cacheKeyForURL:url];
    
    [self.imageCache diskImageExistsWithKey:key completion:^(BOOL isInDiskCache) {
        
        if (completionBlock)
        {
            completionBlock(isInDiskCache);
        }
        
    }];
}

- (id<VideoCoverImageOperation>)loadImageWithURL:(NSURL *)url completed:(VCInternalCompletionBlock)completedBlock
{
    if ([url isKindOfClass:[NSString class]])
    {
        url=[NSURL URLWithString:(NSString *)url];
    }
    
    if (![url isKindOfClass:[NSURL class]])
    {
        url=nil;
    }
    
    __block VCImageCombinedOperation *operation=[VCImageCombinedOperation new];
    
    __weak VCImageCombinedOperation *weakOperation=operation;
    
    BOOL isFailedUrl=NO;
    
    if (url)
    {
        @synchronized (self.failedURLs)
        {
            isFailedUrl=[self.failedURLs containsObject:url];
        }
    }
    
    if (url.absoluteString.length==0||isFailedUrl)
    {
        NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil];
        
        [self callCompletionBlockForOperation:operation completion:completedBlock error:error url:url];
        
        return operation;
    }
    
    @synchronized (self.runningOperations)
    {
        [self.runningOperations addObject:operation];
    }
    
    NSString *key=[self cacheKeyForURL:url];
    
    operation.cacheOperation=[self.imageCache queryCacheOperationForKey:key done:^(UIImage *cachedImage,NSData *cachedData,VideoCoverImageCacheType cacheType){
        
        if (operation.isCancelled)
        {
            [self safelyRemoveOperationFromRunning:operation];
            
            return ;
        }
        
        if (cachedImage)
        {
            __strong __typeof(weakOperation) strongOperation = weakOperation;
            
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            
            [self safelyRemoveOperationFromRunning:operation];
        }
        else
        {
            VideoCoverImageDownloadToken *subOperationToken=[self.imageDownloader downloadImageWithURL:url completed:^(UIImage *downloadedImage, NSData *downloadedData, NSError *error, BOOL finished) {
                
                __strong __typeof(weakOperation) strongOperation=weakOperation;
                
                if (!strongOperation||strongOperation.isCancelled)
                {
                    
                }
                else if (error)
                {
                    [self callCompletionBlockForOperation:strongOperation completion:completedBlock error:error url:url];
                    
                    if (error.code!=NSURLErrorNotConnectedToInternet&&error.code!=NSURLErrorCancelled&&error.code!=NSURLErrorTimedOut&&error.code!=NSURLErrorInternationalRoamingOff&&error.code!=NSURLErrorDataNotAllowed&&error.code!=NSURLErrorCannotFindHost&&error.code!=NSURLErrorNotConnectedToInternet&&error.code!=NSURLErrorNetworkConnectionLost) {
                        @synchronized (self.failedURLs)
                        {
                            [self.failedURLs addObject:url];
                        }
                    }
                }
                else
                {
                    if (downloadedImage&&finished)
                    {
                        [self.imageCache storeImage:downloadedImage imageData:downloadedData forKey:key toDisk:YES completion:nil];
                    }
                    
                    [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:downloadedImage data:downloadedData error:nil cacheType:VideoCoverImageCacheTypeNone finished:finished url:url];
                    
                    if (finished)
                    {
                        [self safelyRemoveOperationFromRunning:strongOperation];
                    }
                }
                
            }];
            
            operation.cancelBlock=^{
                
                [self.imageDownloader cancel:subOperationToken];
                
                __strong __typeof(weakOperation) strongOperation=weakOperation;
                
                [self safelyRemoveOperationFromRunning:strongOperation];
                
            };
        }
        
        
        
    }];
    
    
    return operation;
}


- (void)savaImageToCache:(UIImage *)image forURL:(NSURL *)url
{
    if (image&&url)
    {
        NSString *key=[self cacheKeyForURL:url];
        
        [self.imageCache storeImage:image forKey:key toDisk:YES completion:nil];
    }
}

- (void)cancelAll
{
    @synchronized (self.runningOperations)
    {
        NSArray<VCImageCombinedOperation *> *copiedOperattions=[self.runningOperations copy];
        
        [copiedOperattions makeObjectsPerformSelector:@selector(cancel)];
        
        [self.runningOperations removeObjectsInArray:copiedOperattions];
    }
}

- (BOOL)isRunning
{
    BOOL isRunning=NO;
    
    @synchronized (self.runningOperations)
    {
        isRunning=(self.runningOperations.count>0);
    }
    
    return isRunning;
}

- (void)safelyRemoveOperationFromRunning:(VCImageCombinedOperation *)operation
{
    @synchronized (self.runningOperations)
    {
        if (operation)
        {
            [self.runningOperations removeObject:operation];
        }
    }
}

- (void)callCompletionBlockForOperation:(VCImageCombinedOperation *)operation completion:(VCInternalCompletionBlock)completionBlock error:(NSError *)error url:(NSURL *)url
{
    [self callCompletionBlockForOperation:operation completion:completionBlock image:nil data:nil error:error cacheType:VideoCoverImageCacheTypeNone finished:YES url:url];
}

- (void)callCompletionBlockForOperation:(VCImageCombinedOperation *)operation completion:(VCInternalCompletionBlock)completionBlock image:(UIImage *)image data:(NSData *)data error:(NSError *)error cacheType:(VideoCoverImageCacheType)cacheType finished:(BOOL)finished url:(NSURL *)url
{
    dispatch_main_custom_async_safe(^{
        
        if (operation&&!operation.isCancelled&&completionBlock)
        {
            completionBlock(image,data,error,cacheType,finished,url);
        }
        
    });
}

@end

@implementation VCImageCombinedOperation

- (void)setCancelBlock:(VCImageNoParamsBlock)cancelBlock
{
    if (self.isCancelled)
    {
        if (cancelBlock)
        {
            cancelBlock();
        }
        
        _cancelled=nil;
    }
    else
    {
        _cancelBlock=[cancelBlock copy];
    }
}

- (void)cancel
{
    self.cancelled=YES;
    
    if (self.cacheOperation)
    {
        [self.cacheOperation cancel];
        
        self.cacheOperation=nil;
    }
    
    if (self.cancelBlock)
    {
        self.cancelBlock();
        
        _cancelBlock=nil;
    }
}

@end









