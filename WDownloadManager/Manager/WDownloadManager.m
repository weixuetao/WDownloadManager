//
//  WDownloadManager.m
//  WDownloadManager
//
//  Created by 魏学涛 on 2017/4/27.
//  Copyright © 2017年 魏学涛. All rights reserved.
//


NSString *const kDownloading            = @"Dwonloading";
NSString *const kDownloaded             = @"Downloaded";
NSString *const kDownloadUrl              = @"DownloadUrl";
NSString *const kDownloadState            = @"DownloadState";
NSString *const kDownloadExtrasData       = @"DownloadExtrasData";
NSString *const kDownloadProgress         = @"DownloadProgress";
NSString *const kTargetPath               = @"TargetPath";
NSString *const kTotalLength              = @"TotalLength";
NSString *const kDownloadedLength         = @"DownloadedLength";
NSString *const kResumeData               = @"ResumeData";

#import "WDownloadManager.h"
#import "WDownloadItem.h"
#import "NSString+Md5.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/mount.h>
@interface WDownloadManager ()<NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic,strong) NSMutableArray             *downloadingInfo;
@property (nonatomic,strong) NSMutableDictionary        *downloadedInfoDic;
@property (nonatomic,strong) NSMutableArray<id<WDownloadProtocol>>    *downloaded_items;
@property (nonatomic,strong) NSMutableArray<id<WDownloadProtocol>>    *downloading_items;
@property (nonatomic,strong) NSMutableDictionary        *downloadersDic;
@property (nonatomic,strong) NSURLSession               *session;
@property (nonatomic,assign) NSInteger                   currentDownloadingCount;
@property (nonatomic,copy)   NSString                   * tempDirectory;
@property (nonatomic,assign) SCNetworkReachabilityRef     reachabilityRef;


- (void)networkReachableChangedWith:(SCNetworkReachabilityFlags)flags;


@end

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
    @autoreleasepool
    {
        WDownloadManager* manager = (__bridge WDownloadManager*)info;
        [manager networkReachableChangedWith:flags];
    }
}

@implementation WDownloadManager

+ (void)load
{
    __block id observer =
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationDidFinishLaunchingNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *note) {
         [WDownloadManager shareDownloadManager];
         [[NSNotificationCenter defaultCenter] removeObserver:observer];
     }];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSURLSession *)backgroundSession
{
    static NSURLSession * session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = nil;

        //后台执行的配置
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"WeixuetaoMac.WDownloadManager.backgroundSession"];
        }
        else {
            configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:@"WeixuetaoMac.WDownloadManager.backgroundSession"];
        }
        NSOperationQueue *queue            = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount  = 1;
        configuration.allowsCellularAccess = false;
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
    });
    return session;
}


