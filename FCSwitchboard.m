//
//  FCSwitchboard.m
//
//  Created by Chris Farber on 30/03/09.
//  All code is provided under the New BSD license.
//


#import "FCSwitchboard.h"

static NSMutableDictionary *sharedSwitchboards = nil;


@interface FCSwitchboardConnection : NSObject <FCSwitchboardConnection> {
}

@property(nonatomic,strong) NSMutableData *data;
@property(nonatomic,strong) NSURLConnection *connection;
@property(nonatomic,copy) void (^callback)(id, NSError *error);
@property(weak, nonatomic,readonly) FCSwitchboard *switchboard;
@property(nonatomic) BOOL parseDataAsJSON;

@property(nonatomic,strong) NSHTTPURLResponse *response;
@property(nonatomic,strong) NSError *error;

- initWithSwitchboard:(FCSwitchboard *)aSwitchboard connection:(NSURLConnection *)conn;

- (void)cancel;

@end


@interface FCSwitchboard ()

- (void)_returnResponseForConnection:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)removeConnection:(NSURLConnection *)connection;

- (void)cancelDownloading:(FCSwitchboardConnection *)representedConnection;

- (NSString *)URLEncodeDictionary:(NSDictionary *)dict;

@end


NSString *URLEncode(id object);


@implementation FCSwitchboardConnection

@synthesize data;
@synthesize connection;
@synthesize response;
@synthesize error;
@synthesize callback;
@synthesize switchboard;
@synthesize parseDataAsJSON;
@synthesize uploadProgressBlock;

- initWithSwitchboard:(FCSwitchboard *)aSwitchboard connection:(NSURLConnection *)conn
{
    if ((self = [super init])) {
        switchboard = aSwitchboard;
        self.connection = conn;
        self.data = [NSMutableData data];
        parseDataAsJSON = YES;
    }
    return self;
}


- (void)cancel
{
    [switchboard cancelDownloading:self];
}

@end


@implementation FCSwitchboard

#ifndef __MAC_OS_X_VERSION_MIN_REQUIRED
@synthesize showsNetworkActivityIndicator;
#endif

@synthesize baseURL;

#pragma mark Implementation

- init
{
    if ((self = [super init])) {
        connections = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    }
    return self;
}

- (id <FCSwitchboardConnection>)sendRequest:(NSString *)verb forPath:(NSString *)subpath withData:(id)data
                                      block:(void(^)(id data, NSError *error))block
{
    NSError *error = nil;
    subpath = [self adjustSubpath:subpath withRequestData:data forMethod:verb error:&error];
    if (error) {
        if (block) {
            block(nil, error);
        }
        return nil;
    }
    NSURL *requestURL = [NSURL URLWithString:subpath relativeToURL:baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    [request setHTTPMethod:verb];
    [self includeData:data inRequest:request forMethod:verb error:&error];
    if (error) {
        if (block) {
            block(nil, error);
        }
        return nil;
    }
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!connection) {
        NSError *error = [NSError errorWithDomain:@"FCSwitchboardError" code:1 userInfo:nil];
        block(nil, error);
        return nil;
    }
    FCSwitchboardConnection *connectionInfo = [[FCSwitchboardConnection alloc] initWithSwitchboard:self connection:connection];
    connectionInfo.callback = block;
    CFDictionarySetValue(connections, (__bridge void *)connection, (__bridge void *)connectionInfo);
#ifndef __MAC_OS_X_VERSION_MIN_REQUIRED
    if (showsNetworkActivityIndicator) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    }
#endif
    return connectionInfo;
}

- (NSString *)adjustSubpath:(NSString *)path withRequestData:(id)data forMethod:(NSString *)verb error:(NSError **)outError
{
    if (data && [verb compare:@"get" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        path = [NSString stringWithFormat:@"%@?%@", path, [self URLEncodeDictionary:data]];
    }
    return path;
}

- (BOOL)includeData:(id)data inRequest:(NSMutableURLRequest *)request forMethod:(NSString *)verb error:(NSError **)outError
{
    if (data && [verb compare:@"get" options:NSCaseInsensitiveSearch] != NSOrderedSame) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSData *serializedJSON = [NSJSONSerialization dataWithJSONObject:data options:0 error:outError];
        if (serializedJSON) {
            [request setHTTPBody:serializedJSON];
            [request setValue:[NSString stringWithFormat:@"%d", [serializedJSON length]] forHTTPHeaderField:@"Content-length"];
        }
        return serializedJSON != nil;
    }
    return NO;
}

- (id <FCSwitchboardConnection>)downloadURL:(NSURL *)aURL withBlock:(void (^)(NSData *, NSError *))block
{
    NSURLRequest *request = [NSURLRequest requestWithURL:aURL];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!connection) {
        NSError *error = [NSError errorWithDomain:@"FCSwitchboardError" code:1 userInfo:nil];
        block(nil, error);
        return nil;
    }
    FCSwitchboardConnection *connectionInfo = [[FCSwitchboardConnection alloc] initWithSwitchboard:self connection:connection];
    connectionInfo.callback = block;
    connectionInfo.parseDataAsJSON = NO;
    CFDictionarySetValue(connections, (__bridge void *)connection, (__bridge void *)connectionInfo);
