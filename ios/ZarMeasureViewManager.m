#import <Foundation/Foundation.h>
#import "React/RCTViewManager.h"

@interface RCT_EXTERN_MODULE(ZarMeasureViewManager, RCTViewManager)

RCT_EXTERN_METHOD(checkVideoAuthorizationStatus: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXPORT_VIEW_PROPERTY(units, NSString)
RCT_EXPORT_VIEW_PROPERTY(minDistanceCamera, double)
RCT_EXPORT_VIEW_PROPERTY(maxDistanceCamera, double)
RCT_EXPORT_VIEW_PROPERTY(intersectDistance, double)
RCT_EXPORT_VIEW_PROPERTY(torchOn, BOOL)
RCT_EXPORT_VIEW_PROPERTY(paused, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showPlanes, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showGeometry, BOOL)
RCT_EXPORT_VIEW_PROPERTY(showMeshes, BOOL)

RCT_EXPORT_VIEW_PROPERTY(onARStatusChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMeasuringStatusChange, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMountError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onTextTap, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPlaneTap, RCTDirectEventBlock)

RCT_EXTERN_METHOD(clear: (nonnull NSNumber *)node clear:(nonnull NSString *)clear resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(clearCurrent: (nonnull NSNumber *)node resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(removeLast: (nonnull NSNumber *)node resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(removeMeasurement: (nonnull NSNumber *)node nodeId:(nonnull NSString *)nid resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(editMeasurement: (nonnull NSNumber *)node nodeId:(nonnull NSString *)nid nodeText:(nonnull NSString *)text resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addPoint: (nonnull NSNumber *)node setCurrent:(BOOL)current resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addPlane: (nonnull NSNumber *)node planeId:(nonnull NSString *)planeId left:(BOOL)left top:(BOOL)top right:(BOOL)right bottom:(BOOL)bottom resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getMeasurements: (nonnull NSNumber *)node resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getPlanes: (nonnull NSNumber *)node minArea:(nonnull NSNumber *)area resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(takePicture: (nonnull NSNumber *)node imagePath:(NSString*) path resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(saveToFile: (nonnull NSNumber *)node filePath:(NSString*) path resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(showPreview: (NSString*) path resolver: (RCTPromiseResolveBlock)resolve rejecter: (RCTPromiseRejectBlock)reject)
@end
