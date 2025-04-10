package com.teqani.teqani_youtube_player;

import android.content.Context;
import android.util.Log;
import android.view.View;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleObserver;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.OnLifecycleEvent;

import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.PlayerConstants;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.YouTubePlayer;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.listeners.AbstractYouTubePlayerListener;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.listeners.FullscreenListener;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.options.IFramePlayerOptions;
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.views.YouTubePlayerView;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import java.lang.reflect.Field;
import java.util.Map;

import kotlin.Unit;
import kotlin.jvm.functions.Function0;

public class TeqaniYoutubePlayerView implements PlatformView, MethodChannel.MethodCallHandler, LifecycleObserver {
    private final YouTubePlayerView youTubePlayerView;
    private final FrameLayout container;
    private final MethodChannel methodChannel;
    private final int viewId;
    private final Context context;
    
    private YouTubePlayer youTubePlayer;
    private boolean isPlayerInitialized = false;
    private boolean isPaused = false;
    private boolean isMuted = false;
    private PlayerConstants.PlaybackRate playbackRate = PlayerConstants.PlaybackRate.RATE_1;
    
    // Pending initialization parameters (in case player is not ready yet)
    private String pendingVideoId = null;
    private Boolean pendingAutoPlay = null;
    private Boolean pendingShowControls = null;
    private Boolean pendingMuted = null;
    private Integer pendingStartAt = null;
    private Integer pendingEndAt = null;

    private Function0<Unit> exitFullscreen = null;

    public TeqaniYoutubePlayerView(Context context, int viewId, Map<String, Object> creationParams, BinaryMessenger messenger) {
        this.viewId = viewId;
        this.context = context;
        
        // Create a container for the player
        container = new FrameLayout(context);
        
        // Setup method channel for player control
        methodChannel = new MethodChannel(messenger, "com.teqani.youtube_player/player_" + viewId);
        methodChannel.setMethodCallHandler(this);
        
        // Create the YouTube player view
        youTubePlayerView = new YouTubePlayerView(context);
        
        // Disable automatic initialization using reflection
        try {
            java.lang.reflect.Field autoInitField = YouTubePlayerView.class.getDeclaredField("enableAutomaticInitialization");
            autoInitField.setAccessible(true);
            autoInitField.set(youTubePlayerView, false);
            Log.d("YouTubePlayer", "Successfully disabled automatic initialization using reflection");
        } catch (Exception e) {
            Log.e("YouTubePlayer", "Error disabling automatic initialization: " + e.getMessage(), e);
        }
        
        // Add view to container
        container.addView(youTubePlayerView);
        
        // Initialize player with parameters
        initializePlayer(creationParams);
    }
    
