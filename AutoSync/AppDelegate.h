//
//  AppDelegate.h
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

#pragma mark - Menu
@property (strong) IBOutlet NSMenu *menu;

@property (weak) IBOutlet NSMenuItem *menuSync;
- (IBAction)onMenuSync:(id)sender;

@property (weak) IBOutlet NSMenuItem *menuMusicRoot;

@property (weak) IBOutlet NSMenuItem *menuInfoSongs;
@property (weak) IBOutlet NSMenuItem *menuInfoPlaylists;

@property (weak) IBOutlet NSMenuItem *menuRecentDate;

@property (weak) IBOutlet NSMenuItem *menuLogSeparator;
@property (weak) IBOutlet NSMenuItem *menuLogMore;
@property (weak) IBOutlet NSMenu *menuLogMoreMenu;
@property (weak) IBOutlet NSMenuItem *menuLogEndSeparator;

@property (weak) IBOutlet NSMenuItem *menuSetting;
- (IBAction)onSetting:(id)sender;

- (IBAction)onMenuAbout:(id)sender;

@property (weak) IBOutlet NSMenuItem *menuQuit;
- (IBAction)onQuit:(id)sender;

#pragma mark - About
@property (unsafe_unretained) IBOutlet NSWindow *windowAbout;
@property (weak) IBOutlet NSTextField *labelAboutVersion;

#pragma mark - Setting
@property (unsafe_unretained) IBOutlet NSWindow *windowSetting;
@property (weak) IBOutlet NSTabView *settingTab;

#pragma mark Library
@property (weak) IBOutlet NSPopUpButton *popUpSelectLibraryFile;
@property (weak) IBOutlet NSMenuItem *popUpMenuLibraryFile;
@property (weak) IBOutlet NSMenuItem *popUpMenuLibraryOther;
- (IBAction)onPopUpButtonMenuSelectOtherLibraryFile:(id)sender;

#pragma mark RootFolder
@property (weak) IBOutlet NSPopUpButton *popUpButtonSelectMusicFolder;
@property (weak) IBOutlet NSMenuItem *popUpButtonMenuRootPath;
@property (weak) IBOutlet NSMenuItem *popUpButtonMenuSelectOtherRootPath;
- (IBAction)onPopUpButtonMenuSelectOtherRootPath:(id)sender;

#pragma mark Settings
@property (weak) IBOutlet NSButton *checkBoxSyncFiles;
@property (weak) IBOutlet NSButton *checkBoxSyncDelete;
@property (weak) IBOutlet NSButton *checkBoxSyncPlaylist;

@property (weak) IBOutlet NSButton *checkBoxLaunchOnStart;
@property (weak) IBOutlet NSButton *checkBoxShowOtherLogs;

- (IBAction)onChangeCheck:(id)sender;

@property (weak) IBOutlet NSButton *buttonReset;
- (IBAction)onButtonReset:(id)sender;

#pragma mark Done
@property (weak) IBOutlet NSButton *buttonDone;
- (IBAction)onButtonDone:(id)sender;


#pragma mark - NSUserDefaults Linked Properties
@property (nonatomic, readonly) BOOL isFirstUse;
@property (nonatomic) NSString *libPath;
@property (nonatomic) NSString *rootPath;
@property (nonatomic) BOOL settingSyncTracks;
@property (nonatomic) BOOL settingSyncPlaylists;
@property (nonatomic) BOOL settingSyncDelete;
@property (nonatomic) BOOL settingLaunchOnStart;
@property (nonatomic) BOOL settingOtherLog;

@end
