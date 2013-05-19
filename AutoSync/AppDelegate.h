//
//  AppDelegate.h
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (nonatomic) NSString *rootPath;

@property (strong) IBOutlet NSMenu *menu;
- (IBAction)onQuit:(id)sender;

@property (weak) IBOutlet NSMenuItem *menuMusicRoot;
- (IBAction)onSetting:(id)sender;


@property (weak) IBOutlet NSMenuItem *menuRecentDate;

@property (weak) IBOutlet NSMenuItem *menuSettingChangePath;

@property (weak) IBOutlet NSMenuItem *menuSetting;
@property (weak) IBOutlet NSMenuItem *menuSettingSyncTracks;
@property (weak) IBOutlet NSMenuItem *menuSettingSyncDeleteMissingFile;
@property (weak) IBOutlet NSMenuItem *menuSettingSyncPlaylists;
@property (weak) IBOutlet NSMenuItem *menuSettingLaunchOnStart;
@property (weak) IBOutlet NSMenuItem *menuSettingOtherLog;

- (IBAction)onSettingSyncTracks:(id)sender;
- (IBAction)onSettingSyncPlaylists:(id)sender;
- (IBAction)onSettingSyncDeleteMissingFile:(id)sender;
- (IBAction)onSettingLaunchOnStart:(id)sender;
- (IBAction)onSettingOtherLog:(id)sender;


@property (weak) IBOutlet NSMenuItem *menuInfoSongs;
@property (weak) IBOutlet NSMenuItem *menuInfoPlaylists;


@property (weak) IBOutlet NSMenuItem *menuLogSeparator;
@property (weak) IBOutlet NSMenuItem *menuLogMore;
@property (weak) IBOutlet NSMenu *menuLogMoreMenu;
@property (weak) IBOutlet NSMenuItem *menuLogEndSeparator;

@property (weak) IBOutlet NSMenuItem *menuQuit;

@property (weak) IBOutlet NSMenuItem *menuSync;
- (IBAction)onMenuSync:(id)sender;

- (IBAction)onMenuAbout:(id)sender;
@property (weak) IBOutlet NSPanel *panelAbout;


@property (unsafe_unretained) IBOutlet NSWindow *windowFirstUse;


@property (weak) IBOutlet NSPopUpButton *popUpButtonSelectMusicFolder;
@property (weak) IBOutlet NSMenuItem *popUpButtonMenuRootPath;
@property (weak) IBOutlet NSMenuItem *popUpButtonMenuSelectOtherRootPath;
- (IBAction)onPopUpButtonMenuSelectOtherRootPath:(id)sender;

@property (weak) IBOutlet NSButton *checkBoxSyncFiles;
@property (weak) IBOutlet NSButton *checkBoxSyncDelete;
@property (weak) IBOutlet NSButton *checkBoxSyncPlaylist;
@property (weak) IBOutlet NSButton *checkBoxLaunchOnStart;

- (IBAction)onChangeCheck:(id)sender;


@property (weak) IBOutlet NSButton *buttonDone;
- (IBAction)onButtonDone:(id)sender;







@end
