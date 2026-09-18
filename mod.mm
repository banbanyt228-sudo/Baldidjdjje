#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <stdint.h>

// ================= ОФФСЕТЫ =================
#define OFFSET_STAMINA_CHECK     0x123456
#define OFFSET_DETECT_COLLISIONS 0x234567
// ============================================

static bool isFlying = false;

static bool PatchMemory(uintptr_t address, const void* data, size_t size) {
    kern_return_t kr = vm_protect(mach_task_self(), (vm_address_t)address, size, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return false;
    memcpy((void*)address, data, size);
    kr = vm_protect(mach_task_self(), (vm_address_t)address, size, false, VM_PROT_READ | VM_PROT_EXECUTE);
    return (kr == KERN_SUCCESS);
}

static uintptr_t GetImageBase() {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (strstr(name, "UnityFramework")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return (uintptr_t)_dyld_get_image_header(0);
}

@interface FloatButtonView : UIButton
@end

@implementation FloatButtonView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        [self setTitle:@"Fly: OFF" forState:UIControlStateNormal];
        [self setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
        self.layer.cornerRadius = 12.0;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.clipsToBounds = YES;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];

        [self addTarget:self action:@selector(toggleFly) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointMake(0, 0) inView:self.superview];
}

- (void)toggleFly {
    isFlying = !isFlying;
    uintptr_t base = GetImageBase();

    if (isFlying) {
        [self setTitle:@"Fly: ON" forState:UIControlStateNormal];
        [self setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        uint32_t patch_disable[] = { 0x52800001, 0xD65F03C0 };
        PatchMemory(base + OFFSET_DETECT_COLLISIONS, patch_disable, sizeof(patch_disable));
    } else {
        [self setTitle:@"Fly: OFF" forState:UIControlStateNormal];
        [self setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        uint32_t patch_enable[] = { 0x52800021, 0xD65F03C0 };
        PatchMemory(base + OFFSET_DETECT_COLLISIONS, patch_enable, sizeof(patch_enable));
    }
}

@end

static void ShowFloatingButton() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (!w.hidden && w.alpha > 0) {
                window = w;
                break;
            }
        }
        if (!window) window = [UIApplication sharedApplication].keyWindow;

        FloatButtonView *btn = [[FloatButtonView alloc] initWithFrame:CGRectMake(80, 80, 95, 45)];
        [window addSubview:btn];
    });
}

__attribute__((constructor))
static void InitMod() {
    uintptr_t base = GetImageBase();
    uint32_t arm_ret = 0xD65F03C0; 
    PatchMemory(base + OFFSET_STAMINA_CHECK, &arm_ret, sizeof(arm_ret));
    ShowFloatingButton();
}
