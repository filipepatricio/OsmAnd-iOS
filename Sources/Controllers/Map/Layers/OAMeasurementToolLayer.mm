//
//  OAMeasurementToolLayer.m
//  OsmAnd
//
//  Created by Paul on 22.10.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OAMeasurementToolLayer.h"
#import "OAMapLayersConfiguration.h"
#import "OARootViewController.h"
#import "OAMapViewController.h"
#import "OAMapRendererView.h"
#import "OARoutingHelper.h"
#import "OARouteCalculationResult.h"
#import "OAUtilities.h"
#import "OANativeUtilities.h"
#import "OAColors.h"
#import "OAAutoObserverProxy.h"

#import "OAGPXDocument.h"
#import "OAGPXDocumentPrimitives.h"
#import "OAMeasurementEditingContext.h"

#include <OsmAndCore.h>
#include <OsmAndCore/Utilities.h>
#include <OsmAndCore/GeoInfoDocument.h>
#include <OsmAndCore/Map/VectorLine.h>
#include <OsmAndCore/Map/VectorLineBuilder.h>
#include <OsmAndCore/Map/VectorLinesCollection.h>
#include <OsmAndCore/Map/MapMarker.h>
#include <OsmAndCore/Map/MapMarkerBuilder.h>
#include <OsmAndCore/Map/MapMarkersCollection.h>
#include <OsmAndCore/SkiaUtilities.h>
#include <SkCGUtils.h>


@implementation OAMeasurementToolLayer
{
    OARoutingHelper *_routingHelper;

    std::shared_ptr<OsmAnd::VectorLinesCollection> _collection;
    std::shared_ptr<OsmAnd::VectorLinesCollection> _lastLineCollection;
    
    std::shared_ptr<OsmAnd::MapMarkersCollection> _pointMarkers;
    std::shared_ptr<OsmAnd::MapMarkersCollection> _selectedMarkerCollection;
    
    std::shared_ptr<SkBitmap> _pointMarkerIcon;
    
    OsmAnd::PointI _cachedCenter;
    OAGpxTrkPt *_cachedLastPoint;
    
    BOOL _isInMovingMode;
    std::shared_ptr<OsmAnd::MapMarker> _markerToMove;
    std::shared_ptr<OsmAnd::VectorLine> _lineBefore;
    std::shared_ptr<OsmAnd::VectorLine> _lineAfter;
    OsmAnd::PointI _prevPosition;
    OsmAnd::PointI _nextPosition;
    
    BOOL _initDone;
}

- (NSString *) layerId
{
    return kRoutePlanningLayerId;
}

- (void) initLayer
{
    _routingHelper = [OARoutingHelper sharedInstance];
    
    _collection = std::make_shared<OsmAnd::VectorLinesCollection>();
    _lastLineCollection = std::make_shared<OsmAnd::VectorLinesCollection>();
    _pointMarkers = std::make_shared<OsmAnd::MapMarkersCollection>();
    _selectedMarkerCollection = std::make_shared<OsmAnd::MapMarkersCollection>();
    
    _pointMarkerIcon = [OANativeUtilities skBitmapFromPngResource:@"map_plan_route_point_normal"];
    
    _initDone = YES;
    
    [self.mapView addKeyedSymbolsProvider:_collection];
    [self.mapView addKeyedSymbolsProvider:_lastLineCollection];
    [self.mapView addKeyedSymbolsProvider:_pointMarkers];
    [self.mapView addKeyedSymbolsProvider:_selectedMarkerCollection];
}

- (void)updateDistAndBearing
{
    if (_delegate)
    {
        double distance = 0, bearing = 0;
        if (_editingCtx.getPointsCount > 0)
        {
            OAGpxTrkPt *lastPoint = _editingCtx.getPoints[_editingCtx.getPointsCount - 1];
            OsmAnd::LatLon centerLatLon = OsmAnd::Utilities::convert31ToLatLon(self.mapView.target31);
            distance = getDistance(lastPoint.getLatitude, lastPoint.getLongitude, centerLatLon.latitude, centerLatLon.longitude);
            CLLocation *loc1 = [[CLLocation alloc] initWithLatitude:lastPoint.getLatitude longitude:lastPoint.getLongitude];
            CLLocation *loc2 = [[CLLocation alloc] initWithLatitude:centerLatLon.latitude longitude:centerLatLon.longitude];
            bearing = [loc1 bearingTo:loc2];
        }
        [_delegate onMeasue:distance bearing:bearing];
    }
}

- (void)onMapFrameRendered
{
    [self updateLastPointToCenter];
    [self updateDistAndBearing];
}