    private void initializePlayer(Map<String, Object> creationParams) {
        Log.d("YouTubePlayer", "Initializing Player with params: " + creationParams);

        // Extract video ID
        String videoId = null;
        
        // Get video ID
        if (creationParams != null && creationParams.containsKey("videoId")) {
            videoId = (String) creationParams.get("videoId");
            Log.d("YouTubePlayer", "Initial video ID: " + videoId);
            pendingVideoId = videoId;
        } else if (creationParams != null && creationParams.containsKey("initialConfig")) {
            Map<String, Object> config = (Map<String, Object>) creationParams.get("initialConfig");
            if (config != null && config.containsKey("videoId")) {
                videoId = (String) config.get("videoId");
                Log.d("YouTubePlayer", "Found video ID in initialConfig: " + videoId);
                pendingVideoId = videoId;
            } else {
                Log.e("YouTubePlayer", "Video ID is missing in initialConfig");
            }
        } else {
            Log.e("YouTubePlayer", "Video ID is missing in creationParams");
        }

        // Build IFramePlayerOptions
        IFramePlayerOptions.Builder optionsBuilder = new IFramePlayerOptions.Builder();
        optionsBuilder.controls(1); // Show controls
        optionsBuilder.fullscreen(1); // Enable fullscreen button

        // Set related videos setting
        optionsBuilder.rel(0); // Don't show related videos

        // Build options
        IFramePlayerOptions options = optionsBuilder.build();

        // Add listener for player readiness and other events
        try {
            // Add listeners
            youTubePlayerView.addYouTubePlayerListener(new AbstractYouTubePlayerListener() {
                @Override
                public void onReady(@NonNull YouTubePlayer player) {
                    Log.d("YouTubePlayer", "Player is ready");
                    youTubePlayer = player;
                    isPlayerInitialized = true;
                    
                    // Load video if we have a pending ID
                    if (pendingVideoId != null) {
                        loadPendingVideoSettings();
                    }
                    
                    // Notify Flutter side that player is ready
                    methodChannel.invokeMethod("onReady", null);
                }
                
                @Override
                public void onError(@NonNull YouTubePlayer player, @NonNull PlayerConstants.PlayerError error) {
                    Log.e("YouTubePlayer", "Player error: " + error.toString());
                    methodChannel.invokeMethod("onError", error.toString());
                }
                
                @Override
                public void onStateChange(@NonNull YouTubePlayer player, @NonNull PlayerConstants.PlayerState state) {
                    methodChannel.invokeMethod("onStateChanged", state.toString());
                }
                
                @Override
                public void onCurrentSecond(@NonNull YouTubePlayer player, float second) {
                    // Only send updates occasionally to avoid flooding the channel
                    if (Math.floor(second) % 5 == 0) {
                        methodChannel.invokeMethod("onCurrentSecond", second);
                    }
                }
                
                @Override
                public void onVideoDuration(@NonNull YouTubePlayer player, float duration) {
                    methodChannel.invokeMethod("onVideoDuration", duration);
                }
            });

            // Add FullscreenListener
            youTubePlayerView.addFullscreenListener(new FullscreenListener() {
                @Override
                public void onEnterFullscreen(@NonNull View fullscreenView, @NonNull Function0<Unit> exitFullscreenAction) {
                    Log.d("YouTubePlayer", "Entering fullscreen");
                    TeqaniYoutubePlayerView.this.exitFullscreen = exitFullscreenAction;
                    methodChannel.invokeMethod("onEnterFullscreen", null);
                }

                @Override
                public void onExitFullscreen() {
                    Log.d("YouTubePlayer", "Exiting fullscreen");
                    TeqaniYoutubePlayerView.this.exitFullscreen = null;
                    methodChannel.invokeMethod("onExitFullscreen", null);
                }
            });

            // Initialize the player
            try {
                youTubePlayerView.initialize(new AbstractYouTubePlayerListener() {
                    @Override
                    public void onReady(@NonNull YouTubePlayer player) {
                        // This should not be called as we've already set up our listeners
                    }
                }, options);
                
                // Save pending settings for autoplay
                if (creationParams != null && creationParams.containsKey("autoPlay")) {
                    pendingAutoPlay = (Boolean) creationParams.get("autoPlay");
                } else if (creationParams != null && creationParams.containsKey("initialConfig")) {
                    Map<String, Object> config = (Map<String, Object>) creationParams.get("initialConfig");
                    if (config != null && config.containsKey("autoPlay")) {
                        pendingAutoPlay = (Boolean) config.get("autoPlay");
                    }
                }
            } catch (Exception e) {
                Log.e("YouTubePlayer", "Error initializing player: " + e.getMessage(), e);
                methodChannel.invokeMethod("onError", "Initialization error: " + e.getMessage());
            }
        } catch (Exception e) {
            Log.e("YouTubePlayer", "Error setting up YouTube player: " + e.getMessage(), e);
            methodChannel.invokeMethod("onError", "Setup error: " + e.getMessage());
        }
    }

    private void loadPendingVideoSettings() {
        if (youTubePlayer != null && pendingVideoId != null) {
            try {
                // Clean the video ID to make sure it's valid (remove any whitespace, etc.)
                String videoId = pendingVideoId.trim();
                Log.d("YouTubePlayer", "Loading video ID: " + videoId);
                
                if (pendingStartAt != null) {
                    float startTime = pendingStartAt;
                    if (pendingAutoPlay != null && pendingAutoPlay) {
                        youTubePlayer.loadVideo(videoId, startTime);
                    } else {
                        youTubePlayer.cueVideo(videoId, startTime);
                    }
                } else {
                    if (pendingAutoPlay != null && pendingAutoPlay) {
                        youTubePlayer.loadVideo(videoId, 0);
                    } else {
                        youTubePlayer.cueVideo(videoId, 0);
                    }
                }
                
                if (pendingMuted != null && pendingMuted) {
                    youTubePlayer.mute();
                    isMuted = true;
                }
            } catch (Exception e) {
                Log.e("YouTubePlayer", "Error loading video: " + e.getMessage());
                methodChannel.invokeMethod("onError", "Error loading video: " + e.getMessage());
            }
            
            // Clear pending state
            pendingVideoId = null;
            pendingAutoPlay = null;
            pendingShowControls = null;
            pendingMuted = null;
            pendingStartAt = null;
            pendingEndAt = null;
        }
    }

