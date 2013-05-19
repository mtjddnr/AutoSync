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

#define ROOTPATH @"rootPath"
#define SET_SYNCTRACKS @"setting.SyncTracks"
#define SET_SYNCDELETEMISSINGFILE @"setting.SyncDeleteMissingFile"
#define SET_SYNCPLAYLISTS @"setting.SyncPlaylists"
#define SET_LAUNCHONSTART @"setting.LaunchOnStart"
#define SET_OTHERLOG @"setting.OtherLog"
#define LOGKEY @"Logs"

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    
    BOOL _syncing;

    NSMutableArray *_logs;
    
    BOOL _needSync;
    
    BOOL _statusAnimating;
    NSInteger _statusIndex;
    
    BOOL _firstRootFolderReady;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:ROOTPATH];
    
    self.rootPath = [[NSUserDefaults standardUserDefaults] stringForKey:ROOTPATH];
    if (self.rootPath == nil) {
        [self firstUse];
    } else {
        [self setupApplication];
    }
}
- (void)setupApplication {
    assert(self.rootPath != nil);
    
    [self activateStatusMenu];
    
    self.menuMusicRoot.title = self.rootPath;
    NSArray *logs = [[NSUserDefaults standardUserDefaults] objectForKey:LOGKEY];
    if (logs != nil) {
        _logs = [NSMutableArray arrayWithArray:logs];
        
        [self updateLogs];
    }

    self.menuSettingSyncTracks.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS] ? 1 : 0;
    self.menuSettingSyncDeleteMissingFile.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE] ? 1 : 0;
    self.menuSettingSyncPlaylists.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS] ? 1 : 0;
    self.menuSettingLaunchOnStart.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_LAUNCHONSTART] ? 1 : 0;
    self.menuSettingOtherLog.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_OTHERLOG] ? 1 : 0;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFSEvent:) name:FSEventDidReceiveNotification object:nil];
    
    [self doSync];
}

- (void)activateStatusMenu {
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
    _statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];
    
    //[_statusItem setTitle:NSLocalizedString(@"AutoSync", @"")];
    [_statusItem setImage:[NSImage imageNamed:@"StatusIcon"]];
    [_statusItem setHighlightMode:YES];
    [_statusItem setMenu:self.menu];
}

- (IBAction)onQuit:(id)sender {
    exit(0);
}

- (IBAction)onSetting:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSString *path = [panel.URL path];
            
            NSFileManager *fs = [NSFileManager defaultManager];
            BOOL isDir = NO;
            if ([fs fileExistsAtPath:path isDirectory:&isDir] && isDir) {
                self.rootPath = path;
                self.menuMusicRoot.title = self.rootPath;
                [[NSUserDefaults standardUserDefaults] setObject:self.rootPath forKey:ROOTPATH];
            } else {
                NSAlert *alert = [NSAlert alertWithMessageText:@"폴더가 아닙니다." defaultButton:@"확인" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
                [alert runModal];
            }
        }
    }];
}

