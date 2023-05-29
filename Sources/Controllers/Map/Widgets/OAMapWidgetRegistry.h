//
//  OAMapWidgetRegistry.h
//  OsmAnd
//
//  Created by Alexey Kulish on 02/10/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>

#define COLLAPSED_PREFIX @"+"
#define HIDE_PREFIX @"-"
#define SHOW_PREFIX @""
#define SETTINGS_SEPARATOR @";"

#define kWidgetModeDisabled 0x1
#define kWidgetModeEnabled 0x2
#define KWidgetModeAvailable 0x4
#define kWidgetModeDefault 0x8

#define kWidgetRegisteredNotification @"onWidgetRegistered"
#define kWidgetVisibilityChangedMotification @"onWidgetVisibilityChanged"
#define kWidgetsCleared @"onWidgetsCleared"

@class OAApplicationMode, OATextInfoWidget, OAMapWidgetRegInfo, OAWidgetState, OAMapWidgetInfo, OAWidgetsPanel;

@interface OAMapWidgetRegistry : NSObject

- (void) populateStackControl:(UIView *)stack mode:(OAApplicationMode *)mode left:(BOOL)left expanded:(BOOL)expanded;
- (BOOL) hasCollapsibles:(OAApplicationMode *)mode;

- (void) updateInfo:(OAApplicationMode *)mode expanded:(BOOL)expanded;
- (void) removeSideWidget:(NSString *)key;
- (void) removeSideWidgetInternal:(OATextInfoWidget *)widget;

- (OAMapWidgetRegInfo *) registerSideWidgetInternal:(OATextInfoWidget *)widget widgetState:(OAWidgetState *)widgetState key:(NSString *)key left:(BOOL)left priorityOrder:(int)priorityOrder;
- (OAMapWidgetRegInfo *) registerSideWidgetInternal:(OATextInfoWidget *)widget imageId:(NSString *)imageId message:(NSString *)message description:(NSString *)description key:(NSString *)key left:(BOOL)left priorityOrder:(int)priorityOrder;

- (BOOL) isVisible:(NSString *)key;
- (void) setVisibility:(OAMapWidgetRegInfo *)m visible:(BOOL)visible collapsed:(BOOL)collapsed;
- (void) setVisibility:(OAApplicationMode *)mode m:(OAMapWidgetRegInfo *)m visible:(BOOL)visible collapsed:(BOOL)collapsed;
- (void) resetToDefault;
- (void) resetToDefault:(OAApplicationMode *)mode;
- (void) updateVisibleWidgets;

- (NSOrderedSet<OAMapWidgetRegInfo *> *) getLeftWidgetSet;
- (NSOrderedSet<OAMapWidgetRegInfo *> *) getRightWidgetSet;
- (OAMapWidgetRegInfo *) widgetByKey:(NSString *)key;

- (NSArray<OAMapWidgetInfo *> *)getAllWidgets;
- (NSMutableOrderedSet<OAMapWidgetInfo *> * _Nonnull)getWidgetsForPanel:(OAApplicationMode *_Nonnull)appMode
                                                            filterModes:(NSInteger) filterModes
                                                                 panels:(NSArray<OAWidgetsPanel *> *_Nonnull)panels;

- (void) enableDisableWidgetForMode:(OAApplicationMode *)appMode
                         widgetInfo:(OAMapWidgetInfo *)widgetInfo
                            enabled:(NSNumber *)enabled
                   recreateControls:(BOOL)recreateControls;

@end
