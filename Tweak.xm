#import "FallingSnow/XMASFallingSnowView.h"
#import <UIKit/UIKit.h>
#import <rootless.h>
#import <objc/runtime.h>

static NSString * const kSnoverlayPrefsDomain = @"com.ryannair05.snoverlay";
static NSString * const kSnoverlayPrefsNotification = @"com.ryannair05.snoverlay/prefsupdated";
static const UIWindowLevel kSnoverlayWindowLevel = 10000000.0;

static BOOL SnoverlayGetBoolPref(NSString *key, BOOL defaultValue) {
    Boolean found = false;
    Boolean val = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, (__bridge CFStringRef)kSnoverlayPrefsDomain, &found);
    return found ? (BOOL)val : defaultValue;
}

#pragma mark - Window & Hit-Test Isolation

@interface UIWindow (Private)
- (BOOL)_ignoresHitTest;
- (void)_setSecure:(BOOL)secure;
@end

@interface SnoverlaySecureWindow : UIWindow
@end

@implementation SnoverlaySecureWindow

- (BOOL)_ignoresHitTest {
    return YES;
}

- (BOOL)_shouldCreateContextAsSecure {
    return YES;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

@end

#pragma mark - Full Screen Overlay Controller

@interface SnoverlayOverlayViewController : UIViewController
@property (nonatomic, strong) XMASFallingSnowView *snowView;
- (void)updateSnowView;
@end

@implementation SnoverlayOverlayViewController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:CGRectZero];
    root.backgroundColor = [UIColor clearColor];
    root.userInteractionEnabled = NO;
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateSnowView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSnowView)
                                                 name:kSnoverlayPrefsNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSnoverlayPrefsNotification object:nil];
}

- (void)updateSnowView {
    BOOL enabled = SnoverlayGetBoolPref(@"enabled", YES);
    BOOL wallpaperOnly = SnoverlayGetBoolPref(@"wallpaperOnly", YES);

    [self.snowView removeFromSuperview];
    self.snowView = nil;

    // Full screen window overlay is active when tweak is enabled and NOT restricted to wallpaper only
    if (enabled && !wallpaperOnly) {
        self.snowView = [[XMASFallingSnowView alloc] initWithFrame:self.view.bounds];
        self.snowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.snowView];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.snowView) {
        self.snowView.frame = self.view.bounds;
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end

#pragma mark - Window & Scene Management

@interface SnoverlayWindowManager : NSObject {
    SnoverlaySecureWindow *_window;
    BOOL _observingScenes;
}
+ (instancetype)sharedInstance;
- (void)initializeOverlay;
- (BOOL)tryCreateWindow;
- (void)destroyWindow;
@end

@implementation SnoverlayWindowManager

+ (instancetype)sharedInstance {
    static SnoverlayWindowManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SnoverlayWindowManager alloc] init];
    });
    return instance;
}

static UIWindowScene *SnoverlayFindMainWindowScene(void) {
    Class sbWindowSceneClass = NSClassFromString(@"SBWindowScene");
    UIWindowScene *fallback = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.screen != [UIScreen mainScreen]) continue;
        if (sbWindowSceneClass && [windowScene isKindOfClass:sbWindowSceneClass]) return windowScene;
        if (!fallback) fallback = windowScene;
    }
    return fallback;
}

- (void)initializeOverlay {
    if (![self tryCreateWindow]) {
        [self startObservingScenes];
    }
}

