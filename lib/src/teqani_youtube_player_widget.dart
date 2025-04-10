import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:teqani_youtube_player/src/models/ad_config.dart';
import 'package:teqani_youtube_player/src/models/player_state.dart';
import 'package:teqani_youtube_player/src/models/watermark_config.dart';
import 'package:teqani_youtube_player/src/teqani_youtube_player_controller.dart';
import 'package:teqani_youtube_player/src/widgets/ad_overlay.dart';
import 'package:teqani_youtube_player/src/widgets/video_quality_controls.dart';
import 'package:teqani_youtube_player/src/widgets/watermark_overlay.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// --- Ad Feature ---
/// --- End Ad Feature ---

/// Configuration for the appearance of the settings button overlay.
class SettingsButtonConfig {

  /// Creates a configuration for the settings button.
  const SettingsButtonConfig({
    this.icon = Icons.settings,
    this.iconSize = 24.0,
    this.iconColor = Colors.white,
    this.backgroundColor = const Color.fromRGBO(0, 0, 0, 0.5), // Default to semi-transparent black
    this.size = 40.0,
    this.borderColor = Colors.white,
    this.borderWidth = 1.0, // Default to 1px border
    this.elevation = 2.0, // Default to subtle elevation
    this.shape, 
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(8.0),
    this.visible = true,
  });
  /// The icon to display on the button.
  final IconData icon;
  
  /// The size of the icon.
  final double iconSize;
  
  /// The color of the icon.
  final Color iconColor;
  
  /// The background color of the button.
  final Color backgroundColor;
  
  /// The size (width and height) of the button.
  final double size;
  
  /// The color of the button's border.
  final Color borderColor;
  
  /// The width of the button's border.
  final double borderWidth;
  
  /// The elevation of the button (shadow).
  final double elevation;
  
  /// The shape of the button. Defaults to a circle if null.
  final ShapeBorder? shape;
  
  /// The alignment of the button within the player bounds.
  /// Defaults to [Alignment.topRight].
  final AlignmentGeometry alignment;
  
  /// The padding around the button.
  /// Defaults to `EdgeInsets.all(8.0)`.
  final EdgeInsetsGeometry padding;
  
  /// Whether the settings button should be visible.
  /// Defaults to `true`.
  final bool visible;
}

/// A custom YouTube Player widget that displays YouTube videos without external dependencies.
class TeqaniYoutubePlayer extends StatefulWidget {
  
  /// Creates a TeqaniYoutubePlayer widget
  const TeqaniYoutubePlayer({
    super.key,
    required this.controller,
    this.showControls = true,
    this.loadingIndicatorColor = Colors.red,
    this.backgroundColor = Colors.black,
    this.aspectRatio = 16 / 9,
    this.allowFullscreen = true,
    this.handleKeyboardEvents = true,
    this.keepScreenAwake = true,
    this.enableHardwareAcceleration = true,
    this.disableVibration = true,
    this.showQualitySettings = true,
    this.showFilterSettings = true,
    this.settingsButtonConfig,
  });
  /// The controller for this player
  final TeqaniYoutubePlayerController controller;
  
  /// Whether to show custom controls (kept for backward compatibility, but native YouTube controls are used instead)
  final bool showControls;
  
  /// Color for the loading indicator
  final Color loadingIndicatorColor;
  
  /// Background color of the player
  final Color backgroundColor;
  
  /// Aspect ratio for the player (width / height)
  final double aspectRatio;
  
  /// Whether to allow fullscreen mode
  final bool allowFullscreen;
  
  /// Whether to handle keyboard events for seek controls
  final bool handleKeyboardEvents;
  
  /// Keep screen awake while playing
  final bool keepScreenAwake;
  
  /// Whether to enable hardware acceleration
  final bool enableHardwareAcceleration;
  
  /// Whether to disable vibration feedback on long press
  final bool disableVibration;
  
  /// Whether to show quality settings in the settings menu
  final bool showQualitySettings;
  
  /// Whether to show video filter settings in the settings menu
  final bool showFilterSettings;
  
  /// Optional configuration for the settings button overlay.
  final SettingsButtonConfig? settingsButtonConfig;

  @override
  State<TeqaniYoutubePlayer> createState() => _TeqaniYoutubePlayerState();
}

