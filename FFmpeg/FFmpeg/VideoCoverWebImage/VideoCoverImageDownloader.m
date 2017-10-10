//
//  VideoCoverImageDownloader.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "VideoCoverImageDownloader.h"
#import "VideoCoverImageDownloaderOperation.h"


@implementation VideoCoverImageDownloadToken



@end

@interface VideoCoverImageDownloader ()

@property(nonatomic,strong)NSOperationQueue *downloadQueue;

@property(nonatomic,weak)NSOperation *lastAddedOperation;

@property(nonatomic,assign)Class operationClass;

@property(nonatomic,strong)NSMutableDictionary<NSURL *,VideoCoverImageDownloaderOperation *> *URLOperations;

@property(VCDispatchQueueSetterSementics,nonatomic)dispatch_queue_t barrierQueue;

@end

@implementation VideoCoverImageDownloader

+ (instancetype)sharedDownloader
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
    self=[super init];
    
    if (self)
    {
        _operationClass=[VideoCoverImageDownloaderOperation class];
        
        _shouldDecompressImages=YES;
        
        _executionOrder=VCImageDownloaderFIFOExecutionOrder;
        
        _downloadQueue=[NSOperationQueue new];
        
        _downloadQueue.maxConcurrentOperationCount=6;
        
        _downloadQueue.name=@"com.BYG.VideoCoverImageDownloader";
        
        _URLOperations=[NSMutableDictionary new];
        
        _barrierQueue=dispatch_queue_create("com.BYG.VideoCoverImageDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        
        _downloadTimeout=15.0;

    }
    
    return self;
}

- (void)dealloc
{
    [self.downloadQueue cancelAllOperations];
    
    VCDispatchQueueRelease(_barrierQueue);
}

- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads
{
    _downloadQueue.maxConcurrentOperationCount=maxConcurrentDownloads;
}

- (NSInteger)maxConcurrentDownloads
{
    return _downloadQueue.maxConcurrentOperationCount;
}

- (NSUInteger)currentDownloadCount
{
    return _downloadQueue.operationCount;
}



- (VideoCoverImageDownloadToken *)downloadImageWithURL:(NSURL *)url completed:(VCImageDownloaderCompletedBlock)completedBlock
{
    __weak VideoCoverImageDownloader *wself=self;
    
    return [self addCompletedBlock:completedBlock forURL:url createCallBack:^VideoCoverImageDownloaderOperation *{
        
        __strong __typeof(wself) sself=wself;
        
        NSTimeInterval timeoutInterval=sself.downloadTimeout;
        
        if (timeoutInterval==0.0)
        {
            timeoutInterval=15.0;
        }
        
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
        
        request.timeoutInterval=timeoutInterval;
        
        VideoCoverImageDownloaderOperation *operation=[[sself.operationClass alloc]initWithRequest:request];
        
        operation.shouldDecompressImages=sself.shouldDecompressImages;
        
        [sself.downloadQueue addOperation:operation];
        
        if (sself.executionOrder==VCImageDownloaderLIFOExecutionOrder)
        {
            [sself.lastAddedOperation addDependency:operation];
            
            sself.lastAddedOperation=operation;
        }
        
        return operation;
        
    }];
}

- (void)cancel:(VideoCoverImageDownloadToken *)token
{
    dispatch_barrier_async(self.barrierQueue, ^{
        
        VideoCoverImageDownloaderOperation *operation=self.URLOperations[token.url];
        
        BOOL canceld=[operation cancel:token.downloadOperationCancelToken];
        
        if (canceld)
        {
            [self.URLOperations removeObjectForKey:token.url];
        }
        
    });
}

- (VideoCoverImageDownloadToken *)addCompletedBlock:(VCImageDownloaderCompletedBlock)completedBlock forURL:(NSURL *)url createCallBack:(VideoCoverImageDownloaderOperation *(^)(void))createCallBack
{
    if (url==nil)
    {
        if (completedBlock)
        {
            completedBlock(nil,nil,nil,NO);
        }
        
        return nil;
    }
    
    __block VideoCoverImageDownloadToken *token=nil;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        
        VideoCoverImageDownloaderOperation *operation=self.URLOperations[url];
        
        if (!operation)
        {
            operation=createCallBack();
            
            self.URLOperations[url]=operation;
            
            __weak VideoCoverImageDownloaderOperation *woperation=operation;
            
            operation.completionBlock=^{
                
                dispatch_barrier_sync(self.barrierQueue, ^{
                   
                    VideoCoverImageDownloaderOperation *soperation=woperation;
                    
                    if (!soperation)
                    {
                        return ;
                    }
                    
                    if (self.URLOperations[url]==soperation)
                    {
                        [self.URLOperations removeObjectForKey:url];
                    }
                    
                });
                
            };
        }
        
        id downloadOperationCancelToken=[operation addHandlesForCompleted:completedBlock];
        
        token=[VideoCoverImageDownloadToken new];
        
        token.url=url;
        
        token.downloadOperationCancelToken=downloadOperationCancelToken;
        
    });
    
    return token;
}

- (void)setSuspended:(BOOL)suspended
{
    self.downloadQueue.suspended=suspended;
}

- (void)cancelAllDownloads
{
    [self.downloadQueue cancelAllOperations];
}


@end






