//
//  VideoCoverImageDownloaderOperation.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/10.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "VideoCoverImageDownloaderOperation.h"
#import "SDWebImageDecoder.h"
#import "UIImage+MultiFormat.h"
#import <ImageIO/ImageIO.h>
#import "VideoCoverImageManager.h"
#import "NSImage+WebCache.h"
#import "NSData+ImageContentType.h"

#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#import <libswscale/swscale.h>

static NSString *const kVCCompletedCallbackKey= @"completed";

typedef NSMutableDictionary<NSString *, id> VCCallbacksDictionary;

@interface VideoCoverThumnailDownloader : NSObject

@end


@interface VideoCoverImageDownloaderOperation ()

@property(nonatomic,strong)NSMutableArray<VCCallbacksDictionary *> *callbackBlocks;

@property(nonatomic,assign, getter = isExecuting) BOOL executing;

@property(nonatomic,assign,getter=isFinished)BOOL finished;

@property(VCDispatchQueueSetterSementics,nonatomic)dispatch_queue_t barrierQueue;

@property(VCDispatchQueueSetterSementics,nonatomic)dispatch_queue_t downloadQueue;

@property(nonatomic,assign)UIBackgroundTaskIdentifier backgroundTaskId;

@property(nonatomic,assign)AVFormatContext *formatContext;

@property(nonatomic,strong)dispatch_block_t timeoutBlock;

@end

@implementation VideoCoverImageDownloaderOperation

@synthesize executing=_executing;

@synthesize finished=_finished;

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    self=[super init];
    
    if (self)
    {
        _request=[request copy];
        
        _callbackBlocks=[NSMutableArray new];
        
        _executing=NO;
        
        _finished=NO;
        
        _expectedSize=0;
        _barrierQueue=dispatch_queue_create("com.BYG.VideoCoverImageDownloaderOperationBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        
        _downloadQueue=dispatch_queue_create("com.BYG.VideoCoverImageDownloaderOperationDownloadQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

- (void)dealloc
{
    VCDispatchQueueRelease(_barrierQueue);
    
    VCDispatchQueueRelease(_downloadQueue);
}

- (id)addHandlesForCompleted:(VCImageDownloaderCompletedBlock)completedBlock
{
    VCCallbacksDictionary *callbacks=[NSMutableDictionary new];
    
    if (completedBlock)
    {
        callbacks[kVCCompletedCallbackKey]=[completedBlock copy];
        
        dispatch_barrier_async(self.barrierQueue, ^{
            
            [self.callbackBlocks addObject:callbacks];
        });
    }
    
    return callbacks;
}

- (NSArray<id> *)callbacksForKey:(NSString *)key
{
    __block NSMutableArray<id> *callbacks=nil;
    
    dispatch_sync(self.barrierQueue, ^{
        
        callbacks=[[self.callbackBlocks valueForKey:key] mutableCopy];
        
        [callbacks removeObjectIdenticalTo:[NSNull null]];
        
    });
    
    return [callbacks copy];
}

- (BOOL)cancel:(id)token
{
    __block BOOL shouldCancel=NO;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        
        [self.callbackBlocks removeObjectIdenticalTo:token];
        
        if (self.callbackBlocks.count==0)
        {
            shouldCancel=YES;
        }
        
        if (shouldCancel)
        {
            [self cancel];
        }
        
    });
    
    return shouldCancel;
}

- (void)start
{
    @synchronized (self)
    {
        if (self.isCancelled)
        {
            self.finished=YES;
            
            [self reset];
            
            return;
        }
    }
    
    //开始下载获取视频封面
    [self getVideoThumnailWithURL:self.request.URL];
}

- (void)cancel
{
    @synchronized (self)
    {
        [self cancelInternal];
    }
}

- (void)cancelInternal
{
    if (self.isFinished)
    {
        return;
    }
    
    if (self.isExecuting)
    {
        self.executing=NO;
    }
    
    if (!self.isFinished)
    {
        self.finished=YES;
    }
    
    [super cancel];
    
    [self reset];
}

- (void)done
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.finished=YES;
        
        self.executing=NO;
        
        self.formatContext=NULL;
        
        self.downloadQueue=nil;
        
        [self reset];

        
    });
    
   
}