class _TeqaniYoutubePlayerState extends State<TeqaniYoutubePlayer> with WidgetsBindingObserver {
  /// Whether the player is initialized
  bool _isInitialized = false;
  
  /// Whether the device is in landscape mode
  bool _isLandscape = false;
  
  /// Whether the watermark should be visible
  bool _showWatermark = false;
  
  /// Timer for controlling timed watermarks
  Timer? _watermarkTimer;
  
  /// For throttling UI updates
  Timer? _throttleTimer;
    
  /// For auto-hiding settings button
  bool _controlsVisible = true;
  
  /// Timer to check for YouTube controls visibility
  Timer? _ytControlsCheckTimer;
  
  /// Controller listener function
  late VoidCallback _controllerListener;

  /// --- Ad State (COMMENTED OUT temporarily) ---
  /*
  List<AdConfig> _ads = [];
  AdConfig? _activeAd;
  Timer? _adTimer;
  final Set<String> _playedAdIds = {};
  Duration? _lastPosition;
  */
  /// --- End Ad State ---

  AdConfig? _activeAd;
  Timer? _adTimer;
  final Set<String> _playedAdIds = {}; // Track which ads have been shown
  final Map<String, Set<int>> _playedPeriodicAdTimes = {}; // Track when periodic ads were shown
  
  // Variables to detect seek/position changes
  double _lastCheckedPosition = 0.0;
  DateTime? _lastSeekTime;
  final _seekCooldownDuration = const Duration(seconds: 3); // Cooldown after seeking
  
  // Post-ad cooldown tracking
  DateTime? _lastAdSkipTime;
  final _postAdCooldownDuration = const Duration(seconds: 5); // Cooldown after an ad is skipped

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Debug print for initial ad configuration
    debugPrint('Initial ad configuration: ${widget.controller.initialConfig.ads}');
    
    // Keep local state in sync with controller
    
    // Add controller listener 
    _controllerListener = () {
      if (!mounted) return; // Ensure widget is still mounted

      // Debug print for player state changes
      debugPrint('Player state changed to: ${widget.controller.playerState}');

      // --- Throttled UI State Update --- 
      if (!(_throttleTimer?.isActive ?? false)) {
         _throttleTimer = Timer(const Duration(milliseconds: 500), () {
           if (mounted) {
             setState(() {
               // Force rebuild to check for ads when player state changes
               _checkForAds();
             });
           }
         });
      }
      // --- End Throttled UI State Update --- 
      
      // Prevent video playback while ad is active
      if (_activeAd != null) {
        debugPrint('Ad is active, ensuring video is paused');
        // Pause at both Flutter and WebView level
        widget.controller.pause();
        widget.controller.webViewController.runJavaScript('''
          if (document.querySelector('video')) {
            document.querySelector('video').pause();
          }
        ''');
      }
    };
    
    widget.controller.addListener(_controllerListener);
    