- (void)buildLine:(OsmAnd::VectorLineBuilder &)builder collection:(std::shared_ptr<OsmAnd::VectorLinesCollection> &)collection linePoints:(const QVector<OsmAnd::PointI> &)linePoints {
    builder.setPoints(linePoints);
    const auto line = builder.buildAndAddToCollection(collection);
    if (_isInMovingMode)
    {
        OAGpxTrkPt *pt = _editingCtx.originalPointToMove;
        const auto pos = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(pt.getLatitude, pt.getLongitude));
        if (linePoints.contains(pos))
        {
            if (linePoints.contains(_prevPosition))
                _lineBefore = line;
            else if (linePoints.contains(_nextPosition))
                _lineAfter = line;
        }
    }
}

- (void)drawLines:(const QVector<OsmAnd::PointI> &)points collection:(std::shared_ptr<OsmAnd::VectorLinesCollection>&)collection
{
    [self drawLines:points collection:collection modeAware:NO];
}

- (void)drawLines:(const QVector<OsmAnd::PointI> &)points collection:(std::shared_ptr<OsmAnd::VectorLinesCollection>&)collection modeAware:(BOOL)modeAware
{
    if (points.size() < 2)
        return;
    
    OsmAnd::ColorARGB lineColor = OsmAnd::ColorARGB(0xff, 0xff, 0x88, 0x00);
    
    EOAAddPointMode mode = _editingCtx.addPointMode;
    NSInteger selectedPoint = _editingCtx.selectedPointPosition;
    
    for (int i = 0; i < points.size() - 1; i++)
    {
        if (((i == selectedPoint && mode == EOAAddPointModeAfter) || (i == (selectedPoint - 1) && mode == EOAAddPointModeBefore)) && modeAware)
            continue;
        
        OsmAnd::VectorLineBuilder builder;
        builder.setBaseOrder(self.baseOrder)
        .setIsHidden(points.size() == 0)
        .setLineId(1)
        .setLineWidth(30);
        
        builder.setFillColor(lineColor);
        QVector<OsmAnd::PointI> linePoints;
        linePoints.append(points[i]);
        linePoints.append(points[i + 1]);
        [self buildLine:builder collection:collection linePoints:linePoints];
    }
}

- (void)drawMovePointLines
{
    if (!_lastLineCollection->getLines().isEmpty())
        _lastLineCollection->removeAllLines();
    
    const auto center = self.mapViewController.mapView.target31;
    if (center != _cachedCenter && _markerToMove != nullptr)
    {
        _cachedCenter = center;
        _markerToMove->setPosition(center);
        if (_lineAfter != nullptr)
        {
            QVector<OsmAnd::PointI> updatedPoints;
            updatedPoints.append(center);
            updatedPoints.append(_nextPosition);
            _lineAfter->setPoints(updatedPoints);
        }
        if (_lineBefore != nullptr)
        {
            QVector<OsmAnd::PointI> updatedPoints;
            updatedPoints.append(_prevPosition);
            updatedPoints.append(center);
            _lineBefore->setPoints(updatedPoints);
        }
    }
}

- (std::shared_ptr<OsmAnd::MapMarker>) drawMarker:(const OsmAnd::Point<int> &)posiotion collection:(std::shared_ptr<OsmAnd::MapMarkersCollection> &)collection
{
    OsmAnd::MapMarkerBuilder pointMarkerBuilder;
    pointMarkerBuilder.setIsAccuracyCircleSupported(false);
    pointMarkerBuilder.setBaseOrder(self.baseOrder - 15);
    pointMarkerBuilder.setIsHidden(false);
    pointMarkerBuilder.setPinIconHorisontalAlignment(OsmAnd::MapMarker::CenterHorizontal);
    pointMarkerBuilder.setPinIconVerticalAlignment(OsmAnd::MapMarker::CenterVertical);
    pointMarkerBuilder.setPinIcon(_pointMarkerIcon);
    
    auto marker = pointMarkerBuilder.buildAndAddToCollection(collection);
    marker->setPosition(posiotion);
    return marker;
}

