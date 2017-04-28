//
//  ViewController.m
//  WDownloadManager
//
//  Created by 魏学涛 on 2017/4/27.
//  Copyright © 2017年 魏学涛. All rights reserved.
//

#import "ViewController.h"
#import "WDownloadManager.h"
#import "WDownloadViewController.h"
@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>

@property (nonatomic, strong) UITableView * sourceTableView;

@property (nonatomic, strong) NSArray * downloadSource;

@end

@implementation ViewController

#pragma mark- view live cycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"点击下载";
    
    UIButton * rightButton  = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
    [rightButton setTitle:@"下载页" forState:UIControlStateNormal];
    [rightButton addTarget:self action:@selector(rightItemAction:) forControlEvents:UIControlEventTouchUpInside];
    [rightButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    rightButton.titleLabel.font = [UIFont systemFontOfSize:13];
    UIBarButtonItem * rightItem = [[UIBarButtonItem alloc] initWithCustomView:rightButton];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [WDownloadManager shareDownloadManager].allowedBackgroundDownload = YES;//设置是否允许后台下载
    [WDownloadManager shareDownloadManager].allowedDownloadOnWWAN = false;//设置是否允许蜂窝移动网络下下载
    
    [self createListTableView];
}

- (void)createListTableView{
    
    self.sourceTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.sourceTableView.dataSource = self;
    self.sourceTableView.delegate = self;
    self.sourceTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.sourceTableView];
    
}


#pragma mark- delegate
#pragma mark UITabelViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.downloadSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *iden = @"ListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:iden];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:iden];
    }
    cell.textLabel.text = self.downloadSource[indexPath.row];
    return cell;
}

#pragma mark UITabelViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *url = self.downloadSource[indexPath.row];
    WDownloadError error = [[WDownloadManager shareDownloadManager] startDownloadWithUrl:url extrasData:@{@"index":@"需要存入的附加信息"}];
    if (error == WDownloadErrorNone) {
        NSLog(@"已加入下载队列");
    }
    else if (error == WDownloadErrorExisting) {
        NSLog(@"已经在下载队列");
    }
    else if (error == WDownloadErrorNetworkNotReachable){
        NSLog(@"请检查网络");
    }
    else if (error == WDownloadErrorUrlError) {
        NSLog(@"无效的下载地址");
    }
    else if (error == WDownloadErrorWifiNotReachable) {
        NSLog(@"请连接Wifi");
    }
}

#pragma mark- getter
- (NSArray *)downloadSource
{
    if (!_downloadSource) {
        _downloadSource = @[
                  @"http://devstreaming.apple.com/videos/wwdc/2014/210xxksa9s9ewsa/210/210_hd_accessibility_on_ios.mov",
                  @"http://devstreaming.apple.com/videos/wwdc/2014/210xxksa9s9ewsa/210/210_sd_accessibility_on_ios.mov",
                  @"http://devstreaming.apple.com/videos/wwdc/2014/229xx77tq0pmkwo/229/229_sd_advanced_ios_architecture_and_patterns.mov",
                  @"http://devstreaming.apple.com/videos/wwdc/2014/404xxdxsstkaqjb/404/404_sd_advanced_swift.mov",
                  @"http://devstreaming.apple.com/videos/wwdc/2014/413xxr7gdc60u2p/413/413_sd_debugging_in_xcode_6.mov"];
    }
    return _downloadSource;
}


- (void)rightItemAction:(UIButton *)btn{
    WDownloadViewController * downloadVC = [[WDownloadViewController alloc] init];
    [self.navigationController pushViewController:downloadVC animated:YES];
}

@end
