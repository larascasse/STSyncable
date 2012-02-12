//
//  NSManagedObject+STSyncable.m
//  STSyncable
//
//  Created by Bill Williams on 11.01.2012.
//  Copyright (c) 2012 Bill Williams. All rights reserved.
//

#import "NSManagedObject+STSyncable.h"
#import "AFJSONRequestOperation.h"
#import "AFJSONUtilities.h"

@implementation NSManagedObject (STSyncable)
+ (NSNumber *)numberFromValue:(id)value {
	if(value == NULL) {
		return [NSNumber new];
	}
	
	if([value isKindOfClass:[NSNumber class]]) {
		return value;
	}
	
	return nil;
}


+ (NSOperation *)performSync {
	return [[self class] performSync:NULL onFailure:NULL];
}


+ (NSOperation *)performSync:(void (^)())success {
	return [[self class] performSync:success onFailure:NULL];
}


+ (NSOperation *)performSync:(void (^)())success onFailure:(STFailureBlock)failure {
	// STSyncable protocol methods are required for -performSync to function
	if (![self conformsToProtocol:@protocol(STSyncable)]) {
		return NULL;
	}
	
	// reference the API and model to sync
	Class<STSyncable> syncableClass = [self class];
	AFHTTPClient *webAPI = [syncableClass webAPI];
	NSString *syncablePath;
	
	if ([(Class)syncableClass resolveClassMethod:@selector(syncPath:)]) {
		syncablePath = [syncableClass syncPath];
	} else {
		syncablePath = [NSStringFromClass(syncableClass) lowercaseString];
	}
	
	// Failure block to be used for both requests
	__block STFailureBlock failureBlock = ^(AFHTTPRequestOperation *operation, NSError *error) {
		if(failure == NULL) {
			NSLog(@"Operation failed: %@\nError:%@", operation, error);
		} else {
			failure(operation, error);
		}
	};
	
	// Create the first request, to determine how many objects exist	
	NSMutableDictionary *params = [NSMutableDictionary dictionary];
	[webAPI getPath:syncablePath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		// Retrieve JSON from the response
		NSError *error = [NSError new];
		id JSON = AFJSONDecode(operation.responseData, &error);
		
		// Now, sync all extant objects
		NSNumber *count = [[JSON objectForKey:@"meta"] objectForKey:@"total_count"];
		[params setObject:count forKey:@"limit"];
		[webAPI getPath:syncablePath parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
			// Create a mutable dictionary of items to sync, keyed by resource URL
			NSArray *jsonObjects = [JSON objectForKey:@"objects"];
			NSMutableDictionary *syncItems = [NSMutableDictionary dictionaryWithCapacity:jsonObjects.count];
			for(id syncItem in jsonObjects) {
				[syncItems setObject:syncItem forKey:[syncItem objectForKey:@"resource_uri"]];
			}
			
			// Update and delete locally–stored items
			for(id<STSyncable> syncItem in [syncableClass MR_findAll]) {
				NSDictionary *updateDict = [syncItems objectForKey:[syncItem resourceUri]];
				if([syncItem resourceUri]) {
					[syncItems removeObjectForKey:[syncItem resourceUri]];
				}
				
				if ([updateDict isKindOfClass:[NSNull class]]) {
					[syncItem MR_deleteEntity];
				} else {
					[syncItem updateFromDictionary:updateDict];
				}
			}
			
			// Any sync items left to process will be created as new 
			for(NSString *resourceUri in syncItems) {
				id<STSyncable> newItem = [syncableClass MR_createEntity];
				[newItem setResourceUri:resourceUri];
				[newItem updateFromDictionary:[syncItems objectForKey:resourceUri]];
			}
			
			// Persist the synced data
			syncItems = nil;
			[[NSManagedObjectContext defaultContext] save];
			
			// Perform the success block
			if(success) {
				success();
			}
		} failure:failureBlock];
	} failure:failureBlock];
	
	
	return operation;
}
@end