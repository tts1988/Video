//
//  VideoCoverImageDownloaderOperation.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/10.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoCoverImageDownloader.h"


@interface VideoCoverImageDownloaderOperation : NSOperation<VideoCoverImageOperation>

@property(nonatomic,strong,readonly)NSURLRequest *request;

@property(nonatomic,assign)BOOL shouldDecompressImages;

@property(nonatomic,assign)NSInteger expectedSize;

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (id)addHandlesForCompleted:(VCImageDownloaderCompletedBlock)completedBlock;

- (BOOL)cancel:(id)token;

@end
