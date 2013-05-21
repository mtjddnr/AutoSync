//
//  iTunesConnection.m
//  iTunesHelper
//
//  Created by 문성욱 on 13. 5. 15..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import "iTunesConnection.h"

@implementation iTunesConnection

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (iTunesApplication *)iTunes {
    return [SBApplication applicationWithBundleIdentifier:@"com.apple.itunes"];
}

- (iTunesSource *)library {
    SBElementArray *items = [self.iTunes sources];
    NSArray *sources = [items get];
    
    //보관함 찾기
    __block iTunesSource *library = nil;
    [sources enumerateObjectsUsingBlock:^(iTunesSource *item, NSUInteger idx, BOOL *stop) {
        if ([item kind] == iTunesESrcLibrary) {
            library = item;
            *stop = YES;
        }
    }];
    return library;
}

- (NSArray *)allTracks {
    __block iTunesLibraryPlaylist *libraryPlaylist = nil;
    
    NSArray *playlists = [[self.library playlists] get];
    [playlists enumerateObjectsUsingBlock:^(iTunesPlaylist *playlist, NSUInteger idx, BOOL *stop) {
        if ([NSStringFromClass([playlist class]) isEqualToString:@"ITunesLibraryPlaylist"]) {
            libraryPlaylist = (iTunesLibraryPlaylist *)playlist;
            *stop = YES;
        }
    }];
    
    //모든 노래 가져오기
    return [[libraryPlaylist fileTracks] get];
}

#pragma mark - 트랙 관리
- (void)loadiTunesTracks {
    NSArray *tracks = [self allTracks];
    
    NSMutableDictionary *tracksById = [NSMutableDictionary dictionary];
    
    [tracks enumerateObjectsUsingBlock:^(iTunesFileTrack *itunesTrack, NSUInteger idx, BOOL *stop) {
        NSString *iTunesPid = itunesTrack.persistentID;
        tracksById[iTunesPid] = itunesTrack;
    }];
    
    _iTunesTracks = [NSMutableArray arrayWithArray:tracks];
    _iTunesTracksById = tracksById;
}
- (NSInteger)iTunesTrackCount {
    NSAssert([[_iTunesTracksById allKeys] count] == [_iTunesTracks count], @"트랙 개수 비일치");
    return [_iTunesTracks count];
}

- (void)deleteTracks:(NSArray *)persistentIDs {
    NSMutableArray *locations = [NSMutableArray array];
    NSMutableArray *remove = [NSMutableArray array];
    [persistentIDs enumerateObjectsUsingBlock:^(NSString *persistentID, NSUInteger idx, BOOL *stop) {
        iTunesFileTrack *itunesTrack = _iTunesTracksById[persistentID];
        
        [itunesTrack delete];
        NSString *location = [[NSURL URLWithString:_libTracksById[persistentID][@"Location"]] path];
        [locations addObject:location];
        [remove addObject:itunesTrack];
        NSLog(@"Delete: %@", location);
        
        if (_onDeleteTrackEvent) {
            _onDeleteTrackEvent(location);
        }
    }];
    [_iTunesTracks removeObjectsInArray:remove];
    [_iTunesTracksById removeObjectsForKeys:persistentIDs];
    [_libTracksById removeObjectsForKeys:persistentIDs];
    [_libTracksByLocation removeObjectsForKeys:locations];
}

