#import "NSManagedObject+STSyncable.h"
#import "AFJSONRequestOperation.h"

@implementation NSManagedObject (STSyncable)
- (NSOperation *)performSync:(__block)successBlock onFailure:(__block)failureBlock {
	// STSyncable protocol methods are required for -performSync to function
	if (![self conformsToProtocol:@protocol(STSyncable)]) {
		return NULL;
	}
	
	// reference the NSManagedObject subclass actually being synced
	Class<STSyncable> syncableClass = [self class];
	
	// Generate a request operation
	request = [NSURLRequest requestWithURL:[syncableClass syncURL]];
	AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSDictionary *JSON) {
		// Create a mutable dictionary of items to sync, keyed by resource URL
		NSArray *jsonObjects = [JSON objectForKey:@"objects"];
		NSMutableDictionary *syncItems = [NSMutableDictionary dictionaryWithCapacity:jsonObjects.count];
		for(id syncItem in jsonObjects) {
			[syncItems setObject:syncItem forKey:[syncItem objectForKey:@"resource_uri"]];
		}
		
		// Update and delete locally–stored items
		for(id<STSyncable> syncItem in [syncableClass findAll]) {
			NSDictionary *updateDict = [syncItems objectForKey:[syncItem resourceUri]];
			[syncItems removeObjectForKey:[syncItem resourceUri]];
			if ([updateDict isKindOfClass:[NSNull class]]) {
				[syncItem deleteEntity];
			} else {
				[syncItem updateFromDictionary:updateDict];
			}
		}
		
		// Any sync items left to process will be created as new 
		for(NSString *resourceUri in syncItems) {
			id<STSyncable> newItem = [syncableClass createEntity];
			[newItem updateFromDictionary:[syncItems objectForKey:resourceUri]];
		}
		
		// Persist the synced data and reload the UI
		syncItems = nil;
		[[NSManagedObjectContext defaultContext] save];
		successBlock();
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON){
		failureBlock();
	}];
	
	return operation;
}
@end