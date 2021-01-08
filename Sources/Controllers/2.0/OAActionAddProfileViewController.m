//
//  OAActionAddProfileViewController.m
//  OsmAnd
//
//  Created by nnngrach on 24.12.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OAActionAddProfileViewController.h"
#import "OAActionConfigurationViewController.h"
#import "Localization.h"
#import "OAMenuSimpleCell.h"
#import "OASizes.h"
#import "OsmAndApp.h"
#import "OAIAPHelper.h"
#import "OAMapSource.h"
#import "OAApplicationMode.h"
#import "OAAppSettings.h"
#import "OAMapStyleTitles.h"
#import "OAProfileDataObject.h"
#import "OAProfileDataUtils.h"

@interface OAActionAddProfileViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIView *navBarView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *titleView;
@property (weak, nonatomic) IBOutlet UIButton *backBtn;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;

@end

@implementation OAActionAddProfileViewController
{
    NSMutableArray<NSString *> *_initialValues;
    NSArray<OAProfileDataObject *> *_data;
}

- (instancetype)initWithNames:(NSMutableArray<NSString *> *)names
{
    self = [super init];
    if (self) {
        _initialValues = names;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self commonInit];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0.0, 55., 0.0, 0.0);
    [self.tableView setEditing:YES];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48.;
    [self.backBtn setImage:[[UIImage imageNamed:@"ic_navbar_chevron"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [self.backBtn setTintColor:UIColor.whiteColor];
    
    [self selectCells];
}

- (void) selectCells
{
    for (int i = 0; i < _data.count; i ++)
    {
        if ([_initialValues containsObject:_data[i].stringKey])
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applySafeAreaMargins];
}

-(void) commonInit
{
    _data = [OAProfileDataUtils getDataObjects:[OAApplicationMode allPossibleValues]];
}

- (void)applyLocalization
{
    _titleView.text = OALocalizedString(@"select_application_profile");
    [_doneButton setTitle:OALocalizedString(@"shared_string_done") forState:UIControlStateNormal];
}

-(UIView *) getTopView
{
    return _navBarView;
}

-(UIView *) getMiddleView
{
    return _tableView;
}

- (IBAction)backPressed:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)doneButtonPressed:(id)sender
{
    NSArray *selectedItems = [self.tableView indexPathsForSelectedRows];
    NSMutableArray *arr = [NSMutableArray new];
    for (NSIndexPath *path in selectedItems)
    {
        OAProfileDataObject *profile = _data[path.row];
        [arr addObject:@{@"name" : profile.name, @"stringKey" : profile.stringKey, @"img" : profile.iconName, @"iconColor" : [NSNumber numberWithInt:profile.iconColor]}];
    }
    if (self.delegate)
        [self.delegate onProfileSelected:[NSArray arrayWithArray:arr]];
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OAProfileDataObject *item = _data[indexPath.row];
    static NSString* const identifierCell = @"OAMenuSimpleCell";
    
    OAMenuSimpleCell* cell = nil;
    
    cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:identifierCell owner:self options:nil];
        cell = (OAMenuSimpleCell *)[nib objectAtIndex:0];
    }
    
    if (cell)
    {
        cell.textView.text = item.name;
        cell.descriptionView.text = item.descr;
        cell.imgView.image = [[UIImage imageNamed:item.iconName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imgView.tintColor = UIColorFromRGB(item.iconColor);
        cell.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
    }
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _data.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return OALocalizedString(@"app_profiles");
}

@end
