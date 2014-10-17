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
    self.opaque = NO;
    
    [self insertSubview:self.rootView atIndex:0];
    [self addSubview:self.ninjaPane];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_windowWillSendTouches:) name:kRZWindowWillSendTouchesNotificaton object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRZWindowWillSendTouchesNotificaton object:nil];
}

#pragma mark - public methods

- (void)addSubview:(UIView *)view
{
    [self.rootView addSubview:view];
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

- (void)touchOccurred:(UITouch *)touch
{
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

// --- end TODO

- (void)_commitSlice
{
    UIBezierPath *maskPath = [UIBezierPath bezierPath];
    
    CGPoint firstPoint, lastPoint;
    
    if ( self.startPoint.x < self.endPoint.x ) {
        firstPoint = self.startPoint;
        lastPoint = self.endPoint;
    }
    else {
        firstPoint = self.endPoint;
        lastPoint = self.startPoint;
    }
    
    [maskPath moveToPoint:firstPoint];
    
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(self.bounds), firstPoint.y)];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMinY(self.bounds))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(self.bounds), CGRectGetMinY(self.bounds))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(self.bounds), lastPoint.y)];
    
    [maskPath closePath];
    
//    [maskPath applyTransform:CGAffineTransformMakeScale(1.0f, -1.0f)];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.ninjaView.bounds;
    maskLayer.path = maskPath.CGPath;
    
    self.ninjaView.rootView.layer.mask = maskLayer;
}

- (void)_configureSlicedSectionWithPath:(UIBezierPath *)path
{
    UIView *slicedSection = [self.ninjaView snapshotViewAfterScreenUpdates:YES];
    slicedSection.frame = self.bounds;
    slicedSection.userInteractionEnabled = YES;
    slicedSection.clipsToBounds = YES;
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = slicedSection.bounds;
    maskLayer.path = path.CGPath;
    
    [self addSubview:slicedSection];
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