//创建单例对象
+ (WDownloadManager *)shareDownloadManager{
    static WDownloadManager * _downloadManger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _downloadManger = [[WDownloadManager alloc] init];
        
        //获取下载任务
        _downloadManger.downloaded_items = [[NSMutableArray alloc] initWithCapacity:0];
        _downloadManger.downloading_items = [[NSMutableArray alloc] initWithCapacity:0];
        
        
        _downloadManger.session = [_downloadManger backgroundSession];
        _downloadManger.downloadersDic        = [NSMutableDictionary dictionary];
        
        NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
       
        if ([userDefaults objectForKey:kDownloaded]) {
            
            _downloadManger.downloadedInfoDic = [NSMutableDictionary dictionaryWithDictionary:[userDefaults objectForKey:kDownloaded]];
            for (NSDictionary *dic in [_downloadManger.downloadedInfoDic allValues]) {
                WDownloadItem *downloadedItem = [[WDownloadItem alloc] init];
                downloadedItem.downloadUrl          =   dic[kDownloadUrl];
                downloadedItem.downloadState        =   [dic[kDownloadState] integerValue];
                downloadedItem.downloadExtrasData   =   dic[kDownloadExtrasData];
                downloadedItem.downloadProgress     =   [dic[kDownloadProgress] floatValue];
                downloadedItem.targetPath           =   dic[kTargetPath];
                downloadedItem.totalLength          =   [dic[kTotalLength] longLongValue];
                downloadedItem.downloadedLength     =   [dic[kDownloadedLength] longLongValue];
                [_downloadManger.downloaded_items addObject:downloadedItem];
            }

        }else{
            _downloadManger.downloadedInfoDic = [NSMutableDictionary dictionary];
        }
        
        
        if ([userDefaults objectForKey:kDownloading]) {
            _downloadManger.downloadingInfo = [NSMutableArray arrayWithArray:[userDefaults objectForKey:kDownloading]];
            for (NSDictionary *dic in _downloadManger.downloadingInfo) {
                WDownloadItem *downloadingItem    = [[WDownloadItem alloc] init];
                downloadingItem.downloadUrl        =   dic[kDownloadUrl];
                downloadingItem.downloadProgress   =   [dic[kDownloadProgress] floatValue];
                downloadingItem.downloadState      =   WDownloadStatePaused;
                downloadingItem.downloadExtrasData =   dic[kDownloadExtrasData];
                downloadingItem.targetPath         =   dic[kTargetPath];
                downloadingItem.totalLength        =   [dic[kTotalLength] longLongValue];
                downloadingItem.downloadedLength   =   [dic[kDownloadedLength] longLongValue];
                if ([dic objectForKey:kResumeData]) {
                    downloadingItem.resumeData = dic[kResumeData];
                }
                _downloadManger.downloadersDic[[downloadingItem.downloadUrl md5]] = downloadingItem;
                [_downloadManger.downloading_items addObject:downloadingItem];
            }
        }
        else {
            _downloadManger.downloadingInfo   = [NSMutableArray array];
        }

        [_downloadManger.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSURLSessionDownloadTask *task in downloadTasks) {
                    if (!task.error) {
                        [task cancelByProducingResumeData:^(NSData *resumeData) {
                            NSString *url        = task.currentRequest.URL.absoluteString;
                            WDownloadItem *item = _downloadManger.downloadersDic[[url md5]];
                            item.resumeData = resumeData ?: nil;
                        }];
                    }
                }
            });
        }];
        
        
        _downloadManger.concurrentDownloadingCount = kDownloadDefaultConcurrentDownloadingCount;
        _downloadManger.allowedBackgroundDownload = YES;
        
        //创建零地址，0.0.0.0的地址表示查询本机的网络连接状态
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        _downloadManger.reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
        
        
        //添加通知
        [[NSNotificationCenter defaultCenter] addObserver:_downloadManger selector:@selector(didEnterBackgroundHandle) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:_downloadManger selector:@selector(willTerminateHandle) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:_downloadManger selector:@selector(willEnterForegroundHandle) name:UIApplicationWillEnterForegroundNotification object:nil];
       
        
        [_downloadManger startNotifierOnRunLoop:[NSRunLoop currentRunLoop]];
    });
    return _downloadManger;
}


#pragma mark ---------------NetWorkReachability
- (BOOL)startNotifierOnRunLoop:(NSRunLoop *)runLoop{
    //获取最新的网路状态
    BOOL retVal = NO;
    SCNetworkReachabilityContext context = { 0, (__bridge  void *)(self), NULL, NULL, NULL };

    if (SCNetworkReachabilitySetCallback(self.reachabilityRef, ReachabilityCallback, &context)) {
        if(SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, runLoop.getCFRunLoop, kCFRunLoopDefaultMode)) {
            retVal = YES;
        }
    }
    return retVal;
}



