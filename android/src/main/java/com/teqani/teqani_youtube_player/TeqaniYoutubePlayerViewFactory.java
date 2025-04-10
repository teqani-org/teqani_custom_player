package com.teqani.teqani_youtube_player;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

import java.util.HashMap;
import java.util.Map;

public class TeqaniYoutubePlayerViewFactory extends PlatformViewFactory {
    private final BinaryMessenger messenger;

    public TeqaniYoutubePlayerViewFactory(BinaryMessenger messenger) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
    }

    @NonNull
    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        // Cast args to Map safely
        Map<String, Object> creationParams = args != null ? (Map<String, Object>) args : new HashMap<>();
        
        // Create the TeqaniYoutubePlayerView with the creation params
        return new TeqaniYoutubePlayerView(context, viewId, creationParams, messenger);
    }
}
