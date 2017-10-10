//
//  ViewController.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/9/5.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "ViewController.h"
#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#import <libswscale/swscale.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "UIImageView+WebCache.h"
#import "VideoCoverImageDownloader.h"
#import "UIImageView+VideoCoverCache.h"

@interface ViewController ()

@property(nonatomic,weak)IBOutlet UIImageView *imageView1;

@property(nonatomic,weak)IBOutlet UIImageView *imageView2;

@property(nonatomic,weak)IBOutlet UIImageView *imageView3;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString *url=@"http://www.86ps.com/imgWeb/psd/hf_fj/FJ_159.jpg";
    
    [self.imageView3 sd_setImageWithURL:[NSURL URLWithString:url] placeholderImage:nil options:SDWebImageRefreshCached];
}

- (IBAction)pressButton:(id)sender
{
    NSString *videoURL = @"http://192.168.2.32/aigei1.mp4";
    
    NSString *videoURL2=[NSString stringWithFormat:@"%@",videoURL];
    
    NSURL *url=[NSURL URLWithString:videoURL];
    
    NSURL *url2=[NSURL URLWithString:videoURL2];
    
    if ([url isEqual:url2])
    {
        NSLog(@"isEqual");
    }
    
    if ([url hash]==[url2 hash])
    {
        NSLog(@"hashEqual");
    }
    
    NSMutableSet *set=[NSMutableSet set];
    
    [set addObject:url];
    
    if ([set containsObject:url2])
    {
        NSLog(@"set contain %ld", SDWebImageRetryFailed<<1);
    }
    
    
    
//    MPMoviePlayerController *iosMPMovie = [[MPMoviePlayerController alloc]initWithContentURL:[NSURL URLWithString:videoURL]];
//    
//    iosMPMovie.shouldAutoplay = NO;
//    
//    UIImage *thumbnail = [iosMPMovie thumbnailImageAtTime:0 timeOption:MPMovieTimeOptionNearestKeyFrame];

    
    self.imageView1.image=[self getVideoPreViewImage:videoURL];
    
}

- (UIImage*)getVideoPreViewImage:(NSString *)videoPath
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL URLWithString:videoPath] options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
 
    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *img = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    
    return img;
}




- (IBAction)pressFFmpegButton:(id)sender
{
    self.imageView2.image=nil;
    
    NSURL *url=[NSURL URLWithString:@"http://192.168.2.32/aigei.mov"];
    
    [self getVideoThumnailWithURL:url];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self getVideoThumnailWithURL:url];
    });
    
    
}


- (void)getVideoThumnailWithURL:(NSURL *)url
{
    [self.imageView2 vc_setImageWithURL:url];
}