- (void) drawAddPointLines
{
    NSArray<OAGpxTrkPt *> *allPoints = _editingCtx.getAllPoints;
    OAGpxTrkPt *prevPt = allPoints[_editingCtx.selectedPointPosition];
    const auto prevPos = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(prevPt.getLatitude, prevPt.getLongitude));
    NSInteger nextInd = _editingCtx.selectedPointPosition + (_editingCtx.addPointMode == EOAAddPointModeBefore ? -1 : 1);
    OAGpxTrkPt *nextPt = nil;
    if (nextInd >= 0 && nextInd < allPoints.count)
        nextPt = allPoints[nextInd];
    const auto nextPos = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(nextPt.getLatitude, nextPt.getLongitude));
    const auto center = self.mapViewController.mapView.target31;
    if (center == _cachedCenter)
        return;
    _cachedCenter = center;
    QVector<OsmAnd::PointI> pointsBefore;
    pointsBefore.push_back(prevPos);
    pointsBefore.push_back(center);
    QVector<OsmAnd::PointI> pointsAfter;
    pointsAfter.push_back(nextPos);
    pointsAfter.push_back(center);
    if (!_lastLineCollection->getLines().isEmpty())
    {
        _lastLineCollection->getLines().first()->setPoints(pointsBefore);
        if (nextPt)
            _lastLineCollection->getLines().last()->setPoints(pointsAfter);
    }
    else
    {
        [self drawLines:pointsBefore collection:_lastLineCollection];
        if (nextPt)
            [self drawLines:pointsAfter collection:_lastLineCollection];
    }
    
    if (_selectedMarkerCollection->getMarkers().size() == 0)
    {
        [self drawMarker:center collection:_selectedMarkerCollection];
    }
    else
    {
        _selectedMarkerCollection->getMarkers().first()->setPosition(center);
    }
}

- (void)drawLineFromLastPoint
{
    OAGpxTrkPt *lastBeforePoint = nil;
    if (_editingCtx.getBeforePoints.count > 0)
        lastBeforePoint = _editingCtx.getBeforePoints.lastObject;
    if (lastBeforePoint)
    {
        const auto center = self.mapViewController.mapView.target31;
        if (center == _cachedCenter && _cachedLastPoint == lastBeforePoint)
            return;
        _cachedLastPoint = lastBeforePoint;
        _cachedCenter = center;
        const auto lastBeforePnt = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(lastBeforePoint.getLatitude, lastBeforePoint.getLongitude));
        QVector<OsmAnd::PointI> points;
        points.push_back(lastBeforePnt);
        points.push_back(center);
        if (_lastLineCollection->getLines().size() != 0)
        {
            const auto lastLine = _lastLineCollection->getLines().last();
            lastLine->setPoints(points);
        }
        else
        {
            [self drawLines:points collection:_lastLineCollection];
        }
    }
}

- (void) updateLastPointToCenter
{
    [self.mapViewController runWithRenderSync:^{
        if (_editingCtx && _editingCtx.selectedPointPosition != -1 && _isInMovingMode)
        {
            [self drawMovePointLines];
        }
        else if (_editingCtx && _editingCtx.selectedPointPosition != -1 && _editingCtx.addPointMode != EOAAddPointModeUndefined)
        {
            [self drawAddPointLines];
        }
        else
        {
            [self drawLineFromLastPoint];
        }
    }];
    
}

- (void) resetLayer
{
    _collection->removeAllLines();
    _lastLineCollection->removeAllLines();
    _pointMarkers->removeAllMarkers();
    _selectedMarkerCollection->removeAllMarkers();
    _cachedCenter = OsmAnd::PointI(0, 0);
    _cachedLastPoint = nil;
}

- (BOOL) updateLayer
{
    [self resetLayer];
    const auto points = [self calculatePointsToDraw];
    [self drawRouteSegment:points];
    return YES;
}

- (void) enterMovingPointMode
{
    _isInMovingMode = YES;
    [self updateLayer];
    //    moveMapToPoint(editingCtx.getSelectedPointPosition());
    //    editingCtx.splitSegments(editingCtx.getSelectedPointPosition());
}

- (void) exitMovingMode
{
    _isInMovingMode = NO;
    _prevPosition = OsmAnd::PointI(0, 0);
    _nextPosition = OsmAnd::PointI(0, 0);
    _markerToMove = nullptr;
    _lineBefore = nullptr;
    _lineAfter = nullptr;
    
    [self updateLayer];
}

- (OAGpxTrkPt *) getMovedPointToApply
{
    const auto latLon = OsmAnd::Utilities::convert31ToLatLon(self.mapViewController.mapView.target31);
    
    OAGpxTrkPt *originalPoint = _editingCtx.originalPointToMove;
    OAGpxTrkPt *point = [[OAGpxTrkPt alloc] initWithPoint:originalPoint];
    point.position = CLLocationCoordinate2DMake(latLon.latitude, latLon.longitude);
//    point.trkpt->position = latLon;
//    [point copyExtensions:originalPoint];
    return point;
}

