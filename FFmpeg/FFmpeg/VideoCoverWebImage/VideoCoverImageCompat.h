//
//  VideoCoverImageCompat.h
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import <TargetConditionals.h>
#import <UIKit/UIKit.h>

#if OS_OBJECT_USE_OBJC
#undef VCDispatchQueueRelease
#undef VCDispatchQueueSetterSementics
#define VCDispatchQueueRelease(q)
#define VCDispatchQueueSetterSementics strong
#else
#undef VCDispatchQueueRelease
#undef VCDispatchQueueSetterSementics
#define VCDispatchQueueRelease(q) (dispatch_release(q))
#define VCDispatchQueueSetterSementics assign
#endif

typedef void(^VCImageNoParamsBlock)(void);

extern NSString *const VCWebImageErrorDomain;

#ifndef dispatch_main_custom_async_safe
#define dispatch_main_custom_async_safe(block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}
#endif



