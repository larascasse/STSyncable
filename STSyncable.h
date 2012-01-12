#import <Foundation/Foundation.h>

@protocol STSyncable
+ (NSURL *)syncURL;
- (NSString *)resourceUri;
- (id<NSManagedObject>)createFromDictionary:(NSDictionary *)dictionary;
- (void)updateFromDictionary:(NSDictionary *)dictionary;
@end


@interface NSManagedObject (STSyncable)
- (NSOperation *)performSync:(__block)successBlock onFailure:(__block)failureBlock;
@end
