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

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    
    BOOL _syncing;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self activateStatusMenu];
    
    self.rootPath = [[NSUserDefaults standardUserDefaults] stringForKey:ROOTPATH];
    
    if (self.rootPath == nil) {
        [self discoverMusicRoot];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SET_SYNCTRACKS];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SET_SYNCDELETEMISSINGFILE];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SET_SYNCPLAYLISTS];
    } else {
        self.menuMusicRoot.title = self.rootPath;
    }
    
    self.menuSettingSyncTracks.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS] ? 1 : 0;
    self.menuSettingSyncDeleteMissingFile.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE] ? 1 : 0;
    self.menuSettingSyncPlaylists.state = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS] ? 1 : 0;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFSEvent:) name:FSEventDidReceiveNotification object:nil];
    
    [self doSync];
}

- (void)activateStatusMenu {
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    
    _statusItem = [bar statusItemWithLength:NSVariableStatusItemLength];
    
    [_statusItem setTitle:NSLocalizedString(@"AutoSync",@"")];
    [_statusItem setHighlightMode:YES];
    [_statusItem setMenu:self.menu];
}

- (IBAction)onQuit:(id)sender {
    exit(0);
}

- (void)discoverMusicRoot {
    self.menuMusicRoot.title = @"준비중...";
    [self.menuSetting setEnabled:NO];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        [NSThread sleepForTimeInterval:5];
        
        iTunesConnection *iTunes = [[iTunesConnection alloc] init];
        [iTunes loadLibraryFile];
        
        NSArray *locations = [iTunes.libTracksByLocation allKeys];
        if ([locations count] > 0) {
            [iTunes discoverRootPathFromLocations:locations];
            self.rootPath = iTunes.rootPath;
        } else {
            self.rootPath = nil;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.menuMusicRoot.title = self.rootPath == nil ? @"경로가 없습니다." : self.rootPath;
            [[NSUserDefaults standardUserDefaults] setObject:self.rootPath forKey:ROOTPATH];
            [self.menuSetting setEnabled:YES];
        });
        
    });
   
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
    
    [self doSync];
}

- (void)doSync {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS] == NO
        && [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS] == NO
        && [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE] == NO) return;
    if (_rootPath == nil) return;
    
    if (_syncing) return;
    _syncing = YES;
    
    _statusItem.title = NSLocalizedString(@"Syncing...",@"");
    [self.menuSetting setEnabled:NO];
    
    BOOL syncTrack = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCTRACKS];
    BOOL syncDelete = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCDELETEMISSINGFILE];
    BOOL syncPlaylist = [[NSUserDefaults standardUserDefaults] boolForKey:SET_SYNCPLAYLISTS];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        iTunesConnection *iTunes = [[iTunesConnection alloc] init];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue addOperationWithBlock:^{
            NSLog(@"Start Load iTunes Tracks");
            [iTunes loadiTunesTracks];
            NSLog(@"Done Load iTunes Tracks: %i", (int)[iTunes iTunesTrackCount]);
        }];
        [queue addOperationWithBlock:^{
            NSLog(@"Start Load Library Plist Tracks");
            [iTunes loadLibraryFile];
            NSLog(@"Done Load Library Plist Tracks: %i", (int)[iTunes libTrackCount]);
        }];
        
        [queue waitUntilAllOperationsAreFinished];
        
        iTunes.rootPath = _rootPath;
        iTunes.rootName = [_rootPath lastPathComponent];
        
        if (syncTrack) {
            [queue addOperationWithBlock:^{
                NSLog(@"Searching Files");
                [iTunes searchFiles:iTunes.rootPath];
                NSLog(@"Done Searching Files: %i", (int)[iTunes.files count]);
            }];
        }
        NSLog(@"recover Missing Location Tracks: %i", (int)[iTunes.libTracksByIdWithNoLocation count]);
        [iTunes recoverMissingLocationLibTracksFromiTunesTracks:iTunes.iTunesTracksById];
        
        NSLog(@"Tracks: %i", (int)[iTunes iTunesTrackCount]);
        
        if (syncDelete) {
            NSArray *missingTrackIds = [iTunes findMissingFileLibTrackIds];
            NSLog(@"File Missing Tracks: %i", (int)[missingTrackIds count]);
            
            if ([missingTrackIds count] > 0) {
                NSLog(@"Deleting Missing Tracks");
                [iTunes deleteTracks:missingTrackIds];
                NSLog(@"Done Deleting Missing Tracks");
                
                NSLog(@"Tracks: %i", (int)[iTunes iTunesTrackCount]);
            }
        }
        
        [queue waitUntilAllOperationsAreFinished];
        
        if (syncTrack) {
            BOOL modified = [iTunes syncFiles:iTunes.files currentFiles:[iTunes.libTracksByLocation allKeys]];
            if (modified) {
                NSLog(@"Reloading Tracks...");
                [queue addOperationWithBlock:^{
                    [iTunes loadiTunesTracks];
                }];
                [queue addOperationWithBlock:^{
                    [iTunes loadLibraryFile];
                }];
                
                [queue waitUntilAllOperationsAreFinished];
                
                [iTunes recoverMissingLocationLibTracksFromiTunesTracks:iTunes.iTunesTracksById];
                
                NSLog(@"Tracks: %i", (int)[iTunes iTunesTrackCount]);
            }
        }
        
        if (syncPlaylist) {
            [queue addOperationWithBlock:^{
                NSLog(@"Build Playlists");
                [iTunes buildPlaylistAndFolderFromLibTracks:iTunes.libTracksByLocation rootPath:iTunes.rootPath];
                NSLog(@"Done Build Playlists: %i Folders, %i Playlists", (int)[iTunes.libFolders count], (int)[iTunes.libPlaylists count]);
            }];
            
            [queue addOperationWithBlock:^{
                NSLog(@"Load iTunes Playlists");
                [iTunes loadiTunesPlaylists];
                NSLog(@"Done Load iTunes Playlists: %i Folders, %i Playlists", (int)[iTunes.iTunesFolders count], (int)[iTunes.iTunesUserPlaylists count]);
            }];
            
            [queue waitUntilAllOperationsAreFinished];
            
            NSLog(@"Sync playlist structure");
            [iTunes synciTunesFolder:iTunes.libFolders AndPlaylist:[iTunes.libPlaylists allKeys]];
            NSLog(@"Done Playlists: %i Folders, %i Playlists", (int)[iTunes.iTunesFolders count], (int)[iTunes.iTunesUserPlaylists count]);
            
            NSLog(@"Sync playlist Tracks");
            [iTunes synciTunesPlaylistTracks:iTunes.libPlaylists];
            
        }
        NSLog(@"Done");

        dispatch_async(dispatch_get_main_queue(), ^{
            _syncing = NO;
            _statusItem.title = NSLocalizedString(@"AutoSync",@"");
            [self.menuSetting setEnabled:YES];
        });
        
    });
}

@end
