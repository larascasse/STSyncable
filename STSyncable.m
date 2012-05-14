//
//  STSyncable.m
//  STSyncable
//
//  Created by Bill Williams on 07.05.12.
//  Copyright (c) 2012 Bill Williams. All rights reserved.
//

#import "STSyncable.h"

@interface STSyncable
+ (STSyncable *)sharedClient;
@end




@protocol STSyncable // For subclasses
+ (NSURL *)baseURL;
@optional
- (id)initWithBaseURL:(NSURL *)baseURL; // Register operation classes and headers
@end




NSString * const kSTTwitterClientSyncCompleted = @"STTwitterClientSyncCompleted";
NSString * const kSTTwitterClientSyncFailed = @"STTwitterClientSyncFailed";
NSString * const kSTTwitterClientLastSync = @"STTwitterClientLastSync";




@implementation STSyncable
#pragma mark - Singleton
+ (STTwitterClient *)sharedClient {
	static STTwitterClient *_sharedClient = nil;
	static dispatch_once_t oncePredicate;
	dispatch_once(&oncePredicate, ^{
		_sharedClient = [[self alloc] initWithBaseURL:self.class.baseURL];
	});

	return _sharedClient;
}


#pragma mark - Sync engine
- (void)syncClass:(Class<STSyncable>)syncableClass withParameters:(NSDictionary *)parameters success:(STSyncableSuccessBlock)successBlock failure:(STSyncableFailureBlock)failureBlock {

	[self.class.sharedClient getPath:[syncableClass resourcePath] parameters:parameters success:^(AFHTTPRequestOperation *operation, id JSON) {
		NSMutableSet *newObjects = [NSMutableSet set];
		// TODO handle errors
		// the top-level JSON object should be a dictionary.
		// Twitter might changed the API though.

		for (NSDictionary *objectData in JSON) {
			NSString *objectID = [objectData objectForKey:…];
			if (![syncableClass findFirstByAttribute:@"…" withValue:objectID]) {
				id newObject = [syncableClass createEntity];
				[newObjects addObject:newObject];
			}
		}

		// persist downloaded tweets
		[[NSManagedObjectContext defaultContext] saveWithErrorHandler:^(NSError *error){
			NSLog(@"Core Data error: %@\nuserInfo: %@", error, error.userInfo);
		}];

		// save the last-sync time to the defaults
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kSTTwitterClientLastSync];

		// TODO only send notification if block isn't provided?
		// TODO check if sending newTweets slows anything down
		if (successBlock) successBlock(newTweets);
		[[NSNotificationCenter defaultCenter] postNotificationName:kSTTwitterClientSyncCompleted object:newTweets];

	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		// TODO only sending notification if block isn't provided?
		if (failureBlock) failureBlock(error);
		[[NSNotificationCenter defaultCenter] postNotificationName:kSTTwitterClientSyncFailed object:error];
	}];
	
}

@end
