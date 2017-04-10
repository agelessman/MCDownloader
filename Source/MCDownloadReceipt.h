//
//  MCDownloadReceipt.h
//  MCDownloadManager
//
//  Created by M.C on 17/4/6. (QQ:714080794 Gmail:chaoma0609@gmail.com)
//  Copyright © 2017年 qikeyun. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>

@class MCDownloadReceipt;

/** The download state */
typedef NS_ENUM(NSUInteger, MCDownloadState) {
    MCDownloadStateNone,           /** default */
    MCDownloadStateWillResume,     /** waiting */
    MCDownloadStateDownloading,    /** downloading */
    MCDownloadStateSuspened,       /** suspened */
    MCDownloadStateCompleted,      /** download completed */
    MCDownloadStateFailed          /** download failed */
};

/** The download prioritization */
typedef NS_ENUM(NSInteger, MCDownloadPrioritization) {
    MCDownloadPrioritizationFIFO,  /** first in first out */
    MCDownloadPrioritizationLIFO   /** last in first out */
};


typedef void(^MCDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize,  NSInteger speed, NSURL * _Nullable targetURL);
typedef void(^MCDownloaderCompletedBlock)(MCDownloadReceipt * _Nullable receipt, NSError * _Nullable error, BOOL finished);

/**
 *  The receipt of a downloader,we can get all the informations from the receipt.
 */
@interface MCDownloadReceipt : NSObject

/**
 * Download State
 */
@property (nonatomic, assign, readonly) MCDownloadState state;

/**
 The download source url
 */
@property (nonatomic, copy, readonly, nonnull) NSString *url;

/**
 The file path, you can use it to get the downloaded data.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *filePath;

/**
 The url's pathExtension through the MD5 processing.
 */
@property (nonatomic, copy, readonly, nullable) NSString *filename;

/**
 The url's pathExtension without through the MD5 processing.
 */
@property (nonatomic, copy, readonly, nullable) NSString *truename;

/**
 The current download speed,
 */
@property (nonatomic, copy, readonly, nullable) NSString *speed;  // KB/s

@property (assign, nonatomic, readonly) long long totalBytesWritten;
@property (assign, nonatomic, readonly) long long totalBytesExpectedToWrite;

/**
 The current download progress object
 */
@property (nonatomic, strong, readonly, nullable) NSProgress *progress;

@property (nonatomic, strong, readonly, nullable) NSError *error;


/**
 The call back block. When setting this block，the progress block will be called during downloading，the complete block will be called after download finished.
 */
@property (nonatomic,copy, nullable, readonly)MCDownloaderProgressBlock downloaderProgressBlock;
@property (nonatomic,copy, nullable, readonly)MCDownloaderCompletedBlock downloaderCompletedBlock;





#pragma mark - Private Methods
///=============================================================================
/// Method is at the bottom of the private method, do not need to use
///=============================================================================

/**
 The `MCDowmloadReceipt` method of initialization. Generally don't need to use this method.
 
 use `MCDownloadReceipt *receipt = [[MCDownloader sharedDownloader] downloadReceiptForURLString:url];` to get the `MCDowmloadReceipt`.

 */
- (nonnull instancetype)initWithURLString:(nonnull NSString *)URLString
             downloadOperationCancelToken:(nullable id)downloadOperationCancelToken
                  downloaderProgressBlock:(nullable MCDownloaderProgressBlock)downloaderProgressBlock
                 downloaderCompletedBlock:(nullable MCDownloaderCompletedBlock)downloaderCompletedBlock;

- (void)setTotalBytesExpectedToWrite:(long long)totalBytesExpectedToWrite;
- (void)setState:(MCDownloadState)state;
- (void)setDownloadOperationCancelToken:(nullable id)downloadOperationCancelToken;
- (void)setDownloaderProgressBlock:(nullable MCDownloaderProgressBlock)downloaderProgressBlock;
- (void)setDownloaderCompletedBlock:(nullable MCDownloaderCompletedBlock)downloaderCompletedBlock;
- (void)setSpeed:(NSString * _Nullable)speed;



/**
 Auxiliary attributes and don't need to use
 */
@property (nonatomic, assign) NSUInteger totalRead;
@property (nonatomic, strong, nullable) NSDate *date;
@property (nonatomic, strong, nullable) id downloadOperationCancelToken;
@end
