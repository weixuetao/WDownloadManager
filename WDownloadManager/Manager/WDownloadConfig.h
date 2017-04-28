//
//  WDownloadConfig.h
//  WDownloadManager
//
//  Created by 魏学涛 on 2017/4/27.
//  Copyright © 2017年 魏学涛. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WDownloadConfig : NSObject



#define kDownloadDirectory                           @"WVideoDownload"//下载路径

#define kDownloadDefaultConcurrentDownloadingCount   3 //最大并发数



typedef NS_ENUM(NSInteger, WDownloadState){
    WDownloadStateReady,
    WDownloadStateDownloading,
    WDownloadStateWaiting,
    WDownloadStatePaused,
    WDownloadStateFinished,
    WDownloadStateFailed        //准备，正在下载，等待，暂停，完成，失败
};


typedef NS_ENUM(NSInteger, WDownloadError) {
    WDownloadErrorNone,
    WDownloadErrorExisting,
    WDownloadErrorDownloaded,
    WDownloadErrorUrlError,
    WDownloadErrorNetworkNotReachable,
    WDownloadErrorWifiNotReachable      //未知错误，已经存在，已经下载完成，url错误，网络错误，wift不可用
};



@end