- (BOOL)tryCreateWindow {
    if (_window) return YES;

    UIWindowScene *scene = SnoverlayFindMainWindowScene();
    if (!scene) {
        if (@available(iOS 16.0, *)) {
            // On iOS 16+, wait for SpringBoard's SBWindowScene
            return NO;
        }
        _window = [[SnoverlaySecureWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    } else {
        _window = [[SnoverlaySecureWindow alloc] initWithWindowScene:scene];
        _window.frame = scene.coordinateSpace.bounds;
    }

    if ([_window respondsToSelector:@selector(_setSecure:)]) {
        [_window _setSecure:YES];
    }
    _window.windowLevel = kSnoverlayWindowLevel;
    _window.backgroundColor = [UIColor clearColor];
    _window.userInteractionEnabled = NO;

    SnoverlayOverlayViewController *rootVC = [[SnoverlayOverlayViewController alloc] init];
    _window.rootViewController = rootVC;

    _window.hidden = NO;
    return YES;
}

- (void)destroyWindow {
    if (!_window) return;
    _window.hidden = YES;
    _window = nil;
}

- (void)startObservingScenes {
    if (_observingScenes) return;
    _observingScenes = YES;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(sceneDidChange:) name:UISceneWillConnectNotification object:nil];
    [nc addObserver:self selector:@selector(sceneDidChange:) name:UISceneDidActivateNotification object:nil];
    [nc addObserver:self selector:@selector(sceneDidDisconnect:) name:UISceneDidDisconnectNotification object:nil];
}

- (void)sceneDidChange:(NSNotification *)note {
    if (_window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self tryCreateWindow];
    });
}

- (void)sceneDidDisconnect:(NSNotification *)note {
    if (_window && _window.windowScene == note.object) {
        [self destroyWindow];
    }
}

@end

#pragma mark - Hooks

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[SnoverlayWindowManager sharedInstance] initializeOverlay];
}
%end

@interface SBFStaticWallpaperView : UIView
@property (nonatomic, strong) XMASFallingSnowView *snowView;
- (void)snoverlay_updateSnowView;
@end

%hook SBFStaticWallpaperView
%property (nonatomic, strong) XMASFallingSnowView *snowView;

- (void)_setupContentViewWithOptions:(NSUInteger)options {
    %orig;
    [self snoverlay_updateSnowView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(snoverlay_updateSnowView)
                                                 name:kSnoverlayPrefsNotification
                                               object:nil];
}

- (void)_setupContentView {
    %orig;
    [self snoverlay_updateSnowView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(snoverlay_updateSnowView)
                                                 name:kSnoverlayPrefsNotification
                                               object:nil];
}

%new
- (void)snoverlay_updateSnowView {
    BOOL enabled = SnoverlayGetBoolPref(@"enabled", YES);
    BOOL wallpaperOnly = SnoverlayGetBoolPref(@"wallpaperOnly", YES);

    [self.snowView removeFromSuperview];
    self.snowView = nil;

    if (enabled && wallpaperOnly) {
        self.snowView = [[XMASFallingSnowView alloc] initWithFrame:self.bounds];
        [self addSubview:self.snowView];

        self.snowView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.snowView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
        [self.snowView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
        [self.snowView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
        [self.snowView.heightAnchor constraintEqualToAnchor:self.heightAnchor].active = YES;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSnoverlayPrefsNotification object:nil];
    %orig;
}

%end

@interface CarplayLockOutViewController : UIViewController
@property (nonatomic, strong) XMASFallingSnowView *snowView;
@end

%group CarPlay

%hook CarplayLockOutViewController
%property (nonatomic, strong) XMASFallingSnowView *snowView;

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    BOOL enabled = SnoverlayGetBoolPref(@"enabled", YES);
    if (enabled) {
        [[self snowView] removeFromSuperview];
        XMASFallingSnowView *view = [[XMASFallingSnowView alloc] initWithFrame:[self view].bounds];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self setSnowView:view];
        [[self view] addSubview:view];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    [[self snowView] removeFromSuperview];
    [self setSnowView:nil];
}

%end

%end

#pragma mark - Notification & Constructor

static void loadPrefs(void) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kSnoverlayPrefsNotification object:nil];
}

%ctor {
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            (CFNotificationCallback)loadPrefs,
            (__bridge CFStringRef)kSnoverlayPrefsNotification,
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );

        %init(_ungrouped);

        Class carplayClass = objc_getClass("CARLockOutViewController") ?: objc_getClass("SBStarkLockOutViewController");
        if (carplayClass) {
            %init(CarPlay, CarplayLockOutViewController = carplayClass);
        }
    }
}