+ (NSString *)defaultLibraryFilePath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Music/iTunes/iTunes Music Library.xml"];
}
+ (BOOL)isLibraryValid:(NSString *)path {
    NSFileManager *fs = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExists = [fs fileExistsAtPath:path isDirectory:&isDir];
    if (isExists == NO || isDir == YES) return NO;
    
    NSDictionary *lib = [NSDictionary dictionaryWithContentsOfFile:path];
    
    if (lib == nil) return NO;
    
    if (lib[@"Tracks"] == nil) return NO;
    
    return YES;
}
- (void)loadLibraryFile {
    [self loadLibraryFileWithPath:[iTunesConnection defaultLibraryFilePath]];
}
- (void)loadLibraryFileWithPath:(NSString *)path {
    NSFileManager *fs = [NSFileManager defaultManager];
    BOOL isExists = [fs fileExistsAtPath:path isDirectory:NULL];
    NSAssert(isExists, @"No iTunes Library File");
    
    //iTunesConnection으로 트랙 정보 불러오면 너무 느리니 XML파일을 직접 분석한다.
    NSDictionary *lib = [NSDictionary dictionaryWithContentsOfFile:path];
    
    NSAssert(lib != nil, @"라이브러리 로드 실패");
    
    NSDictionary *libTracks = lib[@"Tracks"];
    NSMutableDictionary *libTracksById = [NSMutableDictionary dictionary];
    NSMutableDictionary *libTracksByLocation = [NSMutableDictionary dictionary];
    NSMutableDictionary *libDuplicatedTracks = [NSMutableDictionary dictionary];
    NSMutableDictionary *libTracksByIdWithNoLocation = [NSMutableDictionary dictionary];
    
    [libTracks enumerateKeysAndObjectsUsingBlock:^(id key, NSDictionary *track, BOOL *stop) {
        NSString *location = [[NSURL URLWithString:track[@"Location"]] path];
        NSString *persistentId = track[@"Persistent ID"];
        
        NSAssert(persistentId != nil, @"persistentId값 없음");
        
        if (location == nil) {
            libTracksByIdWithNoLocation[persistentId] = track;
        } else if (libTracksByLocation[location] != nil) {
            libDuplicatedTracks[persistentId] = track;
        } else {
            libTracksById[persistentId] = track;
            libTracksByLocation[location] = track;
        }
    }];
    
    _libTracks = libTracks;
    _libTracksById = libTracksById;
    _libTracksByLocation = libTracksByLocation;
    _libDuplicatedTracks = libDuplicatedTracks;
    _libTracksByIdWithNoLocation = libTracksByIdWithNoLocation;
}
- (NSInteger)libTrackCount {
    return [[_libTracksByLocation allKeys] count];
}

- (void)recoverMissingLocationLibTracksFromiTunesTracks:(NSDictionary *)iTunesTracksById {
    [_libTracksByIdWithNoLocation enumerateKeysAndObjectsUsingBlock:^(NSString *persistentId, NSDictionary *track, BOOL *stop) {
        iTunesFileTrack *itunesTrack = iTunesTracksById[persistentId];
        if (itunesTrack == nil) return;
        
        NSString *location = [[itunesTrack location] path];
        
        if (location == nil) {
        } else if (_libTracksByLocation[location] != nil) {
            _libDuplicatedTracks[persistentId] = track;
        } else {
            NSMutableDictionary *newTrack = [NSMutableDictionary dictionaryWithDictionary:track];
            newTrack[@"Location"] = [[NSURL fileURLWithPath:location] absoluteString];
            track = newTrack;
            _libTracksById[persistentId] = track;
            _libTracksByLocation[location] = track;
        }
    }];
    
    [_libTracksByIdWithNoLocation removeObjectsForKeys:[_libTracksById allKeys]];
}

#define MAX_Threads 5

- (NSArray *)findMissingFileLibTrackIds {
    NSFileManager *fs = [NSFileManager defaultManager];
    NSMutableArray *missionList = [NSMutableArray array];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:50];
    
    
	dispatch_queue_t syncQueue = dispatch_queue_create(NULL, NULL);
    
    [_libTracksById enumerateKeysAndObjectsUsingBlock:^(NSString *persistentId, NSDictionary *track, BOOL *stop) {
        NSString *location = [[NSURL URLWithString:track[@"Location"]] path];
        
        [queue addOperationWithBlock:^{
            if ([fs fileExistsAtPath:location isDirectory:NULL] == NO) {
                dispatch_sync(syncQueue, ^{
                    [missionList addObject:persistentId];
                });
            }
        }];
    }];
    
    [queue waitUntilAllOperationsAreFinished];
    
    return [NSArray arrayWithArray:missionList];
}

- (void)searchFiles:(NSString *)rootPath {
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue setMaxConcurrentOperationCount:50];
    
	dispatch_queue_t syncQueue = dispatch_queue_create("searchFiles", NULL);
    
    NSFileManager *fs = [NSFileManager defaultManager];
    
    NSArray *allFilesAndFolders = [fs subpathsOfDirectoryAtPath:rootPath error:nil];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:[allFilesAndFolders count]];
    
    [allFilesAndFolders enumerateObjectsUsingBlock:^(NSString *subPath, NSUInteger idx, BOOL *stop) {
        NSString *path = [rootPath stringByAppendingPathComponent:subPath];
        if ([[path lastPathComponent] rangeOfString:@"."].location == NSNotFound) return;
        
        [queue addOperationWithBlock:^{
            BOOL isDirectory = NO;
            if ([fs fileExistsAtPath:path isDirectory:&isDirectory] == YES && isDirectory == NO) {
                
                NSString *ext = [[path pathExtension] lowercaseString];
                if ([ext isEqualToString:@"mp3"]) {
                    dispatch_sync(syncQueue, ^{
                        [files addObject:path];
                    });
                }
            }
        }];
    }];
    
    [queue waitUntilAllOperationsAreFinished];
    
    _files = files;
    
}

