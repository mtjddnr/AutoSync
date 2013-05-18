//
//  FSEventNotificationCenter.h
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString * const FSEventDidReceiveNotification;
NSString * const FSEventDidReceiveNotificationEventPathsKey;

@interface FSEventNotificationCenter : NSObject
+ (id)sharedCenter;

@property (nonatomic, readonly) NSArray *paths;
- (void)addPath:(NSString *)path;
- (void)removePath:(NSString *)path;
@end