//- (OAGpxTrkPt *) addPoint:(EOAAddPointMode)mode
//{
//    if (pressedPointLatLon != null) {
//        WptPt pt = new WptPt();
//        double lat = pressedPointLatLon.getLatitude();
//        double lon = pressedPointLatLon.getLongitude();
//        pt.lat = lat;
//        pt.lon = lon;
//        pressedPointLatLon = null;
//        boolean allowed = editingCtx.getPointsCount() == 0 || !editingCtx.getPoints().get(editingCtx.getPointsCount() - 1).equals(pt);
//        if (allowed) {
//            ApplicationMode applicationMode = editingCtx.getAppMode();
//            if (applicationMode != MeasurementEditingContext.DEFAULT_APP_MODE) {
//                pt.setProfileType(applicationMode.getStringKey());
//            }
//            editingCtx.addPoint(pt);
//            moveMapToLatLon(lat, lon);
//            return pt;
//        }
//    }
//    return null;
//}

- (OAGpxTrkPt *) addCenterPoint
{
    const auto center = self.mapViewController.mapView.target31;
    const auto latLon = OsmAnd::Utilities::convert31ToLatLon(center);
    
    OAGpxTrkPt *pt = [[OAGpxTrkPt alloc] init];
    [pt setPosition:CLLocationCoordinate2DMake(latLon.latitude, latLon.longitude)];
    BOOL allowed = _editingCtx.getPointsCount == 0 || ![_editingCtx.getAllPoints containsObject:pt];
    if (allowed) {
        // TODO: add routing profile later
//        OAApplicationMode *applicationMode = _editingCtx.appMode;
//        if (applicationMode != OAApplicationMode.DEFAULT)
//            [pt setProfileType:applicationMode.stringKey];
        [_editingCtx addPoint:pt];
        return pt;
    }
    return nil;
}

- (void)addPointMarkers:(const QVector<OsmAnd::PointI>&)points
{
    for (int i = 0; i < points.size(); i++)
    {
        const auto& point = points[i];
        auto marker = [self drawMarker:point collection:_pointMarkers];
        if (i == _editingCtx.selectedPointPosition && _isInMovingMode)
            _markerToMove = marker;
    }
}

- (QVector<OsmAnd::PointI>) calculatePointsToDraw
{
    QVector<OsmAnd::PointI> points;
    
    OAGpxRtePt *lastBeforePoint = nil;
    NSMutableArray<OAGpxRtePt *> *beforePoints = [NSMutableArray arrayWithArray:_editingCtx.getBeforePoints];
    if (beforePoints.count > 0)
        lastBeforePoint = beforePoints[beforePoints.count - 1];
    OAGpxRtePt *firstAfterPoint = nil;
    NSMutableArray<OAGpxRtePt *> *afterPoints = [NSMutableArray arrayWithArray:_editingCtx.getAfterPoints];
    if (afterPoints.count > 0)
        firstAfterPoint = afterPoints.firstObject;
    
    [beforePoints addObjectsFromArray:afterPoints];

    for (int i = 0; i < beforePoints.count; i++)
    {
        OAGpxRtePt *pt = beforePoints[i];
        points.append(OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(pt.getLatitude, pt.getLongitude)));
        if (i == _editingCtx.selectedPointPosition && _isInMovingMode)
        {
            if (i > 0)
            {
                _prevPosition = points[i - 1];
            }
            if (i < beforePoints.count - 1)
            {
                OAGpxRtePt *nextPt = beforePoints[i + 1];
                const auto pos = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(nextPt.getLatitude, nextPt.getLongitude));
                _nextPosition = pos;
            }
        }
    }
    
    return points;
}

- (void) drawBeforeAfterPath:(QVector<OsmAnd::PointI> &)points
{
    OATrackSegment *before = _editingCtx.getBeforeTrkSegmentLine;
    OATrackSegment *after = _editingCtx.getAfterTrkSegmentLine;
    if (before.points.count > 0 || after.points.count > 0)
    {
        if (before.points.count > 0)
        {
            OAGpxTrkPt *pt = before.points[before.points.count - 1];
            points.push_back(OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(pt.getLatitude, pt.getLongitude)));
        }
        if (after.points.count > 0)
        {
            if (before.points.count == 0)
            {
                points.push_back(self.mapViewController.mapView.target31);
            }
            OAGpxTrkPt *pt = after.points[0];
            points.push_back(OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(pt.getLatitude, pt.getLongitude)));
        }
        
        [self drawRouteSegment:points];
    }
}

- (void) drawRouteSegment:(const QVector<OsmAnd::PointI> &)points {
    [self.mapViewController runWithRenderSync:^{
        [self addPointMarkers:points];
        [self drawLines:points collection:_collection modeAware:YES];
    }];
}

@end
