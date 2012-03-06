//
//  FCSwitchboard.h
//
//  Created by Chris Farber on 30/03/09.
//  All code is provided under the New BSD license.
//

#import <Foundation/Foundation.h>


@protocol FCSwitchboardConnection <NSObject>
- (void)cancel;

@property(copy) void (^uploadProgressBlock)(NSInteger bytesWritten, NSInteger bytesExpectedToWrite);

@end


@interface FCSwitchboard : NSObject {
@private;
    CFMutableDictionaryRef connections;
}

+ switchboard;

#ifndef __MAC_OS_X_VERSION_MIN_REQUIRED
@property(nonatomic) BOOL showsNetworkActivityIndicator;
#endif

@property(nonatomic,copy) NSURL *baseURL;

- (id <FCSwitchboardConnection>)sendRequest:(NSString *)verb forPath:(NSString *)subpath withData:(id)data
                                   block:(void(^)(id data, NSError *error))block;

- (id <FCSwitchboardConnection>)downloadURL:(NSURL *)aURL withBlock:(void (^)(NSData *data, NSError *error))block;

- (NSString *)adjustSubpath:(NSString *)path withRequestData:(id)data forMethod:(NSString *)verb error:(NSError **)outError;
- (BOOL)includeData:(id)data inRequest:(NSMutableURLRequest *)request forMethod:(NSString *)verb error:(NSError **)outError;

- (NSString *)URLEncodeDictionary:(NSDictionary *)dict;

// This method executes synchronously; do NOT call from the main thread
- (NSData *)downloadURL:(NSURL *)aURL;

@end
