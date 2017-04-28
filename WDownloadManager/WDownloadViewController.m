//
//  WDownloadViewController.m
//  WDownloadManager
//
//  Created by 魏学涛 on 2017/4/27.
//  Copyright © 2017年 魏学涛. All rights reserved.
//

#import "WDownloadViewController.h"
#import "WDownloadManager.h"
#import "DownloadCell.h"
@interface WDownloadViewController ()<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, strong) UITableView            *taskTableView;
@property (nonatomic, strong) UISegmentedControl     *segmentedControl;
@property (nonatomic, strong) UIView                 *topView;
@property (nonatomic, strong) UILabel                *diskSpace;

@end

@implementation WDownloadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self layoutDownloadTaskView];
}


- (void)layoutDownloadTaskView{
    UISegmentedControl * navSeg = [[UISegmentedControl alloc] initWithItems:@[@"正在下载",@"下载完成"]];
    navSeg.selectedSegmentIndex = 0;
    navSeg.frame = CGRectMake(0, 0, 160, 30);
    [navSeg addTarget:self action:@selector(selectTableChanged:) forControlEvents:UIControlEventValueChanged];
    navSeg.tintColor = [UIColor orangeColor];
    self.navigationItem.titleView  = navSeg;
    
    
    UIBarButtonItem * rightItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(navButtonAction)];
    self.navigationItem.rightBarButtonItem = rightItem;
    
    
    //0,122,255
    UIButton * deleteAll = [[UIButton alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width/2, 35)];
    [deleteAll setTitle:@"全部删除" forState:UIControlStateNormal];
    [deleteAll setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [deleteAll addTarget:self action:@selector(deleteAllAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:deleteAll];
    
    
    self.diskSpace = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2, 64, self.view.frame.size.width/2, 35)];
    self.diskSpace.textColor = [UIColor blackColor];
    self.diskSpace.font = [UIFont systemFontOfSize:15];
    self.diskSpace.textAlignment = NSTextAlignmentCenter;
    self.diskSpace.text = self.diskSpaceInfo;
    [self.view addSubview:self.diskSpace];
    
    self.taskTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, self.diskSpace.frame.origin.y+35, self.view.frame.size.width, self.view.frame.size.height-99) style:UITableViewStylePlain];
    self.taskTableView.clipsToBounds = YES;
    self.taskTableView.dataSource = self;
    self.taskTableView.delegate = self;
    self.taskTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.taskTableView];
    
}


#pragma mark- delegate
#pragma mark UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_segmentedControl.selectedSegmentIndex == 0) {
        return WDownloadManager.shareDownloadManager.downloadingItems.count;
    }
    else {
        return WDownloadManager.shareDownloadManager.downloadedItems.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *iden = @"ListCell";
    DownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:iden];
    if (!cell) {
        cell = [[[NSBundle mainBundle]loadNibNamed:@"DownloadCell" owner:self options:nil]lastObject];
    }
    id<WDownloadProtocol> item = nil;
    cell.progressView.hidden        = _segmentedControl.selectedSegmentIndex;
    cell.progressLabel.hidden       = _segmentedControl.selectedSegmentIndex;
    cell.speedLabel.hidden          = _segmentedControl.selectedSegmentIndex;
    cell.detailTextLabel.hidden     = _segmentedControl.selectedSegmentIndex;
    if (_segmentedControl.selectedSegmentIndex == 1) {
        if ([WDownloadManager shareDownloadManager].downloadedItems.count) {
            item = [WDownloadManager shareDownloadManager].downloadedItems[indexPath.row];
        }
    }
    else {
        if ([WDownloadManager shareDownloadManager].downloadingItems.count) {
            item = [WDownloadManager shareDownloadManager].downloadingItems[indexPath.row];
        }
    }
    cell.item = item;
    return cell;
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_segmentedControl.selectedSegmentIndex == 1) {
        return;
    }
    id<WDownloadProtocol> item = [WDownloadManager shareDownloadManager].downloadingItems[indexPath.row];
    switch ([item downloadState]) {
        case WDownloadStateDownloading:
            [[WDownloadManager shareDownloadManager] pauseDownloadTaskWithUrl:[item downloadUrl]];
            break;
        case WDownloadStateFailed:
        case WDownloadStateWaiting:
        case WDownloadStatePaused:
        {
            WDownloadError  error = [[WDownloadManager shareDownloadManager] resumeDownloadTaskWithUrl:[item downloadUrl]];
            if (error == WDownloadErrorNone) {
                return;
            }
            else if (error == WDownloadErrorNetworkNotReachable) {
                NSLog(@"请检查网络");
            }
            else if (error == WDownloadErrorWifiNotReachable) {
                NSLog(@"请连接Wifi");
            }
        }
            break;
        default:
            break;
    }
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return  UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<WDownloadProtocol> item = nil;
    if (_segmentedControl.selectedSegmentIndex) {
        item = [WDownloadManager shareDownloadManager].downloadedItems[indexPath.row];
    }
    else {
        item = [WDownloadManager shareDownloadManager].downloadingItems[indexPath.row];
    }
    [[WDownloadManager shareDownloadManager] deleteDownloadWithUrl:[item downloadUrl]];
    [tableView beginUpdates];
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [tableView endUpdates];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"删除";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 80;
}

