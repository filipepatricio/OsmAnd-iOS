//
//  OAChoosePlanViewController.m
//  OsmAnd
//
//  Created by Alexey on 17/12/2018.
//  Copyright © 2018 OsmAnd. All rights reserved.
//

#import "OAChoosePlanViewController.h"
#import "Localization.h"
#import "OAUtilities.h"
#import "OAIAPHelper.h"
#import "OAOsmLiveCardView.h"
#import "OAPurchaseCardView.h"
#import "OAColors.h"

#define kMargin 16.0
#define kTextBorderH 32.0

@interface OAFeature()

@property (nonatomic) EOAFeature value;

@end

@implementation OAFeature

- (instancetype) initWithFeature:(EOAFeature)feature
{
    self = [super init];
    if (self)
    {
        self.value = feature;
    }
    return self;
}

- (NSString *) toHumanString
{
    switch (self.value)
    {
        case EOAFeatureWikivoyageOffline:
            return OALocalizedString(@"wikivoyage_offline");
        case EOAFeatureDailyMapUpdates:
            return OALocalizedString(@"daily_map_updates");
        case EOAFeatureMonthlyMapUpdates:
            return OALocalizedString(@"monthly_map_updates");
        case EOAFeatureUnlimitedDownloads:
            return OALocalizedString(@"unlimited_downloads");
        case EOAFeatureWikipediaOffline:
            return OALocalizedString(@"wikipedia_offline");
        case EOAFeatureContourLinesHillshadeMaps:
            return OALocalizedString(@"contour_lines_hillshade_maps");
        case EOAFeatureSeaDepthMaps:
            return OALocalizedString(@"index_item_depth_contours_osmand_ext");
        case EOAFeatureDonationToOSM:
            return OALocalizedString(@"donation_to_osm");
        case EOAFeatureRegionAfrica:
            return OALocalizedString(@"product_desc_africa");
        case EOAFeatureRegionRussia:
            return OALocalizedString(@"product_desc_russia");
        case EOAFeatureRegionAsia:
            return OALocalizedString(@"product_desc_asia");
        case EOAFeatureRegionAustralia:
            return OALocalizedString(@"product_desc_australia");
        case EOAFeatureRegionEurope:
            return OALocalizedString(@"product_desc_europe");
        case EOAFeatureRegionCentralAmerica:
            return OALocalizedString(@"product_desc_centralamerica");
        case EOAFeatureRegionNorthAmerica:
            return OALocalizedString(@"product_desc_northamerica");
        case EOAFeatureRegionSouthAmerica:
            return OALocalizedString(@"product_desc_southamerica");
        default:
            return @"";
    }
}

- (UIImage *) getImage
{
    switch (self.value)
    {
        case EOAFeatureWikivoyageOffline:
            return [UIImage imageNamed:@"ic_live_wikivoyage"];
        case EOAFeatureDailyMapUpdates:
            return [UIImage imageNamed:@"ic_live_map_updates"];
        case EOAFeatureMonthlyMapUpdates:
            return [UIImage imageNamed:@"ic_live_monthly_updates"];
        case EOAFeatureUnlimitedDownloads:
        case EOAFeatureRegionAfrica:
        case EOAFeatureRegionRussia:
        case EOAFeatureRegionAsia:
        case EOAFeatureRegionAustralia:
        case EOAFeatureRegionEurope:
        case EOAFeatureRegionCentralAmerica:
        case EOAFeatureRegionNorthAmerica:
        case EOAFeatureRegionSouthAmerica:
            return [UIImage imageNamed:@"ic_live_unlimited_downloads"];
        case EOAFeatureWikipediaOffline:
            return [UIImage imageNamed:@"ic_live_wikipedia"];
        case EOAFeatureContourLinesHillshadeMaps:
            return [UIImage imageNamed:@"ic_live_srtm"];
        case EOAFeatureSeaDepthMaps:
            return [UIImage imageNamed:@"ic_live_nautical_depth"];
        case EOAFeatureDonationToOSM:
            return nil;
        default:
            return nil;
    }
}

