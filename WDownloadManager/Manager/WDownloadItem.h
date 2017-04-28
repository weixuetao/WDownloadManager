//
//  WDownloadItem.h
//  WDownloadManager
//
//  Created by 魏学涛 on 2017/4/27.
//  Copyright © 2017年 魏学涛. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WDownloadProtocol.h"

@interface WDownloadItem : NSObject<WDownloadProtocol>

@property (nonatomic,strong) NSString                   * downloadUrl;
@property (nonatomic,strong) NSString                   * targetPath;
@property (nonatomic,strong) NSURLSessionDownloadTask   * downloadTask;
@property (nonatomic,strong) NSDictionary               * downloadExtrasData;
@property (nonatomic,assign) WDownloadState            downloadState;
@property (nonatomic,assign) long long                    totalLength;
@property (nonatomic,assign) long long                    downloadedLength;
@property (nonatomic,assign) double                       downloadProgress;
@property (nonatomic,strong) NSString                   * downloadSpeed;
@property (nonatomic,strong) NSDate                     * date;
@property (nonatomic,assign) long long                    bytesOfOneSecondDownload;
@property (nonatomic,strong) NSData                     * resumeData;
@property (nonatomic,strong) NSURLRequest               * request;
@property (nonatomic,assign) BOOL                         canceling;

@end
