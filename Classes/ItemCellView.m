//
//  ItemCellView.m
//  EVEUniverse
//
//  Created by Artem Shimanski on 2/1/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ItemCellView.h"


@implementation ItemCellView
@synthesize iconImageView;
@synthesize titleLabel;

- (void)dealloc {
	[iconImageView release];
	[titleLabel release];
    [super dealloc];
}


@end
