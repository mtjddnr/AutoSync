//
//  AppDelegate.h
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic) NSString *rootPath;

@property (strong) IBOutlet NSMenu *menu;
- (IBAction)onQuit:(id)sender;

@property (weak) IBOutlet NSMenuItem *menuMusicRoot;
- (IBAction)onSetting:(id)sender;


@property (weak) IBOutlet NSMenuItem *menuRecentSeparator;
@property (weak) IBOutlet NSMenuItem *menuRecentDate;

@property (weak) IBOutlet NSMenuItem *menuSetting;
@property (weak) IBOutlet NSMenuItem *menuSettingSyncTracks;
@property (weak) IBOutlet NSMenuItem *menuSettingSyncDeleteMissingFile;
@property (weak) IBOutlet NSMenuItem *menuSettingSyncPlaylists;
- (IBAction)onSettingSyncTracks:(id)sender;
- (IBAction)onSettingSyncPlaylists:(id)sender;
- (IBAction)onSettingSyncDeleteMissingFile:(id)sender;

@end
