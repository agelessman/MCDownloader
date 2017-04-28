//
//  TableViewCell.m
//  MCDownloadManager
//
//  Created by 马超 on 16/9/6.
//  Copyright © 2016年 qikeyun. All rights reserved.
//

#import "TableViewCell.h"
#import "MCDownloader.h"



@implementation TableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
    self.button.clipsToBounds = YES;
    self.button.layer.cornerRadius = 10;
    self.button.layer.borderWidth = 1;
    self.button.layer.borderColor = [UIColor orangeColor].CGColor;
    [self.button setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setUrl:(NSString *)url {
    _url = url;
    
    MCDownloadReceipt *receipt = [[MCDownloader sharedDownloader] downloadReceiptForURLString:url];
//    NSLog(@"%@", receipt.filePath);
    self.nameLabel.text = receipt.truename;
    self.speedLable.text = nil;
    self.bytesLable.text = nil;
    self.progressView.progress = 0;
    
    self.progressView.progress = receipt.progress.fractionCompleted;
    
//    self.imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfFile:receipt.filePath]];
    
    if (receipt.state == MCDownloadStateDownloading || receipt.state == MCDownloadStateWillResume) {
        [self.button setTitle:@"Stop" forState:UIControlStateNormal];
    }else if (receipt.state == MCDownloadStateCompleted) {
         [self.button setTitle:@"Play" forState:UIControlStateNormal];
        self.nameLabel.text = @"Download Finished";
    }else {
         [self.button setTitle:@"Start" forState:UIControlStateNormal];
    }

    __weak typeof(receipt) weakReceipt = receipt;
    receipt.downloaderProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSInteger speed, NSURL * _Nullable targetURL) {
        __strong typeof(weakReceipt) strongReceipt = weakReceipt;
        if ([targetURL.absoluteString isEqualToString:self.url]) {
            [self.button setTitle:@"Stop" forState:UIControlStateNormal];
            self.bytesLable.text = [NSString stringWithFormat:@"%0.1fm/%0.1fm", receivedSize/1024.0/1024,expectedSize/1024.0/1024];
            self.progressView.progress = (receivedSize/1024.0/1024) / (expectedSize/1024.0/1024);
            self.speedLable.text = [NSString stringWithFormat:@"%@/s", strongReceipt.speed ?: @"0"];
        }
        
    };
    
    receipt.downloaderCompletedBlock = ^(MCDownloadReceipt *receipt, NSError * _Nullable error, BOOL finished) {
        if (error) {
            [self.button setTitle:@"Start" forState:UIControlStateNormal];
            self.nameLabel.text = @"Download Failure";
        }else {
            [self.button setTitle:@"Play" forState:UIControlStateNormal];
            self.nameLabel.text = @"Download Finished";
        }
        
    };


}
- (IBAction)buttonAction:(UIButton *)sender {
    
    MCDownloadReceipt *receipt = [[MCDownloader sharedDownloader] downloadReceiptForURLString:self.url];
    if (receipt.state == MCDownloadStateDownloading) {
        
        [[MCDownloader sharedDownloader] cancel:receipt completed:^{
            [self.button setTitle:@"Start" forState:UIControlStateNormal];
        }];
    }else if (receipt.state == MCDownloadStateCompleted) {

        if ([self.delegate respondsToSelector:@selector(cell:didClickedBtn:)]) {
            [self.delegate cell:self didClickedBtn:sender];
        }
    }else {
        [self.button setTitle:@"Stop" forState:UIControlStateNormal];
        [self download];
    }

}

- (void)download {
    
    [[MCDownloader sharedDownloader] downloadDataWithURL:[NSURL URLWithString:self.url] progress:^(NSInteger receivedSize, NSInteger expectedSize, NSInteger speed, NSURL * _Nullable targetURL) {

    } completed:^(MCDownloadReceipt *receipt, NSError * _Nullable error, BOOL finished) {
        NSLog(@"==%@", error.description);
    }];
   

}
@end
