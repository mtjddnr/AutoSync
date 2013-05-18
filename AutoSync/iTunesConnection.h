//
//  iTunesConnection.h
//  iTunesHelper
//
//  Created by 문성욱 on 13. 5. 15..
//  Copyright (c) 2013년 ML. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import "iTunes.h"

@interface iTunesConnection : NSObject

@property (nonatomic, readonly) iTunesApplication *iTunes;
@property (nonatomic, readonly) iTunesSource *library;

- (NSArray *)allTracks;

/*********
 * 트랙 관리
 */
//iTunes에서 트랙 목록 로드. 트랙의 상세 정보 불러오는건 느리다.
- (void)loadiTunesTracks;
@property (nonatomic, readonly) NSMutableArray *iTunesTracks;
@property (nonatomic, readonly) NSMutableDictionary *iTunesTracksById;
- (NSInteger)iTunesTrackCount;

//트랙 삭제
- (void)deleteTracks:(NSArray *)persistentIDs;

//~/[User]/Music/iTunes/iTunes Music Library.xml에서 트랙 정보를 불러온다. 가끔 경로가 빠진다.
//iTunes트랙 정보가 있으면 자동 recover Missing Location Tracks
- (void)loadLibraryFile;
- (void)loadLibraryFileWithPath:(NSString *)path;
@property (nonatomic, readonly) NSDictionary *libTracks;
@property (nonatomic, readonly) NSMutableDictionary *libTracksById;
@property (nonatomic, readonly) NSMutableDictionary *libTracksByLocation;
@property (nonatomic, readonly) NSMutableDictionary *libDuplicatedTracks;
@property (nonatomic, readonly) NSMutableDictionary *libTracksByIdWithNoLocation;
- (NSInteger)libTrackCount;

//libTracksByIdWithNoLocation에 있는 빠진 트랙 정보를 iTunes정보로 복구한다.
- (void)recoverMissingLocationLibTracksFromiTunesTracks:(NSDictionary *)iTunesTracksById;

//Location경로의 파일이 없는 것만 뽑아낸다.
- (NSArray *)findMissingFileLibTrackIds;

//해당 폴더 하위로 모든 파일을 검색한다.
- (void)searchFiles:(NSString *)rootPath;
@property (nonatomic, readonly) NSMutableArray *files;

- (BOOL)syncFiles:(NSArray *)files currentFiles:(NSArray *)currentFiles;

/*********
 * 재생 목록 관리
 */

//트랙의 파일 경로 중에서 최상위 루트 폴더 위치를 찾아낸다.
- (void)discoverRootPathFromLocations:(NSArray *)locations;
@property (nonatomic) NSString *rootPath;
@property (nonatomic) NSString *rootName;

//트랙 파일 경로에서 필요한 폴더 및 재생 목록 명단을 준비
- (void)buildPlaylistAndFolderFromLibTracks:(NSDictionary *)libTracksByLocation rootPath:(NSString *)rootPath;
@property (nonatomic, readonly) NSMutableArray *libFolders;
@property (nonatomic, readonly) NSMutableDictionary *libPlaylists;

//iTunes에서 현재의 재생 목록을 불러온다.
- (void)loadiTunesPlaylists;
@property (nonatomic, readonly) NSMutableDictionary *iTunesFolders;
@property (nonatomic, readonly) NSMutableDictionary *iTunesUserPlaylists;

- (NSString *)getPlaylistPath:(iTunesPlaylist *)playlist;

//libFolder와 libPlaylist와 일치 하지 않는 재생목록을 지운다.
- (void)synciTunesFolder:(NSArray *)folders AndPlaylist:(NSArray *)playlists;

- (void)synciTunesPlaylistTracks:(NSDictionary *)playlists;

@end
