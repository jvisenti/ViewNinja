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

@property (weak, nonatomic) UITouch *trackedTouch;

@property (assign, nonatomic) CGPoint startPoint;
@property (assign, nonatomic) CGPoint endPoint;

- (void)touchOccurred:(UITouch *)touch;

@end

#pragma mark - RZNinjaView private interface

@interface RZNinjaView () <UIGestureRecognizerDelegate>

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
    if ( self.ninjaPane.superview == self ) {
        [super insertSubview:view belowSubview:self.ninjaPane];
    }
    else {
        [super addSubview:view];
    }
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index
{
    if ( self.ninjaPane.superview == self ) {
        index = MIN(index, [self.subviews indexOfObject:self.ninjaPane]);
    }
    
    [super insertSubview:view atIndex:index];
}

#pragma mark - private methods

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
//        [self _commitSlice];
        
        self.trackedTouch = nil;
//        self.startPoint = CGPointZero;
//        self.endPoint = CGPointZero;
        
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
    
    CGFloat t = HUGE_VALF;
    
    t = MIN(t, [self _intersectionTimeOfLine:sliceLine withLine:leftEdge]);
    t = MIN(t, [self _intersectionTimeOfLine:sliceLine withLine:rightEdge]);
    t = MIN(t, [self _intersectionTimeOfLine:sliceLine withLine:topEdge]);
    t = MIN(t, [self _intersectionTimeOfLine:sliceLine withLine:bottomEdge]);
    
    return CGPointMake(p1.x + t * vec.dx, p1.y + t * vec.dy);
}

- (CGFloat)_intersectionTimeOfLine:(RZNinjaLine)l1 withLine:(RZNinjaLine)l2
{
    CGVector norm1 = [self _vectorNormalize:l1.v];
    CGVector norm2 = [self _vectorNormalize:l2.v];
    
    if ( fabsf(norm1.dx * norm2.dx + norm1.dy * norm2.dy) == 1.0f ) {
        // parallel lines won't ever intersect
        return HUGE_VALF;
    }
    
    CGVector w = CGVectorMake(l1.p0.x - l2.p0.x, l1.p0.y - l2.p0.y);
    CGFloat t = ((l2.v.dy * w.dx) - (l2.v.dx * w.dy)) / ((l2.v.dx * l1.v.dy) - (l2.v.dy * l1.v.dx));
    
    return t;
}

- (CGVector)_vectorNormalize:(CGVector)v
{
    if ( v.dx == 0.0f && v.dy == 0.0f ) {
        return v;
    }
    
    CGFloat magnitude = sqrtf(v.dx * v.dx + v.dy * v.dy);
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
    
    [maskPath applyTransform:CGAffineTransformMakeScale(1.0f, -1.0f)];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.ninjaView.bounds;
    maskLayer.path = maskPath.CGPath;
    
    self.ninjaView.layer.mask = maskLayer;
    self.ninjaView.clipsToBounds = YES;
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
