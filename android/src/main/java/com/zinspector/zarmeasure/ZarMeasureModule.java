package com.zinspector.zarmeasure;

import android.app.ActivityManager;


import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;


public class ZarMeasureModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;

    public ZarMeasureModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
    }

    @Override
    public String getName() {
        return "ZarMeasureModule";
    }


    @ReactMethod
    public void test(Promise promise) {
        promise.resolve("TEST!");
    }

}