//
//  VideoCoverImageCacheConfig.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoCoverImageCacheConfig : NSObject

@property(nonatomic,assign)BOOL shouldDecompressImages;

@property(nonatomic,assign)BOOL shouldDisableiCoud;

@property(nonatomic,assign)BOOL shouldCacheImagesInMemory;

@property(nonatomic,assign)NSInteger maxCacheAge;

@property(nonatomic,assign)NSUInteger maxCacheSize;

@end