- (BOOL)syncFiles:(NSArray *)files currentFiles:(NSArray *)currentFiles {
    BOOL modified = NO;
    
    NSMutableArray *currentFilesNotInFiles = [NSMutableArray arrayWithArray:currentFiles];
    [currentFilesNotInFiles removeObjectsInArray:files];
    
    if ([currentFilesNotInFiles count] > 0) {
        NSMutableArray *remove = [NSMutableArray array];
        [files enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
            NSString *lowerCased = [path lowercaseString];
            [currentFilesNotInFiles enumerateObjectsUsingBlock:^(NSString *testPath, NSUInteger idx, BOOL *stop) {
                NSString *lowerTest = [testPath lowercaseString];
                if ([lowerCased isEqualToString:lowerTest]) {
                    [remove addObject:testPath];
                    *stop = YES;
                }
            }];
        }];
        [currentFilesNotInFiles removeObjectsInArray:remove];
    }
    
    if ([currentFilesNotInFiles count] > 0) {
        [currentFilesNotInFiles enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
            
            //루트 폴더에 소속되지 않은 노래 파일은 무시
            if ([path rangeOfString:_rootPath options:NSCaseInsensitiveSearch].location != 0) return;
            
            NSDictionary *track = _libTracksByLocation[path];
            NSString *persistentId = track[@"Persistent ID"];
            iTunesFileTrack *itunesTrack = _iTunesTracksById[persistentId];
            
            [itunesTrack delete];
            NSLog(@"Delete: %@", path);
            if (_onDeleteTrackEvent) {
                _onDeleteTrackEvent(path);
            }
        }];
        
        modified = YES;
    }
    
    NSMutableArray *newFiles = [NSMutableArray arrayWithArray:files];
    [newFiles removeObjectsInArray:currentFiles];
    
    if ([newFiles count] > 0) {
        NSMutableArray *remove = [NSMutableArray array];
        [currentFiles enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
            NSString *lowerCased = [path lowercaseString];
            [newFiles enumerateObjectsUsingBlock:^(NSString *testPath, NSUInteger idx, BOOL *stop) {
                NSString *lowerTest = [testPath lowercaseString];
                if ([lowerCased isEqualToString:lowerTest]) {
                    [remove addObject:testPath];
                    *stop = YES;
                }
            }];
        }];
        [newFiles removeObjectsInArray:remove];
    }
    
    if ([newFiles count] > 0) {
        NSMutableArray *locations = [NSMutableArray arrayWithCapacity:[newFiles count]];
        [newFiles enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
            [locations addObject:[NSURL fileURLWithPath:path]];
            NSLog(@"Add: %@", path);
            if (_onAddTrackEvent) {
                _onAddTrackEvent(path);
            }
        }];
        
        [self.iTunes add:locations to:nil];
        
        NSLog(@"%i files added", (int)[locations count]);
        modified = YES;
    }
    return modified;
}

- (void)discoverRootPathFromLocations:(NSArray *)locations {
    NSMutableArray *locationPatterns = [NSMutableArray array];
    
    __block long shortestLength = NSNotFound;
    [locations enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSArray *parts = [path componentsSeparatedByString:@"/"];
        [locationPatterns addObject:parts];
        shortestLength = MIN(shortestLength, (long)[parts count]);
    }];
    
    int i = 0; __block BOOL match = YES;
    for (i = 0; i < shortestLength && match; i++) {
        NSString *test = locationPatterns[0][i];
        [locationPatterns enumerateObjectsUsingBlock:^(NSArray *parts, NSUInteger idx, BOOL *stop) {
            if ([parts[i] isEqualToString:test] == NO) {
                match = NO;
                *stop = YES;
            }
        }];
    }
    
    i--;
    assert(i >= 0);
    
    NSArray *rootPathParts = [locationPatterns[0] subarrayWithRange:NSMakeRange(0, i)];
    NSString *rootPath = [rootPathParts componentsJoinedByString:@"/"];
    
    NSString *rootName = [rootPath lastPathComponent];
    
    _rootPath = rootPath;
    _rootName = rootName;
}



