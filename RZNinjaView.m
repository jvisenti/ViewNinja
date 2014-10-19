//
//  RZNinjaView.m
//  RZViewActionTest
//
//  Created by Rob Visentin on 10/17/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZNinjaView.h"
#import "RZNinjaWindow.h"
#import "RZNinjaMath.h"

static CGFloat const kRZNinjaViewSliceThreshold = 15.0f;

#pragma mark - RZNinjaPane interface

@interface RZNinjaPane : UIView

@property (weak, nonatomic) RZNinjaView *ninjaView;
@property (weak, nonatomic) UIView *slicedSection;

@property (weak, nonatomic) UITouch *trackedTouch;

@property (assign, nonatomic) RZLineSegment *sliceSegment;

@property (weak, nonatomic) CAShapeLayer * maskLayer;
@property (strong, nonatomic) UIBezierPath *currentMask;

- (void)touchOccurred:(UITouch *)touch;

@end

#pragma mark - RZNinjaView private interface

@interface RZNinjaView () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) UIView *rootView;
@property (strong, nonatomic) RZNinjaPane *ninjaPane;

@end

#pragma mark - RZNinjaView implementation

@implementation RZNinjaView

#pragma mark - object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if ( (self = [super initWithFrame:frame]) ) {
        [self _commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ( (self = [super initWithCoder:aDecoder]) ) {
        [self _commonInit];
    }
    return self;
}

- (void)_commonInit
{
    [super setBackgroundColor:[UIColor clearColor]];
    
    [self insertSubview:self.rootView atIndex:0];
    
    // TODO: what about auto layout?
    [[super subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ( obj != self.rootView ) {
            [self.rootView addSubview:obj];
        }
    }];
    
    [super addSubview:self.ninjaPane];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowWillSendTouches:) name:kRZWindowWillSendTouchesNotificaton object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRZWindowWillSendTouchesNotificaton object:nil];
}

#pragma mark - public methods

- (void)addSubview:(UIView *)view
{
    if ( self.rootView.superview == self ) {
        [self.rootView addSubview:view];
    }
    else {
        [super addSubview:view];
    }
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index
{
    if ( self.rootView.superview == self ) {
        [self.rootView insertSubview:view atIndex:index];
    }
    else {
        if ( self.ninjaPane.superview == self ) {
            index = MIN(index, [self.subviews indexOfObject:self.ninjaPane]);
        }
        
        [super insertSubview:view atIndex:index];
    }
}

- (NSArray *)subviews
{
    return self.rootView.subviews;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    self.rootView.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor
{
    return self.rootView.backgroundColor;
}

#pragma mark - private methods

- (UIView *)rootView
{
    if ( _rootView == nil ) {
        _rootView = [[UIView alloc] initWithFrame:self.bounds];
        _rootView.backgroundColor = [UIColor clearColor];
        _rootView.opaque = NO;
        _rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_rootView setTranslatesAutoresizingMaskIntoConstraints:YES];
    }
    return _rootView;
}

- (RZNinjaPane *)ninjaPane
{
    if ( _ninjaPane == nil ) {
        _ninjaPane = [[RZNinjaPane alloc] initWithFrame:self.bounds];
        _ninjaPane.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_ninjaPane setTranslatesAutoresizingMaskIntoConstraints:YES];
        _ninjaPane.ninjaView = self;
    }
    return _ninjaPane;
}

- (void)_windowWillSendTouches:(NSNotification *)notification
{
    NSArray *touches = notification.userInfo[kRZWindowTouchesKey];
    
    [touches enumerateObjectsUsingBlock:^(UITouch *touch, NSUInteger idx, BOOL *stop) {
        [self.ninjaPane touchOccurred:touch];
    }];
}

@end

#pragma mark - RZNinjaPane implementation

@implementation RZNinjaPane

- (BOOL)isMultipleTouchEnabled
{
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    return nil;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ( (self = [super initWithFrame:frame]) ) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
        self.sliceSegment = malloc(sizeof(RZLineSegment));
        self.sliceSegment->p0 = kRZNotAPoint;
        self.sliceSegment->p1 = kRZNotAPoint;
    }
    return self;
}

