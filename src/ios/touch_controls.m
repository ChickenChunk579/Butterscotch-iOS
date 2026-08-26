#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>
#include <math.h>

#include "runner_keyboard.h"
#include "touch_controls.h"

@interface ButterscotchTouchControls : UIView
@property(nonatomic, assign) IOSTouchControlsKeyCallback keyCallback;
@property(nonatomic, assign) IOSTouchControlsExitCallback exitCallback;
@property(nonatomic) BOOL showControls;
@property(nonatomic) BOOL showFPS;
@property(nonatomic, retain) UIButton *exitButton;

@property(nonatomic, retain) CADisplayLink *joystickSnapLink;

// UIKit owns active touches for their sequence, so these are deliberately
// non-owning references.
@property(nonatomic, assign) UITouch *joystickTouch;
@property(nonatomic, assign) UITouch *zTouch;
@property(nonatomic, assign) UITouch *xTouch;
@property(nonatomic, assign) UITouch *cTouch;

@property(nonatomic) BOOL upHeld;
@property(nonatomic) BOOL downHeld;
@property(nonatomic) BOOL leftHeld;
@property(nonatomic) BOOL rightHeld;
@property(nonatomic) BOOL zHeld;
@property(nonatomic) BOOL xHeld;
@property(nonatomic) BOOL cHeld;

@property(nonatomic, retain) UILabel *fpsLabel;

// Smoothed visual joystick position.
@property(nonatomic) CGFloat joystickVisualX;
@property(nonatomic) CGFloat joystickVisualY;

@end

@implementation ButterscotchTouchControls

- (instancetype)initWithFrame:(CGRect)frame
                      callback:(IOSTouchControlsKeyCallback)callback
                  exitCallback:(IOSTouchControlsExitCallback)exitCallback
                  showControls:(BOOL)showControls
                       showFPS:(BOOL)showFPS {
    self = [super initWithFrame:frame];

    if (self) {
        _keyCallback = callback;
        _exitCallback = exitCallback;
        _showControls = showControls;
        _showFPS = showFPS;

        self.opaque = NO;
        self.multipleTouchEnabled = YES;
        self.backgroundColor = UIColor.clearColor;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        _joystickVisualX = 0.0;
        _joystickVisualY = 0.0;

        _exitButton = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
        _exitButton.autoresizingMask =
            UIViewAutoresizingFlexibleRightMargin |
            UIViewAutoresizingFlexibleBottomMargin;
        _exitButton.backgroundColor =
            [UIColor colorWithWhite:0.05 alpha:0.60];
        _exitButton.layer.cornerRadius = 9.0;

        [_exitButton setTitle:@"Exit"
                     forState:UIControlStateNormal];

        [_exitButton setTitleColor:UIColor.whiteColor
                          forState:UIControlStateNormal];

        [_exitButton addTarget:self
                        action:@selector(exitPressed:)
              forControlEvents:UIControlEventTouchUpInside];

        [self addSubview:_exitButton];

        _fpsLabel = [[UILabel alloc] init];
        _fpsLabel.text = @"FPS: ??";
        _fpsLabel.textColor = UIColor.whiteColor;
        _fpsLabel.backgroundColor =
            [UIColor colorWithWhite:0.05 alpha:0.60];
        _fpsLabel.font =
            [UIFont boldSystemFontOfSize:16.0];
        _fpsLabel.textAlignment = NSTextAlignmentCenter;
        _fpsLabel.layer.cornerRadius = 8.0;
        _fpsLabel.clipsToBounds = YES;
        _fpsLabel.hidden = !showFPS;

        [self addSubview:_fpsLabel];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat top = MAX(self.safeAreaInsets.top, 12.0);
    CGFloat right = MAX(self.safeAreaInsets.right, 12.0);

    self.exitButton.frame = CGRectMake(
        16.0,
        top,
        92.0,
        38.0
    );

    self.fpsLabel.frame = CGRectMake(
        CGRectGetWidth(self.bounds) - right - 90.0,
        top,
        90.0,
        32.0
    );
}

- (void)setFPS:(double)fps {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.fpsLabel.text =
            [NSString stringWithFormat:@"FPS: %.0f", fps];
    });
}

- (void)exitPressed:(id)sender {
    [self releaseJoystick];

    if (self.exitCallback) {
        self.exitCallback();
    }
}

- (CGPoint)joystickCenter {
    CGFloat bottom = MAX(self.safeAreaInsets.bottom, 20.0);

    return CGPointMake(
        92.0,
        CGRectGetHeight(self.bounds) - bottom - 92.0
    );
}

- (CGRect)buttonRectForKey:(int32_t)key {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat bottom = MAX(self.safeAreaInsets.bottom, 20.0);

    CGPoint center;

    if (key == 'Z') {
        center = CGPointMake(
            width - 82.0,
            height - bottom - 78.0
        );
    } else if (key == 'X') {
        center = CGPointMake(
            width - 152.0,
            height - bottom - 44.0
        );
    } else {
        center = CGPointMake(
            width - 82.0,
            height - bottom - 148.0
        );
    }

    return CGRectMake(
        center.x - 34.0,
        center.y - 34.0,
        68.0,
        68.0
    );
}