- (void)getVideoThumnail
{
    av_register_all();
    
    avcodec_register_all();
    
    avformat_network_init();
    
    avcodec_register_all();
    
    
    AVFormatContext *formatContext=avformat_alloc_context();
    
    NSString *filePath=[[NSBundle mainBundle]pathForResource:@"1" ofType:@"mkv"];
    
    filePath=@"http://192.168.2.32/aigei.mov";
    
    //filePath=[NSURL fileURLWithPath:filePath].absoluteString;
    
    ;
    
    if (avformat_open_input(&formatContext, [filePath UTF8String], NULL, NULL)!=0)
    {
        return;
    }
    
    int videoStream=-1;
    
    for (int i=0; i<formatContext->nb_streams; i++)
    {
        if (formatContext->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO)
        {
            videoStream=i;
        }
    }
    
    AVCodecContext *codecContext=formatContext->streams[videoStream]->codec;
    
    AVCodec *codec=avcodec_find_decoder(codecContext->codec_id);
    
    if (codec==NULL)
    {
        NSLog(@"解码器未找到");
    }
    else
    {
        NSLog(@"解码器获取成功");
    }
    
    if (avcodec_open2(codecContext, codec, NULL)<0)
    {
        NSLog(@"解码器打开失败");
    }
    else
    {
        NSLog(@"解码器打开成功");
    }
    
    AVFrame *pFrame=av_frame_alloc();
    
    AVFrame *pFrameRGB=av_frame_alloc();
    
    struct SwsContext *img_convert_ctx=sws_getContext(codecContext->width, codecContext->height, AV_PIX_FMT_YUV420P, codecContext->width, codecContext->height, PIX_FMT_RGB24, SWS_FAST_BILINEAR, NULL, NULL, NULL);
    
    int numBytes=avpicture_get_size(PIX_FMT_RGB24, codecContext->width, codecContext->height);
    
    uint8_t *out_buffer=av_malloc(numBytes*sizeof(uint8_t));
    
    avpicture_fill((AVPicture *)pFrameRGB, out_buffer, PIX_FMT_BGR24, codecContext->width, codecContext->height);
    
    int y_size=codecContext->width*codecContext->height;
    
    AVPacket *packet=(AVPacket *)malloc(sizeof(AVPacket));
    
    av_new_packet(packet, y_size);
    
    av_dump_format(formatContext, 0, filePath.UTF8String, 0);
    
    int got_picture;
    
    int ret;
    
    int index=0;
    
    while(1)
    {
        if (av_read_frame(formatContext, packet)<0)//是否找到下一帧
        {
            break;
        }
        
        if (packet->stream_index==videoStream)
        {
            ret=avcodec_decode_video2(codecContext, pFrame,&got_picture , packet);
            
            if (ret<0)
            {
                NSLog(@"解码失败");
                
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
                
                self.imageView2.image=image;
                
                break;
                
            }
        }
    }
}

- (void)getVideoThumnailWithURL:(NSURL *)url completedBlock:(VCImageDownloaderCompletedBlock)completedBlock
{
    
    
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
    
    if (avformat_open_input(&formatContext, [filePath UTF8String], NULL, NULL)!=0)
    {
        return;
    }
    
    int videoStream=-1;
    
    for (int i=0; i<formatContext->nb_streams; i++)
    {
        if (formatContext->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO)
        {
            videoStream=i;
        }
    }
    
    AVCodecContext *codecContext=formatContext->streams[videoStream]->codec;
    
    AVCodec *codec=avcodec_find_decoder(codecContext->codec_id);
    
    if (codec==NULL)
    {
        
        
        NSLog(@"解码器未找到");
    }
    else
    {
        NSLog(@"解码器获取成功");
    }
    
    if (avcodec_open2(codecContext, codec, NULL)<0)
    {
        NSLog(@"解码器打开失败");
    }
    else
    {
        NSLog(@"解码器打开成功");
    }
    
    AVFrame *pFrame=av_frame_alloc();
    
    AVFrame *pFrameRGB=av_frame_alloc();
    
    struct SwsContext *img_convert_ctx=sws_getContext(codecContext->width, codecContext->height, AV_PIX_FMT_YUV420P, codecContext->width, codecContext->height, PIX_FMT_RGB24, SWS_FAST_BILINEAR, NULL, NULL, NULL);
    
    int numBytes=avpicture_get_size(PIX_FMT_RGB24, codecContext->width, codecContext->height);
    
    uint8_t *out_buffer=av_malloc(numBytes*sizeof(uint8_t));
    
    avpicture_fill((AVPicture *)pFrameRGB, out_buffer, PIX_FMT_BGR24, codecContext->width, codecContext->height);
    
    int y_size=codecContext->width*codecContext->height;
    
    AVPacket *packet=(AVPacket *)malloc(sizeof(AVPacket));
    
    av_new_packet(packet, y_size);
    
    av_dump_format(formatContext, 0, filePath.UTF8String, 0);
    
    int got_picture;
    
    int ret;
    
    int index=0;
    
    while(1)
    {
        if (av_read_frame(formatContext, packet)<0)//是否找到下一帧
        {
            break;
        }
        
        if (packet->stream_index==videoStream)
        {
            ret=avcodec_decode_video2(codecContext, pFrame,&got_picture , packet);
            
            if (ret<0)
            {
                NSLog(@"解码失败");
                
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
                
                self.imageView2.image=image;
                
                break;
                
            }
        }
    }

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
