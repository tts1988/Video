//
//  VideoCoverImageDownloader.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "VideoCoverImageCompat.h"
#import "VideoCoverImageOperation.h"

typedef NS_ENUM(NSInteger,VCImageDownloaderExecutionOrder){
    
    VCImageDownloaderFIFOExecutionOrder,
    
    VCImageDownloaderLIFOExecutionOrder
};

typedef void(^VCImageDownloaderCompletedBlock)(UIImage *image,NSData *data,NSError *error,BOOL finished);

@interface VideoCoverImageDownloadToken : NSObject

@property(nonatomic,strong)NSURL *url;

@property(nonatomic,strong)id downloadOperationCancelToken;

@end

@interface VideoCoverImageDownloader : NSObject

@property(nonatomic,assign)BOOL shouldDecompressImages;

@property(nonatomic,assign)NSInteger maxConcurrentDownloads;

@property(nonatomic,assign)NSUInteger currentDownloadCount;

@property(nonatomic,assign)NSTimeInterval downloadTimeout;

@property(nonatomic,assign)VCImageDownloaderExecutionOrder executionOrder;

+ (instancetype)sharedDownloader;


- (VideoCoverImageDownloadToken *)downloadImageWithURL:(NSURL *)url completed:(VCImageDownloaderCompletedBlock)completedBlock;

- (void)cancel:(VideoCoverImageDownloadToken *)token;

- (void)setSuspended:(BOOL)suspended;

- (void)cancelAllDownloads;

@end
