//
//  NSManagedObject+STSyncable.m
//  STSyncable
//
//  Created by Bill Williams on 11.01.2012.
//  Copyright (c) 2012 Bill Williams. All rights reserved.
//

#import "NSManagedObject+STSyncable.h"
#import "AFJSONRequestOperation.h"

@implementation NSManagedObject (STSyncable)
+ (NSNumber *)numberFromValue:(id)value {
	if([value isKindOfClass:[NSNull class]]) {
		return [NSNumber new];
	}
	
	if([value isKindOfClass:[NSNumber class]]) {
		return value;
	}
	
	if([value isKindOfClass:[NSString class]]) {
		NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
		[f setNumberStyle:NSNumberFormatterDecimalStyle];
		return [f numberFromString:value];
	}
	
	return NULL;
}


+ (NSOperation *)performSync {
	return [[self class] performSync:NULL onFailure:NULL];
}


+ (NSOperation *)performSync:(void (^)())success {
	return [[self class] performSync:success onFailure:NULL];
}


+ (NSOperation *)performSync:(void (^)())success onFailure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON))failure {
	// STSyncable protocol methods are required for -performSync to function
	if (![self conformsToProtocol:@protocol(STSyncable)]) {
		return NULL;
	}
	
	// reference the NSManagedObject subclass actually being synced
	Class<STSyncable> syncableClass = [self class];
	
	__block STFailureBlock failureBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON){
		if(failure == NULL) {
			NSLog(@"Request %@ failed\nResponse: %@\nError:%@\nJSON: %@\n\n", request, response, error, JSON);
		} else {
			failure(request, response, error, JSON);
		}
	};
	
	 STSuccessBlock syncBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *JSON) {
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
	};
	
	__block STSuccessBlock countBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *JSON) {
		// Build a URL to request all extant objects
		NSNumber *count = [[JSON objectForKey:@"meta"] objectForKey:@"total_count"]; 
		NSString *requestUri = [NSString stringWithFormat:@"%@&limit=%@", request.URL.absoluteString, count];
		requestUri = [requestUri stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		request = [NSURLRequest requestWithURL:[NSURL URLWithString:requestUri]];
		
		AFJSONRequestOperation *syncOperation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:syncBlock failure:failureBlock];
		[[NSOperationQueue currentQueue] addOperation:syncOperation];
	};
	
	
	// Create the first request, to determine how many objects exist
	NSURLRequest *request = [NSURLRequest requestWithURL:[syncableClass syncURL]];
	AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:countBlock failure:failureBlock];
	
	return operation;
}
@end