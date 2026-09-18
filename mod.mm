#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <stdint.h>

@interface ClickerManager : NSObject
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) CGPoint targetPoint;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UIButton *controlBtn;
@property (nonatomic, strong) UIView *targetReticle;
+ (instancetype)shared;
- (void)setupUI;
- (void)toggleClicker;
- (void)performClick;
@end

@implementation ClickerManager

+ (instancetype)shared {
    static ClickerManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ClickerManager alloc] init];
    });
    return instance;
}

- (void)setupUI {
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.hidden && w.alpha > 0) {
            keyWindow = w;
            break;
        }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;

    // 1. Прицел (куда будут идти клики)
    self.targetReticle = [[UIView alloc] initWithFrame:CGRectMake(160, 240, 44, 44)];
    self.targetReticle.layer.cornerRadius = 22;
    self.targetReticle.layer.borderWidth = 2.0;
    self.targetReticle.layer.borderColor = [UIColor redColor].CGColor;
    self.targetReticle.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.25];
    self.targetReticle.userInteractionEnabled = YES;

    UIPanGestureRecognizer *panTarget = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanTarget:)];
    [self.targetReticle addGestureRecognizer:panTarget];
    [keyWindow addSubview:self.targetReticle];

    // 2. Кнопка включения/выключения
    self.controlBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.controlBtn.frame = CGRectMake(40, 100, 110, 45);
    self.controlBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    [self.controlBtn setTitle:@"AutoClick: OFF" forState:UIControlStateNormal];
    [self.controlBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    self.controlBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    self.controlBtn.layer.cornerRadius = 10;
    self.controlBtn.layer.borderWidth = 1.5;
    self.controlBtn.layer.borderColor = [UIColor whiteColor].CGColor;

    UIPanGestureRecognizer *panBtn = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanBtn:)];
    [self.controlBtn addGestureRecognizer:panBtn];
    [self.controlBtn addTarget:self action:@selector(toggleClicker) forControlEvents:UIControlEventTouchUpInside];
    [keyWindow addSubview:self.controlBtn];
}

- (void)handlePanTarget:(UIPanGestureRecognizer *)pan {
    CGPoint trans = [pan translationInView:self.targetReticle.superview];
    self.targetReticle.center = CGPointMake(self.targetReticle.center.x + trans.x, self.targetReticle.center.y + trans.y);
    [pan setTranslation:CGPointMake(0, 0) inView:self.targetReticle.superview];
}

- (void)handlePanBtn:(UIPanGestureRecognizer *)pan {
    CGPoint trans = [pan translationInView:self.controlBtn.superview];
    self.controlBtn.center = CGPointMake(self.controlBtn.center.x + trans.x, self.controlBtn.center.y + trans.y);
    [pan setTranslation:CGPointMake(0, 0) inView:self.controlBtn.superview];
}

- (void)toggleClicker {
    self.isRunning = !self.isRunning;
    if (self.isRunning) {
        [self.controlBtn setTitle:@"AutoClick: ON" forState:UIControlStateNormal];
        [self.controlBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        self.targetReticle.layer.borderColor = [UIColor greenColor].CGColor;
        
        // 15 кликов в секунду (интервал ~0.066s)
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.066 repeats:YES block:^(NSTimer * _Nonnull t) {
            [self performClick];
        }];
    } else {
        [self.controlBtn setTitle:@"AutoClick: OFF" forState:UIControlStateNormal];
        [self.controlBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        self.targetReticle.layer.borderColor = [UIColor redColor].CGColor;
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)performClick {
    UIWindow *window = self.targetReticle.window;
    if (!window) return;

    CGPoint clickPos = self.targetReticle.center;

    // Временно скрываем наши элементы интерфейса, чтобы найти игровое поле под ними
    self.targetReticle.hidden = YES;
    self.controlBtn.hidden = YES;
    UIView *hitView = [window hitTest:clickPos withEvent:nil];
    self.targetReticle.hidden = NO;
    self.controlBtn.hidden = NO;

    if (!hitView) hitView = window;

    // Отправляем симуляцию нажатия (Touch Down)
    UITouch *touch = [[UITouch alloc] init];
    [touch setValue:@(UITouchPhaseBegan) forKey:@"phase"];
    [touch setValue:hitView forKey:@"view"];
    [touch setValue:window forKey:@"window"];
    [touch setValue:@1 forKey:@"tapCount"];

    if ([hitView respondsToSelector:@selector(touchesBegan:withEvent:)]) {
        [hitView touchesBegan:[NSSet setWithObject:touch] withEvent:nil];
    }

    // Завершаем нажатие (Touch Up) спустя 20мс
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [touch setValue:@(UITouchPhaseEnded) forKey:@"phase"];
        if ([hitView respondsToSelector:@selector(touchesEnded:withEvent:)]) {
            [hitView touchesEnded:[NSSet setWithObject:touch] withEvent:nil];
        }
    });
}

@end

__attribute__((constructor))
static void InitClicker() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[ClickerManager shared] setupUI];
    });
}
