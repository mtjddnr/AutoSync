//
//  AppDelegate.m
//  AutoSync
//
//  Created by 문성욱 on 13. 5. 18..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import "AppDelegate.h"
#import "iTunesConnection.h"
#import "FSEventNotificationCenter.h"


#define SET_LIBPATH @"setting.LibPath"
#define SET_ROOTPATH @"setting.RootPath"
#define SET_SYNCTRACKS @"setting.SyncTracks"
#define SET_SYNCDELETEMISSINGFILE @"setting.SyncDeleteMissingFile"
#define SET_SYNCPLAYLISTS @"setting.SyncPlaylists"
#define SET_LAUNCHONSTART @"setting.LaunchOnStart"
#define SET_OTHERLOG @"setting.OtherLog"
#define SET_COMBINE @"setting.CombineSeperated"
#define LOGKEY @"Logs"

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    
    BOOL _syncing;

    NSMutableArray *_logs;
    
    BOOL _needSync;
    
    BOOL _statusAnimating;
    NSInteger _statusIndex;
    
    BOOL _libraryFileReady;
    BOOL _rootFolderReady;
}
#pragma mark - NSApplicationDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self.labelAboutVersion setStringValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"]];
    
    if (self.isFirstUse) {
        [self resetSettings];
        [self firstUse];
    } else {
        [self setupApplication:YES];
    }
    
    NSTableView *t = nil;
    [t display];
}


#pragma mark - Menu Events
- (IBAction)onMenuSync:(id)sender {
    [self doSync];
}
- (IBAction)onSetting:(id)sender {
    [self openSetting];
}
- (IBAction)onMenuAbout:(id)sender {
    [self.windowAbout makeKeyAndOrderFront:nil];
}
- (IBAction)onQuit:(id)sender {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [NSApp terminate:self];
}


#pragma mark - Status Bar Icon
- (void)activateStatusMenu {
    if (_statusItem != nil) return;
    
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
    _statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];
    
    [_statusItem setImage:[NSImage imageNamed:@"StatusIcon"]];
    [_statusItem setHighlightMode:YES];
    [_statusItem setMenu:self.menu];
}
- (void)deactivateStatusMenu {
    if (_statusItem != nil) {
        [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
        _statusItem = nil;
    }
}
#define StatusImageCount 18
- (void)setStatusSyncing:(BOOL)syncing {
    if (syncing && _statusAnimating == NO) {
        _statusAnimating = YES;
        _statusIndex = 0;
        //_statusItem.title = NSLocalizedString(@"동기화중.",@"");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            while (_statusAnimating || (_statusAnimating == NO && _statusIndex != 0)) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [_statusItem setImage:[NSImage imageNamed:[NSString stringWithFormat:@"StatusIcon_%02d", (int)_statusIndex]]];
                    
                    _statusIndex++;
                    _statusIndex %= StatusImageCount;
                });
                [NSThread sleepForTimeInterval:0.08];
            }
            dispatch_sync(dispatch_get_main_queue(), ^{
                //_statusItem.title = NSLocalizedString(@"AutoSync",@"");
                [_statusItem setImage:[NSImage imageNamed:@"StatusIcon"]];
            });
        });
    } else {
        _statusAnimating = NO;
    }
}


