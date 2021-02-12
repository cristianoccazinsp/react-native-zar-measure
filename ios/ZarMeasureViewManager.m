#import "ZarMeasureViewManager.h"
#import "ZarMeasureView.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ARKit/ARKit.h>


@implementation ZarMeasureViewManager

RCT_EXPORT_MODULE();


//@synthesize bridge = _bridge;

bool _supportsAR = NO;


#pragma mark - initialization

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (NSDictionary *)constantsToExport
{
    if (@available(iOS 11.0, *)) {
        _supportsAR = ARConfiguration.isSupported;
    } else {
        _supportsAR = NO;
    }
    
    return @{ @"AR_SUPPORTED": @(_supportsAR)};
}

- (UIView *)view
{
    return [[ZarMeasureView alloc] initWithBridge:self.bridge];
}


#pragma mark - props

RCT_EXPORT_VIEW_PROPERTY(onCameraReady, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onMountError, RCTDirectEventBlock);


#pragma mark - methods

RCT_EXPORT_METHOD(checkVideoAuthorizationStatus:(RCTPromiseResolveBlock)resolve
                  reject:(__unused RCTPromiseRejectBlock)reject) {
#ifdef DEBUG
    if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSCameraUsageDescription"]) {
        RCTLogWarn(@"Checking video permissions without having key 'NSCameraUsageDescription' defined in your Info.plist. If you do not add it your app will crash when being built in release mode. You will have to add it to your Info.plist file, otherwise the component is not allowed to use the camera.  You can learn more about adding permissions here: https://stackoverflow.com/a/38498347/4202031");
        resolve(@(NO));
        return;
    }
#endif
    __block NSString *mediaType = AVMediaTypeVideo;
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        resolve(@(granted));
    }];
}


@end