#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == 0) {
        return;
    } else {
        if (_segmentedControl.selectedSegmentIndex == 0) {
            [[WDownloadManager shareDownloadManager] deleteAllDownloadingTask];
            [self.taskTableView reloadData];
        }
        else {
            [[WDownloadManager shareDownloadManager] deleteAllDownloadedFile];
            [self.taskTableView reloadData];
        }
    }
}


#pragma mark- action
- (void)pauseOrResumeAll:(UIButton *)sender
{
    sender.selected = !sender.selected;
    if (sender.selected) {
        [[WDownloadManager shareDownloadManager] pauseAllDownloadTask];
    }
    else {
        WDownloadError error = [[WDownloadManager shareDownloadManager] resumeAllDownloadTask];
        if (error == WDownloadErrorNetworkNotReachable) {
            NSLog(@"请检查网络");
        } else if (error == WDownloadErrorWifiNotReachable) {
            NSLog(@"请连接Wifi");
        }
    }
}

- (IBAction)segmentedControlAction:(UISegmentedControl *)sender
{
    _topView.hidden = sender.selectedSegmentIndex;
    [UIView animateWithDuration:.3 animations:^{
        self.taskTableView.frame = CGRectMake(0, sender.selectedSegmentIndex?64:94,[UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - (sender.selectedSegmentIndex?64:94));
    } completion:^(BOOL finished) {
    }];
    [self.taskTableView reloadData];
}

- (void)deleteAllAction:(UIBarButtonItem *)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"删除全部" delegate:self cancelButtonTitle:@"关闭" otherButtonTitles:@"确定", nil];
    [alert show];
}

- (void)downloadDidFinish:(NSNotification *)notification
{
    id<WDownloadProtocol> item = notification.object;
    if (item.downloadState == WDownloadStateFinished) {
        NSInteger index = [notification.userInfo[@"index"] integerValue];
        [self.taskTableView beginUpdates];
        [self.taskTableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
        [self.taskTableView endUpdates];
    }
}

#pragma mark- getter
- (NSString *)diskSpaceInfo
{
    NSString *totalSpace = [NSString stringWithFormat:@"可用:%.1fG",[WDownloadManager totalDiskSpaceInBytes]/1024/1024/1024];
    NSString *freeSpace ;
    float free = [WDownloadManager freeDiskSpaceInBytes]/1024/1024/1024;
    if (free < 1) {
        freeSpace = [NSString stringWithFormat:@"剩余:%.1fM",[WDownloadManager freeDiskSpaceInBytes]/1024/1024];
    }
    else {
        freeSpace = [NSString stringWithFormat:@"剩余:%.1fG",free];
    }
    return [NSString stringWithFormat:@"%@/%@",freeSpace,totalSpace];
}





- (void)selectTableChanged:(UISegmentedControl *)control{

}

- (void)navButtonAction{
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