- (IBAction)onSettingSyncTracks:(id)sender {
    BOOL newValue = ![[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS];
    [[NSUserDefaults standardUserDefaults] setBool:newValue forKey:SET_SYNCTRACKS];
    self.menuSettingSyncTracks.state = newValue ? 1 : 0;
}

- (IBAction)onSettingSyncDeleteMissingFile:(id)sender {
    BOOL newValue = ![[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE];
    [[NSUserDefaults standardUserDefaults] setBool:newValue forKey:SET_SYNCDELETEMISSINGFILE];
    self.menuSettingSyncDeleteMissingFile.state = newValue ? 1 : 0;
}

- (IBAction)onSettingLaunchOnStart:(id)sender {
    BOOL newValue = ![[NSUserDefaults standardUserDefaults] boolForKey:SET_LAUNCHONSTART];
    [[NSUserDefaults standardUserDefaults] setBool:newValue forKey:SET_LAUNCHONSTART];
    self.menuSettingLaunchOnStart.state = newValue ? 1 : 0;
    
    if (newValue) {
        [[NSApplication sharedApplication] enableRelaunchOnLogin];
    } else {
        [[NSApplication sharedApplication] disableRelaunchOnLogin];
    }
}

- (IBAction)onSettingOtherLog:(id)sender {
    BOOL newValue = ![[NSUserDefaults standardUserDefaults] boolForKey:SET_OTHERLOG];
    [[NSUserDefaults standardUserDefaults] setBool:newValue forKey:SET_OTHERLOG];
    self.menuSettingOtherLog.state = newValue ? 1 : 0;
}

- (IBAction)onSettingSyncPlaylists:(id)sender {
    BOOL newValue = ![[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS];
    [[NSUserDefaults standardUserDefaults] setBool:newValue forKey:SET_SYNCPLAYLISTS];
    self.menuSettingSyncPlaylists.state = newValue ? 1 : 0;
}


- (void)setRootPath:(NSString *)rootPath {
    if (_rootPath != nil) {
        [[FSEventNotificationCenter sharedCenter] removePath:_rootPath];
    }
    _rootPath = rootPath;
    if (_rootPath != nil) {
        [[FSEventNotificationCenter sharedCenter] addPath:_rootPath];
    }
}

- (void)onFSEvent:(NSNotification *)noti {
    NSArray *eventPaths = noti.userInfo[FSEventDidReceiveNotificationEventPathsKey];
    NSLog(@"%@", eventPaths);
    _needSync = YES;
    [self doSync];
}

- (void)doSync {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS] == NO
        && [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS] == NO
        && [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE] == NO) return;
    if (_rootPath == nil) return;
    
    if (_syncing) return;
    _syncing = YES;
    _needSync = NO;
    
    [self setStatus:YES];
    
    //[self.menuSetting setEnabled:NO];
    [self.menuSettingChangePath setEnabled:NO];
    [self.menuSync setHidden:YES];
    
    BOOL syncTrack = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS];
    BOOL syncDelete = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE];
    BOOL syncPlaylist = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS];
    
    self.menuRecentDate.title = NSLocalizedString(@"동기화중...", @"");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        iTunesConnection *iTunes = [[iTunesConnection alloc] init];
        iTunes.onAddTrackEvent = ^(NSString *filePath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *path = [filePath substringFromIndex:[_rootPath length]];
                [self log:[NSString stringWithFormat:NSLocalizedString(@"추가 %@", @""), path]];
            });
        };
        iTunes.onDeleteTrackEvent = ^(NSString *filePath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *path = [filePath substringFromIndex:[_rootPath length]];
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
                if ([[NSUserDefaults standardUserDefaults] boolForKey:SET_OTHERLOG]) {
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
            [iTunes loadLibraryFile];
            onOtherEvent([NSString stringWithFormat:@"Done Load Library Plist Tracks: %i", (int)[iTunes libTrackCount]]);
        }];
        
        [queue waitUntilAllOperationsAreFinished];
        
        iTunes.rootPath = _rootPath;
        iTunes.rootName = [_rootPath lastPathComponent];
        
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
        
        if (syncTrack) {
            onOtherEvent(@"Sync Tracks...");
            BOOL modified = [iTunes syncFiles:iTunes.files currentFiles:[iTunes.libTracksByLocation allKeys]];
            if (modified) {
                onOtherEvent(@"Reloading Tracks...");
                [queue addOperationWithBlock:^{
                    [iTunes loadiTunesTracks];
                }];
                [queue addOperationWithBlock:^{
                    [iTunes loadLibraryFile];
                }];
                
                [queue waitUntilAllOperationsAreFinished];
                
                [iTunes recoverMissingLocationLibTracksFromiTunesTracks:iTunes.iTunesTracksById];
                
                onOtherEvent([NSString stringWithFormat:@"Tracks: %i", (int)[iTunes iTunesTrackCount]]);
            }
        }
        
        if (syncPlaylist) {
            [queue addOperationWithBlock:^{
                onOtherEvent(@"Build Playlists");
                [iTunes buildPlaylistAndFolderFromLibTracks:iTunes.libTracksByLocation rootPath:iTunes.rootPath];
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
            [self setStatus:NO];
            //[self.menuSetting setEnabled:YES];
            [self.menuSettingChangePath setEnabled:YES];
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            
            self.menuRecentDate.title = [dateFormatter stringFromDate:[NSDate date]];
            
            self.menuInfoSongs.title = [NSString stringWithFormat:NSLocalizedString(@"%i 곡", @""), (int)iTunes.libTrackCount];
            self.menuInfoPlaylists.title = [NSString stringWithFormat:NSLocalizedString(@"%i 목록", @""), (int)[[iTunes.libPlaylists allKeys] count]];
            [self.menuSync setHidden:NO];
            
            if (_needSync) {
                [self doSync];
            }
        });
        
    });
}

