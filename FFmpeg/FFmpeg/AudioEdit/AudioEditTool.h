//
//  AudioEditTool.h
//  AudioEdit
//
//  Created by tangtianshuai on 2017/9/4.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioEditTool : NSObject

+ (void)clipAudioAtFilePath:(NSString *)srcPath toPath:(NSString *)dstPath startTime:(int64_t)startTime endTime:(int64_t)endTime completion:(void(^)(BOOL isSuccess,NSError *error))completion;

@end
