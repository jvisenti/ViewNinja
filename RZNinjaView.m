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

- (void)touchOccurred:(UITouch *)touch;

@end

#pragma mark - RZNinjaView private interface

@interface RZNinjaView ()

@property (strong, nonatomic) UIView *rootView;
@property (strong, nonatomic) RZNinjaPane *ninjaPane;
@property (strong, nonatomic) UIBezierPath *currentMask;

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

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if ( self.rootView.layer.mask == nil ) {
        self.currentMask = [UIBezierPath bezierPathWithRect:self.bounds];
    }
}

- (void)setCurrentMask:(UIBezierPath *)currentMask
{
    _currentMask = currentMask;
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.bounds;
    maskLayer.path = currentMask.CGPath;

    self.rootView.layer.mask = maskLayer;
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

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    return [self.ninjaView.currentMask containsPoint:point];
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

            RZLineSegmentSnapToPolygon(self.sliceSegment, self.ninjaView.currentMask.CGPath, false);
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
        RZLineSegmentSnapToPolygon(self.sliceSegment, self.ninjaView.currentMask.CGPath, true);
        
        [self _commitSlice];
        
        self.trackedTouch = nil;
        self.sliceSegment->p0 = kRZNotAPoint;
        self.sliceSegment->p1 = kRZNotAPoint;
        
        [self setNeedsDisplay];
    }
}

- (void)_commitSlice
{
    UIBezierPath *newBounds, *slice;
    [self _sliceBoundsPath:self.ninjaView.currentMask maxPath:&newBounds minPath:&slice];
    
    [self _configureSlicedSectionWithPath:slice];
    
    self.ninjaView.currentMask = newBounds;
}

- (void)_sliceBoundsPath:(UIBezierPath *)bounds maxPath:(UIBezierPath * __autoreleasing *)maxPath minPath:(UIBezierPath * __autoreleasing *)minPath
{
    CFIndex n;
    CGPoint *boundsPoints = RZPathGetPoints(bounds.CGPath, &n);
    
    RZLine sliceLine = RZLineFromLineSegment(*self.sliceSegment);
    
    UIBezierPath *path1 = [UIBezierPath bezierPath];
    UIBezierPath *path2 = [UIBezierPath bezierPath];
    
    UIBezierPath *currentPath = path1;
    UIBezierPath *nextPath = path2;
    
    for (CFIndex i = 0; i < n; i++) {
        CGPoint s0 = boundsPoints[i];
        CGPoint s1 = boundsPoints[(i+1) % n];
        
        RZLineSegment boundsSegment = (RZLineSegment){.p0 = s0, .p1 = s1};
        
        if ( currentPath.isEmpty ) {
            [currentPath moveToPoint:s0];
        }
        else {
            [currentPath addLineToPoint:s0];
        }
        
        CGPoint sliceIntersection = RZLineIntersectionWithSegment(sliceLine, boundsSegment, NULL, NULL);
        
        if ( !CGPointEqualToPoint(sliceIntersection, kRZNotAPoint) ) {
            [currentPath addLineToPoint:sliceIntersection];
            
            if ( nextPath.isEmpty ) {
                [nextPath moveToPoint:sliceIntersection];
            }
            else {
                [nextPath addLineToPoint:sliceIntersection];
            }
            
            UIBezierPath *temp = currentPath;
            currentPath = nextPath;
            nextPath = temp;
        }
    }
    
    free(boundsPoints);
    
    [path1 closePath];
    [path2 closePath];
    
    CGRect bounds1 = path1.bounds;
    CGRect bounds2 = path2.bounds;
    
    CGFloat area1 = CGRectGetWidth(bounds1) * CGRectGetHeight(bounds1);
    CGFloat area2 = CGRectGetWidth(bounds2) * CGRectGetHeight(bounds2);
    
    UIBezierPath *max = (area1 > area2) ? path1 : path2;
    UIBezierPath *min = (area1 > area2) ? path2 : path1;
    
    if ( maxPath != NULL ) {
        *maxPath = max;
    }
    
    if ( minPath != NULL ) {
        *minPath = min;
    }
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
    
    CGRect currentBounds = self.ninjaView.currentMask.bounds;
    
    CGRect sliceBounds = path.bounds;
    CGFloat midX = CGRectGetMidX(sliceBounds);
    CGFloat midY = CGRectGetMidY(sliceBounds);
    
    CGVector vec = RZVectorNormalize(CGVectorMake(midX - CGRectGetMidX(currentBounds), midY - CGRectGetMidY(currentBounds)));
    
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

