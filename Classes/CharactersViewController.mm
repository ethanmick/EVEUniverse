//
//  CharactersViewController.m
//  EVEUniverse
//
//  Created by Mr. Depth on 12/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "CharactersViewController.h"
#import "CharacterEqualSkills.h"
#import "CharacterEVE.h"
#import "CharacterCustom.h"
#import "EVEAccountStorage.h"
#import "EUOperationQueue.h"
#import "CharacterCellView.h"
#import "NibTableViewCell.h"
#import "CharacterSkillsEditorViewController.h"

@implementation CharactersViewController
@synthesize charactersTableView;
@synthesize delegate;
@synthesize modifiedFit;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.title = @"Characters";
	[self.navigationItem setRightBarButtonItem:self.editButtonItem];
	[self.navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStyleBordered target:self action:@selector(onClose:)] autorelease]];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
	[self setCharactersTableView:nil];
/*	[sections release];
	sections = nil;*/
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSMutableArray* sectionsTmp = [NSMutableArray array];
	EUSingleBlockOperation* operation = [EUSingleBlockOperation operationWithIdentifier:@"CharactersViewController+load"];
	[operation addExecutionBlock:^{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSMutableArray* staticCharacters = [NSMutableArray array];
		for (int i = 0; i <= 5; i++)
			[staticCharacters addObject:[CharacterEqualSkills characterWithSkillsLevel:i]];
		
		NSMutableDictionary* eveCharactersDic = [NSMutableDictionary dictionary];
		NSMutableArray* customCharacters = [NSMutableArray array];
		NSString* path = [Character charactersDirectory];
		NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
		
		for (NSString* fileName in items) {
			Character* character = [NSKeyedUnarchiver unarchiveObjectWithFile:[path stringByAppendingPathComponent:fileName]];
			if ([character isKindOfClass:[CharacterEVE class]])
				[eveCharactersDic setValue:character forKey:[NSString stringWithFormat:@"%d", character.characterID]];
			else if ([character isKindOfClass:[CharacterCustom class]])
				[customCharacters addObject:character];
		}
		[[EVEAccountStorage sharedAccountStorage] reload];
		for (EVEAccountStorageCharacter* accountCharacter in [[[EVEAccountStorage sharedAccountStorage] characters] allValues]) {
			if (accountCharacter.enabled) {
				CharacterEVE* character = [CharacterEVE characterWithCharacter:accountCharacter];
				[eveCharactersDic setValue:character forKey:[NSString stringWithFormat:@"%d", character.characterID]];
			}
		}
		NSArray* sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
		[customCharacters sortUsingDescriptors:sortDescriptors];
		NSMutableArray* eveCharacters = [NSMutableArray arrayWithArray:[eveCharactersDic allValues]];
		[eveCharacters sortUsingDescriptors:sortDescriptors];
		
		[sectionsTmp addObject:eveCharacters];
		[sectionsTmp addObject:customCharacters];
		[sectionsTmp addObject:staticCharacters];
		
		[pool release];
	}];
	
	[operation setCompletionBlockInCurrentThread:^{
		[sections release];
		sections = [sectionsTmp retain];
		[charactersTableView reloadData];
	}];
	
	[[EUOperationQueue sharedQueue] addOperation:operation];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		return UIInterfaceOrientationIsLandscape(interfaceOrientation);
	else
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
	[charactersTableView release];
	[sections release];
	[modifiedFit release];
	[super dealloc];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];
	[charactersTableView setEditing:editing animated:animated];

	NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[[sections objectAtIndex:1] count] inSection:1];
	NSArray* array = [NSArray arrayWithObject:indexPath];
	if (editing)
		[charactersTableView insertRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationFade];
	else
		[charactersTableView deleteRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationFade];
}

- (IBAction) onClose:(id)sender {
	[self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return sections.count;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.editing) {
		NSInteger number = [[sections objectAtIndex:section] count];
		if (section == 1)
			return number + 1;
		else
			return number;
	}
	else
		return [[sections objectAtIndex:section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return @"EVE Charaters";
	else if (section == 1)
		return @"Custom Characters";
	else
		return @"Static Characters";
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *cellIdentifier = @"CharacterCellView";
	
    CharacterCellView *cell = (CharacterCellView*) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [CharacterCellView cellWithNibName:@"CharacterCellView" bundle:nil reuseIdentifier:cellIdentifier];
    }
	if (indexPath.row == [[sections objectAtIndex:indexPath.section] count])
		cell.characterNameLabel.text = @"Add Character";
	else
		cell.characterNameLabel.text = [[[sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] name];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		Character* character = [[sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		NSString* path = [[[Character charactersDirectory] stringByAppendingPathComponent:character.guid] stringByAppendingPathExtension:@"plist"];
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];

		[[sections objectAtIndex:indexPath.section] removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
	else if (editingStyle == UITableViewCellEditingStyleInsert) {
		CharacterCustom* character = [[[CharacterCustom alloc] init] autorelease];
		character.name = @"Custom Character";
		[character save];
		[[sections objectAtIndex:1] addObject:character];
		[tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
		
		CharacterSkillsEditorViewController* controller = [[CharacterSkillsEditorViewController alloc] initWithNibName:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"CharacterSkillsEditorViewController-iPad" : @"CharacterSkillsEditorViewController")
																												bundle:nil];
		controller.character = character;
		[self.navigationController pushViewController:controller animated:YES];
		[controller release];

	}
}

#pragma mark -
#pragma mark Table view delegate

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row == [[sections objectAtIndex:indexPath.section] count])
		return UITableViewCellEditingStyleInsert;
	else
		return indexPath.section == 0 || indexPath.section == 1 ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UIView *header = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 22)] autorelease];
	header.opaque = NO;
	header.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:0.9];
	
	UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(10, 0, 300, 22)] autorelease];
	label.opaque = NO;
	label.backgroundColor = [UIColor clearColor];
	label.text = [self tableView:tableView titleForHeaderInSection:section];
	label.textColor = [UIColor whiteColor];
	label.font = [label.font fontWithSize:12];
	label.shadowColor = [UIColor blackColor];
	label.shadowOffset = CGSizeMake(1, 1);
	[header addSubview:label];
	return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 37;
}

- (void)tableView:(UITableView*) tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row == [[sections objectAtIndex:indexPath.section] count]) {
		[self tableView:tableView commitEditingStyle:UITableViewCellEditingStyleInsert forRowAtIndexPath:indexPath];
	}
	else {
		Character* character = [[sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		
		__block EUSingleBlockOperation* operation = [EUSingleBlockOperation operationWithIdentifier:@"CharactersViewController+LoadSkills"];
		[operation addExecutionBlock:^{
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
			if (character.skills && [character isKindOfClass:[CharacterEVE class]]) {
				[[NSFileManager defaultManager] createDirectoryAtPath:[Character charactersDirectory] withIntermediateDirectories:YES attributes:nil error:nil];
				[character save];
			}
			[pool release];
		}];
		
		[operation setCompletionBlockInCurrentThread:^{
			if (![operation isCancelled]) {
				if (self.editing) {
					CharacterSkillsEditorViewController* controller = [[CharacterSkillsEditorViewController alloc] initWithNibName:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"CharacterSkillsEditorViewController-iPad" : @"CharacterSkillsEditorViewController")
																															bundle:nil];
					controller.character = [[sections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
					[self.navigationController pushViewController:controller animated:YES];
					[controller release];
				}
				else {
					[delegate charactersViewController:self didSelectCharacter:character];
				}
			}
		}];
		
		[[EUOperationQueue sharedQueue] addOperation:operation];
	}
}

@end
