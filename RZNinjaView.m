//
//  RZNinjaView.m
//  RZViewActionTest
//
//  Created by Rob Visentin on 10/17/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZNinjaView.h"
#import "RZNinjaWindow.h"

typedef struct _RZNinjaLine {
    CGPoint p0;
    CGVector v;
} RZNinjaLine;

static CGFloat const kRZNinjaViewSliceThreshold = 15.0f;

#pragma mark - RZNinjaPane interface

@interface RZNinjaPane : UIView

@property (weak, nonatomic) RZNinjaView *ninjaView;
@property (weak, nonatomic) UIView *slicedSection;

@property (weak, nonatomic) UITouch *trackedTouch;

@property (assign, nonatomic) CGPoint startPoint;
@property (assign, nonatomic) CGPoint endPoint;

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
    UIView *hitView = nil;
    
    if ( [self.slicedSection pointInside:point withEvent:event] ) {
        hitView = self.slicedSection;
    }
    
    return hitView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ( (self = [super initWithFrame:frame]) ) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
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
            
            self.startPoint = [self _boundsIntersectionOfLineFromPoint:oldLoc toPoint:touchLoc];
            self.endPoint = touchLoc;
        }
    }
    else if ( touch == self.trackedTouch ) {
        [self _updateEndpointWithPoint:touchLoc];
        [self setNeedsDisplay];
    }
}

- (void)_touchEnded:(UITouch *)touch
{
    if ( touch == self.trackedTouch ) {
        self.endPoint = [self _boundsIntersectionOfLineFromPoint:self.endPoint toPoint:self.startPoint];
        [self _commitSlice];
        
        self.trackedTouch = nil;
        self.startPoint = CGPointZero;
        self.endPoint = CGPointZero;
        
        [self setNeedsDisplay];
    }
}

// TODO: move to math header file

- (void)_updateEndpointWithPoint:(CGPoint)point
{
    if ( CGPointEqualToPoint(point, self.startPoint) ) {
        self.endPoint = self.startPoint;
    }
    else {
        CGVector curVec = CGVectorMake(self.endPoint.x - self.startPoint.x, self.endPoint.y - self.startPoint.y);
        CGVector newVec = CGVectorMake(point.x - self.startPoint.x, point.y - self.startPoint.y);
        
        CGFloat scalar = (newVec.dx * curVec.dx + newVec.dy * curVec.dy) / (curVec.dx * curVec.dx + curVec.dy * curVec.dy);
        
        self.endPoint = CGPointMake(self.startPoint.x + scalar * curVec.dx, self.startPoint.y + scalar * curVec.dy);
    }
}

