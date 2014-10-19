//
//  RZNinjaMath.h
//  RZViewActionTest
//
//  Created by Rob Visentin on 10/17/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#ifndef __RZViewActionTest__RZNinjaMath__
#define __RZViewActionTest__RZNinjaMath__

#include <CoreGraphics/CoreGraphics.h>

typedef struct _RZLine {
    CGPoint p0;
    CGVector v;
} RZLine;

typedef struct _RZLineSegment {
    CGPoint p0, p1;
} RZLineSegment;

CG_EXTERN CGPoint const kRZNotAPoint;

#pragma mark - RZLine functions

CG_EXTERN RZLine RZLineFromLineSegment(RZLineSegment segment);
CG_EXTERN CGPoint RZLineProjectPoint(RZLine line, CGPoint point);
CG_EXTERN bool RZLineContainsPoint(RZLine line, CGPoint point);
CG_EXTERN CGPoint RZLineIntersection(RZLine l1, RZLine l2, CGFloat *t, CGFloat *s);
CG_EXTERN CGPoint RZLineIntersectionWithSegment(RZLine line, RZLineSegment seg, CGFloat *t, CGFloat *s);

#pragma mark - RZLineSegment functions

CG_EXTERN CGFloat RZLineSegmentLength(RZLineSegment segment);
CG_EXTERN CGVector RZLineSegmentDirection(RZLineSegment segment);

/** @note path must be a convex polygon. */
CG_EXTERN void RZLineSegmentSnapToPolygon(RZLineSegment *segment, CGPathRef path, bool snapEnd);

#pragma mark - CGVector functions

CG_EXTERN CGFloat RZVectorMagnitude(CGVector v);
CG_EXTERN CGVector RZVectorNormalize(CGVector v);
CG_EXTERN CGVector RZVectorAdd(CGVector v1, CGVector v2);
CG_EXTERN CGVector RZVectorSubtract(CGVector v1, CGVector v2);
CG_EXTERN CGVector RZVectorMultiplyScalar(CGVector v, CGFloat s);
CG_EXTERN CGFloat RZVectorDot(CGVector v1, CGVector v2);
CG_EXTERN CGPoint RZVectorTranslate(CGVector v, CGPoint p);

#pragma mark - CGPathRef functions

/** @note caller is responsible for freeing the points array. */
CG_EXTERN CGPoint* RZPathGetPoints(CGPathRef path, CFIndex *n);

#endif /* defined(__RZViewActionTest__RZNinjaMath__) */
