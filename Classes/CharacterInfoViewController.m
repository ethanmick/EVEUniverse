//
//  CharacterInfoViewController.m
//  EVEUniverse
//
//  Created by Artem Shimanski on 1/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CharacterInfoViewController.h"
#import "EVEOnlineAPI.h"
#import "EVEAccount.h"
#import "Globals.h"
#import "EUOperationQueue.h"
#import "NSInvocation+Variadic.h"
#import "NSString+TimeLeft.h"

@interface CharacterInfoViewController(Private)
- (void) update;
- (void) updateCharacterInfo:(EVEAccount*) account;
- (void) updateSkillInfoWithAccount:(EVEAccount*) account;
- (void) show;
- (void) didSelectAccount:(NSNotification*) notification;
- (void) checkServerStatus;
@end

@implementation CharacterInfoViewController
@synthesize portraitImageView;
@synthesize corpImageView;
@synthesize allianceImageView;
@synthesize corpLabel;
@synthesize allianceLabel;
@synthesize skillsLabel;
@synthesize wealthLabel;
@synthesize serverStatusLabel;
@synthesize onlineLabel;
@synthesize delegate;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	[delegate characterInfoViewController:self willChangeContentSize:CGSizeMake(320, 24) animated:NO];
	
	/*[[EUOperationQueue sharedQueue] addOperationWithBlock:^(void) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]  init];
		NSError *error = nil;
		EVEServerStatus *serverStatus = [EVEServerStatus serverStatusWithError:&error];
		if (error) {
			[self.serverStatusLabel performSelectorOnMainThread:@selector(setText:) withObject:@"error" waitUntilDone:NO];
			[self.onlineLabel performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
		}
		else {		
			[self.serverStatusLabel performSelectorOnMainThread:@selector(setText:)
														  withObject:serverStatus.serverOpen ? @"Online" : @"Offline"
													   waitUntilDone:NO];
			[self.onlineLabel performSelectorOnMainThread:@selector(setText:)
													withObject:[NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithInt:serverStatus.onlinePlayers] numberStyle:NSNumberFormatterDecimalStyle]
												 waitUntilDone:NO];
		}
		[pool release];
	}];*/
	[self checkServerStatus];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSelectAccount:) name:NotificationSelectAccount object:nil];
	[self update];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationSelectAccount object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	self.portraitImageView = nil;
	self.corpImageView = nil;
	self.allianceImageView = nil;
	self.corpLabel = nil;
	self.allianceLabel = nil;
	self.skillsLabel = nil;
	self.wealthLabel = nil;
	self.serverStatusLabel = nil;
	self.onlineLabel = nil;
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NotificationSelectAccount object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[portraitImageView release];
	[corpImageView release];
	[allianceImageView release];
	[corpLabel release];
	[allianceLabel release];
	[skillsLabel release];
	[wealthLabel release];
	[serverStatusLabel release];
	[onlineLabel release];
    [super dealloc];
}

@end


@implementation CharacterInfoViewController(Private)

- (void) update {
	EVEAccount *account = [EVEAccount currentAccount];
	[self checkServerStatus];

	__block EUSingleBlockOperation *operation = [EUSingleBlockOperation operationWithIdentifier:[NSString stringWithFormat:@"CharacterInfoViewController+Update+%p", self]];
	[operation addExecutionBlock:^(void) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		[self updateCharacterInfo:account];
		[pool release];
	}];

	[[EUOperationQueue sharedQueue] addOperation:operation];
}

