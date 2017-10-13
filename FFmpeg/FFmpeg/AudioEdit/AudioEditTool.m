//
//  AudioEditTool.m
//  AudioEdit
//
//  Created by tangtianshuai on 2017/9/4.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "AudioEditTool.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioEditTool

+ (void)clipAudioAtFilePath:(NSString *)srcPath toPath:(NSString *)dstPath startTime:(int64_t)startTime endTime:(int64_t)endTime completion:(void(^)(BOOL isSuccess,NSError *error))completion
{
    //1 判断待编辑语音文件是否存在
    NSFileManager *fileManager=[NSFileManager defaultManager];
    
    BOOL isExist=[fileManager fileExistsAtPath:srcPath];
    
    if (!isExist)
    {
        NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:@{@"文件不存在":NSLocalizedDescriptionKey}];
        
        if (completion)
        {
            completion(NO,error);
        }
        
        return;
    }
    
    //2 获取到待编辑的语音文件
    NSURL *srcURL=[NSURL fileURLWithPath:srcPath];
    
    AVURLAsset *srcAsset=[AVURLAsset assetWithURL:srcURL];
    
    //3 创建新的语音文件
    if ([fileManager fileExistsAtPath:srcPath])
    {
        [fileManager removeItemAtPath:srcPath error:nil];
    }
    
    
    NSError *assetError;
    
    NSURL *dstURL=[NSURL fileURLWithPath:dstPath];
    
    [AVAssetWriter assetWriterWithURL:dstURL fileType:AVFileTypeAppleM4A error:&assetError];
    
    if (assetError)
    {
        NSError *error=[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:@{@"创建文件失败":NSLocalizedDescriptionKey}];
        
        if (completion)
        {
            completion(NO,error);
        }
        
        return;
    }
    
    //4 创建音频输出会话
    AVAssetExportSession *exportSession=[AVAssetExportSession exportSessionWithAsset:srcAsset presetName:AVAssetExportPresetAppleM4A];
    
    NSArray *supportedFileTypes=[exportSession supportedFileTypes];
    
    NSLog(@"%@",supportedFileTypes);
    
    CMTime exportStartTime=CMTimeMake(startTime, 1);
    
    CMTime exportEndTime=CMTimeMake(endTime, 1);
    
    CMTimeRange exportTimeRange=CMTimeRangeMake(exportStartTime, exportEndTime);
    
    exportSession.outputURL=dstURL;
    
    exportSession.outputFileType=AVFileTypeAppleM4A;
    
    exportSession.timeRange=exportTimeRange;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        
        if (exportSession.status==AVAssetExportSessionStatusCompleted)//完成
        {
            if (completion)
            {
                completion(YES,nil);
            }
        }
        else if (exportSession.status==AVAssetExportSessionStatusFailed)
        {
            
        }
        else
        {
            
        }
        
    }];
    
}

@end


