- (void)buildPlaylistFromLibTracks:(NSDictionary *)libTracksByLocation rootPath:(NSString *)rootPath {
    NSMutableDictionary *playlists = [NSMutableDictionary dictionary];
    
    [libTracksByLocation enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSDictionary *track, BOOL *stop) {
        
        //루트 폴더에 소속되지 않은 노래 파일은 무시
        if ([path rangeOfString:_rootPath options:NSCaseInsensitiveSearch].location != 0) return;
        
        NSString *playlistPath = [path stringByDeletingLastPathComponent];
        playlistPath = [playlistPath substringFromIndex:[[rootPath stringByDeletingLastPathComponent] length] +1];
        
        NSMutableArray *playlist = playlists[playlistPath];
        if (playlist == nil) {
            playlist = [NSMutableArray array];
            playlists[playlistPath] = playlist;
        }
        
        [playlist addObject:track];
    }];
    
    _libPlaylists = playlists;
}

- (void)buildFolders {
    NSMutableArray *folders = [NSMutableArray array];
    
    NSArray *paths = [_libPlaylists allKeys];
    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSString *folderPath = [path stringByDeletingLastPathComponent];
        while ([folderPath length] > 0) {
            if ([folders containsObject:folderPath] == NO) [folders addObject:folderPath];
            folderPath = [folderPath stringByDeletingLastPathComponent];
        }
    }];
    
    _libFolders = folders;
}

- (void)combinePlaylistsIfSeperatedDiscAlbums {
   
    NSMutableDictionary *parentGrouped = [NSMutableDictionary dictionary];
    
    NSArray *paths = [_libPlaylists allKeys];
    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSString *folderPath = [path stringByDeletingLastPathComponent];
        NSString *name = [path lastPathComponent];
        
        NSMutableDictionary *group = parentGrouped[folderPath];
        if (group == nil) {
            group = [NSMutableDictionary dictionary];
            parentGrouped[folderPath] = group;
        }
        
        group[name] = path;
    }];

    NSArray *possiblePatterns = @[
                                  @"cd*.[0-9]{1,2}",
                                  @"disc*.[0-9]{1,2}"
                                  ];
    
    [parentGrouped enumerateKeysAndObjectsUsingBlock:^(NSString *folderPath, NSMutableDictionary *group, BOOL *stop) {
        
        __block BOOL match = YES;
        __block NSString *testPrefix = nil;
        __block NSString *testPattern = nil; //cd or disc
        [group enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *path, BOOL *stop) {
            if (testPattern == nil) {
                [possiblePatterns enumerateObjectsUsingBlock:^(NSString *pattern, NSUInteger idx, BOOL *stop) {
                    NSRange r = [name rangeOfString:pattern options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
                    if (r.location != NSNotFound) {
                        testPattern = pattern;
                        *stop = YES;
                    }
                }];
                if (testPattern == nil) {
                    *stop = YES;
                    match = NO;
                    return;
                }
                
                NSRange range = [name rangeOfString:testPattern options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
                
                testPrefix = [name substringWithRange:NSMakeRange(0, range.location)];
                
            } else {
                NSRange range = [name rangeOfString:testPattern options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
                if (range.location == NSNotFound) {
                    match = NO;
                    *stop = YES;
                    return;
                }
                NSString *prefix = [name substringWithRange:NSMakeRange(0, range.location)];
                
                if ([prefix isEqualToString:testPrefix] == NO) {
                    match = NO;
                    *stop = YES;
                    return;
                }
            }
        }];
        
        if (match) {            
            //folderPath -> new Playlist
            NSMutableArray *newPlaylist = [NSMutableArray array];
            [group enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *path, BOOL *stop) {
                NSMutableArray *playlist = _libPlaylists[path];
                [newPlaylist addObjectsFromArray:playlist];
                [_libPlaylists removeObjectForKey:path];
            }];
            
            if (_libPlaylists[folderPath] != nil) {
                NSMutableArray *l = _libPlaylists[folderPath];
                [newPlaylist addObjectsFromArray:l];
            }
            
            _libPlaylists[folderPath] = newPlaylist;
            
        }
        
    }];
    
}