    // Handle fullscreen - disable fullscreen button and double-click if configured
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _initializePlayer();
    });
    
    _setupWatermark();

    if (widget.keepScreenAwake) {
      WakelockPlus.enable();
    }

    // Set up keyboard listener if needed
    if (widget.handleKeyboardEvents) {
      HardwareKeyboard.instance.addHandler(_handleKeyPress);
    }
    
    // Start a timer to check YouTube controls visibility (more frequently)
    _ytControlsCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkYouTubeControlsVisibility();
    });

    // Start a timer to check for ads more frequently to improve reliability
    Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        _checkForAds();
      }
    });
  }

  @override
  void didUpdateWidget(TeqaniYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if video ID changed
    if (widget.controller.initialConfig.videoId != oldWidget.controller.initialConfig.videoId) {
      // _resetAdState(); // COMMENTED OUT
      // _ads = widget.controller.initialConfig.ads ?? []; // COMMENTED OUT
      final allowFullscreen = widget.controller.initialConfig.allowFullscreen;
      if (!allowFullscreen) {
        _ensureFullscreenDisabled();
      }
    }
    
    // Track controller change
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerListener);
      // _resetAdState(); // COMMENTED OUT
      // _ads = widget.controller.initialConfig.ads ?? []; // COMMENTED OUT
      widget.controller.addListener(_controllerListener);
      final allowFullscreen = widget.controller.initialConfig.allowFullscreen;
      if (!allowFullscreen) {
        _ensureFullscreenDisabled();
      }
    }
  }

  @override
  void dispose() {
    // Platform channels for haptic feedback removed
    
    widget.controller.removeListener(_controllerListener);
    _watermarkTimer?.cancel();
    _ytControlsCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    if (widget.handleKeyboardEvents) {
      HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    }
    
    if (widget.keepScreenAwake) {
      WakelockPlus.disable();
    }
    
    _adTimer?.cancel();
    _playedAdIds.clear(); // Clear played ads when widget is disposed
    _playedPeriodicAdTimes.clear(); // Clear periodic ad tracking
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume playback if it was playing before, with delay
      if (widget.controller.playerState == PlayerState.playing) {
        Future.delayed(const Duration(milliseconds: 300), () {
        widget.controller.play();
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // Pause playback when app goes to background
      if (widget.controller.playerState == PlayerState.playing) {
        widget.controller.pause();
      }
    }
  }
  
  /// Initialize the player
  Future<void> _initializePlayer() async {
    try {
      await widget.controller.initialize();
      
      // After initialization, check if fullscreen should be disabled
      final allowFullscreen = widget.controller.initialConfig.allowFullscreen;
      if (!allowFullscreen) {
        await _ensureFullscreenDisabled();
      }
      
      if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      }
    } catch (e) {
      debugPrint('Failed to initialize player: $e');
    }
  }
  
  /// Setup watermark timers if needed
  void _setupWatermark() {
    final config = widget.controller.initialConfig;
    
    // Text watermark
    if (config.textWatermark != null) {
      _showWatermark = true;
      
      if (config.textWatermark!.durationType == WatermarkDuration.timed &&
          config.textWatermark!.durationSeconds != null) {
        _watermarkTimer = Timer(
          Duration(seconds: config.textWatermark!.durationSeconds!),
          () {
            if (mounted) {
              setState(() {
                _showWatermark = false;
              });
            }
          },
        );
      }
    }
    
    // Image watermark
    if (config.imageWatermark != null) {
      _showWatermark = true;
      
      if (config.imageWatermark!.durationType == WatermarkDuration.timed &&
          config.imageWatermark!.durationSeconds != null &&
          (_watermarkTimer == null || !_watermarkTimer!.isActive)) {
        _watermarkTimer = Timer(
          Duration(seconds: config.imageWatermark!.durationSeconds!),
          () {
            if (mounted) {
              setState(() {
                _showWatermark = false;
              });
            }
          },
        );
      }
    }
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        widget.controller.fastForward(10);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        widget.controller.rewind(10);
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        if (widget.controller.isPlaying) {
          widget.controller.pause();
        } else {
          widget.controller.play();
        }
      }
    }
    return true;
  }
  

  // Check YouTube controls visibility using a more robust method
  void _checkYouTubeControlsVisibility() {
    if (!_isInitialized || !mounted) return;
    
    widget.controller.webViewController.runJavaScriptReturningResult('''
      (function() {
        try {
          const playerElement = document.querySelector('.html5-video-player');
          // Check if the player has the 'ytp-autohide' class, which indicates controls are hidden
          const controlsHidden = playerElement && playerElement.classList.contains('ytp-autohide');
          
          // Return true if controls are VISIBLE (i.e., NOT hidden)
          return !controlsHidden;
        } catch (e) {
          console.error('Error checking YouTube controls visibility (autohide):', e);
          return true; // Default to visible on error
        }
      })();
    ''').then((result) {
      if (!mounted) return; // Check if still mounted after async operation
      try {
        // ignore: unnecessary_null_comparison
        if (result != null) {
          // Ensure result is parsed as boolean correctly
          final bool visible = result is bool ? result : (result.toString().toLowerCase() == 'true');
          
          if (visible != _controlsVisible) {
            setState(() {
              _controlsVisible = visible;
            });
          }
        }
      } catch (e) {
        debugPrint('Error parsing or updating controls visibility: $e');
      }
    }).catchError((e) {
      debugPrint('Error executing JS for controls visibility: $e');
      // Optionally default to visible on error
      if (mounted && !_controlsVisible) {
        setState(() {
          _controlsVisible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _isLandscape = mediaQuery.orientation == Orientation.landscape;
    
    // Get the settings button config or use default
    final settingsConfig = widget.settingsButtonConfig ?? const SettingsButtonConfig();
    
    return AspectRatio(
      aspectRatio: _isLandscape ? mediaQuery.size.width / mediaQuery.size.height : widget.aspectRatio,
      child: ColoredBox(
        color: widget.backgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Player surface with interaction detector
            GestureDetector(
              onTap: () {
                // Show YouTube controls
                widget.controller.webViewController.runJavaScript('''
                  document.querySelector('video')?.click();
                ''');
                
                // Trigger an immediate visibility check after tap
                Future.delayed(const Duration(milliseconds: 100), () {
                  _checkYouTubeControlsVisibility();
                });
              },
              child: _buildPlayerSurface(),
            ),
            
            // Ad Overlay
            _buildAdOverlay(),
            
            // Loading indicator
            if (!widget.controller.isReady)
              RepaintBoundary(
                child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(widget.loadingIndicatorColor),
                  ),
                ),
              ),
            
            // Network error overlay
            if (widget.controller.lastError?.code == -2)
              RepaintBoundary(child: _buildNetworkErrorOverlay()),
            
            // Watermark overlay
            if (_showWatermark && widget.controller.isReady)
              RepaintBoundary(
                child: WatermarkOverlay(
                textWatermark: widget.controller.initialConfig.textWatermark,
                imageWatermark: widget.controller.initialConfig.imageWatermark,
                ),
              ),
            
            // Settings button that syncs with YouTube controls visibility
            if (settingsConfig.visible &&
                _isInitialized && 
                (widget.showQualitySettings || widget.showFilterSettings) &&
                _activeAd == null) // Hide settings button when an ad is active
              Align(
                alignment: settingsConfig.alignment,
                child: Padding(
                  padding: settingsConfig.padding,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: _buildSettingsButton(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Build a reliable settings button that uses the provided config
  Widget _buildSettingsButton() {
    // Use provided config or default values
    final config = widget.settingsButtonConfig ?? const SettingsButtonConfig();
    
    // Determine the shape, defaulting to CircleBorder
    final shape = config.shape ?? CircleBorder(
      side: BorderSide(
        color: config.borderColor, 
        width: config.borderWidth,
      ),
    );
    
    // If the shape is CircleBorder, use radius calculation, otherwise default to null

    return Material(
      type: MaterialType.canvas, // Use canvas for custom shapes
      shape: shape,
      elevation: config.elevation,
      color: config.backgroundColor,
      clipBehavior: Clip.antiAlias, // Ensure content respects the shape
      child: InkWell(
        // Use customBorder only if shape is defined, otherwise let InkWell handle defaults
        customBorder: shape, 
        onTap: () => _showVideoQualityControlsDialog(context),
        child: SizedBox(
          width: config.size,
          height: config.size,
          // Decoration is now handled by Material shape and color
          child: Center( // Center the icon
            child: Icon(
              config.icon,
              color: config.iconColor,
              size: config.iconSize,
            ),
          ),
        ),
      ),
    );
  }
  
  /// Builds the network error overlay with retry button
  Widget _buildNetworkErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.signal_wifi_off,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reloadPlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Reload the player to retry connection
  void _reloadPlayer() {
    widget.controller.clearError();
    setState(() {
      _isInitialized = false;
    });
    widget.controller.webViewController.reload();
    _initializePlayer();
  }

  /// Build the WebView player surface with performance optimizations
  Widget _buildPlayerSurface() {
    if (!_isInitialized) {
      return const SizedBox.expand();
    }
    
    // Create the WebView widget
    final webView = WebViewWidget(
      controller: widget.controller.webViewController,
      gestureRecognizers: {
        // Only include tap recognizer for basic interaction
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      },
    );

    // Use a vibration-cancelling approach that still allows touch
    if (widget.disableVibration) {
      return RepaintBoundary(
        child: GestureDetector(
          // Empty callbacks for all gestures to prevent default behavior
          onLongPress: () {},
          onLongPressStart: (_) {},
          onLongPressEnd: (_) {},
          onLongPressMoveUpdate: (_) {},
          onForcePressStart: (_) {},
          onForcePressEnd: (_) {},
          onForcePressPeak: (_) {},
          onForcePressUpdate: (_) {},
          // Let touches pass through but also capture taps
          behavior: HitTestBehavior.translucent,
          child: webView,
        ),
      );
    }
    
    return RepaintBoundary(child: webView);
  }

  /// Ensures fullscreen is properly disabled at various key times
  Future<void> _ensureFullscreenDisabled() async {
    // First attempt - may fail if player not ready
    await widget.controller.disableFullscreen();
    
    // Schedule additional attempts to ensure it takes effect
    for (int delay in [1000, 3000, 5000]) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) {
          widget.controller.disableFullscreen();
        }
      });
    }
  }
  
  /// Shows a dialog with video quality and sharpness controls
  void _showVideoQualityControlsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: VideoQualityControls(
          controller: widget.controller,
          showQualitySettings: widget.showQualitySettings,
          showFilterSettings: widget.showFilterSettings,
          onSettingsApplied: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// --- Ad Management Methods (COMMENTED OUT temporarily) ---
  /*
  void _resetAdState() {
    _adTimer?.cancel();
    _adTimer = null;
    _activeAd = null;
    _playedAdIds.clear();
    if (mounted) {
      setState(() {}); 
    }
  }

  void _checkForAdTriggers(Duration currentPosition, Duration totalDuration, PlayerState state) {
    if (_activeAd != null || _ads.isEmpty) return;
    for (final ad in _ads) {
      if (_playedAdIds.contains(ad.id)) continue;
      bool shouldTrigger = false;
      switch (ad.displayTime) {
        case AdDisplayTime.start:
          if (currentPosition <= const Duration(seconds: 1) && state == PlayerState.playing) {
             shouldTrigger = true;
          }
          break;
        case AdDisplayTime.end:
          if (state == PlayerState.ended) {
             shouldTrigger = true;
          }
          break;
        case AdDisplayTime.custom:
          if (currentPosition >= ad.customStartTime! &&
              currentPosition < ad.customStartTime! + const Duration(milliseconds: 500)) {
             shouldTrigger = true;
          }
          break;
      }
      if (shouldTrigger) {
        _showAd(ad);
        break; 
      }
    }
  }

  void _showAd(AdConfig ad) {
    if (!mounted || _activeAd != null) return;
    debugPrint('Showing Ad: ${ad.id}');
    widget.controller.pause(); 
    setState(() {
      _activeAd = ad;
      _playedAdIds.add(ad.id); 
    });
    _adTimer?.cancel();
    _adTimer = Timer(ad.duration, _hideAd);
  }

  void _hideAd() {
    if (!mounted || _activeAd == null) return;
    debugPrint('Hiding Ad: ${_activeAd!.id}');
    _adTimer?.cancel();
    _adTimer = null;
    setState(() {
      _activeAd = null;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && 
          widget.controller.playerState != PlayerState.ended && 
          widget.controller.playerState != PlayerState.paused) { 
        widget.controller.play();
      }
    });
  }
  */
  /// --- End Ad Management Methods ---

  void _startAd(AdConfig ad, [int? timeMarker]) {
    // For one-time ads, track that we've shown this ad
    if (ad.displayTime != AdDisplayTime.everyMinute && 
        ad.displayTime != AdDisplayTime.everyTwoMinutes && 
        ad.displayTime != AdDisplayTime.everyFiveMinutes) {
      _playedAdIds.add(ad.id);
    } 
    // For periodic ads, track the specific time marker
    else if (timeMarker != null) {
      _playedPeriodicAdTimes.putIfAbsent(ad.id, () => {}).add(timeMarker);
    }

    // Ensure video is paused at both Flutter and WebView level
    widget.controller.pause();
    widget.controller.webViewController.runJavaScript('''
      if (document.querySelector('video')) {
        document.querySelector('video').pause();
      }
    ''');

    setState(() {
      _activeAd = ad;
    });

    _adTimer?.cancel();
    _adTimer = Timer(ad.duration, () {
      setState(() {
        _activeAd = null;
      });
      // Resume video playback after ad ends
      if (widget.controller.playerState != PlayerState.ended) {
        widget.controller.play();
      }
    });
  }

  // Check if the user has recently performed a seek operation
  bool _hasRecentlyPerformedSeek(double currentPosition) {
    // If position changed significantly (more than 2 seconds), it's likely a seek operation
    final positionDelta = (currentPosition - _lastCheckedPosition).abs();
    final isSignificantJump = positionDelta > 2.0;
    
    if (isSignificantJump) {
      debugPrint('Detected position jump: from $_lastCheckedPosition to $currentPosition (delta: $positionDelta)');
      _lastSeekTime = DateTime.now();
      _lastCheckedPosition = currentPosition;
      return true;
    }
    
    // Update last position for future checks
    _lastCheckedPosition = currentPosition;
    
    // Check if we're within the cooldown period of a previous seek
    if (_lastSeekTime != null) {
      final timeSinceSeek = DateTime.now().difference(_lastSeekTime!);
      final isInCooldown = timeSinceSeek < _seekCooldownDuration;
      
      if (isInCooldown) {
        debugPrint('Still in seek cooldown: ${_seekCooldownDuration.inSeconds - timeSinceSeek.inSeconds}s remaining');
      } else {
        // Reset seek time if cooldown has passed
        _lastSeekTime = null;
      }
      
      return isInCooldown;
    }
    
    return false;
  }

  Widget _buildAdOverlay() {
    debugPrint('Building ad overlay...');
    debugPrint('Ads configuration: ${widget.controller.initialConfig.ads}');
    
    if (widget.controller.initialConfig.ads == null || 
        widget.controller.initialConfig.ads!.isEmpty) {
      debugPrint('No ads configured in controller');
      return const SizedBox.shrink();
    }

    // If there's an active ad, show it
    if (_activeAd != null) {
      debugPrint('Showing active ad: ${_activeAd!.id}');
      debugPrint('Active ad details: displayTime=${_activeAd!.displayTime}, duration=${_activeAd!.duration}');
      // Ensure video is paused at both Flutter and WebView level
      widget.controller.pause();
      widget.controller.webViewController.runJavaScript('''
        if (document.querySelector('video')) {
          document.querySelector('video').pause();
        }
      ''');

      // Return the ad overlay directly, no need for nested stacks
      return AdOverlay(
        adConfig: _activeAd!,
        onAdComplete: () {
          debugPrint('Ad ${_activeAd!.id} completed manually');
          setState(() {
            _activeAd = null;
          });
          // Resume video playback when ad is manually closed
          if (widget.controller.playerState != PlayerState.ended) {
            widget.controller.play();
          }
        },
        onSkipAd: _activeAd!.isSkippable ? () {
          debugPrint('Ad ${_activeAd!.id} skipped by user');
          // Cancel the automatic ad timer
          _adTimer?.cancel();
          setState(() {
            _activeAd = null;
          });
          // Set cooldown after skipping an ad
          _lastAdSkipTime = DateTime.now();
          // Resume video playback after ad is skipped
          if (widget.controller.playerState != PlayerState.ended) {
            widget.controller.play();
          }
        } : null,
      );
    }

    return const SizedBox.shrink();
  }

  // Check if we're in the post-ad cooldown period
  bool _isInPostAdCooldown() {
    if (_lastAdSkipTime == null) return false;
    
    final timeSinceAdSkip = DateTime.now().difference(_lastAdSkipTime!);
    final isInCooldown = timeSinceAdSkip < _postAdCooldownDuration;
    
    if (isInCooldown) {
      debugPrint('Still in post-ad cooldown: ${_postAdCooldownDuration.inSeconds - timeSinceAdSkip.inSeconds}s remaining');
    } else {
      // Reset skip time if cooldown has passed
      _lastAdSkipTime = null;
    }
    
    return isInCooldown;
  }

  void _checkForAds() {
    if (!mounted || widget.controller.initialConfig.ads == null || 
        widget.controller.initialConfig.ads!.isEmpty) {
      return;
    }

    // Don't check for ads until player is ready
    if (!widget.controller.isReady) {
      debugPrint('Player not ready for ads yet - isReady: ${widget.controller.isReady}');
      return;
    }

    // If an ad is already showing, don't check for new ones
    if (_activeAd != null) {
      return;
    }

    // Get current position and duration from video element
    widget.controller.webViewController.runJavaScriptReturningResult('''
      (function() {
        const video = document.querySelector('video');
        const position = video ? video.currentTime : 0;
        const duration = video ? video.duration : 0;
        return { position: position, duration: duration };
      })();
    ''').then((result) {
      // ignore: unnecessary_null_comparison
      if (result != null) {
        try {
          // The result is already an object, no need to parse JSON
          double? position;
          double? duration;
          
          if (result is Map) {
            // Direct access if it's already a Map
            position = double.tryParse(result['position'].toString());
            duration = double.tryParse(result['duration'].toString());
          } else {
            // Try to extract values from the result string
            final resultStr = result.toString();
            debugPrint('Raw result type: ${result.runtimeType}, value: $resultStr');
            
            // Use RegExp to extract values
            final positionMatch = RegExp(r'"?position"?\s*:\s*([0-9.]+)').firstMatch(resultStr);
            final durationMatch = RegExp(r'"?duration"?\s*:\s*([0-9.]+)').firstMatch(resultStr);
            
            if (positionMatch != null && positionMatch.groupCount >= 1) {
              position = double.tryParse(positionMatch.group(1)!);
            }
            
            if (durationMatch != null && durationMatch.groupCount >= 1) {
              duration = double.tryParse(durationMatch.group(1)!);
            }
          }
          
          if (position != null && duration != null) {
            final currentPositionSeconds = position;
            final totalDurationSeconds = duration;
            final playerState = widget.controller.playerState;

            // Skip ad checks if we've recently performed a seek operation
            if (_hasRecentlyPerformedSeek(currentPositionSeconds)) {
              debugPrint('Skipping ad checks due to recent seek operation');
              return;
            }
            
            // Skip ad checks if we're in post-ad cooldown period
            if (_isInPostAdCooldown()) {
              debugPrint('Skipping ad checks due to recent ad skip');
              return;
            }

            debugPrint('Checking for ads - Position: $currentPositionSeconds, Duration: $totalDurationSeconds, State: $playerState');

            // Check for ads based on display time
            for (final ad in widget.controller.initialConfig.ads!) {
              debugPrint('Checking ad: ${ad.id} with displayTime: ${ad.displayTime}');
              
              // Check if this ad should be skipped based on display time
              bool isPeriodicAd = ad.displayTime == AdDisplayTime.everyMinute || 
                                ad.displayTime == AdDisplayTime.everyTwoMinutes || 
                                ad.displayTime == AdDisplayTime.everyFiveMinutes;
                                
              if (!isPeriodicAd && _playedAdIds.contains(ad.id)) {
                debugPrint('Non-periodic ad ${ad.id} already shown, skipping');
                continue;
              }

              bool shouldShowAd = false;
              int? currentTimeMarker;

              switch (ad.displayTime) {
                case AdDisplayTime.start:
                  // For start ads, use wider window - show in first 3 seconds
                  shouldShowAd = (playerState == PlayerState.playing || playerState == PlayerState.unknown) && 
                                currentPositionSeconds <= 3;
                  debugPrint('Start ad check - state: $playerState, position: $currentPositionSeconds, shouldShow: $shouldShowAd');
                  break;
                case AdDisplayTime.end:
                  shouldShowAd = playerState == PlayerState.ended;
                  debugPrint('End ad check - state: $playerState, shouldShow: $shouldShowAd');
                  break;
                case AdDisplayTime.custom:
                  // Use wider window (±2 seconds around target) for more reliable ad showing
                  shouldShowAd = ad.customStartTime != null && 
                                currentPositionSeconds >= (ad.customStartTime!.inSeconds - 2) &&
                                currentPositionSeconds <= (ad.customStartTime!.inSeconds + 2);
                  debugPrint('Custom ad check - position: $currentPositionSeconds, target: ${ad.customStartTime?.inSeconds}, shouldShow: $shouldShowAd');
                  break;
                case AdDisplayTime.quarter:
                  // Use wider window (±2 seconds around target) for more reliable ad showing
                  shouldShowAd = totalDurationSeconds > 0 && 
                                currentPositionSeconds >= (totalDurationSeconds * 0.25 - 2) &&
                                currentPositionSeconds <= (totalDurationSeconds * 0.25 + 2);
                  debugPrint('Quarter ad check - position: $currentPositionSeconds, target: ${totalDurationSeconds * 0.25}, shouldShow: $shouldShowAd');
                  break;
                case AdDisplayTime.half:
                  // Use wider window (±2 seconds around target) for more reliable ad showing
                  shouldShowAd = totalDurationSeconds > 0 && 
                                currentPositionSeconds >= (totalDurationSeconds * 0.5 - 2) &&
                                currentPositionSeconds <= (totalDurationSeconds * 0.5 + 2);
                  debugPrint('Half ad check - position: $currentPositionSeconds, target: ${totalDurationSeconds * 0.5}, shouldShow: $shouldShowAd');
                  break;
                case AdDisplayTime.threeQuarter:
                  // Use wider window (±2 seconds around target) for more reliable ad showing
                  shouldShowAd = totalDurationSeconds > 0 && 
                                currentPositionSeconds >= (totalDurationSeconds * 0.75 - 2) &&
                                currentPositionSeconds <= (totalDurationSeconds * 0.75 + 2);
                  debugPrint('Three quarter ad check - position: $currentPositionSeconds, target: ${totalDurationSeconds * 0.75}, shouldShow: $shouldShowAd');
                  break;
                case AdDisplayTime.everyMinute:
                  // Calculate current minute marker
                  currentTimeMarker = (currentPositionSeconds / 60).floor();
                  
                  // Check if we've shown this ad at this minute marker already
                  if (_playedPeriodicAdTimes.containsKey(ad.id) && 
                      _playedPeriodicAdTimes[ad.id]!.contains(currentTimeMarker)) {
                    debugPrint('Ad ${ad.id} already shown at minute $currentTimeMarker, skipping');
                    shouldShowAd = false;
                  } else {
                    // Use wider window (±2 seconds around minute boundary) for more reliable ad showing
                    shouldShowAd = currentPositionSeconds > 0 && 
                                  (currentPositionSeconds % 60 >= 58 || currentPositionSeconds % 60 <= 2);
                    debugPrint('Every minute ad check - position: $currentPositionSeconds, minute: $currentTimeMarker, shouldShow: $shouldShowAd');
                  }
                  break;
                case AdDisplayTime.everyTwoMinutes:
                  // Calculate current two-minute marker
                  currentTimeMarker = (currentPositionSeconds / 120).floor();
                  
                  // Check if we've shown this ad at this two-minute marker already
                  if (_playedPeriodicAdTimes.containsKey(ad.id) && 
                      _playedPeriodicAdTimes[ad.id]!.contains(currentTimeMarker)) {
                    debugPrint('Ad ${ad.id} already shown at two-minute block $currentTimeMarker, skipping');
                    shouldShowAd = false;
                  } else {
                    // Use wider window (±2 seconds around two-minute boundary) for more reliable ad showing
                    shouldShowAd = currentPositionSeconds > 0 && 
                                  (currentPositionSeconds % 120 >= 118 || currentPositionSeconds % 120 <= 2);
                    debugPrint('Every two minutes ad check - position: $currentPositionSeconds, two-minute block: $currentTimeMarker, shouldShow: $shouldShowAd');
                  }
                  break;
                case AdDisplayTime.everyFiveMinutes:
                  // Calculate current five-minute marker
                  currentTimeMarker = (currentPositionSeconds / 300).floor();
                  
                  // Check if we've shown this ad at this five-minute marker already
                  if (_playedPeriodicAdTimes.containsKey(ad.id) && 
                      _playedPeriodicAdTimes[ad.id]!.contains(currentTimeMarker)) {
                    debugPrint('Ad ${ad.id} already shown at five-minute block $currentTimeMarker, skipping');
                    shouldShowAd = false;
                  } else {
                    // Use wider window (±2 seconds around five-minute boundary) for more reliable ad showing
                    shouldShowAd = currentPositionSeconds > 0 && 
                                  (currentPositionSeconds % 300 >= 298 || currentPositionSeconds % 300 <= 2);
                    debugPrint('Every five minutes ad check - position: $currentPositionSeconds, five-minute block: $currentTimeMarker, shouldShow: $shouldShowAd');
                  }
                  break;
              }

              if (shouldShowAd) {
                debugPrint('Starting ad: ${ad.id}');
                _startAd(ad, currentTimeMarker);
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing video data: $e');
          debugPrint('Raw result: $result');
        }
      }
    });
  }
}
