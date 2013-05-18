//
//  FSEventNotificationReceiver.h
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FSEventNotificationCenter.h"

@interface FSEventNotificationReceiver : NSObject

- (id)initWithPath:(NSString *)path;

@property (nonatomic, weak) FSEventNotificationCenter *target;
@property (nonatomic, readonly) NSString *path;
@end
