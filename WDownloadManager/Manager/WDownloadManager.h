//
//  WDownloadManager.h
//  WDownloadManager
//
//  Created by 魏学涛 on 2017/4/27.
//  Copyright © 2017年 魏学涛. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WDownloadProtocol.h"

typedef void(^ChallengeCompletionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential);
typedef void(^ReceiveChallengeHandle)(NSURLSession*session,NSURLSessionTask*task,NSURLAuthenticationChallenge *challenge,ChallengeCompletionHandler completionHandler);


@interface WDownloadManager : NSObject

///正在下载的任务
@property (nonatomic,readonly) NSArray<id<WDownloadProtocol>>   *downloadedItems;

///已经下载完成的任务
@property (nonatomic,readonly) NSArray<id<WDownloadProtocol>>   *downloadingItems;

///自定义http请求头
@property (nonatomic,copy    ) NSDictionary                    *httpHeader;

@property (nonatomic,assign  ) NSInteger                       concurrentDownloadingCount;//defarlt 2 max 3

@property (nonatomic,assign  ) BOOL                            allowedBackgroundDownload;//default YES

@property (nonatomic,assign  ) BOOL                            allowedDownloadOnWWAN;//default NO

@property (nonatomic,copy    ) ReceiveChallengeHandle          receiveChallengeHandle;

@property (nonatomic,copy    ) void(^downloadAllCompleteInbackground)();

/**
 创建单例

 @return 单例对象
 */
+ (WDownloadManager *)shareDownloadManager;



/**
 开始下载

 @param url urlsource
 @param extrasData 保存附加信息
 @return 返回下载返回的错误状态
 */
- (WDownloadError)startDownloadWithUrl:(NSString *)url
                             extrasData:(NSDictionary *)extrasData;

- (WDownloadError)startDownloadWithRequest:(NSURLRequest *)urlRequest
                                 extrasData:(NSDictionary *)extrasData;


/**
 暂停所有下载任务
 */
- (void)pauseAllDownloadTask;

/**
 回复所有下载

 @return 返回恢复下载的错误状态
 */
- (WDownloadError)resumeAllDownloadTask;


/**
 删除一个下载中任务或者已下载的文件
 @param url urlSource
 */
- (void)deleteDownloadWithUrl:(NSString *)url;

/**
 暂停一个下载任务
 
 @param url url
 */
- (void)pauseDownloadTaskWithUrl:(NSString *)url;

/**
 恢复一个下载任务
 
 @param url urlSource
 @return 返回恢复下载的错误状态
 */
- (WDownloadError)resumeDownloadTaskWithUrl:(NSString *)url;

/**
 删除所有下载任务
 */
- (void)deleteAllDownloadingTask;

/**
 删除所有已下载文件
 */
- (void)deleteAllDownloadedFile;

/**
 返回下载目录
 
 @return 下载目录
 */
- (NSString *)downloadDirectory;

/**
 获取文件下载路径
 
 @param url url
 @return 文件下载路径
 */
- (NSString *)downloadPathWithUrl:(NSString *)url;

/**
 磁盘总空间
 
 @return 磁盘总空间
 */
+ (float)totalDiskSpaceInBytes;

/**
 磁盘剩余空间
 
 @return 磁盘剩余空间
 */
+ (float)freeDiskSpaceInBytes;


@end

/*
 下载进度发生变化的通知
 */
extern NSString * const WDownloadProgressChangedNotification;

/*
 下载状态发生变化的通知
 */
extern NSString * const WDownloadStateChangedNotification;



