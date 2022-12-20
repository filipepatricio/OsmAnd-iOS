//
//  OASimpleTableViewCell.m
//  OsmAnd Maps
//
//  Created by Skalii on 22.09.2022.
//  Copyright © 2022 OsmAnd. All rights reserved.
//

#import "OASimpleTableViewCell.h"

@interface OASimpleTableViewCell ()

@property (weak, nonatomic) IBOutlet UIStackView *textCustomMarginTopStackView;
@property (weak, nonatomic) IBOutlet UIStackView *contentInsideStackView;
@property (weak, nonatomic) IBOutlet UIStackView *textCustomMarginBottomStackView;

@end

@implementation OASimpleTableViewCell

- (void)leftIconVisibility:(BOOL)show
{
    self.leftIconView.hidden = !show;
    [self updateMargins];
}

- (void)titleVisibility:(BOOL)show
{
    self.titleLabel.hidden = !show;
    [self updateMargins];
}

- (void)descriptionVisibility:(BOOL)show
{
    self.descriptionLabel.hidden = !show;
    [self updateMargins];
}

- (void)updateMargins
{
    self.topContentSpaceView.hidden = (self.descriptionLabel.hidden || self.titleLabel.hidden) && [self checkSubviewsToUpdateMargins];
    self.bottomContentSpaceView.hidden = (self.descriptionLabel.hidden || self.titleLabel.hidden) && [self checkSubviewsToUpdateMargins];
}

- (BOOL)checkSubviewsToUpdateMargins
{
    return !self.leftIconView.hidden;
}

- (void)textIndentsStyle:(EOATableViewCellTextIndentsStyle)style
{
    self.textCustomMarginTopStackView.spacing = style == EOATableViewCellTextIncreasedTopCenterIndentStyle ? 9. : 5.;
    self.textStackView.spacing = style == EOATableViewCellTextNormalIndentsStyle ? 2. : 6.;
    self.textCustomMarginBottomStackView.spacing = 5.;
}

- (void)anchorContent:(EOATableViewCellContentStyle)style
{
    if (style == EOATableViewCellContentCenterStyle)
    {
        self.contentInsideStackView.alignment = UIStackViewAlignmentCenter;
    }
    else if (style == EOATableViewCellContentTopStyle)
    {
        self.contentInsideStackView.alignment = UIStackViewAlignmentTop;
    }
}

@end