- (void)dealloc
{
    free(self.sliceSegment);
}

- (void)setNinjaView:(RZNinjaView *)ninjaView
{
    _ninjaView = ninjaView;

    self.currentMask = [UIBezierPath bezierPathWithRect:ninjaView.bounds];
}

- (void)touchOccurred:(UITouch *)touch
{
    if ( self.slicedSection != nil ) {
        return;
    }
    
    BOOL inside = [self pointInside:[touch locationInView:self] withEvent:nil];
    
    if ( touch == self.trackedTouch && !inside ) {
        [self _touchEnded:touch];
    }
    else if ( inside ) {
        if ( touch.phase == UITouchPhaseMoved ) {
            [self _touchMoved:touch];
        }
        else if ( touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded ) {
            [self _touchEnded:touch];
        }
    }
}

void MyCGPathApplierFunc (void *info, const CGPathElement *element) {
    NSMutableArray *bezierPoints = (__bridge NSMutableArray *)info;
    
    CGPoint *points = element->points;
    CGPathElementType type = element->type;
    
    switch(type) {
        case kCGPathElementMoveToPoint: // contains 1 point
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            break;
            
        case kCGPathElementAddLineToPoint: // contains 1 point
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            break;
            
        case kCGPathElementAddQuadCurveToPoint: // contains 2 points
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[1]]];
            break;
            
        case kCGPathElementAddCurveToPoint: // contains 3 points
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[1]]];
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[2]]];
            break;
            
        case kCGPathElementCloseSubpath: // contains no point
            break;
    }
}

#pragma mark - private methods

- (void)_touchMoved:(UITouch *)touch
{
    CGPoint touchLoc = [touch locationInView:self];
    
    if ( self.trackedTouch == nil ) {
        CGPoint oldLoc = [touch previousLocationInView:self];
        
        CGFloat speed = MAX(fabsf(touchLoc.x - oldLoc.x), fabsf(touchLoc.y - oldLoc.y));
        
        if ( speed > kRZNinjaViewSliceThreshold ) {
            self.trackedTouch = touch;
            
            self.sliceSegment->p0 = oldLoc;
            self.sliceSegment->p1 = touchLoc;

            RZLineSegmentSnapToPolygon(self.sliceSegment, self.currentMask.CGPath, false);
        }
    }
    else if ( touch == self.trackedTouch ) {
        self.sliceSegment->p1 = RZLineProjectPoint(RZLineFromLineSegment(*self.sliceSegment), touchLoc);
        [self setNeedsDisplay];
    }
}

- (void)_touchEnded:(UITouch *)touch
{
    if ( touch == self.trackedTouch ) {
        RZLineSegmentSnapToPolygon(self.sliceSegment, self.currentMask.CGPath, true);
        
        [self _commitSlice];
        
        self.trackedTouch = nil;
        self.sliceSegment->p0 = kRZNotAPoint;
        self.sliceSegment->p1 = kRZNotAPoint;
        
        [self setNeedsDisplay];
    }
}

