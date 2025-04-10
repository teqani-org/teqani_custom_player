package com.teqani.teqani_youtube_player_example;

import androidx.annotation.NonNull;
import com.teqani.teqani_youtube_player.TeqaniYoutubePlayerPlugin;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // The plugin is registered automatically by the Flutter framework with the 
        // FlutterPlugin interface, so we don't need to manually register it anymore
    }
}
