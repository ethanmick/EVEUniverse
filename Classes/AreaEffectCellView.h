//
//  AreaEffectCellView.h
//  EVEUniverse
//
//  Created by Mr. Depth on 1/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AreaEffectCellView : UITableViewCell {
	UIImageView *stateView;
	UILabel *titleLabel;
}
@property (nonatomic, retain) IBOutlet UIImageView *stateView;
@property (nonatomic, retain) IBOutlet UILabel *titleLabel;

@end
