#import <Foundation/Foundation.h>
#import "React/RCTViewManager.h"

@interface RCT_EXTERN_MODULE(ZarMeasureViewManager, RCTViewManager)

RCT_EXTERN_METHOD(checkVideoAuthorizationStatus: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXPORT_VIEW_PROPERTY(units, NSString)
RCT_EXPORT_VIEW_PROPERTY(minDistanceCamera, double)
RCT_EXPORT_VIEW_PROPERTY(maxDistanceCamera, double)

RCT_EXPORT_VIEW_PROPERTY(onARStatusChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMeasuringStatusChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMountError, RCTDirectEventBlock)

RCT_EXTERN_METHOD(clear: (nonnull NSNumber *)node resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(removeLast: (nonnull NSNumber *)node resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addPoint: (nonnull NSNumber *)node setCurrent:(BOOL)current resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(takePicture: (nonnull NSNumber *)node imagePath:(NSString*) path resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)
@end
