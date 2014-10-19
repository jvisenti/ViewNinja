//
//  RZNinjaMath.c
//  RZViewActionTest
//
//  Created by Rob Visentin on 10/17/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#include "RZNinjaMath.h"
#include <stdlib.h>
#include <math.h>

CGPoint const kRZNotAPoint = {HUGE_VALF, HUGE_VALF};

// private function prototypes
void RZCGPathApplierFunction (void *info, const CGPathElement *element);
CFDataRef RZDataCreateWithPoint(CGPoint point);
CGPoint RZDataCGPointValue(CFDataRef data);

#pragma mark - RZLine functions

RZLine RZLineFromLineSegment(RZLineSegment segment)
{
    return (RZLine){.p0 = segment.p0, .v = RZLineSegmentDirection(segment)};
}

CGPoint RZLineProjectPoint(RZLine line, CGPoint point)
{
    if ( CGPointEqualToPoint(line.p0, point) ) {
        return point;
    }
    else {
        CGVector dir = (CGVector){.dx = point.x - line.p0.x, .dy = point.y - line.p0.y};
        CGFloat scalar = RZVectorDot(dir, line.v) / RZVectorDot(line.v, line.v);
        
        return RZVectorTranslate(RZVectorMultiplyScalar(line.v, scalar), line.p0);
    }
}

bool RZLineContainsPoint(RZLine line, CGPoint point)
{
    CGVector v = CGVectorMake(point.x - line.p0.x, point.y - line.p0.y);
    
    CGVector n1 = RZVectorNormalize(line.v);
    CGVector n2 = RZVectorNormalize(v);
    
    return (fabsf(RZVectorDot(n1, n2)) == 1);
}

CGPoint RZLineIntersection(RZLine l1, RZLine l2, CGFloat *t, CGFloat *s)
{
    CGVector n1 = RZVectorNormalize(l1.v);
    CGVector n2 = RZVectorNormalize(l2.v);
    
    CGFloat tRet, sRet;
    CGPoint intersection;
    
    // NOTE: doesn't handle case when lines are equal (i.e. all points are intersection points)
    if ( fabsf(RZVectorDot(n1, n2)) == 1.0f ) {
        tRet = HUGE_VALF;
        sRet = HUGE_VALF;
        intersection = kRZNotAPoint;
    }
    else {
        CGVector w = CGVectorMake(l1.p0.x - l2.p0.x, l1.p0.y - l2.p0.y);
        
        tRet = ((l2.v.dy * w.dx) - (l2.v.dx * w.dy)) / ((l2.v.dx * l1.v.dy) - (l2.v.dy * l1.v.dx));
        sRet = ((l1.v.dx * w.dy) - (l1.v.dy * w.dx)) / ((l1.v.dx * l2.v.dy) - (l1.v.dy * l2.v.dx));
        
        intersection = CGPointMake(l1.p0.x + tRet * l1.v.dx, l1.p0.y + tRet * l1.v.dy);
    }
    
    if ( t != NULL ) {
        *t = tRet;
    }
    
    if ( s != NULL ) {
        *s = sRet;
    }
    
    return intersection;
}

CGPoint RZLineIntersectionWithSegment(RZLine line, RZLineSegment seg, CGFloat *t, CGFloat *s)
{
    CGPoint intersection;
    CGFloat tRet, sRet;
    
    if ( CGPointEqualToPoint(seg.p0, seg.p1) ) {
        if ( RZLineContainsPoint(line, seg.p0) ) {
            if ( line.v.dx != 0.0f ) {
                tRet = (seg.p0.x - line.p0.x) / line.v.dx;
            }
            else if ( line.v.dy != 0.0f ) {
                tRet = (seg.p0.y - line.p0.y) / line.v.dy;
            }
            else {
                tRet = 0.0f;
            }
            
            sRet = 0.0f;
            intersection = seg.p0;
        }
        else {
            tRet = HUGE_VALF;
            sRet = HUGE_VALF;
            intersection = kRZNotAPoint;
        }
    }
    else {
        RZLine segLine = RZLineFromLineSegment(seg);
        
        intersection = RZLineIntersection(line, segLine, &tRet, &sRet);
        
        // intersection occurs outside the segment
        if ( sRet < 0.0f || sRet > 1.0f ) {
            tRet = HUGE_VALF;
            sRet = HUGE_VALF;
            intersection = kRZNotAPoint;
        }
    }
    
    if ( t != NULL ) {
        *t = tRet;
    }
    
    if ( s != NULL ) {
        *s = sRet;
    }
    
    return intersection;
}

#pragma mark - RZLineSegment functions

CGFloat RZLineSegmentLength(RZLineSegment segment)
{
    return RZVectorMagnitude(RZLineSegmentDirection(segment));
}
    
CGVector RZLineSegmentDirection(RZLineSegment segment)
{
    return (CGVector){.dx = segment.p1.x - segment.p0.x, .dy = segment.p1.y - segment.p0.y};
}