- (BOOL) isFeaturePurchased
{
    OAIAPHelper *helper = [OAIAPHelper sharedInstance];
    if (helper.subscribedToLiveUpdates)
        return YES;
    
    switch (self.value)
    {
        case EOAFeatureDailyMapUpdates:
        case EOAFeatureDonationToOSM:
        case EOAFeatureMonthlyMapUpdates:
            return NO;
        case EOAFeatureUnlimitedDownloads:
            return [helper.allWorld isPurchased];
        case EOAFeatureRegionAfrica:
            return [helper.africa isPurchased];
        case EOAFeatureRegionRussia:
            return [helper.russia isPurchased];
        case EOAFeatureRegionAsia:
            return [helper.asia isPurchased];
        case EOAFeatureRegionAustralia:
            return [helper.australia isPurchased];
        case EOAFeatureRegionEurope:
            return [helper.europe isPurchased];
        case EOAFeatureRegionCentralAmerica:
            return [helper.centralAmerica isPurchased];
        case EOAFeatureRegionNorthAmerica:
            return [helper.northAmerica isPurchased];
        case EOAFeatureRegionSouthAmerica:
            return [helper.southAmerica isPurchased];
        case EOAFeatureWikipediaOffline:
            return [helper.wiki isPurchased];
        case EOAFeatureWikivoyageOffline:
            return NO;
        case EOAFeatureSeaDepthMaps:
            return [helper.nautical isPurchased];
        case EOAFeatureContourLinesHillshadeMaps:
            return [helper.srtm isPurchased];
        default:
            return NO;
    }
}

@end

@interface OAChoosePlanViewController ()

@end

@implementation OAChoosePlanViewController
{
    OAIAPHelper *_iapHelper;
    OAOsmLiveCardView *_osmLiveCard;
    OAPurchaseCardView *_planTypeCard;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (instancetype) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [super initWithNibName:@"OAChoosePlanViewController" bundle:nil];
}

- (void) commonInit
{
    _iapHelper = [OAIAPHelper sharedInstance];
}

- (void) applyLocalization
{
    self.lbTitle.text = OALocalizedString(@"purchase_dialog_title");
    self.lbDescription.text = [self getInfoDescription];
    [self.btnLater setTitle:OALocalizedString(@"shared_string_later") forState:UIControlStateNormal];
}

- (NSString *) getInfoDescription
{
    return [[[NSString stringWithFormat:OALocalizedString(@"free_version_message"), [OAIAPHelper freeMapsAvailable]] stringByAppendingString:@"\n"] stringByAppendingString:OALocalizedString(@"get_osmand_live")];
}

- (NSArray<OAFeature *> *) getOsmLiveFeatures
{
    return nil; // not implemented
}

- (NSArray<OAFeature *> *) getPlanTypeFeatures
{
    return nil; // not implemented
}

- (NSArray<OAFeature *> *) getSelectedOsmLiveFeatures
{
    return nil; // not implemented
}

- (NSArray<OAFeature *> *) getSelectedPlanTypeFeatures
{
    return nil; // not implemented
}

- (UIImage *) getPlanTypeHeaderImage
{
    return nil; // not implemented
}

- (NSString *) getPlanTypeHeaderTitle
{
    return nil; // not implemented
}

- (NSString *) getPlanTypeHeaderDescription
{
    return nil; // not implemented
}

- (NSString *) getPlanTypeButtonTitle
{
    OAProduct *product = [self getPlanTypeProduct];
    if (product)
    {
        if ([product isPurchased])
            return product.formattedPrice;
        else
            return [NSString stringWithFormat:OALocalizedString(@"purchase_unlim_title"), product.formattedPrice];
    }
    return @"";
}

- (NSString *) getPlanTypeButtonDescription
{
    return nil; // not implemented
}

- (void) setPlanTypeButtonClickListener:(UIButton *)button
{
    // not implemented
}

- (OAProduct * _Nullable) getPlanTypeProduct;
{
    return nil; // not implemented
}

