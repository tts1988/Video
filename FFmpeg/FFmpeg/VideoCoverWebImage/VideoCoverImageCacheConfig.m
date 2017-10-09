//
//  VideoCoverImageCacheConfig.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "VideoCoverImageCacheConfig.h"

static const NSInteger kDefalutCacheMaxCacheAge = 60*60*24*7; // 1 week

@implementation VideoCoverImageCacheConfig

- (instancetype)init
{
    self=[super init];
    
    if (self)
    {
        _shouldDecompressImages=YES;
        
        _shouldDisableiCoud=YES;
        
        _shouldCacheImagesInMemory=YES;
        
        _maxCacheAge=kDefalutCacheMaxCacheAge;
        
        _maxCacheSize=0;
    }
    
    return self;
}

@end
