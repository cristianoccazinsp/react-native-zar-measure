package com.zinspector.zarmeasure;

import androidx.annotation.Nullable;
import android.widget.FrameLayout;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.events.RCTEventEmitter;



// Just placeholders for now

public class ZarMeasureView extends FrameLayout implements LifecycleEventListener {
    private static final String LOG_TAG = "ZarMeasureView";

    private ThemedReactContext _context;

    public ZarMeasureView(ThemedReactContext context) {
        super(context.getCurrentActivity());
        _context = context;
        context.addLifecycleEventListener(this);
    }

    private void emitEvent(String name, @Nullable WritableMap event) {
        if (event == null) {
            event = Arguments.createMap();
        }

        _context.getJSModule(RCTEventEmitter.class).receiveEvent(
                getId(),
                name,
                event
        );
    }

    public void cleanUp(){
        _context.removeLifecycleEventListener(this);
    }

    @Override
    public void onHostResume() {
        //Log.i(LOG_TAG, "onHostResume");
    }

    @Override
    public void onHostPause() {
        //Log.i(LOG_TAG, "onHostPause");
    }

    @Override
    public void onHostDestroy() {
        this.cleanUp();
        //Log.i(LOG_TAG, "onHostDestroy");
    }
}
