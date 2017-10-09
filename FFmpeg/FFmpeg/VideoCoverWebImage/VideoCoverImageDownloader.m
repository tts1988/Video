//
//  VideoCoverImageDownloader.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "VideoCoverImageDownloader.h"

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

@end
