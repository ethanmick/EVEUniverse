//
//  EUFilterItem.h
//  EVEUniverse
//
//  Created by Mr. Depth on 9/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EUFilterItemValue.h"

@interface EUFilterItem : NSObject<NSCopying> {
	NSString *name;
	NSString *allValue;
	NSString *valuePropertyKey;
	NSString *titlePropertyKey;
	NSMutableSet *values;
}
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *allValue;
@property (nonatomic, retain) NSString *valuePropertyKey;
@property (nonatomic, retain) NSString *titlePropertyKey;
@property (nonatomic, retain) NSMutableSet *values;

+ (id) filterItem;
- (void) updateWithValue:(id) value;
- (NSSet*) selectedValues;
- (NSPredicate*) predicate;

@end