- (void)_commitSlice
{
//
//    // This is an example of how to use _closeWisePathFromPoint insidePath
//    // It requires debuggin. OBVIOYSLY!
//    
////    CGPoint minPoint = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMinY(self.bounds));
////    CGPoint maxPoint = CGPointMake(CGRectGetMaxX(self.bounds), CGRectGetMaxY(self.bounds));
////
////    UIBezierPath *yourPath = [[UIBezierPath alloc]init]; // Assume this has some points in it
////    [yourPath moveToPoint:CGPointMake(minPoint.x, minPoint.y)];
////    [yourPath addLineToPoint:CGPointMake(maxPoint.x, minPoint.y)];
////    [yourPath addLineToPoint:CGPointMake(maxPoint.x, maxPoint.y)];
////    [yourPath addLineToPoint:CGPointMake(minPoint.x, maxPoint.y)];
////    [yourPath addLineToPoint:CGPointMake(minPoint.x, minPoint.y)];
//    
//    self.ninjaView.rootView.layer.mask = nil;
//    
////    UIBezierPath *path1 = [self _clockWisePathFromPoint:self.startPoint toPoint:self.endPoint insidePath:yourPath];
////    UIBezierPath *path2 = [self _clockWisePathFromPoint:self.endPoint toPoint:self.startPoint insidePath:yourPath];
//    
//    UIBezierPath *path1 = [self _clockWisePathFromPoint:self.startPoint toPoint:self.endPoint insidePath:self.currentMask];
//    UIBezierPath *path2 = [self _clockWisePathFromPoint:self.endPoint toPoint:self.startPoint insidePath:self.currentMask];
//    
//    CGRect bounding1 = [path1 bounds];
//    CGRect bounding2 = [path2 bounds];
//    
//    CGFloat area1 = bounding1.size.width * bounding1.size.height;
//    CGFloat area2 = bounding2.size.width * bounding2.size.height;
//    
//    UIBezierPath *slicedPath = (area1 > area2) ? path2 : path1;
//    UIBezierPath *keepPath = (area1 > area2) ? path1 : path2;
//    
//    if (!keepPath) {
//        return;
//    }
//    
//    CAShapeLayer *maskLayer = [CAShapeLayer layer];
//    maskLayer.frame = self.ninjaView.bounds;
//    maskLayer.path = keepPath.CGPath;
//    
//    [self _configureSlicedSectionWithPath:slicedPath];
//    
//    self.ninjaView.rootView.layer.mask = maskLayer;
//    
//    self.currentMask = keepPath;
}

-(UIBezierPath *) _clockWisePathFromPoint:(CGPoint) firstPoint toPoint:(CGPoint) lastPoint insidePath:(UIBezierPath*) path{
//
//    CGPathRef yourCGPath = path.CGPath;
//    NSMutableArray *bezierPoints = [NSMutableArray array];
//    CGPathApply(yourCGPath, (__bridge void *)(bezierPoints), MyCGPathApplierFunc);
//    self.ninjaView.rootView.layer.mask = nil;
//    
//    NSInteger pathLength = bezierPoints.count;
//    NSInteger currentPath = -1;
//    NSInteger lastPointPath = -1;
//    NSInteger overflowCounter = pathLength;
//    
//    for (NSInteger i = 0 ; i < pathLength; i++) {
//        
//        NSInteger nextIndex = (i == bezierPoints.count - 1)? 0: i + 1;
//        CGPoint nextPoint = ((NSValue *)bezierPoints[nextIndex]).CGPointValue;
//        CGPoint currPoint = ((NSValue *)bezierPoints[i]).CGPointValue;
//        NSLog(@"%@", NSStringFromCGPoint(nextPoint));
//        NSLog(@"%@", NSStringFromCGPoint(currPoint));
//        if ([self _pointOnSegmentFromPoint:currPoint toPoint:nextPoint withPoint:firstPoint]) {
//            currentPath = nextIndex;
//        }
//        if ([self _pointOnSegmentFromPoint:currPoint toPoint:nextPoint withPoint:lastPoint]) {
//            lastPointPath = i;
//        }
//        if (currentPath != -1 && lastPointPath != -1) {
//            break;
//        }
//    }
//    
//    if (currentPath == -1) {
//        [NSException raise:@"Point and path not match" format:@"Start point not found inside path"];
//    }
//    
//    UIBezierPath *maskPath = [UIBezierPath bezierPath];
//    [maskPath moveToPoint:firstPoint];
//    
//    while (true) {
//        if (currentPath == lastPointPath) {
//            [maskPath addLineToPoint: lastPoint];
//            break;
//        } else {
//            [maskPath addLineToPoint:((NSValue *)bezierPoints[currentPath]).CGPointValue];
//        }
//        if (currentPath == pathLength - 1) {
//            currentPath = 0;
//        } else
//            currentPath++;
//        overflowCounter --;
//        if (overflowCounter < -1) {
//            NSLog(@"OVREFLOWWWING");
//            break;
//        }
//    }
//    return maskPath;
    
    return nil;

}