    private void applyPendingOperations() {
        if (pendingVideoId != null) {
            loadPendingVideoSettings();
        }
        
        // Apply other player settings
        if (isMuted) {
            youTubePlayer.mute();
        }
        
        if (playbackRate != PlayerConstants.PlaybackRate.RATE_1) {
            youTubePlayer.setPlaybackRate(playbackRate);
        }
    }

    @Override
    public View getView() {
        return container;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "initialize":
                handleInitialize(call, result);
                break;
            case "play":
                if (youTubePlayer != null) {
                    youTubePlayer.play();
                    isPaused = false;
                }
                result.success(null);
                break;
            case "pause":
                if (youTubePlayer != null) {
                    youTubePlayer.pause();
                    isPaused = true;
                }
                result.success(null);
                break;
            case "seekTo":
                if (youTubePlayer != null && call.argument("seconds") != null) {
                    double seconds = call.argument("seconds");
                    youTubePlayer.seekTo((float) seconds);
                }
                result.success(null);
                break;
            case "setPlaybackRate":
                if (youTubePlayer != null && call.argument("rate") != null) {
                    double rate = call.argument("rate");
                    PlayerConstants.PlaybackRate pbRate = convertToPlaybackRate(rate);
                    playbackRate = pbRate;
                    youTubePlayer.setPlaybackRate(pbRate);
                }
                result.success(null);
                break;
            case "enterFullscreen":
                if (youTubePlayerView != null) {
                    methodChannel.invokeMethod("onFullscreenChange", true);
                }
                result.success(null);
                break;
            case "exitFullscreen":
                if (youTubePlayerView != null) {
                    methodChannel.invokeMethod("onFullscreenChange", false);
                }
                result.success(null);
                break;
            case "loadVideo":
                handleLoadVideo(call, result);
                break;
            case "mute":
                if (youTubePlayer != null) {
                    youTubePlayer.mute();
                    isMuted = true;
                }
                result.success(null);
                break;
            case "unmute":
                if (youTubePlayer != null) {
                    youTubePlayer.unMute();
                    isMuted = false;
                }
                result.success(null);
                break;
            case "toggleFullscreen":
                Log.d("YouTubePlayer", "Toggle Fullscreen requested");
                 if (this.exitFullscreen != null) {
                    Log.d("YouTubePlayer", "Exiting fullscreen via function");
                    this.exitFullscreen.invoke(); // Use invoke() for Function0
                 } else {
                     Log.w("YouTubePlayer", "Not currently fullscreen, cannot exit.");
                     // We don't enter fullscreen programmatically here,
                     // It's typically handled by the player's UI button.
                     // If programmatic entering is needed, it requires different handling.
                 }
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }
    
    private PlayerConstants.PlaybackRate convertToPlaybackRate(double rate) {
        if (rate <= 0.25) return PlayerConstants.PlaybackRate.RATE_0_25;
        if (rate <= 0.5) return PlayerConstants.PlaybackRate.RATE_0_5;
        if (Math.abs(rate - 1.0) < 0.1) return PlayerConstants.PlaybackRate.RATE_1;
        if (rate <= 1.5) return PlayerConstants.PlaybackRate.RATE_1_5;
        return PlayerConstants.PlaybackRate.RATE_2;
    }
    