#pragma mark - Logs
#define MAX_LOG_DISPLAY_COUNT 5
#define MAX_LOG_COUNT 50
- (void)log:(NSString *)message {
    
    NSArray *logs = [[NSUserDefaults standardUserDefaults] objectForKey:LOGKEY];
    if (logs != nil) {
        _logs = [NSMutableArray arrayWithArray:logs];
    } else {
        _logs = [[NSMutableArray alloc] initWithCapacity:MAX_LOG_COUNT];
    }
    
    [_logs insertObject:message atIndex:0];
    
    if ([_logs count] > MAX_LOG_COUNT) {
        [_logs removeObjectsInRange:NSMakeRange(MAX_LOG_COUNT, [_logs count] - MAX_LOG_COUNT)];
    }
    [self updateLogs];
}
- (void)updateLogs {
    
    BOOL moreHidden = ([_logs count] <= MAX_LOG_DISPLAY_COUNT);
    
    [self.menuLogEndSeparator setHidden:([_logs count] == 0)];
    [self.menuLogMore setHidden:moreHidden];
    //Display Log
    NSInteger seperatorIndex = [self.menu indexOfItem:self.menuLogSeparator];
    __block NSInteger endIndex = [self.menu indexOfItem:self.menuLogMore];
    
    [_logs enumerateObjectsUsingBlock:^(NSString *message, NSUInteger idx, BOOL *stop) {
        if (idx < MAX_LOG_DISPLAY_COUNT) {
            NSInteger index = seperatorIndex + idx + 1;
            if (index >= endIndex) {
                NSMenuItem *newMenuItem = [[NSMenuItem alloc] init];
                [self.menu insertItem:newMenuItem atIndex:index];
                endIndex++;
            }
            NSMenuItem *menuItem = [self.menu itemAtIndex:index];
            [menuItem setEnabled:NO];
            menuItem.title = message;
        } else {
            NSInteger index = idx - MAX_LOG_DISPLAY_COUNT;
            if (index >= [self.menuLogMoreMenu numberOfItems]) {
                NSMenuItem *newMenuItem = [[NSMenuItem alloc] init];
                [self.menuLogMoreMenu addItem:newMenuItem];
            }
            NSMenuItem *menuItem = [self.menuLogMoreMenu itemAtIndex:index];
            [menuItem setEnabled:NO];
            menuItem.title = message;
        }
    }];
    
    [[NSUserDefaults standardUserDefaults] setObject:_logs forKey:LOGKEY];
}


#pragma mark - Properties
- (BOOL)isFirstUse {
    return self.libPath == nil;
}
- (void)setLibPath:(NSString *)libPath {
    [[NSUserDefaults standardUserDefaults] setObject:libPath forKey:SET_LIBPATH];
}
- (NSString *)libPath {
    return [[NSUserDefaults standardUserDefaults] stringForKey:SET_LIBPATH];
}
- (void)setRootPath:(NSString *)rootPath {
    if (self.rootPath != nil) {
        [[FSEventNotificationCenter sharedCenter] removePath:self.rootPath];
    }
    [[NSUserDefaults standardUserDefaults] setObject:rootPath forKey:SET_ROOTPATH];
    if (rootPath != nil) {
        [[FSEventNotificationCenter sharedCenter] addPath:rootPath];
    }
}
- (NSString *)rootPath {
    return [[NSUserDefaults standardUserDefaults] stringForKey:SET_ROOTPATH];
}
- (void)setSettingSyncTracks:(BOOL)settingSyncTracks {
    [[NSUserDefaults standardUserDefaults] setBool:settingSyncTracks forKey:SET_SYNCTRACKS];
}
- (BOOL)settingSyncTracks {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS];
}
- (void)setSettingSyncDelete:(BOOL)settingSyncDelete {
    [[NSUserDefaults standardUserDefaults] setBool:settingSyncDelete forKey:SET_SYNCDELETEMISSINGFILE];
}
- (BOOL)settingSyncDelete {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE];
}
- (void)setSettingSyncPlaylists:(BOOL)settingSyncPlaylists {
    [[NSUserDefaults standardUserDefaults] setBool:settingSyncPlaylists forKey:SET_SYNCPLAYLISTS];
}
- (BOOL)settingSyncPlaylists {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS];
}
- (void)setSettingLaunchOnStart:(BOOL)settingLaunchOnStart {
    [NSApp disableRelaunchOnLogin];
    if (settingLaunchOnStart) {
        [NSApp enableRelaunchOnLogin];
    }
    [[NSUserDefaults standardUserDefaults] setBool:settingLaunchOnStart forKey:SET_LAUNCHONSTART];
}
- (BOOL)settingLaunchOnStart {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SET_LAUNCHONSTART];
}
- (void)setSettingOtherLog:(BOOL)settingOtherLog {
    [[NSUserDefaults standardUserDefaults] setBool:settingOtherLog forKey:SET_OTHERLOG];
}
- (BOOL)settingOtherLog {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SET_OTHERLOG];
}
- (void)setSettingCombineSeperated:(BOOL)settingCombineSeperated {
    [[NSUserDefaults standardUserDefaults] setBool:settingCombineSeperated forKey:SET_COMBINE];
}
- (BOOL)settingCombineSeperated {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SET_COMBINE];
}

