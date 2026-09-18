#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

@interface TrueUniversalClicker : NSObject
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UIView *targetDot;
@property (nonatomic, strong) UIButton *toggleBtn;
+ (instancetype)shared;
- (void)setupUI;
@end

@implementation TrueUniversalClicker

+ (instancetype)shared {
    static TrueUniversalClicker *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[TrueUniversalClicker alloc] init]; });
    return inst;
}

- (void)setupUI {
    UIWindow *window = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.hidden && w.alpha > 0) {
            window = w;
            break;
        }
    }
    if (!window) window = [UIApplication sharedApplication].keyWindow;

    // 1. Точка прицела (куда кликать)
    self.targetDot = [[UIView alloc] initWithFrame:CGRectMake(200, 200, 36, 36)];
    self.targetDot.layer.cornerRadius = 18;
    self.targetDot.layer.borderWidth = 2.5;
    self.targetDot.layer.borderColor = [UIColor redColor].CGColor;
    self.targetDot.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.35];
    self.targetDot.userInteractionEnabled = YES;

    UIPanGestureRecognizer *panDot = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanDot:)];
    [self.targetDot addGestureRecognizer:panDot];
    [window addSubview:self.targetDot];

    // 2. Кнопка вкл/выкл
    self.toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleBtn.frame = CGRectMake(40, 90, 100, 42);
    self.toggleBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    [self.toggleBtn setTitle:@"CLICK: OFF" forState:UIControlStateNormal];
    [self.toggleBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    self.toggleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    self.toggleBtn.layer.cornerRadius = 10;
    self.toggleBtn.layer.borderWidth = 1.5;
    self.toggleBtn.layer.borderColor = [UIColor whiteColor].CGColor;

    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanBtn:)];
    [self.toggleBtn addGestureRecognizer:panBtn];
    [self.toggleBtn addTarget:self action:@selector(toggleState) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:self.toggleBtn];
}

- (void)handlePanDot:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:self.targetDot.superview];
    self.targetDot.center = CGPointMake(self.targetDot.center.x + t.x, self.targetDot.center.y + t.y);
    [p setTranslation:CGPointMake(0, 0) inView:self.targetDot.superview];
}

- (void)handlePanBtn:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:self.toggleBtn.superview];
    self.toggleBtn.center = CGPointMake(self.toggleBtn.center.x + t.x, self.toggleBtn.center.y + t.y);
    [p setTranslation:CGPointMake(0, 0) inView:self.toggleBtn.superview];
}

- (void)toggleState {
    self.isRunning = !self.isRunning;
    if (self.isRunning) {
        [self.toggleBtn setTitle:@"CLICK: ON" forState:UIControlStateNormal];
        [self.toggleBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        self.targetDot.layer.borderColor = [UIColor greenColor].CGColor;
        self.targetDot.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.35];

        // 12 кликов в секунду
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.08 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [self dispatchTap];
        }];
    } else {
        [self.toggleBtn setTitle:@"CLICK: OFF" forState:UIControlStateNormal];
        [self.toggleBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        self.targetDot.layer.borderColor = [UIColor redColor].CGColor;
        self.targetDot.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.35];
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)dispatchTap {
    UIWindow *win = self.targetDot.window;
    if (!win) return;

    CGPoint location = self.targetDot.center;

    // Прячем оверлеи от hitTest
    self.targetDot.hidden = YES;
    self.toggleBtn.hidden = YES;
    UIView *hitView = [win hitTest:location withEvent:nil];
    self.targetDot.hidden = NO;
    self.toggleBtn.hidden = NO;

    if (!hitView) hitView = win;

    // Инициализация низкоуровневого UITouch
    UITouch *touch = [[UITouch alloc] init];
    [touch setValue:@(UITouchPhaseBegan) forKey:@"phase"];
    [touch setValue:hitView forKey:@"view"];
    [touch setValue:win forKey:@"window"];
    [touch setValue:@1 forKey:@"tapCount"];
    [touch setValue:[NSValue valueWithCGPoint:location] forKey:@"locationInWindow"];

    UIEvent *event = [[UIApplication sharedApplication] performSelector:NSSelectorFromString(@"_touchesEvent")];

    // Фаза 1: Касание экрана (Began)
    if ([hitView respondsToSelector:@selector(touchesBegan:withEvent:)]) {
        [hitView touchesBegan:[NSSet setWithObject:touch] withEvent:event];
    }
    
    // Фаза 2: Отпускание пальца (Ended) спустя 20 миллисекунд
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [touch setValue:@(UITouchPhaseEnded) forKey:@"phase"];
        if ([hitView respondsToSelector:@selector(touchesEnded:withEvent:)]) {
            [hitView touchesEnded:[NSSet setWithObject:touch] withEvent:event];
        }
        // Передача в главный цикл приложения для захвата игровым движком
        [[UIApplication sharedApplication] sendEvent:event];
    });
}

@end

__attribute__((constructor))
static void InitMod() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[TrueUniversalClicker shared] setupUI];
    });
}
