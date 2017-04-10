//
//  MCDownloader.m
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

#import "MCDownloader.h"
#import "MCDownloadOperation.h"
#import "MCDownloadReceipt.h"

NSString * const MCDownloadCacheFolderName = @"MCDownloadCache";

NSString * cacheFolder() {
    NSFileManager *filemgr = [NSFileManager defaultManager];
    static NSString *cacheFolder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!cacheFolder) {
            NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
            cacheFolder = [cacheDir stringByAppendingPathComponent:MCDownloadCacheFolderName];
        }
        NSError *error = nil;
        if(![filemgr createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create cache directory at %@", cacheFolder);
            cacheFolder = nil;
        }
    });
    return cacheFolder;
}

static NSString * LocalReceiptsPath() {
    return [cacheFolder() stringByAppendingPathComponent:@"receipts.data"];
}

@interface MCDownloader() <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;
@property (weak, nonatomic, nullable) NSOperation *lastAddedOperation;
@property (assign, nonatomic, nullable) Class operationClass;
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, MCDownloadOperation *> *URLOperations;
@property (strong, nonatomic, nullable) MCHTTPHeadersMutableDictionary *HTTPHeaders;
// This queue is used to serialize the handling of the network responses of all the download operation in a single queue
@property (strong, nonatomic, nullable) dispatch_queue_t barrierQueue;

// The session in which data tasks will run
@property (strong, nonatomic) NSURLSession *session;

@property (nonatomic, strong) NSMutableDictionary *allDownloadReceipts;
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;
@end
@implementation MCDownloader

- (NSMutableDictionary *)allDownloadReceipts {
    if (_allDownloadReceipts == nil) {
        NSDictionary *receipts = [NSKeyedUnarchiver unarchiveObjectWithFile:LocalReceiptsPath()];
        _allDownloadReceipts = receipts != nil ? receipts.mutableCopy : [NSMutableDictionary dictionary];
    }
    return _allDownloadReceipts;
}

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    if ((self = [super init])) {
        _operationClass = [MCDownloadOperation class];
        _downloadPrioritizaton = MCDownloadPrioritizationFIFO;
        _downloadQueue = [NSOperationQueue new];
        _downloadQueue.maxConcurrentOperationCount = 3;
        _downloadQueue.name = @"com.machao.MCDownloader";
        _URLOperations = [NSMutableDictionary new];
        _barrierQueue = dispatch_queue_create("com.machao.MCDownloaderBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        _downloadTimeout = 15.0;
        
        sessionConfiguration.timeoutIntervalForRequest = _downloadTimeout;
        sessionConfiguration.HTTPMaximumConnectionsPerHost = 10;
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
         */
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                     delegate:self
                                                delegateQueue:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

#pragma mark -  NSNotification
- (void)applicationWillTerminate:(NSNotification *)not {
    [self saveAllDownloadReceipts];
}

- (void)applicationDidReceiveMemoryWarning:(NSNotification *)not {
    [self saveAllDownloadReceipts];
}

- (void)applicationWillResignActive:(NSNotification *)not {
    [self saveAllDownloadReceipts];
    /// 捕获到失去激活状态后
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
    if (hasApplication ) {
        __weak __typeof__ (self) wself = self;
        UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
        self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
            __strong __typeof (wself) sself = wself;
            
            if (sself) {
                [sself saveAllDownloadReceipts];
                
                [app endBackgroundTask:sself.backgroundTaskId];
                sself.backgroundTaskId = UIBackgroundTaskInvalid;
            }
        }];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)not {
    
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
}

- (void)saveAllDownloadReceipts {
     [NSKeyedArchiver archiveRootObject:self.allDownloadReceipts toFile:LocalReceiptsPath()];
}

- (void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;
    
    [self.downloadQueue cancelAllOperations];

}

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    if (value) {
        self.HTTPHeaders[field] = value;
    }
    else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
}

- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    return self.HTTPHeaders[field];
}

- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

- (NSUInteger)currentDownloadCount {
    return _downloadQueue.operationCount;
}

- (NSInteger)maxConcurrentDownloads {
    return _downloadQueue.maxConcurrentOperationCount;
}

- (void)setOperationClass:(nullable Class)operationClass {
    if (operationClass && [operationClass isSubclassOfClass:[NSOperation class]] && [operationClass conformsToProtocol:@protocol(MCDownloaderOperationInterface)]) {
        _operationClass = operationClass;
    } else {
        _operationClass = [MCDownloadOperation class];
    }
}