- (BOOL) hasSelectedOsmLiveFeature:(OAFeature *)feature
{
    NSArray<OAFeature *> *features = [self getSelectedOsmLiveFeatures];
    if (features)
        for (OAFeature *f in features)
            if (feature.value == f.value)
                return YES;

    return NO;
}

- (BOOL) hasSelectedPlanTypeFeature:(OAFeature *)feature
{
    NSArray<OAFeature *> *features = [self getSelectedPlanTypeFeatures];
    if (features)
        for (OAFeature *f in features)
            if (feature.value == f.value)
                return YES;

    return NO;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    CALayer *bl = self.btnLater.layer;
    bl.cornerRadius = 3;
    bl.shadowColor = UIColor.blackColor.CGColor;
    bl.shadowOpacity = 0.2;
    bl.shadowRadius = 1.5;
    bl.shadowOffset = CGSizeMake(0.0, 0.5);
    
    _osmLiveCard = [self buildOsmLiveCard];
    [self.cardsContainer addSubview:_osmLiveCard];
    _planTypeCard = [self buildPlanTypeCard];
    [self.cardsContainer addSubview:_planTypeCard];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setupOsmLiveCardButtons:NO];
    [self setupPlanTypeCardButtons:NO];
}

- (UIStatusBarStyle) preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (void) viewWillLayoutSubviews
{
    CGRect frame = self.scrollView.frame;
    
    CGFloat w = frame.size.width;
    CGFloat descrHeight = [OAUtilities calculateTextBounds:self.lbDescription.text width:w - kTextBorderH * 2 font:self.lbDescription.font].height;
    CGRect nf = self.navBarView.frame;
    CGRect df = self.lbDescription.frame;
    self.lbDescription.frame = CGRectMake(kTextBorderH, nf.origin.y + nf.size.height, w - kTextBorderH * 2, descrHeight + kMargin);
    df = self.lbDescription.frame;

    CGFloat y = 0;
    CGFloat cw = w - kMargin * 2;
    for (UIView *v in self.cardsContainer.subviews)
    {
        if ([v isKindOfClass:[OAPurchaseDialogItemView class]])
        {
            OAPurchaseDialogItemView *card = (OAPurchaseDialogItemView *)v;
            CGRect crf = [card updateFrame:cw];
            crf.origin.y = y;
            card.frame = crf;
            y += crf.size.height + kMargin;
        }
    }
    if (y > 0)
        y -= kMargin;
    
    CGRect cf = self.cardsContainer.frame;
    cf.origin.y =  df.origin.y + df.size.height + kMargin;
    cf.size.height = y;
    cf.size.width = cw;
    self.cardsContainer.frame = cf;
    
    CGRect lbf = self.btnLater.frame;
    self.btnLater.frame = CGRectMake(kMargin, cf.origin.y + cf.size.height + kMargin, w - kMargin * 2, lbf.size.height);
    lbf = self.btnLater.frame;

    self.scrollView.contentSize = CGSizeMake(frame.size.width, lbf.origin.y + lbf.size.height + kMargin);
}

- (IBAction) backButtonClicked:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (OAOsmLiveCardView *) buildOsmLiveCard
{
    OAOsmLiveCardView *cardView = [[OAOsmLiveCardView alloc] initWithFrame:{0, 0, 300, 200}];
    cardView.imageView.image = [UIImage imageNamed:@"img_logo_38dp_osmand"];
    cardView.lbTitle.text = OALocalizedString(@"osmand_live_title");
    cardView.lbDescription.text = OALocalizedString(@"osm_live_subscription");

    BOOL firstRow = YES;
    for (OAFeature *feature in [self getOsmLiveFeatures])
    {
        NSString *featureName = [feature toHumanString];
        BOOL selected = [self hasSelectedOsmLiveFeature:feature];
        UIImage *image = [feature isFeaturePurchased] ? [UIImage imageNamed:@"ic_live_purchased"] : [feature getImage];
        [cardView addInfoRowWithText:featureName image:image selected:selected showDivider:!firstRow];
        if (firstRow)
            firstRow = NO;
    }
    return cardView;
}