    private void handleLoadVideo(MethodCall call, MethodChannel.Result result) {
        if (call.arguments != null && call.arguments instanceof Map) {
            Map<String, Object> args = call.arguments();
            
            // Get video ID (required)
            String videoId = (String) args.get("videoId");
            if (videoId == null) {
                result.error("INVALID_PARAMETER", "VideoId cannot be null", null);
                return;
            }
            
            // Get optional parameters
            Boolean autoPlay = (Boolean) args.get("autoPlay");
            Integer startAt = (Integer) args.get("startAt");
            
            if (!isPlayerInitialized) {
                // Save params for when player is ready
                pendingVideoId = videoId;
                pendingAutoPlay = autoPlay;
                pendingStartAt = startAt;
                
                result.success(null);
                return;
            }
            
            // If player is already initialized, apply settings immediately
            if (startAt != null) {
                float startTime = startAt;
                if (autoPlay != null && autoPlay) {
                    youTubePlayer.loadVideo(videoId, startTime);
                } else {
                    youTubePlayer.cueVideo(videoId, startTime);
                }
            } else {
                if (autoPlay != null && autoPlay) {
                    youTubePlayer.loadVideo(videoId, 0);
                } else {
                    youTubePlayer.cueVideo(videoId, 0);
                }
            }
            
            result.success(null);
        } else {
            result.error("INVALID_PARAMETER", "Arguments are null or not a Map", null);
        }
    }
    
    private void handleInitialize(MethodCall call, MethodChannel.Result result) {
        try {
            if (call.arguments != null && call.arguments instanceof Map) {
                Map<String, Object> args = call.arguments();
                
                // Get video ID (required)
                String videoId = (String) args.get("videoId");
                if (videoId == null || videoId.trim().isEmpty()) {
                    result.error("INVALID_PARAMETER", "VideoId cannot be null or empty", null);
                    return;
                }
                videoId = videoId.trim(); // Clean up video ID
                
                // Log the parameters for debugging
                Log.d("YouTubePlayer", "Initializing with video ID: " + videoId);
                
                // Get optional parameters
                Boolean autoPlay = (Boolean) args.get("autoPlay");
                Boolean showControls = (Boolean) args.get("showControls");
                Boolean muted = (Boolean) args.get("muted");
                Integer startAt = (Integer) args.get("startAt");
                Integer endAt = (Integer) args.get("endAt");
                
                if (!isPlayerInitialized) {
                    // Save params for when player is ready
                    pendingVideoId = videoId;
                    pendingAutoPlay = autoPlay;
                    pendingShowControls = showControls;
                    pendingMuted = muted;
                    pendingStartAt = startAt;
                    pendingEndAt = endAt;
                    
                    Log.d("YouTubePlayer", "Player not initialized yet, saved parameters for later");
                    result.success(null);
                    return;
                }
                
                // If player is already initialized, apply settings immediately
                try {
                    if (startAt != null) {
                        float startTime = startAt;
                        if (autoPlay != null && autoPlay) {
                            youTubePlayer.loadVideo(videoId, startTime);
                        } else {
                            youTubePlayer.cueVideo(videoId, startTime);
                        }
                    } else {
                        if (autoPlay != null && autoPlay) {
                            youTubePlayer.loadVideo(videoId, 0);
                        } else {
                            youTubePlayer.cueVideo(videoId, 0);
                        }
                    }
                    
                    if (muted != null && muted) {
                        youTubePlayer.mute();
                        isMuted = true;
                    }
                    
                    Log.d("YouTubePlayer", "Video initialized successfully");
                    result.success(null);
                } catch (Exception e) {
                    Log.e("YouTubePlayer", "Error initializing video: " + e.getMessage());
                    result.error("INITIALIZATION_ERROR", "Error initializing video: " + e.getMessage(), null);
                }
            } else {
                result.error("INVALID_PARAMETER", "Arguments are null or not a Map", null);
            }
        } catch (Exception e) {
            Log.e("YouTubePlayer", "Exception in handleInitialize: " + e.getMessage());
            result.error("EXCEPTION", "Exception in handleInitialize: " + e.getMessage(), null);
        }
    }
    
    @Override
    public void dispose() {
        if (youTubePlayerView != null) {
            youTubePlayerView.release();
        }
        methodChannel.setMethodCallHandler(null);
    }
    
    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    public void onDestroy() {
        Log.d("YouTubePlayer", "Releasing YouTubePlayerView");
        if (youTubePlayerView != null) {
            youTubePlayerView.release();
        }
        methodChannel.setMethodCallHandler(null);
    }
}