#pragma mark - Sync
- (void)onFSEvent:(NSNotification *)noti {
    NSArray *eventPaths = noti.userInfo[FSEventDidReceiveNotificationEventPathsKey];
    NSLog(@"Root Folder Modified Notification: %@", eventPaths);
    _needSync = YES;
    [self doSync];
}
- (void)doSync {
    if (self.settingSyncTracks == NO && self.settingSyncPlaylists == NO && self.settingSyncDelete == NO) return;
    if (self.rootPath == nil) return;
    
    if (_syncing) return;
    _syncing = YES;
    _needSync = NO;
    
    [self setEnabledWhileSync:NO];
    
    BOOL syncTrack = self.settingSyncTracks;
    BOOL syncDelete = self.settingSyncDelete;
    BOOL syncPlaylist = self.settingSyncPlaylists;
    BOOL syncCombine = self.settingCombineSeperated;
    
    self.menuRecentDate.title = NSLocalizedString(@"동기화중...", @"");
    
    NSString *libPath = self.libPath;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        iTunesConnection *iTunes = [[iTunesConnection alloc] init];
        iTunes.onAddTrackEvent = ^(NSString *filePath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *path = [filePath substringFromIndex:[self.rootPath length]];
                [self log:[NSString stringWithFormat:NSLocalizedString(@"추가 %@", @""), path]];
            });
        };
        iTunes.onDeleteTrackEvent = ^(NSString *filePath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *path = [filePath substringFromIndex:[self.rootPath length]];
                [self log:[NSString stringWithFormat:NSLocalizedString(@"삭제 %@", @""), path]];
            });
        };
        iTunes.onAddPlaylistEvent = ^(NSString *path) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self log:[NSString stringWithFormat:NSLocalizedString(@"+ %@", @""), path]];
            });
        };
        iTunes.onDeletePlaylistEvent = ^(NSString *path) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self log:[NSString stringWithFormat:NSLocalizedString(@"- %@", @""), path]];
            });
        };
        
        void(^onOtherEvent)(NSString *message) = ^(NSString *message) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", message);
                if (self.settingOtherLog) {
                    [self log:message];
                }
            });
        };
        iTunes.onOtherEvent = onOtherEvent;
        
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue addOperationWithBlock:^{
            onOtherEvent(@"Start Load iTunes Tracks");
            [iTunes loadiTunesTracks];
            onOtherEvent([NSString stringWithFormat:@"Done Load iTunes Tracks: %i", (int)[iTunes iTunesTrackCount]]);
        }];
        [queue addOperationWithBlock:^{
            onOtherEvent(@"Start Load Library Plist Tracks");
            [iTunes loadLibraryFileWithPath:libPath];
            onOtherEvent([NSString stringWithFormat:@"Done Load Library Plist Tracks: %i", (int)[iTunes libTrackCount]]);
        }];
        
        [queue waitUntilAllOperationsAreFinished];
        if ([self breakIfNeedResync]) return;
        
        iTunes.rootPath = self.rootPath;
        iTunes.rootName = [self.rootPath lastPathComponent];
        
        if (syncTrack) {
            [queue addOperationWithBlock:^{
                onOtherEvent(@"Searching Files");
                [iTunes searchFiles:iTunes.rootPath];
                onOtherEvent([NSString stringWithFormat:@"Done Searching Files: %i", (int)[iTunes.files count]]);
            }];
        }
        onOtherEvent([NSString stringWithFormat:@"recover Missing Location Tracks: %i", (int)[iTunes.libTracksByIdWithNoLocation count]]);
        [iTunes recoverMissingLocationLibTracksFromiTunesTracks:iTunes.iTunesTracksById];
        
        onOtherEvent([NSString stringWithFormat:@"Tracks: %i", (int)[iTunes iTunesTrackCount]]);
        
        if (syncDelete) {
            NSArray *missingTrackIds = [iTunes findMissingFileLibTrackIds];
            onOtherEvent([NSString stringWithFormat:@"File Missing Tracks: %i", (int)[missingTrackIds count]]);
            
            if ([missingTrackIds count] > 0) {
                onOtherEvent(@"Deleting Missing Tracks");
                [iTunes deleteTracks:missingTrackIds];
                onOtherEvent(@"Done Deleting Missing Tracks");
                
                onOtherEvent([NSString stringWithFormat:@"Tracks: %i", (int)[iTunes iTunesTrackCount]]);
            }
        }
        
        [queue waitUntilAllOperationsAreFinished];
        if ([self breakIfNeedResync]) return;
        
        if (syncTrack) {
            onOtherEvent(@"Sync Tracks...");
            BOOL modified = [iTunes syncFiles:iTunes.files currentFiles:[iTunes.libTracksByLocation allKeys]];
            if (modified) {
                onOtherEvent(@"Reloading Tracks...");
                [queue addOperationWithBlock:^{
                    [iTunes loadiTunesTracks];
                }];
                [queue addOperationWithBlock:^{
                    [iTunes loadLibraryFileWithPath:libPath];
                }];
                
                [queue waitUntilAllOperationsAreFinished];
                
                [iTunes recoverMissingLocationLibTracksFromiTunesTracks:iTunes.iTunesTracksById];
                
                onOtherEvent([NSString stringWithFormat:@"Tracks: %i", (int)[iTunes iTunesTrackCount]]);
            }
            if ([self breakIfNeedResync]) return;
        }
        
        if (syncPlaylist) {
            [queue addOperationWithBlock:^{
                onOtherEvent(@"Build Playlists");
                [iTunes buildPlaylistFromLibTracks:iTunes.libTracksByLocation rootPath:iTunes.rootPath];
                
                if (syncCombine) {
                    [iTunes combinePlaylistsIfSeperatedDiscAlbums];
                }
                
                [iTunes buildFolders];
                
                onOtherEvent([NSString stringWithFormat:@"Done Build Playlists: %i Folders, %i Playlists", (int)[iTunes.libFolders count], (int)[iTunes.libPlaylists count]]);
            }];
            
            [queue addOperationWithBlock:^{
                onOtherEvent(@"Load iTunes Playlists");
                [iTunes loadiTunesPlaylists];
                onOtherEvent([NSString stringWithFormat:@"Done Load iTunes Playlists: %i Folders, %i Playlists", (int)[iTunes.iTunesFolders count], (int)[iTunes.iTunesUserPlaylists count]]);
            }];
            
            [queue waitUntilAllOperationsAreFinished];
            
            onOtherEvent(@"Sync playlist structure");
            [iTunes synciTunesFolder:iTunes.libFolders AndPlaylist:[iTunes.libPlaylists allKeys]];
            onOtherEvent([NSString stringWithFormat:@"Done Playlists: %i Folders, %i Playlists", (int)[iTunes.iTunesFolders count], (int)[iTunes.iTunesUserPlaylists count]]);
            
            onOtherEvent(@"Sync playlist Tracks");
            [iTunes synciTunesPlaylistTracks:iTunes.libPlaylists];
            
        }
        onOtherEvent(@"Done");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _syncing = NO;
            [self setEnabledWhileSync:YES];
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            
            self.menuRecentDate.title = [dateFormatter stringFromDate:[NSDate date]];
            
            self.menuInfoSongs.title = [NSString stringWithFormat:NSLocalizedString(@"%i 곡", @""), (int)iTunes.libTrackCount];
            self.menuInfoPlaylists.title = [NSString stringWithFormat:NSLocalizedString(@"%i 목록", @""), (int)[[iTunes.libPlaylists allKeys] count]];
            
            if (_needSync) {
                [self doSync];
            }
        });
        
    });
}
- (BOOL)breakIfNeedResync {
    if (_needSync == NO) return NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        _syncing = NO;
        [self doSync];
    });
    return YES;
}
- (void)setEnabledWhileSync:(BOOL)enabled {
    if (enabled == NO) {
        [self.menuSync setHidden:YES];
        [self setStatusSyncing:YES];
        [self.menuSetting setEnabled:NO];
    } else {
        [self.menuSync setHidden:NO];
        [self setStatusSyncing:NO];
        [self.menuSetting setEnabled:YES];
    }
}


