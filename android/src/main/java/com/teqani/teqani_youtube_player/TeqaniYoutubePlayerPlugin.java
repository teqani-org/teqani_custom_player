package com.teqani.teqani_youtube_player;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import java.util.HashMap;
import java.util.Map;

/** TeqaniYoutubePlayerPlugin */
public class TeqaniYoutubePlayerPlugin implements FlutterPlugin, MethodCallHandler {
  private MethodChannel playerChannel;
  private MethodChannel factoryChannel;
  private EventChannel eventChannel;
  private Map<String, EventChannel.EventSink> eventSinks = new HashMap<>();

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    // Setup player channel
    playerChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "com.teqani.youtube_player/player");
    playerChannel.setMethodCallHandler(this);
    
    // Setup factory channel
    factoryChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "com.teqani.youtube_player/factory");
    factoryChannel.setMethodCallHandler(this);
    
    // Setup event channel
    eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "com.teqani.youtube_player/events");
    eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object arguments, EventChannel.EventSink events) {
        if (arguments instanceof String) {
          String id = (String) arguments;
          eventSinks.put(id, events);
        }
      }

      @Override
      public void onCancel(Object arguments) {
        if (arguments instanceof String) {
          String id = (String) arguments;
          eventSinks.remove(id);
        }
      }
    });
    
    // Register view factory
    flutterPluginBinding
      .getPlatformViewRegistry()
      .registerViewFactory(
        "com.teqani.youtube_player/player_view", 
        new TeqaniYoutubePlayerViewFactory(flutterPluginBinding.getBinaryMessenger())
      );
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    // Handle factory channel methods
    if (call.method.equals("create")) {
      int viewId = 0; // You can generate unique view IDs here if needed
      result.success(viewId);
      return;
    }
    
    // Handle player channel methods
    switch (call.method) {
      case "getPlatformVersion":
        result.success("Android " + android.os.Build.VERSION.RELEASE);
        break;
      case "initialize":
        // Handle initialization with parameters from the call.arguments map
        try {
          // For now, just acknowledge the call - implementation details will depend on how you handle the player
          result.success(null);
        } catch (Exception e) {
          result.error("INITIALIZATION_ERROR", "Failed to initialize player: " + e.getMessage(), null);
        }
        break;
      case "play":
        // Implement play functionality
        result.success(null);
        break;
      case "pause":
        // Implement pause functionality
        result.success(null);
        break;
      case "seekTo":
        // Implement seekTo functionality
        result.success(null);
        break;
      case "setPlaybackRate":
        // Implement playback rate change
        result.success(null);
        break;
      case "enterFullscreen":
        // Implement enter fullscreen
        result.success(null);
        break;
      case "exitFullscreen":
        // Implement exit fullscreen
        result.success(null);
        break;
      case "loadVideo":
        // Implement load video
        result.success(null);
        break;
      case "mute":
        // Implement mute
        result.success(null);
        break;
      case "unmute":
        // Implement unmute
        result.success(null);
        break;
      case "dispose":
        // Implement dispose
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    playerChannel.setMethodCallHandler(null);
    factoryChannel.setMethodCallHandler(null);
    eventChannel.setStreamHandler(null);
  }
  
  public static void sendEventToFlutter(String eventId, String eventName, Object eventData) {
    // This method can be called from the player view to send events to Flutter
    // Implementation would need to know which event sink to use
  }
}
