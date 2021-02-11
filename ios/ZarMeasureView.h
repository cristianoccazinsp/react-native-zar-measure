#import <UIKit/UIKit.h>
#import <React/RCTView.h>

#if __has_include("ZarMeasureView-Swift.h")
#import "ZarMeasureView-Swift.h"
#elif __has_include("react_native_zar_measure-Swift.h")
#import "react_native_zar_measure-Swift.h"
#endif


@class RCTBridge;

@interface ZarMeasureView : RCTView

- (instancetype)initWithBridge:(RCTBridge *)bridge;

@end
