//
//  MCDownloader.h
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
#import "MCDownloadReceipt.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Use dispatch_main_async_safe instead of dispatch_async(dispatch_get_main_queue(), block)
#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}
#endif



FOUNDATION_EXPORT NSString * const MCDownloadCacheFolderName;
FOUNDATION_EXPORT NSString * cacheFolder();


extern NSString * _Nonnull const MCDownloadStartNotification;
extern NSString * _Nonnull const MCDownloadStopNotification;

typedef NSDictionary<NSString *, NSString *> MCHTTPHeadersDictionary;
typedef NSMutableDictionary<NSString *, NSString *> MCHTTPHeadersMutableDictionary;

typedef MCHTTPHeadersDictionary * _Nullable (^MCDownloaderHeadersFilterBlock)(NSURL * _Nullable url, MCHTTPHeadersDictionary * _Nullable headers);


@interface MCDownloader : NSObject

/**
 *  The maximum number of concurrent downloads
 */
@property (assign, nonatomic) NSInteger maxConcurrentDownloads;

/**
 * Shows the current amount of downloads that still need to be downloaded
 */
@property (readonly, nonatomic) NSUInteger currentDownloadCount;


/**
 *  The timeout value (in seconds) for the download operation. Default: 15.0.
 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;


/**
 Defines the order prioritization of incoming download requests being inserted into the queue. `MCDownloadPrioritizationFIFO` by default.
 */
@property (nonatomic, assign) MCDownloadPrioritization downloadPrioritizaton;
/**
 *  Singleton method, returns the shared instance
 *
 *  @return global shared instance of downloader class
 */
+ (nonnull instancetype)sharedDownloader;


/**
 * Set filter to pick headers for downloading image HTTP request.
 *
 * This block will be invoked for each downloading image request, returned
 * NSDictionary will be used as headers in corresponding HTTP request.
 */
@property (nonatomic, copy, nullable) MCDownloaderHeadersFilterBlock headersFilter;

/**
 * Creates an instance of a downloader with specified session configuration.
 * *Note*: `timeoutIntervalForRequest` is going to be overwritten.
 * @return new instance of downloader class
 */
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration NS_DESIGNATED_INITIALIZER;

/**
 * Set a value for a HTTP header to be appended to each download HTTP request.
 *
 * @param value The value for the header field. Use `nil` value to remove the header.
 * @param field The name of the header field to set.
 */
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field;

/**
 * Returns the value of the specified HTTP header field.
 *
 * @return The value associated with the header field field, or `nil` if there is no corresponding header field.
 */
- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field;

/**
 * Sets a subclass of `MCDownloadOperation` as the default
 * `NSOperation` to be used each time MCDownload constructs a request
 * operation to download an data.
 *
 * @param operationClass The subclass of `MCDownloadOperation` to set
 *        as default. Passing `nil` will revert to `MCDownloadOperation`.
 */
- (void)setOperationClass:(nullable Class)operationClass;

/**
 Creates an `MCDownloadReceipt` with the specified request.
 
 @param url The URL  for the request.
 @param progressBlock A block object to be executed when the download progress is updated. Note this block is called on the main queue.
 */
- (nullable MCDownloadReceipt *)downloadDataWithURL:(nullable NSURL *)url
                                                  progress:(nullable MCDownloaderProgressBlock)progressBlock
                                                 completed:(nullable MCDownloaderCompletedBlock)completedBlock;

- (nullable MCDownloadReceipt *)downloadReceiptForURLString:(nullable NSString *)URLString;

- (void)cancel:(nullable MCDownloadReceipt *)token completed:(nullable void (^)())completed;

- (void)remove:(nullable MCDownloadReceipt *)token completed:(nullable void (^)())completed;
/**
 * Sets the download queue suspension state
 */
- (void)setSuspended:(BOOL)suspended;

/**
 * Cancels all download operations in the queue
 */
- (void)cancelAllDownloads;

/**
 Romove All files in the cache folder.
 @Waring:
 This method is synchronized methods, you should be careful when using, will delete all the data in the cache folder
 */
- (void)removeAndClearAll;
@end

NS_ASSUME_NONNULL_END