- (CGPoint)_boundsIntersectionOfLineFromPoint:(CGPoint)p1 toPoint:(CGPoint)p2
{
    CGVector vec = CGVectorMake(p2.x - p1.x, p2.y - p1.y);
    
    RZNinjaLine sliceLine = {.p0 = p1, .v = vec};
    
    CGFloat maxX = CGRectGetMaxX(self.bounds);
    CGFloat maxY = CGRectGetMaxY(self.bounds);
    
    NSMutableArray *bezierPoints = [NSMutableArray array];
    CGPathApply(self.currentMask.CGPath, (__bridge void *)(bezierPoints), MyCGPathApplierFunc);
    
    NSMutableDictionary *intersectionDistances = [NSMutableDictionary dictionary];
    
    for (NSUInteger i = 0; i < [bezierPoints count]; i++) {
        CGPoint s0 = [bezierPoints[i] CGPointValue];
        CGPoint s1 = [bezierPoints[(i+1) % [bezierPoints count]] CGPointValue];
        
        CGPoint intersection = [self _intersectionOfLine:sliceLine withSegmentFromPoint:s0 toPoint:s1];
        
        if ( intersection.x != HUGE_VALF && intersection.y != HUGE_VALF ) {
            CGFloat dist = [self _lengthOfSegmentFromPoint:p1 toPoint:intersection];
            [intersectionDistances setObject:[NSValue valueWithCGPoint:intersection] forKey:@(dist)];
        }
    }
    
    NSArray *sortedKeys = [[intersectionDistances allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    return [[intersectionDistances objectForKey:[sortedKeys firstObject]] CGPointValue];
    
    //bounds lines
    RZNinjaLine leftEdge = {.p0 = CGPointZero, .v = {.dx = 0.0f, .dy = 1.0f}};
    RZNinjaLine rightEdge = {.p0 = {.x = maxX, .y = 0.0f}, .v = {.dx = 0.0f, .dy = 1.0f}};
    RZNinjaLine topEdge = {.p0 = CGPointZero, .v = {.dx = 1.0f, .dy = 0.0f}};
    RZNinjaLine bottomEdge = {.p0 = {.x = 0.0f, .y = maxY}, .v = {.dx = 1.0f, .dy = 0.0f}};
    
    
    CGPoint leftInt = [self _intersectionOfLine:sliceLine withLine:leftEdge];
    CGPoint rightInt = [self _intersectionOfLine:sliceLine withLine:rightEdge];
    CGPoint topInt = [self _intersectionOfLine:sliceLine withLine:topEdge];
    CGPoint bottomInt = [self _intersectionOfLine:sliceLine withLine:bottomEdge];
    
    CGFloat minLen = HUGE_VALF;
    
    CGFloat leftDist = [self _lengthOfSegmentFromPoint:p1 toPoint:leftInt];
    CGFloat rightDist = [self _lengthOfSegmentFromPoint:p1 toPoint:rightInt];
    CGFloat topDist = [self _lengthOfSegmentFromPoint:p1 toPoint:topInt];
    CGFloat bottomDist = [self _lengthOfSegmentFromPoint:p1 toPoint:bottomInt];
    
    minLen = MIN(minLen, leftDist);
    minLen = MIN(minLen, rightDist);
    minLen = MIN(minLen, topDist);
    minLen = MIN(minLen, bottomDist);
    
    if ( minLen == leftDist ) {
        return leftInt;
    }
    else if ( minLen == rightDist ) {
        return rightInt;
    }
    else if ( minLen == topDist ) {
        return topInt;
    }
    else {
        return bottomInt;
    }
}

- (CGPoint)_intersectionOfLine:(RZNinjaLine)l1 withLine:(RZNinjaLine)l2
{
    CGVector norm1 = [self _vectorNormalize:l1.v];
    CGVector norm2 = [self _vectorNormalize:l2.v];
    
    if ( fabsf(norm1.dx * norm2.dx + norm1.dy * norm2.dy) == 1.0f ) {
        // parallel lines won't ever intersect
        return CGPointMake(HUGE_VALF, HUGE_VALF);
    }
    
    CGVector w = CGVectorMake(l1.p0.x - l2.p0.x, l1.p0.y - l2.p0.y);
    CGFloat t = ((l2.v.dy * w.dx) - (l2.v.dx * w.dy)) / ((l2.v.dx * l1.v.dy) - (l2.v.dy * l1.v.dx));
    
    return CGPointMake(l1.p0.x + t * l1.v.dx, l1.p0.y + t * l1.v.dy);
}

- (CGPoint) _intersectionOfLine:(RZNinjaLine) l1 withSegmentFromPoint: (CGPoint) p1 toPoint: (CGPoint) p2{
    
    RZNinjaLine lineFromSegment = {.p0 = p1, .v = CGVectorMake(p2.x - p1.x, p2.y - p1.y)};
    
    CGPoint intersection = [self _intersectionOfLine:l1 withLine:lineFromSegment];
    
    CGPoint p = CGPointMake(intersection.x - p1.x, intersection.y - p1.y);
    CGFloat t = (p.x + p.y) / (lineFromSegment.v.dx + lineFromSegment.v.dy);
    
    if (t >= 0 && t <= 1) {
        return intersection;
    }
    return CGPointMake(HUGE_VALF, HUGE_VALF);
}

- (CGFloat)_lengthOfSegmentFromPoint:(CGPoint)p1 toPoint:(CGPoint)p2
{
    CGVector v = CGVectorMake(p2.x - p1.x, p2.y - p1.y);
    return [self _magnitude:v];
}

- (CGFloat)_magnitude:(CGVector)v
{
    return sqrtf(v.dx * v.dx + v.dy * v.dy);
}

- (CGVector)_vectorNormalize:(CGVector)v
{
    if ( v.dx == 0.0f && v.dy == 0.0f ) {
        return v;
    }
    
    CGFloat magnitude = [self _magnitude:v];
    return CGVectorMake(v.dx / magnitude, v.dy / magnitude);
}

-(BOOL) _pointOnSegmentFromPoint:(CGPoint) p1 toPoint:(CGPoint)p2 withPoint:(CGPoint) testPoint{
    CGVector v = CGVectorMake(p2.x - p1.x, p2.y - p1.y);
    CGVector vTest = CGVectorMake(testPoint.x - p1.x, testPoint.y - p1.y);
    CGVector normalV = [self _vectorNormalize:v];
    CGVector normalVtest = [self _vectorNormalize:vTest];
    
    CGFloat dotProduct = normalV.dx * normalVtest.dx + normalV.dy * normalVtest.dy;
    return dotProduct == 1;
}

// --- end TODO

- (void)_commitSlice
{

    // This is an example of how to use _closeWisePathFromPoint insidePath
    // It requires debuggin. OBVIOYSLY!
    
//    CGPoint minPoint = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMinY(self.bounds));
//    CGPoint maxPoint = CGPointMake(CGRectGetMaxX(self.bounds), CGRectGetMaxY(self.bounds));
//
//    UIBezierPath *yourPath = [[UIBezierPath alloc]init]; // Assume this has some points in it
//    [yourPath moveToPoint:CGPointMake(minPoint.x, minPoint.y)];
//    [yourPath addLineToPoint:CGPointMake(maxPoint.x, minPoint.y)];
//    [yourPath addLineToPoint:CGPointMake(maxPoint.x, maxPoint.y)];
//    [yourPath addLineToPoint:CGPointMake(minPoint.x, maxPoint.y)];
//    [yourPath addLineToPoint:CGPointMake(minPoint.x, minPoint.y)];
    
    self.ninjaView.rootView.layer.mask = nil;
    
//    UIBezierPath *path1 = [self _clockWisePathFromPoint:self.startPoint toPoint:self.endPoint insidePath:yourPath];
//    UIBezierPath *path2 = [self _clockWisePathFromPoint:self.endPoint toPoint:self.startPoint insidePath:yourPath];
    
    UIBezierPath *path1 = [self _clockWisePathFromPoint:self.startPoint toPoint:self.endPoint];
    UIBezierPath *path2 = [self _clockWisePathFromPoint:self.endPoint toPoint:self.startPoint];
    
    CGRect bounding1 = [path1 bounds];
    CGRect bounding2 = [path2 bounds];
    
    CGFloat area1 = bounding1.size.width * bounding1.size.height;
    CGFloat area2 = bounding2.size.width * bounding2.size.height;
    
    UIBezierPath *slicedPath = (area1 > area2) ? path2 : path1;
    UIBezierPath *keepPath = (area1 > area2) ? path1 : path2;
    
    if (!keepPath) {
        return;
    }
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.ninjaView.bounds;
    maskLayer.path = keepPath.CGPath;
    
    [self _configureSlicedSectionWithPath:slicedPath];
    
    self.ninjaView.rootView.layer.mask = maskLayer;
    
    self.currentMask = keepPath;
}
-(UIBezierPath *) _clockWisePathFromPoint:(CGPoint) firstPoint toPoint:(CGPoint) lastPoint insidePath:(UIBezierPath*) path{

    CGPathRef yourCGPath = path.CGPath;
    NSMutableArray *bezierPoints = [NSMutableArray array];
    CGPathApply(yourCGPath, (__bridge void *)(bezierPoints), MyCGPathApplierFunc);
    self.ninjaView.rootView.layer.mask = nil;
    
    NSInteger pathLength = bezierPoints.count;
    NSInteger currentPath = -1;
    NSInteger lastPointPath = -1;
    NSInteger overflowCounter = pathLength;
    
    for (NSInteger i = 0 ; i < pathLength; i++) {
        
        NSInteger nextIndex = (i == bezierPoints.count - 1)? 0: i + 1;
        CGPoint nextPoint = ((NSValue *)bezierPoints[nextIndex]).CGPointValue;
        CGPoint currPoint = ((NSValue *)bezierPoints[i]).CGPointValue;
        NSLog(@"%@", NSStringFromCGPoint(nextPoint));
        NSLog(@"%@", NSStringFromCGPoint(currPoint));
        if ([self _pointOnSegmentFromPoint:currPoint toPoint:nextPoint withPoint:firstPoint]) {
            currentPath = nextIndex;
        }
        if ([self _pointOnSegmentFromPoint:currPoint toPoint:nextPoint withPoint:lastPoint]) {
            lastPointPath = i;
        }
        if (currentPath != -1 && lastPointPath != -1) {
            break;
        }
    }
    
    if (currentPath == -1) {
        [NSException raise:@"Point and path not match" format:@"Start point not found inside path"];
    }
    
    UIBezierPath *maskPath = [UIBezierPath bezierPath];
    [maskPath moveToPoint:firstPoint];
    
    while (true) {
        if (currentPath == lastPointPath) {
            [maskPath addLineToPoint: lastPoint];
            break;
        } else {
            [maskPath addLineToPoint:((NSValue *)bezierPoints[currentPath]).CGPointValue];
        }
        if (currentPath == pathLength - 1) {
            currentPath = 0;
        } else
            currentPath++;
        overflowCounter --;
        if (overflowCounter < -1) {
            NSLog(@"OVREFLOWWWING");
            break;
        }
    }
    return maskPath;

}

-(UIBezierPath *) _clockWisePathFromPoint:(CGPoint) firstPoint toPoint:(CGPoint) lastPoint {
    
    if (CGPointEqualToPoint(self.startPoint, self.endPoint)) {
        return nil;
    }
    UIBezierPath *maskPath = [UIBezierPath bezierPath];
    
    CGPoint minPoint = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMinY(self.bounds));
    CGPoint maxPoint = CGPointMake(CGRectGetMaxX(self.bounds), CGRectGetMaxY(self.bounds));
    
    [maskPath moveToPoint:firstPoint];
    int overflowCounter = 0;
    
    while (!CGPointEqualToPoint(firstPoint, lastPoint)) {
        NSLog(@"Current Point: %@", NSStringFromCGPoint(firstPoint));
        if (round(firstPoint.x) == maxPoint.x && (round(firstPoint.y) != maxPoint.y)) {
            if (round(lastPoint.x) != round(firstPoint.x)){
                [maskPath addLineToPoint: maxPoint];
                firstPoint = maxPoint;
            }
            else {
                [maskPath addLineToPoint:lastPoint];
                break;
            }
        } else if (round(firstPoint.y) == maxPoint.y && round(firstPoint.x) != minPoint.x){
            if (round(lastPoint.y) != round(firstPoint.y)) {
                [maskPath addLineToPoint:CGPointMake(minPoint.x, maxPoint.y)];
                firstPoint = CGPointMake(minPoint.x, maxPoint.y);
            } else {
                [maskPath addLineToPoint:lastPoint];
                break;
            }
        } else if (round(firstPoint.x) == minPoint.x && ( round(firstPoint.y) != minPoint.y)){
            if (round(lastPoint.x) != round(firstPoint.x)) {
                [maskPath addLineToPoint:minPoint];
                firstPoint = minPoint;
            } else {
                [maskPath addLineToPoint:lastPoint];
                break;
            }
        } else {
            if (round(lastPoint.y) != round(firstPoint.y)) {
                [maskPath addLineToPoint:CGPointMake(maxPoint.x, minPoint.y)];
                firstPoint = CGPointMake(maxPoint.x, minPoint.y);
            } else {
                [maskPath addLineToPoint:lastPoint];
                break;
            }
        }
        overflowCounter ++;
        if (overflowCounter > 5){
            NSLog(@"OVERFLOWING!");
            break;
        }
    }
    [maskPath closePath];
    return maskPath;
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
    slicedSection.userInteractionEnabled = YES;
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = slicedSection.bounds;
    maskLayer.path = path.CGPath;
    
    slicedSection.layer.mask = maskLayer;
    
    [self addSubview:slicedSection];
    self.slicedSection = slicedSection;
    
    CGRect sliceBounds = [path bounds];
    CGFloat midX = CGRectGetMidX(sliceBounds);
    CGFloat midY = CGRectGetMidY(sliceBounds);
    
    CGVector vec = [self _vectorNormalize:CGVectorMake(midX - CGRectGetMidX(self.bounds), midY - CGRectGetMidY(self.bounds))];
    
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
    
    if ( !CGPointEqualToPoint(self.startPoint, self.endPoint) ) {
        [[UIColor redColor] setStroke];
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, self.startPoint.x, self.startPoint.y);
        CGContextAddLineToPoint(context, self.endPoint.x, self.endPoint.y);
        CGContextStrokePath(context);
    }
}

@end