- (nullable MCDownloadReceipt *)downloadDataWithURL:(nullable NSURL *)url
                                                  progress:(nullable MCDownloaderProgressBlock)progressBlock
                                                 completed:(nullable MCDownloaderCompletedBlock)completedBlock {
    __weak MCDownloader *wself = self;
    
    MCDownloadReceipt *receipt = [self downloadReceiptForURLString:url.absoluteString];
    if (receipt.state == MCDownloadStateCompleted) {
        dispatch_main_async_safe(^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:MCDownloadFinishNotification object:self];
            if (completedBlock) {
                completedBlock(receipt ,nil ,YES);
            }
            if (receipt.downloaderCompletedBlock) {
                receipt.downloaderCompletedBlock(receipt, nil, YES);
            }
            
        });
        return receipt;
    }
    
    return [self addProgressCallback:progressBlock completedBlock:completedBlock forURL:url createCallback:^MCDownloadOperation *{
        __strong __typeof (wself) sself = wself;
        
        NSTimeInterval timeoutInterval = sself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        MCDownloadReceipt *receipt = [sself downloadReceiptForURLString:url.absoluteString];
        if (receipt.totalBytesWritten > 0) {
            NSString *range = [NSString stringWithFormat:@"bytes=%zd-", receipt.totalBytesWritten];
            [request setValue:range forHTTPHeaderField:@"Range"];
        }
        
        request.HTTPShouldUsePipelining = YES;

        if (sself.headersFilter) {
            request.allHTTPHeaderFields = sself.headersFilter(url, [sself.HTTPHeaders copy]);
        }
        else {
            request.allHTTPHeaderFields = sself.HTTPHeaders;
        }
        

        MCDownloadOperation *operation = [[sself.operationClass alloc] initWithRequest:request inSession:sself.session];

        [sself.downloadQueue addOperation:operation];
        

        if (sself.downloadPrioritizaton == MCDownloadPrioritizationLIFO) {
            // Emulate LIFO execution order by systematically adding new operations as last operation's dependency
            [sself.lastAddedOperation addDependency:operation];
            sself.lastAddedOperation = operation;
        }
        
        return operation;
    }];
}

- (MCDownloadReceipt *)downloadReceiptForURLString:(NSString *)URLString {
    if (URLString == nil) {
        return nil;
    }
    if (self.allDownloadReceipts[URLString]) {
        return self.allDownloadReceipts[URLString];
    }else {
        MCDownloadReceipt *receipt = [[MCDownloadReceipt alloc] initWithURLString:URLString downloadOperationCancelToken:nil downloaderProgressBlock:nil downloaderCompletedBlock:nil];
        self.allDownloadReceipts[URLString] = receipt;
        return receipt;
    }
    
    return nil;
}

- (void)cancel:(nullable MCDownloadReceipt *)token completed:(nullable void (^)())completed {
    dispatch_barrier_async(self.barrierQueue, ^{
        MCDownloadOperation *operation = self.URLOperations[[NSURL URLWithString:token.url]];
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
            [self.URLOperations removeObjectForKey:[NSURL URLWithString:token.url]];
            [token setState:MCDownloadStateNone];
//            [self.allDownloadReceipts removeObjectForKey:token.url];

        }
        
        dispatch_main_async_safe(^{
            if (completed) {
                completed();
            }
        });
        
    });
}

- (void)remove:(MCDownloadReceipt *)token completed:(nullable void (^)())completed{
    [token setState:MCDownloadStateNone];
    [self cancel:token completed:^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:token.filePath error:nil];
        
        dispatch_main_async_safe(^{
            if (completed) {
                completed();
            }
        });
    }];
    
}

- (nullable MCDownloadReceipt *)addProgressCallback:(MCDownloaderProgressBlock)progressBlock
                                           completedBlock:(MCDownloaderCompletedBlock)completedBlock
                                                   forURL:(nullable NSURL *)url
                                           createCallback:(MCDownloadOperation *(^)())createCallback {
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, nil, NO);
        }
        return nil;
    }
    
    __block MCDownloadReceipt *token = nil;
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        MCDownloadOperation *operation = self.URLOperations[url];
        if (!operation) {
            operation = createCallback();
            self.URLOperations[url] = operation;
            
            __weak MCDownloadOperation *woperation = operation;
            operation.completionBlock = ^{
                MCDownloadOperation *soperation = woperation;
                if (!soperation) return;
                if (self.URLOperations[url] == soperation) {
                    [self.URLOperations removeObjectForKey:url];
                };
            };
        }
        id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock completed:completedBlock];
        
        if (!self.allDownloadReceipts[url.absoluteString]) {
            token = [[MCDownloadReceipt alloc] initWithURLString:url.absoluteString
                                    downloadOperationCancelToken:downloadOperationCancelToken
                                         downloaderProgressBlock:progressBlock
                                        downloaderCompletedBlock:completedBlock];
            self.allDownloadReceipts[url.absoluteString] = token;
        }else {
            token = self.allDownloadReceipts[url.absoluteString];
            if (!token.downloaderProgressBlock) {
                [token setDownloaderProgressBlock:progressBlock];
            }
            
            if (!token.downloaderCompletedBlock) {
                [token setDownloaderCompletedBlock:completedBlock];
            }
            
            if (!token.downloadOperationCancelToken) {
                [token setDownloadOperationCancelToken:downloadOperationCancelToken];
            }
        }

    });
    
    return token;
}

- (void)setSuspended:(BOOL)suspended {
    (self.downloadQueue).suspended = suspended;
}

- (void)cancelAllDownloads {
    [self.downloadQueue cancelAllOperations];
  
    [self.allDownloadReceipts enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[MCDownloadReceipt class]]) {
            MCDownloadReceipt *receipt = obj;
            if (receipt.state != MCDownloadStateCompleted) {
                [receipt setState:MCDownloadStateNone];
            }
        }
    }];
    [self saveAllDownloadReceipts];
}

- (void)removeAndClearAll {
    [self cancelAllDownloads];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:cacheFolder() error:nil];
}

#pragma mark Helper methods

- (MCDownloadOperation *)operationWithTask:(NSURLSessionTask *)task {
    MCDownloadOperation *returnOperation = nil;
    for (MCDownloadOperation *operation in self.downloadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    MCDownloadOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    // Identify the operation that runs this task and pass it the delegate method
    MCDownloadOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    MCDownloadOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    // Identify the operation that runs this task and pass it the delegate method
    MCDownloadOperation *dataOperation = [self operationWithTask:task];
    
    [dataOperation URLSession:session task:task didCompleteWithError:error];
}


@end