-(UIBezierPath *) _clockWisePathFromPoint:(CGPoint) firstPoint toPoint:(CGPoint) lastPoint {
//    
//    if (CGPointEqualToPoint(self.startPoint, self.endPoint)) {
//        return nil;
//    }
//    UIBezierPath *maskPath = [UIBezierPath bezierPath];
//    
//    CGPoint minPoint = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMinY(self.bounds));
//    CGPoint maxPoint = CGPointMake(CGRectGetMaxX(self.bounds), CGRectGetMaxY(self.bounds));
//    
//    [maskPath moveToPoint:firstPoint];
//    int overflowCounter = 0;
//    
//    while (!CGPointEqualToPoint(firstPoint, lastPoint)) {
//        NSLog(@"Current Point: %@", NSStringFromCGPoint(firstPoint));
//        if (round(firstPoint.x) == maxPoint.x && (round(firstPoint.y) != maxPoint.y)) {
//            if (round(lastPoint.x) != round(firstPoint.x)){
//                [maskPath addLineToPoint: maxPoint];
//                firstPoint = maxPoint;
//            }
//            else {
//                [maskPath addLineToPoint:lastPoint];
//                break;
//            }
//        } else if (round(firstPoint.y) == maxPoint.y && round(firstPoint.x) != minPoint.x){
//            if (round(lastPoint.y) != round(firstPoint.y)) {
//                [maskPath addLineToPoint:CGPointMake(minPoint.x, maxPoint.y)];
//                firstPoint = CGPointMake(minPoint.x, maxPoint.y);
//            } else {
//                [maskPath addLineToPoint:lastPoint];
//                break;
//            }
//        } else if (round(firstPoint.x) == minPoint.x && ( round(firstPoint.y) != minPoint.y)){
//            if (round(lastPoint.x) != round(firstPoint.x)) {
//                [maskPath addLineToPoint:minPoint];
//                firstPoint = minPoint;
//            } else {
//                [maskPath addLineToPoint:lastPoint];
//                break;
//            }
//        } else {
//            if (round(lastPoint.y) != round(firstPoint.y)) {
//                [maskPath addLineToPoint:CGPointMake(maxPoint.x, minPoint.y)];
//                firstPoint = CGPointMake(maxPoint.x, minPoint.y);
//            } else {
//                [maskPath addLineToPoint:lastPoint];
//                break;
//            }
//        }
//        overflowCounter ++;
//        if (overflowCounter > 5){
//            NSLog(@"OVERFLOWING!");
//            break;
//        }
//    }
//    [maskPath closePath];
//    return maskPath;
    
    return nil;
}

- (void)_configureSlicedSectionWithPath:(UIBezierPath *)path
{
    [self.slicedSection removeFromSuperview];
    
    UIView *view = self.ninjaView.rootView;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0f);
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();

    UIImageView *slicedSection = [[UIImageView alloc] initWithImage:snapshot];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = slicedSection.bounds;
    maskLayer.path = path.CGPath;
    
    slicedSection.layer.mask = maskLayer;
    
    [self addSubview:slicedSection];
    self.slicedSection = slicedSection;
    
    CGRect sliceBounds = [path bounds];
    CGFloat midX = CGRectGetMidX(sliceBounds);
    CGFloat midY = CGRectGetMidY(sliceBounds);
    
    CGVector vec = RZVectorNormalize(CGVectorMake(midX - CGRectGetMidX(self.bounds), midY - CGRectGetMidY(self.bounds)));
    
    CGPoint target = CGPointMake(CGRectGetWidth(sliceBounds) * vec.dx, CGRectGetHeight(sliceBounds) * vec.dy);
    
    [UIView animateWithDuration:1.5f animations:^{
        CGRect slicedFrame = self.slicedSection.frame;
        slicedFrame.origin = target;
        self.slicedSection.frame = slicedFrame;
    }];
    
    [UIView animateWithDuration:1.0f delay:0.5f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.slicedSection.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self.slicedSection removeFromSuperview];
    }];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // TODO: something more interesting here
    
    if ( !CGPointEqualToPoint(self.sliceSegment->p0, self.sliceSegment->p1) ) {
        [[UIColor redColor] setStroke];
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, self.sliceSegment->p0.x, self.sliceSegment->p0.y);
        CGContextAddLineToPoint(context, self.sliceSegment->p1.x, self.sliceSegment->p1.y);
        CGContextStrokePath(context);
    }
}

@end

