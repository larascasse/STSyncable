//
//  NSManagedObject+STSyncable.h
//  STSyncable
//
//  Created by Bill Williams on 11.01.2012.
//  Copyright (c) 2012 Bill Williams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "CoreData+MagicalRecord.h"
#import "AFHTTPClient.h"

typedef void (^STSuccessBlock)(NSURLRequest *request, NSHTTPURLResponse *response, id JSON);
typedef void (^STFailureBlock)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON);

@protocol STSyncable
+ (NSURL *)syncURL;
- (NSString *)resourceUri;
- (void)setResourceUri:(NSString *)string;
- (void)updateFromDictionary:(NSDictionary *)dictionary;

@optional // Defined by MagicalRecord
+ (id)MR_createEntity;
- (BOOL)MR_deleteEntity;
+ (NSArray *)MR_findAll;
@end


@interface NSManagedObject (STSyncable)
+ (NSNumber *)numberFromValue:(id)value;
+ (NSOperation *)performSync;
+ (NSOperation *)performSync:(void (^)())success;
+ (NSOperation *)performSync:(void (^)())success onFailure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON))failure;
@end