- (void)reset
{
    __weak typeof(self) weakSelf=self;
    
    dispatch_barrier_async(self.barrierQueue, ^{
        
        [weakSelf.callbackBlocks removeAllObjects];
    });
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    
    _finished=finished;
    
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    
    _executing=executing;
    
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (void)callCompletionBlocksWithError:(NSError *)error
{
    [self callCompletionBlocksWithImage:nil imageData:nil error:error finished:YES];
}

- (void)callCompletionBlocksWithImage:(UIImage *)image imageData:(NSData *)imageData error:(NSError *)error finished:(BOOL)finished
{
    NSArray<id> *completionBlocks=[self callbacksForKey:kVCCompletedCallbackKey];
    
    dispatch_main_custom_async_safe(^{
        
        for (VCImageDownloaderCompletedBlock completedBlock in completionBlocks)
        {
            completedBlock(image,imageData,error,finished);
        }
        
    });
}

- (void)getVideoThumnailWithURL:(NSURL *)url
{
    __weak typeof(self) wself=self;
    
    dispatch_async(wself.downloadQueue, ^{
        
        NSString *filePath=url.absoluteString;
        
        if (filePath.length==0)
        {
            return;
        }
        
        av_register_all();
        
        avcodec_register_all();
        
        avformat_network_init();
        
        avcodec_register_all();
        
        AVFormatContext *formatContext=avformat_alloc_context();
        
        wself.formatContext=formatContext;
        
        if (!wself)
        {
            return;
        }
        
        //打开视频输入流并读取头部（网络请求）
        int open_input_result=avformat_open_input(&formatContext, [filePath UTF8String], NULL, NULL);
        
        if (open_input_result!=0)
        {
            NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:@{NSLocalizedDescriptionKey:@"open input error"}];
            
            [wself callCompletionBlocksWithError:error];
            
            [wself done];
            
            return;
        }
        
        if (!wself)
        {
            return;
        }
        
        int videoStream=-1;
        
        for (int i=0; i<formatContext->nb_streams; i++)
        {
            if (formatContext->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO)
            {
                videoStream=i;
                
                break;
            }
        }
        
        AVCodecContext *codecContext=formatContext->streams[videoStream]->codec;
        
        AVCodec *codec=avcodec_find_decoder(codecContext->codec_id);
        
        if (codec==NULL)
        {
            NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:@{NSLocalizedDescriptionKey:@"find decoder error"}];
            
            avformat_close_input(&formatContext);
            
            [wself callCompletionBlocksWithError:error];
            
            [wself done];
        }
        
        
        if (avcodec_open2(codecContext, codec, NULL)<0)
        {
            
            NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:@{NSLocalizedDescriptionKey:@"open decoder error"}];
            
            avformat_close_input(&formatContext);
            
            [wself callCompletionBlocksWithError:error];
            
            [wself done];
        }
        
        AVFrame *pFrame=av_frame_alloc();
        
        AVFrame *pFrameRGB=av_frame_alloc();
        
        struct SwsContext *img_convert_ctx=sws_getContext(codecContext->width, codecContext->height, AV_PIX_FMT_YUV420P, codecContext->height, codecContext->width, AV_PIX_FMT_RGB24, SWS_FAST_BILINEAR, NULL, NULL, NULL);
        
    
        
        int numBytes=avpicture_get_size(AV_PIX_FMT_RGB24, codecContext->width, codecContext->height);
        
        uint8_t *out_buffer=av_malloc(numBytes*sizeof(uint8_t));
        
        avpicture_fill((AVPicture *)pFrameRGB, out_buffer, AV_PIX_FMT_BGR24, codecContext->width, codecContext->height);
        
        int y_size=codecContext->width*codecContext->height;
        
        AVPacket *packet=(AVPacket *)malloc(sizeof(AVPacket));
        
        av_new_packet(packet, y_size);
        
        av_dump_format(formatContext, 0, filePath.UTF8String, 0);
        
        int got_picture;
        
        int ret;
        
        while(1)
        {
            //是否找到下一帧(网络请求)
            if (av_read_frame(formatContext, packet)<0)
            {
                NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"Downloaded image has 0 frame"}];
                
                avformat_close_input(&formatContext);
                
                [wself callCompletionBlocksWithError:error];
                
                [wself done];
                
                break;
            }
            
            if (!wself)
            {
                return;
            }
            
            if (packet->stream_index==videoStream)
            {
                ret=avcodec_decode_video2(codecContext, pFrame,&got_picture , packet);
                
                if (ret<0)
                {
                    NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:@{NSLocalizedDescriptionKey:@"open decoder error"}];
                    
                    avformat_close_input(&formatContext);
                    
                    [wself callCompletionBlocksWithError:error];
                    
                    [wself done];
                    
                    break;
                }
                
                if (got_picture)
                {
                    sws_scale(img_convert_ctx, (uint8_t const* const*)pFrame->data, pFrame->linesize, 0, codecContext->height, pFrameRGB->data, pFrameRGB->linesize);
                    
                    int width=codecContext->width;
                    
                    int height=codecContext->height;
                    
                    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
                    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                                  pFrameRGB->data[0],
                                                  pFrameRGB->linesize[0] * height);
                    
                    
                    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    CGImageRef cgImage = CGImageCreate(width,
                                                       height,
                                                       8,
                                                       24,
                                                       pFrameRGB->linesize[0],
                                                       colorSpace,
                                                       bitmapInfo,
                                                       provider,
                                                       NULL,
                                                       NO,
                                                       kCGRenderingIntentDefault);
                    
                    
                    UIImage *image = [UIImage imageWithCGImage:cgImage];
                    
                    NSData * imageData = [image sd_imageDataAsFormat:SDImageFormatUndefined];
                    
                    avformat_close_input(&formatContext);
                    
                    [wself callCompletionBlocksWithImage:image imageData:imageData error:nil finished:YES];
                    
                    [wself done];
                    
                    break;
                }
            }

        }

    });
    
    dispatch_block_t timeoutBlock=^{
        
        if (wself)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [wself cancel];
                
            });
        }
        
    };
    
    self.timeoutBlock=timeoutBlock;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wself.request.timeoutInterval * NSEC_PER_SEC)), self.downloadQueue, timeoutBlock);
    
}

@end



