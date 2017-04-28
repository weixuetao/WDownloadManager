//
//  WDownloadProtocol.h
//  WDownloadManager
//
//  Created by 魏学涛 on 2017/4/27.
//  Copyright © 2017年 魏学涛. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WDownloadProtocol <NSObject>

//下载地址
@property (nonatomic,readonly) NSString              *downloadUrl;


@property (nonatomic,readonly) NSDictionary          *downloadExtrasData;

//存储路径
@property (nonatomic,readonly) NSString              *targetPath;//nil before downloaded

//下载速度
@property (nonatomic,readonly) NSString              *downloadSpeed;

//下载状态
@property (nonatomic,readonly) WDownloadState        downloadState;

//下载的视频总长度
@property (nonatomic,readonly) long long              totalLength;

//已下载的总长度
@property (nonatomic,readonly) long long              downloadedLength;

//下载的进度
@property (nonatomic,readonly) double                 downloadProgress;


@end
