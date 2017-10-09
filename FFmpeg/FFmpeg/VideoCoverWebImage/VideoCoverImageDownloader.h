//
//  VideoCoverImageDownloader.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^VCImageDownloaderCompletedBlock)(UIImage *image,NSData *data,NSError *error,BOOL finished);

@interface VideoCoverImageDownloadToken : NSObject

@property(nonatomic,strong)NSURL *url;

@property(nonatomic,strong)id downloadOperationCancelToken;

@end

@interface VideoCoverImageDownloader : NSObject


+ (instancetype)sharedDownloader;


- (VideoCoverImageDownloadToken *)downloadImageWithURL:(NSURL *)url completed:(VCImageDownloaderCompletedBlock)completedBlock;

- (void)cancel:(VideoCoverImageDownloadToken *)token;

- (void)setSuspended:(BOOL)suspended;

- (void)cancelAllDownloads;

@end
