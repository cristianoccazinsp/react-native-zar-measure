#import "ZarMeasureViewManager.h"
#import "ZarMeasureView.h"
#import <UIKit/UIKit.h>

@implementation ZarMeasureViewManager

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (UIView *)view
{
    return [[ZarMeasureView alloc] initWithBridge:self.bridge];
}

@end