- (void) updateCharacterInfo:(EVEAccount*) account {
	if (account) {
		NSURL *portraitURL;
		NSURL *corpURL;
		float scale;
		if (RETINA_DISPLAY) {
			portraitURL = [EVEImage characterPortraitURLWithCharacterID:account.characterID size:EVEImageSize128 error:nil];
			corpURL = [EVEImage corporationLogoURLWithCorporationID:account.corporationID size:EVEImageSize64 error:nil];
			scale = 2;
		}
		else {
			portraitURL = [EVEImage characterPortraitURLWithCharacterID:account.characterID size:EVEImageSize64 error:nil];
			corpURL = [EVEImage corporationLogoURLWithCorporationID:account.corporationID size:EVEImageSize32 error:nil];
			scale = 1;
		}
		NSInvocation *invocation = [NSInvocation invocationWithTarget:self.portraitImageView selector:@selector(setImageWithContentsOfURL:scale:) argumentPointers:&portraitURL, &scale];
		[invocation retainArguments];
		[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
		
		invocation = [NSInvocation invocationWithTarget:self.corpImageView selector:@selector(setImageWithContentsOfURL:scale:) argumentPointers:&corpURL, &scale];
		[invocation retainArguments];
		[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
		
		[self.corpLabel performSelectorOnMainThread:@selector(setText:) withObject:account.corporationName waitUntilDone:NO];
		
		NSInteger allianceID = 0;
		NSString *allianceName = nil;
		
		if (account.characterSheet) {
			allianceID = account.characterSheet.allianceID;
			allianceName = account.characterSheet.allianceName;
			[self.wealthLabel performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%@ ISK", [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithFloat:account.characterSheet.balance] numberStyle:NSNumberFormatterDecimalStyle]] waitUntilDone:NO];
		}
		else {
			[self.wealthLabel performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
			NSError *error = nil;
			EVECorporationSheet *corporationSheet = [EVECorporationSheet corporationSheetWithKeyID:account.corpKeyID vCode:account.corpVCode characterID:account.characterID corporationID:account.corporationID error:&error];
			if (!error) {
				allianceID = corporationSheet.allianceID;
				allianceName = corporationSheet.allianceName;
			}
		}
		
		if (allianceID) {
			NSURL *url;
			if (RETINA_DISPLAY)
				url = [EVEImage allianceLogoURLWithAllianceID:allianceID size:EVEImageSize64 error:nil];
			else
				url = [EVEImage allianceLogoURLWithAllianceID:allianceID size:EVEImageSize32 error:nil];
			
			invocation = [NSInvocation invocationWithTarget:self.allianceImageView selector:@selector(setImageWithContentsOfURL:scale:) argumentPointers:&url, &scale];
			[invocation retainArguments];
			[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
			
			[self.allianceLabel performSelectorOnMainThread:@selector(setText:) withObject:allianceName waitUntilDone:NO];
		}
		else {
			[self.allianceImageView performSelectorOnMainThread:@selector(setImage:) withObject:nil waitUntilDone:NO];
			[self.allianceLabel performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
		}
		
		[self updateSkillInfoWithAccount:account];
		[self performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	}
	else {
		[corpLabel performSelectorOnMainThread:@selector(setText:) withObject:@"No Character Selected" waitUntilDone:NO];
		if (self.view.frame.size.height != 24) {
			id controller = self;
			CGSize size = CGSizeMake(320, 24);
			BOOL animated = YES;
			NSInvocation *invocation = [NSInvocation invocationWithTarget:delegate
																 selector:@selector(characterInfoViewController:willChangeContentSize:animated:)
														 argumentPointers:&controller, &size, &animated];
			[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
		}
	}
}

- (void) updateSkillInfoWithAccount:(EVEAccount*) account {
	int skillpoints = 0;
	for (EVECharacterSheetSkill *skill in account.characterSheet.skills)
		skillpoints += skill.skillpoints;
	
	if (account.skillQueue) {
		NSMutableString *text = [NSMutableString stringWithFormat:@"%@ points (%d skills)\n",
								 [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithInt:skillpoints] numberStyle:NSNumberFormatterDecimalStyle],
								 account.characterSheet.skills.count];

		if (account.skillQueue.skillQueue.count > 0) {
			NSDate *endTime = [[account.skillQueue.skillQueue lastObject] endTime];
			NSTimeInterval timeLeft = [endTime timeIntervalSinceDate:[account.skillQueue serverTimeWithLocalTime:[NSDate date]]];
			[text appendFormat:@"%@ (%d skills in queue)", [NSString stringWithTimeLeft:timeLeft], account.skillQueue.skillQueue.count];
			
		}
		else
			[text appendString:@"Training queue is inactive"];
		[self.skillsLabel performSelectorOnMainThread:@selector(setText:) withObject:text waitUntilDone:NO];
	}
	else {
		[self.skillsLabel performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
	}
}

- (void) show {
	if (self.view.frame.size.height != 142)
		[delegate characterInfoViewController:self willChangeContentSize:CGSizeMake(320, 142) animated:YES];
}

- (void) didSelectAccount:(NSNotification*) notification {
	[self update];
}

- (void) checkServerStatus {
	__block EUSingleBlockOperation* operation = [EUSingleBlockOperation operationWithIdentifier:@"CharacterInfoViewController+checkServerStatus"];
	__block EVEServerStatus *serverStatus = nil;
	__block NSError *error = nil;
	[operation addExecutionBlock:^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]  init];
		serverStatus = [[EVEServerStatus serverStatusWithError:&error] retain];
		[error retain];
		[pool release];
	}];
	
	[operation setCompletionBlockInCurrentThread:^{
		if (![operation isCancelled]) {
			if (error) {
				self.serverStatusLabel.text = @"Error";
				self.onlineLabel.text = @"";
			}
			else {		
				self.serverStatusLabel.text = serverStatus.serverOpen ? @"Online" : @"Offline";
				self.onlineLabel.text = [NSNumberFormatter localizedStringFromNumber:[NSNumber numberWithInt:serverStatus.onlinePlayers] numberStyle:NSNumberFormatterDecimalStyle];

				NSDate* cachedUntil = [serverStatus localTimeWithServerTime:serverStatus.cachedUntil];
				NSTimeInterval timeInterval = [cachedUntil timeIntervalSinceNow];
				if (timeInterval < 0 || timeInterval > 30 * 60)
					timeInterval = 30 * 60;
				
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkServerStatus) object:nil];
				[self performSelector:@selector(checkServerStatus) withObject:nil afterDelay:timeInterval];
			}
			
		}
		[serverStatus release];
		[error release];
	}];
	
	[[EUOperationQueue sharedQueue] addOperation:operation];
}

@end