- (OAPurchaseCardView *) buildPlanTypeCard
{
    if ([self getPlanTypeFeatures].count == 0)
        return nil;
    
    UIImage *headerImage = [self getPlanTypeHeaderImage];
    NSString *headerTitle = [self getPlanTypeHeaderTitle];
    NSString *headerDescr = [self getPlanTypeHeaderDescription];

    OAPurchaseCardView *cardView = [[OAPurchaseCardView alloc] initWithFrame:{0, 0, 300, 200}];
    [cardView setupCardWithImage:headerImage title:headerTitle description:headerDescr buttonDescription:OALocalizedString(@"in_app_purchase_desc_ex")];

    BOOL firstRow = YES;
    for (OAFeature *feature in [self getPlanTypeFeatures])
    {
        NSString *featureName = [feature toHumanString];
        BOOL selected = [self hasSelectedOsmLiveFeature:feature];
        UIImage *image = [feature isFeaturePurchased] ? [UIImage imageNamed:@"ic_live_purchased"] : [feature getImage];
        [cardView addInfoRowWithText:featureName image:image selected:selected showDivider:!firstRow];
        if (firstRow)
            firstRow = NO;
    }
    
    return cardView;
}

- (void) manageSubscription
{
    //https://apps.apple.com/account/subscriptions
}

- (void) subscribe:(OASubscription *)subscriptipon
{
    
}

- (void) setupOsmLiveCardButtons:(BOOL)progress
{
    if (progress)
    {
        [_osmLiveCard setProgressVisibile:YES];
        [_osmLiveCard setNeedsLayout];
        return;
    }
    else
    {
        for (UIView *v in _osmLiveCard.buttonsContainer.subviews)
            [v removeFromSuperview];
        
        OASubscription *monthlyLiveUpdates = _iapHelper.monthlyLiveUpdates;
        double regularMonthlyPrice = monthlyLiveUpdates.price.doubleValue;
        NSArray<OASubscription *> *visibleSubscriptions = [_iapHelper.liveUpdates getVisibleSubscriptions];
        BOOL anyPurchased = NO;
        for (OASubscription *s in visibleSubscriptions)
        {
            if ([s isPurchased])
            {
                anyPurchased = YES;
                break;
            }
        }
        BOOL firstRow = YES;
        BOOL purchased = NO;
        BOOL prevPurchased = NO;
        BOOL nextPurchased = NO;
        OAChoosePlanViewController * __weak weakSelf = self;
        for (NSInteger i = 0; i < visibleSubscriptions.count; i++)
        {
            OASubscription *s = [visibleSubscriptions objectAtIndex:i];
            OASubscription *next = nil;
            if (i < visibleSubscriptions.count - 1)
                next = [visibleSubscriptions objectAtIndex:i + 1];

            purchased = [s isPurchased];
            nextPurchased = [next isPurchased];
            
            BOOL showTopDiv = NO;
            BOOL showBottomDiv = NO;
            if (purchased)
            {
                showTopDiv = !prevPurchased;
                showBottomDiv = next != nil;
            }
            else
            {
                showTopDiv = !prevPurchased && !firstRow;
            }

            if (purchased)
            {
                [_osmLiveCard addCardButtonWithTitle:[s getTitle:16.0] description:[s getDescription:14.0] buttonText:s.formattedPrice buttonType:EOAPurchaseDialogCardButtonTypeDisabled active:YES discountDescr:@"" showDiscount:NO highDiscount:NO showTopDiv:showTopDiv showBottomDiv:NO onButtonClick:nil];
                
                [_osmLiveCard addCardButtonWithTitle:[[NSAttributedString alloc] initWithString:OALocalizedString(@"osm_live_payment_current_subscription")] description:[s getRenewDescription:14.0] buttonText:OALocalizedString(@"shared_string_cancel") buttonType:EOAPurchaseDialogCardButtonTypeExtended active:YES discountDescr:@"" showDiscount:NO highDiscount:NO showTopDiv:NO showBottomDiv:showBottomDiv onButtonClick:^{
                    [weakSelf manageSubscription];
                }];
            }
            else
            {
                BOOL highDiscount = NO;
                BOOL showDiscount = NO;
                NSString *discountStr = nil;
                double monthlyPrice = s.monthlyPrice ? s.monthlyPrice.doubleValue : 0.0;
                if (regularMonthlyPrice > 0 && monthlyPrice > 0 && monthlyPrice < regularMonthlyPrice)
                {
                    int discount = (int) ((1 - monthlyPrice / regularMonthlyPrice) * 100.0);
                    discountStr = [NSString stringWithFormat:@"%d%%", discount];
                    if (discount > 0)
                    {
                        discountStr = [NSString stringWithFormat:OALocalizedString(@"osm_live_payment_discount_descr"), discountStr];
                        showDiscount = YES;
                        highDiscount = discount > 50;
                    }
                }
                [_osmLiveCard addCardButtonWithTitle:[s getTitle:16.0] description:[s getDescription:14.0] buttonText:s.formattedPrice buttonType:anyPurchased ? EOAPurchaseDialogCardButtonTypeRegular : EOAPurchaseDialogCardButtonTypeExtended active:NO discountDescr:discountStr showDiscount:showDiscount highDiscount:highDiscount showTopDiv:showTopDiv showBottomDiv:showBottomDiv onButtonClick:^{
                    [weakSelf subscribe:s];
                }];
            }
            if (firstRow)
                firstRow = NO;
            
            prevPurchased = purchased;
        }
    }
    [_osmLiveCard setProgressVisibile:NO];
    [_osmLiveCard setNeedsLayout];
}