- (void)setKey:(int32_t)key
          held:(BOOL)held
       current:(BOOL *)current {

    if (*current == held) {
        return;
    }

    *current = held;

    if (self.keyCallback) {
        self.keyCallback(key, held);
    }
}

/*
 * Smoothly move the visual joystick toward its target.
 *
 * This is deliberately separate from the keyboard state. The game
 * receives the key immediately, while the visual knob follows the
 * finger smoothly.
 */
- (void)smoothJoystickToX:(CGFloat)x y:(CGFloat)y {
    const CGFloat smoothing = 0.22;

    _joystickVisualX +=
        (x - _joystickVisualX) * smoothing;

    _joystickVisualY +=
        (y - _joystickVisualY) * smoothing;

    [self setNeedsDisplay];
}

/*
 * Update the joystick based on the actual finger position.
 */
- (void)updateJoystick:(UITouch *)touch {
    CGPoint p = [touch locationInView:self];
    CGPoint center = [self joystickCenter];

    CGFloat dx = p.x - center.x;
    CGFloat dy = p.y - center.y;

    const CGFloat deadZone = 18.0;
    const CGFloat maxDistance = 50.0;

    CGFloat distance = hypot(dx, dy);

    /*
     * Limit the visual knob to the joystick's travel radius.
     */
    if (distance > maxDistance) {
        CGFloat scale = maxDistance / distance;

        dx *= scale;
        dy *= scale;
    }

    /*
     * The visual position follows the finger itself, rather than
     * simply jumping between four hard-coded positions.
     */
    [self smoothJoystickToX:dx y:dy];

    /*
     * Keyboard direction detection.
     *
     * A small overlap between horizontal/vertical axes makes
     * diagonal movement feel less twitchy.
     */
    BOOL horizontal =
        fabs(dx) > fabs(dy) * 0.55;

    BOOL vertical =
        fabs(dy) > fabs(dx) * 0.55;

    [self setKey:VK_LEFT
            held:(horizontal && dx < -deadZone)
         current:&_leftHeld];

    [self setKey:VK_RIGHT
            held:(horizontal && dx > deadZone)
         current:&_rightHeld];

    [self setKey:VK_UP
            held:(vertical && dy < -deadZone)
         current:&_upHeld];

    [self setKey:VK_DOWN
            held:(vertical && dy > deadZone)
         current:&_downHeld];
}

- (void)releaseJoystick {
    self.joystickTouch = nil;

    [self setKey:VK_LEFT
            held:NO
         current:&_leftHeld];

    [self setKey:VK_RIGHT
            held:NO
         current:&_rightHeld];

    [self setKey:VK_UP
            held:NO
         current:&_upHeld];

    [self setKey:VK_DOWN
            held:NO
         current:&_downHeld];

    /*
     * Stop any previous snap animation.
     */
    [self.joystickSnapLink invalidate];
    self.joystickSnapLink = nil;

    /*
     * Animate the knob back to the center every display frame.
     */
    self.joystickSnapLink =
        [CADisplayLink displayLinkWithTarget:self
                                    selector:@selector(snapJoystick)];

    [self.joystickSnapLink addToRunLoop:[NSRunLoop mainRunLoop]
                                forMode:NSRunLoopCommonModes];

    [self setNeedsDisplay];
}

- (void)snapJoystick {
    /*
     * Higher = snappier.
     * Lower = softer/slower.
     */
    const CGFloat smoothing = 0.20;

    _joystickVisualX *= (1.0 - smoothing);
    _joystickVisualY *= (1.0 - smoothing);

    /*
     * Once we're close enough to center, finish exactly at zero
     * and stop the display link.
     */
    if (fabs(_joystickVisualX) < 0.5 &&
        fabs(_joystickVisualY) < 0.5) {

        _joystickVisualX = 0.0;
        _joystickVisualY = 0.0;

        [self.joystickSnapLink invalidate];
        self.joystickSnapLink = nil;
    }

    [self setNeedsDisplay];
}

