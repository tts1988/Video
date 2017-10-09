//
//  UIView+VideoCoverCacheOperation.m
//  FFmpeg
//
//  Created by tangtianshuai on 2017/10/9.
//  Copyright © 2017年 tangtianshuai. All rights reserved.
//

#import "UIView+VideoCoverCacheOperation.h"

#import <objc/runtime.h>

static char vcLoadOperationKey;

typedef NSMutableDictionary<NSString *,id> VCOperationsDictionary;

@implementation UIView (VideoCoverCacheOperation)

-(VCOperationsDictionary *)operationDictionary
{
    VCOperationsDictionary *operations=objc_getAssociatedObject(self, &vcLoadOperationKey);
    
    if (operations)
    {
        return operations;
    }
    
    operations=[NSMutableDictionary dictionary];
    
    objc_setAssociatedObject(self, &vcLoadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return operations;
}

- (void)vc_setImageLoadOperation:(id)operation forKey:(NSString *)key
{
    if (key)
    {
        [self vc_cancelImageLoadOperationWithKey:key];
        
        if (operation)
        {
            VCOperationsDictionary *operationDictionary=[self operationDictionary];
            
            operationDictionary[key]=operation;
        }
    }
}


- (void)vc_cancelImageLoadOperationWithKey:(NSString *)key
{
    VCOperationsDictionary *operationDictionary=[self operationDictionary];
    
    id operations=operationDictionary[key];
    
    if (operations)
    {
        if ([operations isKindOfClass:[NSArray class]])
        {
            for (id<VideoCoverImageOperation> operation in operations)
            {
                [operation cancel];
            }
        }
        else if ([operations conformsToProtocol:@protocol(VideoCoverImageOperation)])
        {
            [(id<VideoCoverImageOperation>) operations cancel];
        }
        
        [operationDictionary removeObjectForKey:key];
    }
}

- (void)vc_removeImageLoadOperationWithKey:(NSString *)key
{
    if (key)
    {
        VCOperationsDictionary *operationDictionary=[self operationDictionary];
        
        [operationDictionary removeObjectForKey:key];
    }
}

@end