#pragma mark - Manage Sync App
- (void)setupApplication:(BOOL)needSyncNow {
    assert(self.rootPath != nil);
    
    [self activateStatusMenu];
    
    self.menuMusicRoot.title = self.rootPath;
    [self updateLogs];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFSEvent:) name:FSEventDidReceiveNotification object:nil];
    
    self.rootPath = self.rootPath;
    
    if (needSyncNow) {
        [self doSync];
    }
}
- (void)firstUse {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingWindowWillClose:) name:NSWindowWillCloseNotification object:nil];
    
    [self openSetting];
}
- (void)settingWindowWillClose:(NSNotification *)notification {
    if (notification.object == self.windowSetting) {
        [NSApp terminate:self];
    }
}

#pragma mark - Setting
- (void)openSetting {
    _libraryFileReady = NO;
    _rootFolderReady = NO;
    
    [self.settingTab selectTabViewItemAtIndex:0];
    
    [self.windowSetting makeKeyAndOrderFront:nil];
    
    [self.popUpButtonSelectMusicFolder setEnabled:NO];
    
    self.popUpMenuLibraryFile.title = NSLocalizedString(@"준비중...", @"");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if (self.libPath == nil) {
            NSString *path = [iTunesConnection defaultLibraryFilePath];
            if ([iTunesConnection isLibraryValid:path]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.popUpMenuLibraryFile.title = path;
                });
                _libraryFileReady = YES;
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.popUpMenuLibraryFile.title = NSLocalizedString(@"파일 없음", @"");
                });
                _libraryFileReady = NO;
            }
        } else {
            _libraryFileReady = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.popUpMenuLibraryFile.title = self.libPath;
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.popUpButtonSelectMusicFolder setEnabled:_libraryFileReady];
            
            if (_libraryFileReady) {
                if (self.rootPath == nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self discoverMusicRoot:self.popUpMenuLibraryFile.title];
                    });
                } else {
                    _rootFolderReady = YES;
                    self.popUpButtonMenuRootPath.title = self.rootPath;
                }
            }
            
            if (self.libPath != nil) {
                self.checkBoxSyncFiles.state = self.settingSyncTracks ? 1 : 0;
                self.checkBoxSyncDelete.state = self.settingSyncDelete ? 1 : 0;
                self.checkBoxSyncPlaylist.state = self.settingSyncPlaylists ? 1 : 0;
                self.checkBoxLaunchOnStart.state = self.settingLaunchOnStart ? 1 : 0;
                self.checkBoxShowOtherLogs.state = self.settingOtherLog ? 1 : 0;
                self.checkBoxCombineSeperated.state = self.settingCombineSeperated ? 1 : 0;
            }
            [self updateDoneButtonStatus];
        });
        
    });
    
    
    
}