- (void)loadiTunesPlaylists {
    NSArray *playlists = [[self.library playlists] get];
    
    NSMutableDictionary *iTunesFolders = [NSMutableDictionary dictionary];
    NSMutableDictionary *iTunesPlaylists = [NSMutableDictionary dictionary];
    [playlists enumerateObjectsUsingBlock:^(iTunesPlaylist *playlist, NSUInteger idx, BOOL *stop) {
        NSString *path = [self getPlaylistPath:playlist];
        if ([[path pathComponents][0] isEqualToString:_rootName] == NO) return;
        
        if ([NSStringFromClass([playlist class]) isEqualToString:@"ITunesFolderPlaylist"]) {
            iTunesFolders[path] = playlist;
        } else if ([NSStringFromClass([playlist class]) isEqualToString:@"ITunesUserPlaylist"]) {
            iTunesUserPlaylist *userPlaylist = (iTunesUserPlaylist *)playlist;
            if (userPlaylist.smart) return;
            
            iTunesPlaylists[path] = playlist;
        }
    }];
    _iTunesFolders = iTunesFolders;
    _iTunesUserPlaylists = iTunesPlaylists;
}

- (NSString *)getPlaylistPath:(iTunesPlaylist *)playlist {
    NSMutableArray *paths = [NSMutableArray arrayWithObject:[playlist name]];
    __weak iTunesPlaylist *parent = playlist.parent;
    while ([parent persistentID] != nil) {
        [paths insertObject:parent.name atIndex:0];
        parent = parent.parent;
    }
    return [paths componentsJoinedByString:@"/"];
}

- (void)synciTunesFolder:(NSArray *)folders AndPlaylist:(NSArray *)playlists {
    NSMutableArray *toDelete = [NSMutableArray array];
    [_iTunesUserPlaylists enumerateKeysAndObjectsUsingBlock:^(NSString *path, iTunesPlaylist *playlist, BOOL *stop) {
        if ([playlists containsObject:path] == NO) {
            //NSLog(@"Delete: %@", path);
            [toDelete addObject:path];
            [playlist delete];
            if (_onDeletePlaylistEvent) {
                _onDeletePlaylistEvent(path);
            }
        }
    }];
    
    [_iTunesUserPlaylists removeObjectsForKeys:toDelete];
    toDelete = [NSMutableArray array];
    [_iTunesFolders enumerateKeysAndObjectsUsingBlock:^(NSString *path, iTunesPlaylist *folder, BOOL *stop) {
        if ([folders containsObject:path] == NO) {
            //NSLog(@"Delete: %@", path);
            [toDelete addObject:path];
            [folder delete];
            if (_onDeletePlaylistEvent) {
                _onDeletePlaylistEvent(path);
            }
        }
    }];
    [_iTunesFolders removeObjectsForKeys:toDelete];
    
    SBElementArray *itunesPlaylists = [self.library playlists];
    
    [folders enumerateObjectsUsingBlock:^(NSString *folder, NSUInteger idx, BOOL *stop) {
        if (_iTunesFolders[folder] != nil) return;
        
        NSArray *folderParts = [folder pathComponents];
        iTunesFolderPlaylist *parentFolder = nil;
        for (int i = 0; i < [folderParts count]; i++) {
            NSString *buildPath = [NSString pathWithComponents:[folderParts subarrayWithRange:NSMakeRange(0, i+1)]];
            iTunesFolderPlaylist *iTunesFolder = _iTunesFolders[buildPath];
            if (iTunesFolder == nil) {
                iTunesFolderPlaylist *playlist = [[[self.iTunes classForScriptingClass:@"folder playlist"] alloc] init];
                [itunesPlaylists insertObject:playlist atIndex:0];
                
                playlist.name = [buildPath lastPathComponent];
                if (parentFolder != nil) [playlist moveTo:parentFolder];
                
                _iTunesFolders[buildPath] = playlist;
                iTunesFolder = playlist;
                //NSLog(@"add %@", buildPath);
                if (_onAddPlaylistEvent) {
                    _onAddPlaylistEvent(buildPath);
                }
            }
            parentFolder = iTunesFolder;
        }
    }];
    
    [playlists enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        //재새목록이 있는 폴더를 불러오기 이미 다 만들었으므로 없으면 문제있다.
        NSString *folderPath = [path stringByDeletingLastPathComponent];
        iTunesFolderPlaylist *iTunesFolder = _iTunesFolders[folderPath];
        assert(iTunesFolder != nil);
        
        //재생목록 찾기 없으면 생성
        iTunesUserPlaylist *userPlaylist = _iTunesUserPlaylists[path];
        if (userPlaylist == nil) {
            iTunesFolderPlaylist *playlist = [[[self.iTunes classForScriptingClass:@"user playlist"] alloc] init];
            [itunesPlaylists addObject:playlist];
            
            playlist.name = [path lastPathComponent];
            [playlist moveTo:iTunesFolder];
            
            _iTunesUserPlaylists[path] = playlist;
            //userPlaylist = playlist;
            
            //NSLog(@"add %@", path);
            
            if (_onAddPlaylistEvent) {
                _onAddPlaylistEvent(path);
            }
        }
    }];
}

