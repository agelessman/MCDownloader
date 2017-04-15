# MCDownloader
A simple and powerful iOS downloader.  [中文简介](http://www.jianshu.com/p/062327c5846a)

![](MCDownload.gif)


## Installation

Copy the source file to your project.


## Usage
### Start the download

	[[MCDownloader sharedDownloader] downloadDataWithURL:[NSURL URLWithString:url] progress:^(NSInteger receivedSize, NSInteger expectedSize, NSInteger speed, NSURL * _Nullable targetURL) {
	                
	            } completed:^(MCDownloadReceipt * _Nullable receipt, NSError * _Nullable error, BOOL finished) {
	                NSLog(@"==%@", error.description);
	            }];
	            
### Stop the download

	[[MCDownloader sharedDownloader] cancel:receipt completed:^{
	            [self.button setTitle:@"Start" forState:UIControlStateNormal];
	        }];

### Remove the download

	[[MCDownloader sharedDownloader] remove:receipt completed:^{
	            [self.tableView reloadData];
	        }];
	      
### Get the download information

	MCDownloadReceipt *receipt = [[MCDownloader sharedDownloader] downloadReceiptForURLString:url];
	
### Cancel and remove all downloads

	[[MCDownloader sharedDownloader] cancelAllDownloads];
	
	[[MCDownloader sharedDownloader] removeAndClearAll];
	
## License
MCDownloader is released under an MIT license. See License.md for more information.