#pragma mark Select Library File
- (IBAction)onPopUpButtonMenuSelectOtherLibraryFile:(id)sender {
    [self.popUpSelectLibraryFile selectItemAtIndex:0];
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setAllowedFileTypes:@[ @"xml", @"plist" ]];
    
    [panel beginSheetModalForWindow:self.windowSetting
                  completionHandler:^(NSInteger result) {
    //[panel beginWithCompletionHandler:^(NSInteger result) {
                      if (result == NSFileHandlingPanelOKButton) {
                          NSString *path = [panel.URL path];
                          
                          NSFileManager *fs = [NSFileManager defaultManager];
                          BOOL isDir = NO;
                          if ([fs fileExistsAtPath:path isDirectory:&isDir] && isDir == NO
                              && [iTunesConnection isLibraryValid:path]) {
                              self.popUpMenuLibraryFile.title = path;
                              _libraryFileReady = YES;
                              
                              if (self.rootPath == nil) {
                                  [self discoverMusicRoot:path];
                              } else {
                                  _rootFolderReady = YES;
                                  self.popUpButtonMenuRootPath.title = self.rootPath;
                              }
                              
                          } else {
                              NSAlert *alert = [NSAlert alertWithMessageText:@"iTunes 라이브러리 파일이 아닙니다." defaultButton:@"확인" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
                              [alert runModal];
                          }
                      }
                  }];
}

