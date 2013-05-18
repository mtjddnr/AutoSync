//
//  FSEventNotificationCenter.m
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import "FSEventNotificationCenter.h"
#import "FSEventNotificationReceiver.h"

NSString * const FSEventDidReceiveNotification = @"FSEventDidReceiveNotification";
NSString * const FSEventDidReceiveNotificationEventPathsKey = @"FSEventDidReceiveNotificationEventPathsKey";


@implementation FSEventNotificationCenter {
    NSMutableDictionary *_paths;
}

static FSEventNotificationCenter *__sharedCenter = nil;

+ (id)sharedCenter {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedCenter = [[FSEventNotificationCenter alloc] init];
    });
    return __sharedCenter;
}

- (NSArray *)paths {
    return [_paths allKeys];
}

- (void)addPath:(NSString *)path {
    if (_paths == nil) _paths = [[NSMutableDictionary alloc] init];
    
    FSEventNotificationReceiver *receiver = [[FSEventNotificationReceiver alloc] initWithPath:path];
    receiver.target = self;
    _paths[path] = receiver;
}
- (void)removePath:(NSString *)path {
    [_paths removeObjectForKey:path];
}


- (void)onReceiveEvent:(NSString *)forPath eventPaths:(NSArray *)eventPaths {
    [[NSNotificationCenter defaultCenter] postNotificationName:FSEventDidReceiveNotification
                                                        object:forPath
                                                      userInfo:@{ FSEventDidReceiveNotificationEventPathsKey: eventPaths }];
}
@end
