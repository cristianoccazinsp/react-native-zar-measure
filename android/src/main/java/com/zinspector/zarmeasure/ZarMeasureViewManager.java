package com.zinspector.zarmeasure;

import androidx.annotation.Nullable;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.events.RCTEventEmitter;


public class ZarMeasureViewManager extends SimpleViewManager<ZarMeasureView> {
    public static final String REACT_CLASS = "ZarMeasureView";

    ReactApplicationContext mCallerContext;

    public ZarMeasureViewManager(ReactApplicationContext reactContext) {
        mCallerContext = reactContext;
    }

    @Override
    public String getName() {
        return REACT_CLASS;
    }

    @Override
    public ZarMeasureView createViewInstance(ThemedReactContext context) {
        return new ZarMeasureView(context);
    }

    @Override
    public void onDropViewInstance(ZarMeasureView view) {
        view.onHostDestroy();
        super.onDropViewInstance(view);
    }

    // @Override
    // public @Nullable Map getExportedCustomDirectEventTypeConstants() {
    //     return MapBuilder.of(
    //             "onImageLoadingFailed",
    //             MapBuilder.of("registrationName", "onImageLoadingFailed"),
    //             "onImageDownloaded",
    //             MapBuilder.of("registrationName", "onImageDownloaded"),
    //             "onImageLoaded",
    //             MapBuilder.of("registrationName", "onImageLoaded")
    //     );
    // }
}