#pragma mark Select Root Folder
- (void)discoverMusicRoot:(NSString *)libPath {
    self.popUpButtonMenuRootPath.title = NSLocalizedString(@"경로 찾는중...", @"");
    [self.popUpButtonSelectMusicFolder setEnabled:NO];
    [self.popUpSelectLibraryFile setEnabled:NO];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        iTunesConnection *iTunes = [[iTunesConnection alloc] init];
        [iTunes loadLibraryFileWithPath:libPath];
        
        NSArray *locations = [iTunes.libTracksByLocation allKeys];
        if ([locations count] > 0) {
            [iTunes discoverRootPathFromLocations:locations];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSString *rootPath = iTunes.rootPath;
            
            if (rootPath == nil) {
                self.popUpButtonMenuRootPath.title = NSLocalizedString(@"경로를 찾을수 없습니다", @"");
                _rootFolderReady = NO;
            } else {
                self.popUpButtonMenuRootPath.title = rootPath;
                _rootFolderReady = YES;
            }
            [self.popUpButtonSelectMusicFolder setEnabled:YES];
            [self.popUpSelectLibraryFile setEnabled:YES];
            [self updateDoneButtonStatus];
        });
        
    });
}


- (IBAction)onPopUpButtonMenuSelectOtherRootPath:(id)sender {
    [self.popUpButtonSelectMusicFolder selectItemAtIndex:0];
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    
    [panel beginSheetModalForWindow:self.windowSetting
                  completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSString *path = [panel.URL path];
            
            NSFileManager *fs = [NSFileManager defaultManager];
            BOOL isDir = NO;
            if ([fs fileExistsAtPath:path isDirectory:&isDir] && isDir) {
                _rootFolderReady = YES;
                self.popUpButtonMenuRootPath.title = path;
            } else {
                NSAlert *alert = [NSAlert alertWithMessageText:@"폴더가 아닙니다." defaultButton:@"확인" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
                [alert runModal];
            }
        }
    }];
    
}

- (IBAction)onChangeCheck:(id)sender {
    [self updateDoneButtonStatus];
}

- (void)updateDoneButtonStatus {
    if (_rootFolderReady == NO || _libraryFileReady == NO) {
        [self.buttonDone setEnabled:NO];
        return;
    }
    
    if (self.checkBoxSyncFiles.state == 0
        && self.checkBoxSyncPlaylist.state == 0
        && self.checkBoxSyncDelete.state == 0) {
        [self.buttonDone setEnabled:NO];
        return;
    }
    
    [self.buttonDone setEnabled:YES];
}
- (IBAction)onButtonDone:(id)sender {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.windowSetting close];
    
    self.libPath = self.popUpMenuLibraryFile.title;
    
    NSString *newPath = self.popUpButtonMenuRootPath.title;
    
    BOOL needSync = [self.rootPath isEqualToString:newPath] == NO;
    self.rootPath = newPath;
    
    self.settingSyncTracks = (self.checkBoxSyncFiles.state != 0);
    self.settingSyncDelete = (self.checkBoxSyncDelete.state != 0);
    self.settingSyncPlaylists = (self.checkBoxSyncPlaylist.state != 0);
    self.settingLaunchOnStart = (self.checkBoxLaunchOnStart.state != 0);
    self.settingOtherLog = (self.checkBoxShowOtherLogs.state != 0);
    self.settingCombineSeperated = (self.checkBoxCombineSeperated.state != 0);
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self setupApplication:needSync];
}



#pragma mark - Debug

- (void)resetApp {
    [self resetSettings];
    
    [NSApp terminate:self];
}
- (void)resetSettings {
    NSArray *keys = @[ SET_LIBPATH,
                       SET_ROOTPATH,
                       SET_SYNCTRACKS,
                       SET_SYNCDELETEMISSINGFILE,
                       SET_SYNCPLAYLISTS,
                       SET_LAUNCHONSTART,
                       SET_OTHERLOG,
                       SET_COMBINE,
                       LOGKEY];
    
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    
    [keys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
        [settings removeObjectForKey:key];
    }];
    [settings synchronize];
}


- (IBAction)onButtonReset:(id)sender {
    [self resetApp];
}
@end
