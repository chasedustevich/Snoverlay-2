#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface XMASFallingSnowView : UIView {
    CAEmitterLayer *_snowEmitterLayer;
}

@property (nonatomic, strong) NSMutableArray *flakesArray;
@property (nonatomic, copy) NSString *flakeFileName;
@property (nonatomic, assign) NSInteger flakesCount;
@property (nonatomic, assign) float animationDurationMin;
@property (nonatomic, assign) float animationDurationMax;

- (void)beginSnowAnimation;
- (void)beginSnowEmmitter;
- (void)handlePrefs;

@end
