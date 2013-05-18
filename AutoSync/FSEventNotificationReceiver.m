//
//  FSEventNotificationReceiver.m
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import "FSEventNotificationReceiver.h"
#include <CoreServices/CoreServices.h>

@interface FSEventNotificationCenter (private)
- (void)onReceiveEvent:(NSString *)forPath eventPaths:(NSArray *)eventPaths;
@end

@implementation FSEventNotificationReceiver {
    FSEventStreamRef stream;    
}
- (id)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = path;
        [self initializeEventStream];
    }
    return self;
}
void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]) {
    NSArray *paths = (__bridge NSArray *)eventPaths;

    FSEventNotificationReceiver *receiver = (__bridge FSEventNotificationReceiver *)userData; 
    [receiver.target onReceiveEvent:receiver.path eventPaths:paths];
}

- (void)initializeEventStream {
    NSString *myPath = _path;
    NSArray *pathsToWatch = [NSArray arrayWithObject:myPath];
    NSTimeInterval latency = 3.0;
    void *appPointer = (__bridge void *)self;
    FSEventStreamContext context = {0, appPointer, NULL, NULL, NULL};
    stream = FSEventStreamCreate(NULL, //allocator
                                 &fsevents_callback, //callback
                                 &context, //context
                                 (__bridge CFArrayRef)pathsToWatch, //pathsToWatch
                                 kFSEventStreamEventIdSinceNow, //sinceWhen
                                 (CFAbsoluteTime) latency, //latency
                                 kFSEventStreamCreateFlagUseCFTypes //flags
                                 );
    
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
}

- (void)dealloc {
    FSEventStreamStop(stream);
    NSLog(@"dealloc");
}
@end