- (void) setupPlanTypeCardButtons:(BOOL)progress
{
    if (_planTypeCard)
    {
        OAProduct *product = [self getPlanTypeProduct];
        BOOL purchased = product && [product isPurchased];

        NSMutableAttributedString *titleStr = [[NSMutableAttributedString alloc] initWithString:[self getPlanTypeButtonTitle]];
        [titleStr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium] range:NSMakeRange(0, titleStr.length)];
        NSMutableAttributedString *subtitleStr = [[NSMutableAttributedString alloc] initWithString:[self getPlanTypeButtonDescription]];
        [subtitleStr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular] range:NSMakeRange(0, subtitleStr.length)];
        if (progress)
        {
            [_planTypeCard setProgressVisibile:YES];
            [_planTypeCard setupCardButtonEnabled:YES buttonText:[[NSAttributedString alloc] initWithString:@" \n "] buttonClickHandler:nil];
        }
        else
        {
            NSMutableAttributedString *buttonText = [[NSMutableAttributedString alloc] initWithString:@""];
            [_planTypeCard setProgressVisibile:NO];
            if (!purchased)
            {
                [titleStr addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, titleStr.length)];
                [subtitleStr addAttribute:NSForegroundColorAttributeName value:UIColorFromARGB(0x80FFFFFF) range:NSMakeRange(0, subtitleStr.length)];
                [buttonText appendAttributedString:titleStr];
                [buttonText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                [buttonText appendAttributedString:subtitleStr];
                [_planTypeCard setupCardButtonEnabled:YES buttonText:buttonText buttonClickHandler:nil];
                [self setPlanTypeButtonClickListener:_planTypeCard.cardButton];
            }
            else
            {
                [titleStr addAttribute:NSForegroundColorAttributeName value:UIColorFromRGB(color_secondary_text_blur) range:NSMakeRange(0, titleStr.length)];
                [subtitleStr addAttribute:NSForegroundColorAttributeName value:UIColorFromRGB(color_secondary_text_blur) range:NSMakeRange(0, subtitleStr.length)];
                [buttonText appendAttributedString:titleStr];
                [buttonText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                [buttonText appendAttributedString:subtitleStr];
                [_planTypeCard setupCardButtonEnabled:NO buttonText:buttonText buttonClickHandler:nil];
            }
        }
    }
}

@end