#pragma mark ----------------appNotification
- (void)didEnterBackgroundHandle{
    for (WDownloadItem *item in self.downloading_items) {
        
        if (self.allowedBackgroundDownload) {
            if (item.downloadState == WDownloadStateWaiting) {
                if (item.downloadState != NSURLSessionTaskStateCompleted) {
                    BOOL suc = [self resumeDownloadWithItem:item];
                    if (!suc) {
                        item.downloadState = WDownloadStateFailed;
                        [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                        continue;
                    }
                    item.downloadState = WDownloadStateDownloading;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                }
            }
        }
        else {
            if (item.downloadState == WDownloadStateDownloading) {
                [self cancelDownloadTaskWithItem:item];
            }
            if (item.downloadState != WDownloadStatePaused && item.downloadState != WDownloadStateFailed) {
                item.downloadState  = WDownloadStatePaused;
                [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
            }
        }
    }
    self.currentDownloadingCount = 0;
    [self saveDownloadInfo];
}

- (void)willTerminateHandle{
    for (WDownloadItem *item in self.downloading_items) {
        if (item.downloadTask.state == NSURLSessionTaskStateRunning) {
            [self cancelDownloadTaskWithItem:item];
            item.downloadState = WDownloadStatePaused;
        }
    }
    if (self.downloading_items.count == 0) {
        [self.session invalidateAndCancel];
    }
    [self saveDownloadInfo];
}

- (void)willEnterForegroundHandle{
    for (WDownloadItem *item in self.downloading_items) {
        if (item.downloadState == WDownloadStateDownloading) {
            if (self.currentDownloadingCount < self.concurrentDownloadingCount) {
                ++self.currentDownloadingCount;
            }
            else {
                if (item.downloadTask.state != NSURLSessionTaskStateCompleted) {
                    [self cancelDownloadTaskWithItem:item];
                }
                item.downloadState = WDownloadStateWaiting;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
        }
    }
}


- (void)setHttpheadersWithRequest:(NSMutableURLRequest *)request{
    if (self.httpHeader) {
        [self.httpHeader enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            //设置请求头
            [request setValue:obj forHTTPHeaderField:key];
        }];
    }
}

#pragma mark -----------------网络判断
- (BOOL)isReachableViaWWAN{
    SCNetworkReachabilityFlags flags = 0;
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        // check we're REACHABLE
        if(flags & kSCNetworkReachabilityFlagsReachable)
        {
            // now, check we're on WWAN
            if(flags & kSCNetworkReachabilityFlagsIsWWAN)
            {
                return YES;
            }
        }
    }
    return NO;
}

-(BOOL)isReachableViaWiFi
{
    SCNetworkReachabilityFlags flags = 0;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
    {
        // check we're reachable
        if((flags & kSCNetworkReachabilityFlagsReachable))
        {
            // check we're NOT on WWAN
            if((flags & kSCNetworkReachabilityFlagsIsWWAN))
            {
                return NO;
            }
            return YES;
        }
    }
    return NO;
}


-(BOOL)isReachable{
    SCNetworkReachabilityFlags flags;
    
    if(!SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
        return NO;
    
    return [self isReachableWithFlags:flags];
}

#define testcase (kSCNetworkReachabilityFlagsConnectionRequired | kSCNetworkReachabilityFlagsTransientConnection)
-(BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags
{
    BOOL connectionUP = YES;
    
    if(!(flags & kSCNetworkReachabilityFlagsReachable))
        connectionUP = NO;
    
    if( (flags & testcase) == testcase )
        connectionUP = NO;
    if(flags & kSCNetworkReachabilityFlagsIsWWAN)
    {
        // we're on 3G
        if(!self.allowedDownloadOnWWAN)
        {
            //
            // we dont want to connect when on 3G
            connectionUP = NO;
        }
    }
    return connectionUP;
}

-(void)networkChangedToWWANHandle
{
    if (![self isReachableViaWiFi] && [self isReachableViaWWAN]) {
        [self pauseAllDownloadTask];
    }
    else if (![self isReachableViaWiFi] && ![self isReachableViaWWAN]) {
        [self networkNotReachableHandle];
    }
}

- (void)networkNotReachableHandle
{
    if ([self isReachableViaWiFi]) {
        return;
    }
    else if ([self isReachableViaWWAN]
             ) {
        [self networkChangedToWWANHandle];
        return;
    }
    for (WDownloadItem *item in self.downloading_items) {
        if (item.downloadState != WDownloadStatePaused) {
            if (item.downloadTask) {
                [self cancelDownloadTaskWithItem:item];
            }
            if (item.downloadState != WDownloadStateFailed) {
                item.downloadState = WDownloadStateFailed;
                [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
            }
        }
    }
    self.currentDownloadingCount = 0;
}


#pragma mark ------------------Manager Method
/**
 开始下载
 
 @param url urlsource
 @param extrasData 保存附加信息
 @return 返回下载返回的错误状态
 */
- (WDownloadError)startDownloadWithUrl:(NSString *)url
                            extrasData:(NSDictionary *)extrasData{
    NSURL * requestUrl = [NSURL URLWithString:url];
    if (!requestUrl) {
        //判断url是否存在
        return WDownloadErrorUrlError;
    }
    
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:requestUrl cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15];
    [self setHttpheadersWithRequest:request];
    
    if (extrasData == nil) {
        extrasData = @{};
    }
     return [self startDownloadWithRequest:request  extrasData:extrasData];
}

- (WDownloadError)startDownloadWithRequest:(NSURLRequest *)urlRequest
                                extrasData:(NSDictionary *)extrasData{
    if ([self.downloadedInfoDic objectForKey:[urlRequest.URL.absoluteString md5]]) {
        return WDownloadErrorDownloaded;
    }else if ([self.downloadedInfoDic objectForKey:[urlRequest.URL.absoluteString md5]]){
        return WDownloadErrorExisting;
    }
    
    WDownloadItem *downloadItem    = [[WDownloadItem alloc] init];
    downloadItem.downloadUrl        = urlRequest.URL.absoluteString;
    downloadItem.request            = urlRequest;
    downloadItem.downloadExtrasData = extrasData;
    if ([self isReachable]) {
        if (self.currentDownloadingCount < self.concurrentDownloadingCount) {
            downloadItem.downloadTask = [self.session downloadTaskWithRequest:urlRequest];
            if (!downloadItem.downloadTask.currentRequest) {
                [downloadItem.downloadTask cancel];
                return WDownloadErrorUrlError;
            }
            [downloadItem.downloadTask resume];
            downloadItem.downloadState = WDownloadStateDownloading;
            ++self.currentDownloadingCount;
        }
        else {
            downloadItem.downloadState = WDownloadStateWaiting;
        }
    }
    else {
        downloadItem.downloadState    = WDownloadStatePaused;
        if ([self isReachableViaWWAN]) {
            return WDownloadErrorWifiNotReachable;
        }
        else {
            return WDownloadErrorNetworkNotReachable;
        }
    }
    [self.downloading_items addObject:downloadItem];
    self.downloadersDic[[urlRequest.URL.absoluteString md5]] = downloadItem;
    return WDownloadErrorNone;
}


/**
 暂停所有下载任务
 */
- (void)pauseAllDownloadTask{
    for (WDownloadItem * item in self.downloading_items) {
        //失败或者等待状态
        if (item.downloadState == WDownloadStateFailed || item.downloadState == WDownloadStateWaiting) {
            item.downloadState = WDownloadStatePaused;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
        }else if (item.downloadState == WDownloadStateDownloading){
            
            [self cancelDownloadTaskWithItem:item];
            
            item.downloadState = WDownloadStatePaused;
            [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
        }
    }
}

/**
 回复所有下载
 
 @return 返回恢复下载的错误状态
 */
- (WDownloadError)resumeAllDownloadTask{
    if (![self isReachable]) {
        //判断网络是否可用
        if ([self isReachableViaWWAN]) {
            return WDownloadErrorWifiNotReachable;
        }
        return WDownloadErrorNetworkNotReachable;
    }
    
    for (WDownloadItem *item in self.downloading_items) {
        if (self.currentDownloadingCount < self.concurrentDownloadingCount) {
            if (item.downloadState != WDownloadStateDownloading) {
                BOOL suc = [self resumeDownloadWithItem:item];
                if (!suc) {
                    item.downloadState = WDownloadStateFailed;
                    continue;
                }
                item.downloadState = WDownloadStateDownloading;
                ++self.currentDownloadingCount;
            }
        }
        else {
            if (item.downloadState != WDownloadStateDownloading) {
                item.downloadState = WDownloadStateWaiting;
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
    }
    return WDownloadErrorNone;
}


/**
 删除一个下载中任务或者已下载的文件
 @param url urlSource
 */
- (void)deleteDownloadWithUrl:(NSString *)url{
    if ([self.downloadersDic objectForKey:[url md5]]) {
        WDownloadItem *item = self.downloadersDic[[url md5]];
        if (item.downloadState == WDownloadStateDownloading) {
            --self.currentDownloadingCount;
            [self resumeAWaitingItemWithIndex:[self.downloaded_items indexOfObject:item]];
        }
        item.downloadState = WDownloadStateFinished;
        [item.downloadTask cancel];
        item.downloadTask = nil;
        [self.downloading_items removeObject:item];
        [self.downloadersDic   removeObjectForKey:[url md5]];
        [self.downloadingInfo  removeObject:item];
    }
    else if ([self.downloadedInfoDic objectForKey:[url md5]]) {
        [self.downloadedInfoDic removeObjectForKey:[url md5]];
        for (WDownloadItem *item in self.downloaded_items) {
            if ([item.downloadUrl isEqualToString:url]) {
                [self.downloaded_items removeObject:item];
                break;
            }
        }
        
        NSString *filePath = [self downloadPathWithUrl:url];
        BOOL fileExist     = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        NSError *error     = nil;
        if (fileExist) {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        }
        if (error) {
            NSLog(@"%s:删除文件失败：%@",__FUNCTION__,error);
        }
    }

}

/**
 暂停一个下载任务
 
 @param url url
 */
- (void)pauseDownloadTaskWithUrl:(NSString *)url{
    if ([self.downloadersDic objectForKey:[url md5]]) {
        WDownloadItem *item = self.downloadersDic[[url md5]];
        [self cancelDownloadTaskWithItem:item];
        item.downloadState   = WDownloadStatePaused;
        --self.currentDownloadingCount;
        [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
        [self resumeAWaitingItemWithIndex:[self.downloading_items indexOfObject:item]];
    }
}

/**
 恢复一个下载任务
 
 @param url urlSource
 @return 返回恢复下载的错误状态
 */
- (WDownloadError)resumeDownloadTaskWithUrl:(NSString *)url{
    if (![self isReachable]) {
        if ([self isReachableViaWWAN]) {
            return WDownloadErrorWifiNotReachable;
        }
        else {
            return WDownloadErrorNetworkNotReachable;
        }
    }
    WDownloadItem *item = self.downloadersDic[[url md5]];
    if ([self.downloadersDic objectForKey:[url md5]]) {
        switch (item.downloadState) {
            case WDownloadStatePaused:
            {
                if (self.currentDownloadingCount < self.concurrentDownloadingCount) {
                    BOOL success = [self resumeDownloadWithItem:item];
                    if (!success) {
                        item.downloadState = WDownloadStateFailed;
                        [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                        return WDownloadErrorUrlError;
                    }
                    item.downloadState = WDownloadStateDownloading;
                    ++self.currentDownloadingCount;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                    
                }
                else {
                    item.downloadState = WDownloadStateWaiting;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                }
            }
                break;
            case WDownloadStateWaiting:
            {
                item.downloadState = WDownloadStatePaused;
                [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
            }
                break;
            case WDownloadStateFailed:
            {
                if (self.currentDownloadingCount < self.concurrentDownloadingCount) {
                    BOOL success = [self resumeDownloadWithItem:item];
                    if (!success) {
                        return WDownloadErrorUrlError;
                    }
                    item.downloadState = WDownloadStateDownloading;
                    ++self.currentDownloadingCount;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                }
                else {
                    item.downloadState = WDownloadStateWaiting;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                }
            }
                break;
            default:
                break;
        }
    }
    return WDownloadErrorNone;
}

/**
 删除所有下载任务
 */
- (void)deleteAllDownloadingTask{
    [self.downloadersDic removeAllObjects];
    [self.downloadingInfo removeAllObjects];
    for (WDownloadItem *item in self.downloading_items) {
        item.downloadState = WDownloadStateFinished;
        [item.downloadTask cancel];
        item.downloadTask = nil;
    }
    self.currentDownloadingCount = 0;
    [self.downloading_items removeAllObjects];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.session resetWithCompletionHandler:^{dispatch_semaphore_signal(semaphore);}];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (self.tempDirectory) {
        NSError *error = nil;
        NSArray *directoryContents = [[NSFileManager defaultManager]
                                      contentsOfDirectoryAtPath:self.tempDirectory error:&error];
        if (error){NSLog(@"%s--error:%@",__func__,error);}
        error = nil;
        for(NSString *fileName in directoryContents) {
            NSString *path = [self.tempDirectory stringByAppendingPathComponent:fileName];
            BOOL fileExit = [[NSFileManager defaultManager] fileExistsAtPath:path];
            if (!fileExit) {
                return;
            }
            [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
            if(error) {
                NSLog(@"%s--delete downloadedFile error:%@",__func__,error);
            }
        }
    }
    [self saveDownloadInfo];
}

/**
 删除所有已下载文件
 */
- (void)deleteAllDownloadedFile{
    [self.downloaded_items removeAllObjects];
    [self.downloadedInfoDic removeAllObjects];
    NSError *error = nil;
    NSArray *directoryContents = [[NSFileManager defaultManager]
                                  contentsOfDirectoryAtPath:[self downloadDirectory] error:&error];
    if (error) NSLog(@"%s--error:%@",__func__,error);
    error = nil;
    for(NSString *fileName in directoryContents) {
        NSString *path = [[self downloadDirectory] stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        if(error) {
            NSLog(@"%s--delete downloadedFile error:%@",__func__,error);
        }
    }
}

/**
 返回下载目录
 
 @return 下载目录
 */
- (NSString *)downloadDirectory{
    //获取下载路径
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString * cachesDirectory = paths[0];
    NSString *downloadedDirectory = [cachesDirectory stringByAppendingPathComponent:kDownloadDirectory];
    
    BOOL isDirectory = YES;
    BOOL folderExists = [[NSFileManager defaultManager] fileExistsAtPath:downloadedDirectory isDirectory:&isDirectory] && isDirectory;
    
    if (!folderExists)
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:downloadedDirectory withIntermediateDirectories:YES attributes:nil error:&error];
    }
    return downloadedDirectory;
    
}

/**
 获取文件下载路径
 
 @param url url
 @return 文件下载路径
 */
- (NSString *)downloadPathWithUrl:(NSString *)url{
    NSString * filePath = [self.downloadDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",[url md5],url.pathExtension]];
    return filePath;
}

/**
 磁盘总空间
 
 @return 磁盘总空间
 */
+ (float)totalDiskSpaceInBytes{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    struct statfs tStats;
    
    statfs([[paths lastObject] cStringUsingEncoding:NSUTF8StringEncoding], &tStats);
    
    float totalSpace = (float)(tStats.f_blocks * tStats.f_bsize);
    
    return totalSpace;
}

/**
 磁盘剩余空间
 
 @return 磁盘剩余空间
 */
+ (float)freeDiskSpaceInBytes{
    struct statfs buf;
    long long freespace = -1;
    if (statfs("/var", &buf) >= 0) {
        freespace = (long long)(buf.f_bsize * buf.f_bfree);
    }
    return freespace;
}

- (void)networkReachableChangedWith:(SCNetworkReachabilityFlags)flags{
    
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL canConnectionAutomatically = (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0));
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isNetworkReachable == NO) {
            [self performSelector:@selector(networkNotReachableHandle) withObject:nil afterDelay:3.5];
        }
        else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
            //viawwan
            if (!self.allowedDownloadOnWWAN) {
                [self performSelector:@selector(networkChangedToWWANHandle) withObject:nil afterDelay:3.5];
            }
        }
        else {
            //wifi
        }
    });
}


#pragma mark --------------download control
- (void)cancelDownloadTaskWithItem:(WDownloadItem *)item
{
    BOOL notCancelable = (item.canceling || (item.downloadTask == nil) || (item.downloadTask.state == NSURLSessionTaskStateCompleted) || (item.downloadTask.state == NSURLSessionTaskStateCanceling));
    if (notCancelable) {return;}
    item.canceling = YES;
    dispatch_time_t waitTime = dispatch_time(DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER);
    
    dispatch_semaphore_t seamphore = dispatch_semaphore_create(0);
    [item.downloadTask cancelByProducingResumeData:^(NSData *resumeData) {
        item.resumeData = resumeData;
        dispatch_semaphore_signal(seamphore);
    }];
    dispatch_semaphore_wait(seamphore, waitTime);
    item.canceling = NO;
    item.downloadTask = nil;
}

//是否回复当前现在
- (BOOL)resumeDownloadWithItem:(WDownloadItem *)item
{
    if (item.resumeData) {
        item.downloadTask = [self.session downloadTaskWithResumeData:item.resumeData];
    }
    else {
        if (item.request) {
            item.downloadTask = [self.session downloadTaskWithRequest:item.request];
        }
        else {
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:item.downloadUrl]];
            [self setHttpheadersWithRequest:request];
            item.request = request;
            item.downloadTask = [self.session downloadTaskWithRequest:request];
        }
    }
    if (!item.downloadTask.currentRequest) {
        [item.downloadTask cancel];
        return NO;
    }
    [item.downloadTask resume];
    return YES;
}

- (void)resumeAWaitingItemWithIndex:(NSInteger)index
{
    BOOL success = NO;
    for (NSInteger i= (index + 1); i<self.downloading_items.count;++i) {
        WDownloadItem *item = self.downloading_items[i];
        if (item.downloadState == WDownloadStateWaiting && self.currentDownloadingCount < self.concurrentDownloadingCount) {
            if (item.downloadTask.state != NSURLSessionTaskStateCompleted) {
                BOOL suc = [self resumeDownloadWithItem:item];
                if (!suc) {
                    item.downloadState = WDownloadStateFailed;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                    continue;
                }
                item.downloadState = WDownloadStateDownloading;
                ++self.currentDownloadingCount;
                success = YES;
                [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                break;
            }
        }
    }
    
    if (!success) {
        for (int i=0; i<self.downloading_items.count; ++i) {
            WDownloadItem *item = self.downloading_items[i];
            if (item.downloadState == WDownloadStateWaiting && self.currentDownloadingCount < self.concurrentDownloadingCount) {
                if (item.downloadTask.state != NSURLSessionTaskStateCompleted) {
                    BOOL suc = [self resumeDownloadWithItem:item];
                    if (!suc) {
                        item.downloadState = WDownloadStateFailed;
                        [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                        continue;
                    }
                    item.downloadState = WDownloadStateDownloading;
                    ++self.currentDownloadingCount;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:item];
                    break;
                }
            }
        }
    }
}


#pragma mark ------------保存下载信息
- (void)saveDownloadInfo{
    [self.downloadingInfo removeAllObjects];
    
    for (WDownloadItem * downloadItem in self.downloading_items) {
        NSDictionary *itemInfo = @{kDownloadUrl       :downloadItem.downloadUrl,
                                   kDownloadExtrasData:downloadItem.downloadExtrasData,
                                   kDownloadState     :@(downloadItem.downloadState),
                                   kDownloadProgress  :@(downloadItem.downloadProgress),
                                   kTotalLength       :@(downloadItem.totalLength),
                                   kDownloadedLength  :@(downloadItem.downloadedLength)};
        NSMutableDictionary *mutableItemInfo = [NSMutableDictionary dictionaryWithDictionary:itemInfo];
        if (downloadItem.resumeData) {
            mutableItemInfo[kResumeData] = downloadItem.resumeData;
        }
        [self.downloadingInfo addObject:mutableItemInfo];
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:self.downloadedInfoDic forKey:kDownloaded];
    [userDefaults setObject:self.downloadingInfo   forKey:kDownloading];
    [userDefaults synchronize];
}

#pragma mark -------------------------- getter
- (NSArray *)downloadedItems
{
    return self.downloaded_items;
}

- (NSArray *)downloadingItems
{
    return self.downloading_items;
}


#pragma mark   session delegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSHTTPURLResponse *response =  (NSHTTPURLResponse*)downloadTask.response;
    if (response.statusCode == 404) return;
    double progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
    NSString *key = [downloadTask.currentRequest.URL.absoluteString md5];
    dispatch_async(dispatch_get_main_queue(), ^{
        WDownloadItem *item  = self.downloadersDic[key];
        if (item.downloadTask == nil) {
            [downloadTask cancelByProducingResumeData:^(NSData *resumeData) {
                item.resumeData = resumeData;
            }];
            return ;
        }
        item.downloadProgress = progress;
        item.downloadedLength = totalBytesWritten;
        if (!item.date) {
            item.date = [NSDate date];
        }
        if (!item.totalLength) {
            item.totalLength  = totalBytesExpectedToWrite;
        }
        
        item.bytesOfOneSecondDownload += bytesWritten;
        NSDate *currentDate = [NSDate date];
        double time = [currentDate timeIntervalSinceDate:item.date];
        if (time >= 1) {
            long long speed                  = item.bytesOfOneSecondDownload/time;
            item.downloadSpeed               = [NSByteCountFormatter stringFromByteCount:speed countStyle:NSByteCountFormatterCountStyleFile];
            item.bytesOfOneSecondDownload    = 0.0;
            item.date                        = currentDate;
        }
        if (time > 0.5) {
            [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadProgressChangedNotification object:item];
        }
    });
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)downloadURL
{
    
    if (!self.tempDirectory) {
        NSString *lastPathComponent = [downloadURL absoluteString].lastPathComponent;
        NSMutableString *tempUrlStr = [NSMutableString stringWithString:[downloadURL absoluteString]];
        [tempUrlStr deleteCharactersInRange:[tempUrlStr rangeOfString:lastPathComponent]];
        [tempUrlStr deleteCharactersInRange:[tempUrlStr rangeOfString:@"file://"]];
        self.tempDirectory = [NSString stringWithString:tempUrlStr];
    }
    NSString *url              = downloadTask.currentRequest.URL.absoluteString;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExists = [fileManager fileExistsAtPath:[self downloadPathWithUrl:url]];
    if (fileExists) return;
    NSError *errorMove;
    NSURL *destinationURL      = [NSURL fileURLWithPath:[self downloadPathWithUrl:url]];
    BOOL success               = [fileManager moveItemAtURL:downloadURL toURL:destinationURL error:&errorMove];
    if (!success)
    {
        NSLog(@"%s--move file error :%@",__func__,errorMove);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *url = task.currentRequest.URL.absoluteString;
        WDownloadItem *downloadItem = self.downloadersDic[[url md5]];
        if (!downloadItem) {
            [task cancel];
            return;
        }
        if (error == nil) {
            downloadItem.targetPath = [self downloadPathWithUrl:url];
            NSDictionary *itemInfo = @{kDownloadUrl       :downloadItem.downloadUrl,
                                       kDownloadState     :@(WDownloadStateFinished),
                                       kDownloadProgress  :@(downloadItem.downloadProgress),
                                       kDownloadExtrasData:downloadItem.downloadExtrasData,
                                       kTargetPath        :downloadItem.targetPath,
                                       kTotalLength       :@(downloadItem.totalLength),
                                       kDownloadedLength  :@(downloadItem.totalLength)};
            self.downloadedInfoDic[[downloadItem.downloadUrl md5]] = itemInfo;
            [self.downloaded_items addObject:downloadItem];
            NSInteger index = [self.downloading_items indexOfObject:downloadItem];
            if (downloadItem.downloadState == WDownloadStateDownloading && self.currentDownloadingCount > 0) {
                --self.currentDownloadingCount;
                downloadItem.downloadState = WDownloadStateFinished;
                [self resumeAWaitingItemWithIndex:index];
            }
            downloadItem.downloadState = WDownloadStateFinished;
            downloadItem.downloadTask  = nil;
            [self.downloadersDic removeObjectForKey:[downloadItem.downloadUrl md5]];
            [self.downloading_items removeObject:downloadItem];
            if (index != NSNotFound) {
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:WDownloadStateChangedNotification
                 object:downloadItem
                 userInfo:@{@"index":@(index)}];
            }
        }
        else {
            
            if (downloadItem.downloadState == WDownloadStateFinished) return ;
            
            downloadItem.downloadTask = nil;
            NSData *resumeData = nil;
            if (!([[error.userInfo objectForKey:@"NSLocalizedDescription"] isEqualToString:@"cancelled"] && error.code == NSURLErrorCancelled)) {
                resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
                if (resumeData) {
                    downloadItem.resumeData = resumeData;
                    double progress = (double)task.countOfBytesReceived / (double)task.countOfBytesExpectedToReceive;
                    if (!((progress >= 1) || (task.countOfBytesExpectedToReceive == 0) || (task.countOfBytesReceived == 0))) {
                        downloadItem.downloadProgress = progress;
                        downloadItem.downloadedLength = task.countOfBytesReceived;
                        downloadItem.totalLength      = task.countOfBytesExpectedToReceive;
                        [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadProgressChangedNotification object:downloadItem];
                    }
                }
                if (downloadItem.downloadState == WDownloadStateDownloading && error.code != NSURLErrorCancelled) {
                    NSLog(@"%s--downloadError:%@",__func__,error);
                    downloadItem.downloadState = WDownloadStateFailed;
                    --self.currentDownloadingCount;
                    [[NSNotificationCenter defaultCenter] postNotificationName:WDownloadStateChangedNotification object:downloadItem];
                    [self resumeAWaitingItemWithIndex:[self.downloading_items indexOfObject:downloadItem]];
                }
            }
        }
    });
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    id appDelegate = [[UIApplication sharedApplication] delegate];
    if ([appDelegate respondsToSelector:@selector(backgroundSessionCompletionHandler)]) {
        if ([appDelegate performSelector:@selector(backgroundSessionCompletionHandler)]) {
            void (^completionHandler)() = [appDelegate performSelector:@selector(backgroundSessionCompletionHandler)];
            [appDelegate performSelector:@selector(setBackgroundSessionCompletionHandler:) withObject:nil];
            completionHandler();
        }
    }
#pragma clang diagnostic pop
    if (self.downloadAllCompleteInbackground) {
        self.downloadAllCompleteInbackground();
    }
    NSLog(@"All tasks are finished");
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    NSLog(@"resume");
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    if (self.receiveChallengeHandle) {
        self.receiveChallengeHandle(session,task,challenge,completionHandler);
    }
}

@end


NSString * const WDownloadProgressChangedNotification  = @"WDownloadProgressChangedNotification";

NSString * const WDownloadStateChangedNotification     = @"WDownloadStateChangedNotification";