void RZLineSegmentSnapToPolygon(RZLineSegment *segment, CGPathRef path, bool snapEnd)
{
    if ( segment == NULL || path == NULL ) {
        return;
    }
    
    RZLine line = RZLineFromLineSegment(*segment);
    
    // not using RZPathGetPoints to avoid an unnecessary loop over the points
    CFMutableArrayRef pathPoints = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    CGPathApply(path, pathPoints, RZCGPathApplierFunction);
    CFIndex numPoints = CFArrayGetCount(pathPoints);
    
    CGPoint p0Int, p1Int;
    
    for (CFIndex i = 0; i < numPoints; i++) {
        CGPoint s0 = RZDataCGPointValue((CFDataRef)CFArrayGetValueAtIndex(pathPoints, i));
        CGPoint s1 = RZDataCGPointValue((CFDataRef)CFArrayGetValueAtIndex(pathPoints, (i+1) % numPoints));
        
        RZLineSegment seg = (RZLineSegment){.p0 = s0, .p1 = s1};
        
        CGFloat t;
        CGPoint intersection = RZLineIntersectionWithSegment(line, seg, &t, NULL);
        
        if ( t != HUGE_VALF ) {
            if ( t <= 0.0f ) {
                p0Int = intersection;
            }
            else {
                p1Int = intersection;
            }
        }
    }
    
    CFRelease(pathPoints);
    
    segment->p0 = p0Int;
    
    if ( snapEnd ) {
        segment->p1 = p1Int;
    }
}

#pragma mark - CGVector functions

CGFloat RZVectorMagnitude(CGVector v)
{
    return sqrtf(v.dx * v.dx + v.dy * v.dy);
}

CGVector RZVectorNormalize(CGVector v)
{
    CGFloat magnitude = RZVectorMagnitude(v);
    return (magnitude > 0.0f) ? (CGVector){.dx = v.dx / magnitude, .dy = v.dy / magnitude} : v;
}

CGVector RZVectorAdd(CGVector v1, CGVector v2)
{
    return (CGVector){.dx = v1.dx + v2.dx, .dy = v1.dy + v2.dy};
}

CGVector RZVectorSubtract(CGVector v1, CGVector v2)
{
    return (CGVector){.dx = v1.dx - v2.dx, .dy = v1.dy - v2.dy};
}

CGVector RZVectorMultiplyScalar(CGVector v, CGFloat s)
{
    return (CGVector){.dx = v.dx * s, .dy = v.dy * s};
}

CGFloat RZVectorDot(CGVector v1, CGVector v2)
{
    return (v1.dx * v2.dx) + (v1.dy * v2.dy);
}

CGPoint RZVectorTranslate(CGVector v, CGPoint p)
{
    return (CGPoint){.x = p.x + v.dx, .y = p.y + v.dy};
}

#pragma mark - CGPathRef functions

CGPoint* RZPathGetPoints(CGPathRef path, CFIndex *n)
{
    CGPoint *points = NULL;
    
    CFMutableArrayRef pathPoints = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    CGPathApply(path, pathPoints, RZCGPathApplierFunction);
    CFIndex numPoints = CFArrayGetCount(pathPoints);
    
    if ( numPoints > 0 ) {
        points = (CGPoint *)malloc(numPoints * sizeof(CGPoint));
        
        for (CFIndex i = 0; i < numPoints; i++) {
            points[i] = RZDataCGPointValue((CFDataRef)CFArrayGetValueAtIndex(pathPoints, i));
        }
    }

    if ( n != NULL ) {
        *n = numPoints;
    }
    
    return points;
}

#pragma mark - private CGPath functions

void RZCGPathApplierFunction (void *info, const CGPathElement *element) {
    CFMutableArrayRef pathPoints = (CFMutableArrayRef)info;
    
    CGPoint *points = element->points;
    CGPathElementType type = element->type;
    
    CFIndex addedPoints = 0;
    
    switch( type ) {
        case kCGPathElementMoveToPoint:
        case kCGPathElementAddLineToPoint:
            addedPoints = 1;
            break;
            
        case kCGPathElementAddQuadCurveToPoint:
            addedPoints = 2;
            break;
            
        case kCGPathElementAddCurveToPoint:
            addedPoints = 3;
            break;
            
        case kCGPathElementCloseSubpath:
            break;
    }
    
    for (CFIndex i = 0; i < addedPoints; i++) {
        CFDataRef pointData = RZDataCreateWithPoint(points[i]);
        CFArrayAppendValue(pathPoints, pointData);
        CFRelease(pointData);
    }
}

CFDataRef RZDataCreateWithPoint(CGPoint point)
{
    CFMutableDataRef data = CFDataCreateMutable(NULL, sizeof(CGPoint));
    CFDataAppendBytes(data, (UInt8 *)&point, sizeof(CGPoint));
    
    return data;
}

CGPoint RZDataCGPointValue(CFDataRef data)
{
    return *(CGPoint *)CFDataGetBytePtr(data);
}