#define MAX_LOG_DISPLAY_COUNT 5
#define MAX_LOG_COUNT 50
- (void)log:(NSString *)message {
    
    if (_logs == nil) _logs = [[NSMutableArray alloc] initWithCapacity:MAX_LOG_COUNT];
    
    
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
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)onMenuSync:(id)sender {
    [self doSync];
}

- (IBAction)onMenuAbout:(id)sender {
    [self.panelAbout makeKeyAndOrderFront:self];
}

#define StatusImageCount 18
- (void)setStatus:(BOOL)syncing {
    
    if (syncing) {
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

- (void)firstUse {
    [self.windowFirstUse makeKeyAndOrderFront:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:nil];
    
    [self discoverMusicRoot];
    
    [self.buttonDone setEnabled:NO];
}

- (void)discoverMusicRoot {
    self.popUpButtonMenuRootPath.title = NSLocalizedString(@"경로 찾는중...", @"");
    [self.popUpButtonMenuSelectOtherRootPath setEnabled:NO];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        iTunesConnection *iTunes = [[iTunesConnection alloc] init];
        [iTunes loadLibraryFile];
        
        NSArray *locations = [iTunes.libTracksByLocation allKeys];
        if ([locations count] > 0) {
            [iTunes discoverRootPathFromLocations:locations];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSString *rootPath = iTunes.rootPath;
            
            if (rootPath == nil) {
                self.popUpButtonMenuRootPath.title = NSLocalizedString(@"경로를 찾을수 없습니다", @"");
                _firstRootFolderReady = NO;
            } else {
                self.popUpButtonMenuRootPath.title = rootPath;
                _firstRootFolderReady = YES;
            }
            [self.popUpButtonMenuSelectOtherRootPath setEnabled:YES];
            [self updateDoneButtonStatus];
        });
        
    });
}

- (void)windowWillClose:(NSNotification *)notification {
    exit(0);
}
- (IBAction)onPopUpButtonMenuSelectOtherRootPath:(id)sender {
    [self.popUpButtonSelectMusicFolder selectItemAtIndex:0];
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    
    [panel beginSheetModalForWindow:self.windowFirstUse
                  completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSString *path = [panel.URL path];
            
            NSFileManager *fs = [NSFileManager defaultManager];
            BOOL isDir = NO;
            if ([fs fileExistsAtPath:path isDirectory:&isDir] && isDir) {
                _firstRootFolderReady = YES;
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
    if (_firstRootFolderReady == NO) {
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
    
    [self.windowFirstUse close];
    
    self.rootPath = self.popUpButtonMenuRootPath.title;
    [[NSUserDefaults standardUserDefaults] setObject:self.rootPath forKey:ROOTPATH];
    
    [[NSUserDefaults standardUserDefaults] setBool:(self.checkBoxSyncFiles.state != 0) forKey:SET_SYNCTRACKS];
    [[NSUserDefaults standardUserDefaults] setBool:(self.checkBoxSyncDelete.state != 0) forKey:SET_SYNCDELETEMISSINGFILE];
    [[NSUserDefaults standardUserDefaults] setBool:(self.checkBoxSyncPlaylist.state != 0) forKey:SET_SYNCPLAYLISTS];
    [[NSUserDefaults standardUserDefaults] setBool:(self.checkBoxLaunchOnStart.state != 0) forKey:SET_LAUNCHONSTART];

    [self setupApplication];
}


@end