#ifndef __MAC_OS_X_VERSION_MIN_REQUIRED
    if (showsNetworkActivityIndicator) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    }
#endif
    return connectionInfo;
}

- (NSData *)downloadURL:(NSURL *)aURL
{
    if (![NSThread isMainThread]) {
        NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:0];
        __block NSData *data = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [lock lock];
            [self downloadURL:aURL withBlock:^(NSData *downloadedData, NSError *error) {
                data = downloadedData;
                [lock unlockWithCondition:1];
            }];
        });
        [lock lockWhenCondition:1];
        [lock unlockWithCondition:0];
        return data;
    }
    else {
        //avoid a deadlock on the main thread
        NSURLRequest *request = [NSURLRequest requestWithURL:aURL];
        return [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    }

}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    FCSwitchboardConnection *connectionInfo = (__bridge id)CFDictionaryGetValue(connections, (__bridge void *)connection);
    connectionInfo.response = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    FCSwitchboardConnection *connectionInfo = (__bridge id)CFDictionaryGetValue(connections, (__bridge void *)connection);
    [connectionInfo.data appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    FCSwitchboardConnection *connectionInfo = (__bridge id)CFDictionaryGetValue(connections, (__bridge void *)connection);
    connectionInfo.error = error;
    [self _returnResponseForConnection:connection];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self _returnResponseForConnection:connection];
}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    FCSwitchboardConnection *connectionInfo = (__bridge id)CFDictionaryGetValue(connections, (__bridge void *)connection);
    if (connectionInfo.uploadProgressBlock) {
        connectionInfo.uploadProgressBlock(totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)_returnResponseForConnection:(NSURLConnection *)connection
{
    FCSwitchboardConnection *connectionInfo = (__bridge id)CFDictionaryGetValue(connections, (__bridge void *)connection);
    void (^block)(id, id) = connectionInfo.callback;
    NSError *error = connectionInfo.error;
    if (!error) {
        NSHTTPURLResponse *response = connectionInfo.response;
        NSInteger status = [response statusCode];
        if (status != 200) error = [NSError errorWithDomain:@"APIError" code:status userInfo:nil];
    }
    id data = connectionInfo.data;
    if (!error && connectionInfo.parseDataAsJSON) {
        if ([data length] && [error code] != 401) {
            error = nil;
            id parsedData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (parsedData) {
                data = parsedData;
            }
        }
    }
    if (block)
        block(data, error);
    [self removeConnection:connection];
}

- (void)removeConnection:(NSURLConnection *)connection
{
    CFDictionaryRemoveValue(connections, (__bridge void *)connection);
#ifndef __MAC_OS_X_VERSION_MIN_REQUIRED
    //wait for a tenth of a second to disable the network activity indicator
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100000000), dispatch_get_main_queue(), ^{
        if (showsNetworkActivityIndicator && !CFDictionaryGetCount(connections)) {
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        }
    });
#endif
}

- (void)cancelDownloading:(FCSwitchboardConnection *)representedConnection
{
    NSURLConnection *connection = representedConnection.connection;
    if ((__bridge id)CFDictionaryGetValue(connections, (__bridge void *)connection) == representedConnection) {
        [connection cancel];
        [self removeConnection:connection];
    }
}

NSString *URLEncode(id object)
{
    NSString *string = [NSString stringWithFormat:@"%@", object];
    NSString *result = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
       kCFAllocatorDefault,
       (__bridge CFStringRef)string,
       NULL,                   // characters to leave unescaped (NULL = all escaped sequences are replaced)
       CFSTR("?=&+"),          // legal URL characters to be escaped (NULL = all legal characters are replaced)
       kCFStringEncodingUTF8); // encoding
    return result;
}

- (NSString *)URLEncodeDictionary:(NSDictionary *)dict
{
    NSString *encoded = @"";
    if ([dict count]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id key in dict) {
            id value = [dict objectForKey:key];
            NSString *part = [NSString stringWithFormat:@"%@=%@", URLEncode(key), URLEncode(value)];
            [parts addObject:part];
        }
        encoded = [parts componentsJoinedByString: @"&"];
    }
    return encoded;

}

#pragma mark -
#pragma mark Singleton Housekeeping

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSwitchboards = [[NSMutableDictionary alloc] init];
    });
}

+ switchboard
{
    FCSwitchboard *switchboard = nil;
    @synchronized(self) {
        switchboard = [sharedSwitchboards objectForKey:self];
        if (!switchboard) {
            switchboard = [[self alloc] init];
        }
    }
    return switchboard;
}

+ allocWithZone:(NSZone *)zone
{
    FCSwitchboard *switchboard = nil;
    if (self != [FCSwitchboard class]) {
        @synchronized(self) {
            if (![sharedSwitchboards objectForKey:self]) {
                switchboard = [super allocWithZone:zone];
                [sharedSwitchboards setObject:switchboard forKey:self];
            }
        }
    }
    return switchboard;
}

- copyWithZone:(NSZone *)zone
{
    return self;
}

@end