- (void)synciTunesPlaylistTracks:(NSDictionary *)playlists {
    
    //NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    //[queue setMaxConcurrentOperationCount:5];
    
    [playlists enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSMutableArray *tracks, BOOL *stop) {
        
        //재생목록 찾기
        iTunesUserPlaylist *userPlaylist = _iTunesUserPlaylists[path];
        assert(userPlaylist != nil);
        
        //[queue addOperationWithBlock:^{
        
        //먼저 있으면 안되는 노래들 삭제
        NSArray *currentTracks = [[userPlaylist tracks] get];
        
        
        NSMutableDictionary *trackIds = [NSMutableDictionary dictionary];
        NSMutableArray *trackLocations = [NSMutableArray array];
        [tracks enumerateObjectsUsingBlock:^(NSDictionary *track, NSUInteger idx, BOOL *stop) {
            trackIds[track[@"Persistent ID"]] = track;
        }];
        
        __block int deleteCount = 0;
        __block int deleteDupCount = 0;
        __block int addCount = 0;
        
        //중복, 해당안되는 노래 제거
        NSMutableSet *currentTrackIds = [NSMutableSet set];
        [currentTracks enumerateObjectsUsingBlock:^(iTunesFileTrack *track, NSUInteger idx, BOOL *stop) {
            NSString *pid = track.persistentID;
            
            if ([[trackIds allKeys] containsObject:pid] == NO) {
                //NSLog(@"%@ delete %@", _userPlaylist.name, track.name);
                deleteCount++;
                [track delete];
            } else if ([currentTrackIds containsObject:pid]) {
                //중복
                //NSLog(@"%@ delete duplicate %@", _userPlaylist.name, track.name);
                deleteDupCount++;
                [track delete];
            } else {
                assert(pid != nil);
                [currentTrackIds addObject:pid];
            }
        }];
        
        //새로 추가할 노래 목록 생성
        [tracks enumerateObjectsUsingBlock:^(NSDictionary *track, NSUInteger idx, BOOL *stop) {
            NSString *pid = track[@"Persistent ID"];
            assert(pid != nil);
            if ([currentTrackIds containsObject:pid]) return;
            
            assert(track[@"Location"] != nil);
            //NSLog(@"%@ add %@", _userPlaylist.name, track[@"Name"]);
            addCount++;
            NSURL *location = [NSURL URLWithString:track[@"Location"]];
            assert(location != nil);
            [trackLocations addObject:location];
        }];
        
        if ([trackLocations count] > 0) {
            assert(trackLocations != nil);
            assert(userPlaylist != nil);
            //[queue addOperationWithBlock:^{
            [self.iTunes add:trackLocations to:userPlaylist];
            if (_onOtherEvent) {
                _onOtherEvent([NSString stringWithFormat:@"Tracks: %02d(%02d Del, %02d Dup, %02d Add)\t: %@", (int)[tracks count], deleteCount, deleteDupCount, addCount, userPlaylist.name]);
            }
            //NSLog(@"Tracks: %02d(%02d Del, %02d Dup, %02d Add)\t: %@", (int)[tracks count], deleteCount, deleteDupCount, addCount, userPlaylist.name);
            //}];
        } else if (deleteCount + deleteDupCount + addCount > 0) {
            if (_onOtherEvent) {
                _onOtherEvent([NSString stringWithFormat:@"Tracks: %02d(%02d Del, %02d Dup, %02d Add)\t: %@", (int)[tracks count], deleteCount, deleteDupCount, addCount, userPlaylist.name]);
            }
            //NSLog(@"Tracks: %02d(%02d Del, %02d Dup, %02d Add)\t: %@", (int)[tracks count], deleteCount, deleteDupCount, addCount, userPlaylist.name);
        }
        
        //}];
        
    }];
    
    //[queue waitUntilAllOperationsAreFinished];
}

@end

