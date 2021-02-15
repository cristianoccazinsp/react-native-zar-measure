#import <Foundation/Foundation.h>
#import "React/RCTViewManager.h"

@interface RCT_EXTERN_MODULE(ZarMeasureViewManager, RCTViewManager)

RCT_EXTERN_METHOD(checkVideoAuthorizationStatus: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXPORT_VIEW_PROPERTY(units, NSString)
RCT_EXPORT_VIEW_PROPERTY(hideHelp, BOOL)
RCT_EXPORT_VIEW_PROPERTY(minDistanceCamera, double)
RCT_EXPORT_VIEW_PROPERTY(maxDistanceCamera, double)
RCT_EXPORT_VIEW_PROPERTY(onReady, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMountError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDetect, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMeasure, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMeasureError, RCTDirectEventBlock)

RCT_EXTERN_METHOD(clear: (nonnull NSNumber *)node resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)
@end