- (void)setButtonForTouch:(UITouch *)touch held:(BOOL)held {
    if (touch == self.zTouch) {
        [self setKey:'Z'
                held:held
             current:&_zHeld];
    }

    if (touch == self.xTouch) {
        [self setKey:'X'
                held:held
             current:&_xHeld];
    }

    if (touch == self.cTouch) {
        [self setKey:'C'
                held:held
             current:&_cHeld];
    }

    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {

    if (!self.showControls) {
        return;
    }

    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];

        if (!self.joystickTouch &&
            hypot(
                p.x - [self joystickCenter].x,
                p.y - [self joystickCenter].y
            ) <= 82.0) {

            self.joystickTouch = touch;

            /*
             * Start from the center visually, but immediately use
             * the touch position for the actual input.
             */
            [self updateJoystick:touch];

        } else if (!self.zTouch &&
                   CGRectContainsPoint(
                       [self buttonRectForKey:'Z'],
                       p)) {

            self.zTouch = touch;
            [self setButtonForTouch:touch held:YES];

        } else if (!self.xTouch &&
                   CGRectContainsPoint(
                       [self buttonRectForKey:'X'],
                       p)) {

            self.xTouch = touch;
            [self setButtonForTouch:touch held:YES];

        } else if (!self.cTouch &&
                   CGRectContainsPoint(
                       [self buttonRectForKey:'C'],
                       p)) {

            self.cTouch = touch;
            [self setButtonForTouch:touch held:YES];
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {

    if (self.joystickTouch &&
        [touches containsObject:self.joystickTouch]) {

        [self updateJoystick:self.joystickTouch];
    }
}

- (void)finishTouches:(NSSet<UITouch *> *)touches {
    for (UITouch *touch in touches) {

        if (touch == self.joystickTouch) {
            [self releaseJoystick];
        }

        if (touch == self.zTouch) {
            [self setButtonForTouch:touch held:NO];
            self.zTouch = nil;
        }

        if (touch == self.xTouch) {
            [self setButtonForTouch:touch held:NO];
            self.xTouch = nil;
        }

        if (touch == self.cTouch) {
            [self setButtonForTouch:touch held:NO];
            self.cTouch = nil;
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    [self finishTouches:touches];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches
               withEvent:(UIEvent *)event {
    [self finishTouches:touches];
}

- (void)drawRect:(CGRect)rect {
    if (!self.showControls) {
        return;
    }

    CGContextRef context = UIGraphicsGetCurrentContext();

    CGPoint stick = [self joystickCenter];

    /*
     * Joystick base.
     */
    CGContextSetFillColorWithColor(
        context,
        [UIColor colorWithWhite:0.08 alpha:0.35].CGColor
    );

    CGContextFillEllipseInRect(
        context,
        CGRectMake(
            stick.x - 72.0,
            stick.y - 72.0,
            144.0,
            144.0
        )
    );

    /*
     * Smooth visual knob position.
     *
     * Unlike the old implementation, this doesn't snap directly
     * to +/-28 pixels. It follows the finger continuously.
     */
    CGFloat knobX =
        stick.x + self.joystickVisualX;

    CGFloat knobY =
        stick.y + self.joystickVisualY;

    CGContextSetFillColorWithColor(
        context,
        [UIColor colorWithWhite:0.9 alpha:0.45].CGColor
    );

    CGContextFillEllipseInRect(
        context,
        CGRectMake(
            knobX - 32.0,
            knobY - 32.0,
            64.0,
            64.0
        )
    );

    /*
     * Buttons.
     */
    NSDictionary *attributes = @{
        NSFontAttributeName:
            [UIFont boldSystemFontOfSize:23.0],

        NSForegroundColorAttributeName:
            UIColor.whiteColor
    };

    for (NSNumber *keyNumber in @[
        @('Z'),
        @('X'),
        @('C')
    ]) {

        int32_t key = keyNumber.intValue;

        CGRect button =
            [self buttonRectForKey:key];

        BOOL held =
            key == 'Z'
                ? self.zHeld
                : (key == 'X'
                    ? self.xHeld
                    : self.cHeld);

        CGContextSetFillColorWithColor(
            context,
            [UIColor colorWithWhite:
                (held ? 0.85 : 0.15)
                alpha:
                (held ? 0.7 : 0.45)].CGColor
        );

        CGContextFillEllipseInRect(
            context,
            button
        );

        NSString *label =
            [NSString stringWithFormat:@"%c", (char)key];

        CGSize size =
            [label sizeWithAttributes:attributes];

        [label drawAtPoint:
            CGPointMake(
                CGRectGetMidX(button) -
                    size.width / 2.0,

                CGRectGetMidY(button) -
                    size.height / 2.0
            )
            withAttributes:attributes];
    }
}

- (void)dealloc {
    [_joystickSnapLink invalidate];

    [_exitButton release];
    [_fpsLabel release];
    [_joystickSnapLink release];

    [super dealloc];
}

@end


static ButterscotchTouchControls *controls;

void IOSTouchControls_install(
    void *sdlWindow,
    IOSTouchControlsKeyCallback callback,
    IOSTouchControlsExitCallback exitCallback,
    bool showControls,
    bool showFPS) {

    SDL_SysWMinfo info;

    SDL_VERSION(&info.version);

    if (!SDL_GetWindowWMInfo(
            (SDL_Window *)sdlWindow,
            &info) ||
        info.subsystem != SDL_SYSWM_UIKIT) {

        return;
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [controls removeFromSuperview];

            UIWindow *window =
                info.info.uikit.window;

            controls =
                [[ButterscotchTouchControls alloc]
                    initWithFrame:window.bounds
                    callback:callback
                    exitCallback:exitCallback
                    showControls:showControls
                    showFPS:showFPS];

            controls.frame = window.bounds;

            [info.info.uikit.window addSubview:controls];
        }
    );
}

void IOSTouchControls_remove(void) {
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [controls removeFromSuperview];
            controls = nil;
        }
    );
}

void IOSTouchControls_setFPS(double fps) {
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            if (controls) {
                [controls setFPS:fps];
            }
        }
    );
}
