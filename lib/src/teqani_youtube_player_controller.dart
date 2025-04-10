import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:teqani_youtube_player/src/models/player_config.dart';
import 'package:teqani_youtube_player/src/models/player_error.dart';
import 'package:teqani_youtube_player/src/models/player_state.dart';
import 'package:teqani_youtube_player/src/models/youtube_style_options.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Controller for managing a TeqaniYoutubePlayer instance.
class TeqaniYoutubePlayerController extends ChangeNotifier {
  
  /// Constructor for TeqaniYoutubePlayerController
  TeqaniYoutubePlayerController({
    required this.initialConfig,
    this.onReady,
    this.onStateChanged,
    this.onError,
    this.onPlaying,
    this.onPaused,
    this.onEnded,
  }) {
    // Initialize WebViewController immediately
    webViewController = WebViewController();
  }
  
  /// The player configuration
  final PlayerConfig initialConfig;
  
  /// WebViewController for interacting with the WebView
  late final WebViewController webViewController;
  
  /// Whether the player is ready for playback
  bool _isReady = false;
  
  /// Current state of the player
  PlayerState _playerState = PlayerState.unknown;
  
  /// Current position in the video (seconds)
  // ignore: prefer_final_fields
  double _currentPosition = 0.0;
  
  /// Duration of the video (seconds)
  // ignore: prefer_final_fields
  double _videoDuration = 0.0;
  
  /// Current playback rate
  final double _playbackRate = 1.0;
  
  /// Whether the player is in fullscreen mode
  bool _isFullscreen = false;
  
  /// Whether the player is initialized
  bool _isInitialized = false;
  
  /// Last error that occurred
  PlayerError? _lastError;

  /// Callback when the player is ready
  VoidCallback? onReady;
  
  /// Callback when player state changes
  Function(PlayerState)? onStateChanged;
  
  /// Callback when an error occurs
  Function(PlayerError)? onError;
  
  /// Callback when playback starts
  VoidCallback? onPlaying;
  
  /// Callback when playback pauses
  VoidCallback? onPaused;
  
  /// Callback when playback ends
  VoidCallback? onEnded;
  
  /// Whether the controller is disposed
  bool _isDisposed = false;
  
  /// Current video quality setting
  String _currentQuality = 'default';
  
  /// Current filter settings
  double _currentSharpness = 100;
  double _currentBrightness = 100;
  double _currentContrast = 100;
  double _currentSaturation = 100;
  
  /// Initialize the player controller
  bool initializing = false;
  final MethodChannel _methodChannel = const MethodChannel('com.teqani.teqani_youtube_player');
  
  /// Current video ID
  String get videoId => initialConfig.videoId;

  /// Debug logging helper
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('TeqaniYoutubePlayer: $message');
    }
  }

  /// Setup event listeners for the player
  Future<void> _setupPlayerEventListeners() async {
    await webViewController.runJavaScript('''
      // Set up event channel for communication
      window.TeqaniFlutterCallback = function(event, data) {
        window.flutter_inappwebview.callHandler('TeqaniYTPlayer', JSON.stringify({
          event: event,
          data: data
        }));
      };
      
      // Listen for YouTube player events
      if (window.TeqaniPlayer && window.TeqaniPlayer.player) {
        window.TeqaniPlayer.player.addEventListener('onStateChange', function(event) {
          window.TeqaniFlutterCallback('onStateChange', { state: event.data });
        });
        
        window.TeqaniPlayer.player.addEventListener('onError', function(event) {
          window.TeqaniFlutterCallback('onError', { errorCode: event.data });
        });
        
        // Listen for quality changes
        window.TeqaniPlayer.player.addEventListener('onPlaybackQualityChange', function(event) {
          window.TeqaniFlutterCallback('onQualityChange', { quality: event.data });
          console.log('YouTube quality changed to: ' + event.data);
        });
        
        // Send update every second for time
        setInterval(function() {
          if (window.TeqaniPlayer && window.TeqaniPlayer.player) {
            try {
              const currentTime = window.TeqaniPlayer.player.getCurrentTime() || 0;
              const duration = window.TeqaniPlayer.player.getDuration() || 0;
              
              window.TeqaniFlutterCallback('videoTime', {
                currentTime: currentTime,
                duration: duration
              });
            } catch (e) {
              console.error('Error getting video time:', e);
            }
          }
        }, 1000);
      }
      
      // Add a global message listener for iframe communication
      window.addEventListener('message', function(event) {
        try {
          const data = JSON.parse(event.data);
          if (data && data.event === 'onPlaybackQualityChange') {
            window.TeqaniFlutterCallback('onQualityChange', { quality: data.data });
            console.log('YouTube iframe quality changed to: ' + data.data);
          }
        } catch (e) {
          // Not our message or not in the expected format
        }
      });
    ''');
  }

  /// Clean up resources
  void _disposeListeners() {
    // Remove any listeners to prevent memory leaks
    onReady = null;
    onStateChanged = null;
    onError = null;
  }

  /// Initialize the player controller
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // Platform-level vibration disabling caused exceptions - removed

      await webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
      
      // Disable haptic feedback, context menu and long press effects
      await webViewController.runJavaScript('''
        // More aggressive approach to prevent vibration on touch
        // Set a global variable to track touch state
        window.teqaniTouchState = {
          touchStartTime: 0,
          touchStartX: 0,
          touchStartY: 0,
          isLongPress: false,
          timerId: null
        };
        
        // Complete replacement for touch handling to prevent vibration
        document.addEventListener('touchstart', function(e) {
          // Record touch start info
          const state = window.teqaniTouchState;
          state.touchStartTime = Date.now();
          state.touchStartX = e.touches[0].clientX;
          state.touchStartY = e.touches[0].clientY;
          state.isLongPress = false;
          
          // Clear any existing timer
          if (state.timerId) {
            clearTimeout(state.timerId);
          }
          
          // Set timer to detect long press
          state.timerId = setTimeout(function() {
            state.isLongPress = true;
            // For long press, we MUST prevent default to stop vibration
            e.preventDefault();
            
            // Just treat it as a regular tap
            const tap = new MouseEvent('click', {
              bubbles: true,
              cancelable: true,
              view: window
            });
            e.target.dispatchEvent(tap);
          }, 100); // Detect long press very early at 100ms
        }, true);
        
        // Cancel long press detection on touchmove
        document.addEventListener('touchmove', function(e) {
          const state = window.teqaniTouchState;
          // Clear the timer and mark not long press
          if (state.timerId) {
            clearTimeout(state.timerId);
            state.timerId = null;
          }
          state.isLongPress = false;
        }, true);
        
        // Handle touch end
        document.addEventListener('touchend', function(e) {
          const state = window.teqaniTouchState;
          // Clear the timer
          if (state.timerId) {
            clearTimeout(state.timerId);
            state.timerId = null;
          }
          
          // If this was a long press, prevent default
          if (state.isLongPress) {
            e.preventDefault();
          }
          state.isLongPress = false;
        }, true);
        
        // Prevent context menu
        document.addEventListener('contextmenu', function(e) {
          e.preventDefault();
          return false;
        }, false);
        
        // Prevent text selection on long press
        document.addEventListener('selectstart', function(e) {
          e.preventDefault();
          return false;
        }, false);
        
        // Disable hold-to-copy popup
        document.documentElement.style.webkitUserSelect = 'none';
        document.documentElement.style.userSelect = 'none';
        
        // Additional fixes for iOS and Safari
        document.documentElement.style.webkitTouchCallout = 'none';
      ''');
      
      // Set a more generic user agent to avoid potential issues
      await webViewController.setUserAgent(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      // Hardware acceleration check - default to true if not specified
      final bool enableHardware = initialConfig.enableHardwareAcceleration ?? true;
      if (enableHardware) {
        // Enable hardware acceleration on Android
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            await _methodChannel.invokeMethod('enableHardwareAcceleration');
          } catch (e) {
            _debugLog('Hardware acceleration not available: $e');
            // Continue without hardware acceleration
          }
        }
      }

      // Set up the navigation delegate with optimized error handling
      await webViewController.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _debugLog('Page started loading: $url');
          },
          onPageFinished: (String url) {
            _debugLog('Page finished loading: $url');
            _injectPlayerScripts();
          },
          onWebResourceError: (WebResourceError error) {
            _debugLog('Web resource error: ${error.description}');
            
            // Check for network error
            if (error.errorCode == -2) {
              _lastError = PlayerError(
                code: error.errorCode,
                message: 'Network error: ${error.description}',
              );
              
              // Call the error callback directly
              onError?.call(_lastError!);
              
            notifyListeners();
            }
          },
        ),
      );

      // Load the video URL with improved error handling
      // Use optional chaining for properties that might not exist
      
      final videoUrl = _buildYoutubeEmbedUrl();
      _debugLog('Loading video URL: $videoUrl');
      
      await webViewController.loadRequest(Uri.parse(videoUrl));
      
      // Check if fullscreen is allowed
      final allowFullscreen = initialConfig.allowFullscreen;
      if (!allowFullscreen) {
        // Schedule the fullscreen disabling after the page loads
        SchedulerBinding.instance.addPostFrameCallback((_) async {
          await disableFullscreen();
        });
      }
      
      // Initialize basic values
      _isReady = true;
      initializing = false;
      notifyListeners();

      // Create JavaScript function to sync settings button visibility with YouTube controls
      await _setupSettingsButtonSync();
    } catch (e) {
      _debugLog('Error initializing player: $e');
      initializing = false;
      rethrow;
    }
  }
  
  /// Injects all JavaScript scripts and initializes player functionalities
  void _injectPlayerScripts() async {
    // Batch JavaScript operations to reduce thread load
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        await _loadYouTubeApi();
        
        // Hide YouTube logo and branding with CSS
        await _hideYouTubeBranding();
        
        // Apply custom style options if provided
        if (initialConfig.styleOptions != null) {
          await applyStyleOptions(initialConfig.styleOptions!);
        }
        
        await _setupPlayerEventListeners();
        
        // Initialize other needed JavaScript components
        await _initializePlayerJavaScript();
        
        notifyListeners();
      } catch (e) {
        _debugLog('Error setting up player scripts: $e');
      }
    });
  }
  
  /// Hide YouTube branding elements
  Future<void> _hideYouTubeBranding() async {
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Create a style element to inject CSS
          const style = document.createElement('style');
          style.textContent = `
            /* Hide YouTube logo in controls */
            .ytp-youtube-button, .ytp-button[aria-label*='YouTube'], .ytp-chrome-top-buttons {
              display: none !important;
            }
            
            /* Hide logo in the bottom right */
            .ytp-watermark {
              display: none !important;
            }
            
            /* Hide end screen elements and annotations */
            .ytp-ce-element, .annotation {
              display: none !important;
            }
            
            /* Hide video title */
            .ytp-chrome-top {
              display: none !important;
            }
            
            /* Remove context menu popup */
            .ytp-contextmenu, .ytp-contextmenu-popup {
              display: none !important;
            }
            
            /* Hide control buttons */
            .ytp-settings-button, 
            .ytp-subtitles-button, 
            .ytp-miniplayer-button, 
            .ytp-share-button, 
            .ytp-watch-later-button, 
            .ytp-more-button, 
            .ytp-playlist-menu-button {
              display: none !important;
            }
            
            /* Hide info panels and overlays */
            .ytp-info-panel-content, 
            .ytp-cards-button, 
            .ytp-cards-teaser, 
            .ytp-iv-player-content, 
            .ytp-autonav-endscreen-countdown-container, 
            .ytp-pause-overlay, 
            .ytp-spinner {
              display: none !important;
            }
            
            /* Hide gradients */
            .ytp-gradient-top, 
            .ytp-gradient-bottom {
              display: none !important;
            }
            
            /* Hide chapter markers */
            .ytp-chapter-marker, 
            .ytp-player-content, 
            .ytp-menu-container {
              display: none !important;
            }
            
            /* Override touch actions */
            .html5-video-player, video, body, html, * {
              -webkit-touch-callout: none !important;
              -webkit-user-select: none !important;
              -webkit-tap-highlight-color: transparent !important;
              user-select: none !important;
              touch-action: manipulation !important;
              -webkit-touch-action: manipulation !important;
              -webkit-user-drag: none !important;
              user-drag: none !important;
            }
          `;
          
          // Add style to document head
          document.head.appendChild(style);
          
          // Disable YouTube context menu specifically
          const disableYouTubeContextMenu = () => {
            // Find all iframes
            const iframes = document.querySelectorAll('iframe');
            iframes.forEach(iframe => {
              try {
                // Try to access iframe window and document
                iframe.contentWindow.document.addEventListener('contextmenu', e => {
              e.preventDefault();
              return false;
                }, true);
                
                // Also try to find and disable the YouTube context menu
                const ytContextMenus = iframe.contentWindow.document.querySelectorAll('.ytp-contextmenu, .ytp-contextmenu-popup');
                ytContextMenus.forEach(menu => menu.style.display = 'none');
              } catch(e) {
                // Ignore cross-origin errors
              }
            });
            
            // Also handle main document context menu
            document.addEventListener('contextmenu', e => {
              e.preventDefault();
              return false;
            }, true);
          };
          
          // Function to remove elements by class or ID
          const removeElements = () => {
            // Use a comprehensive list of YouTube branded elements
            const selectors = [
              '.ytp-youtube-button',
              '.ytp-watermark',
              '.ytp-ce-element',
              '.annotation',
              '.ytp-chrome-top',
              '.ytp-chrome-top-buttons',
              '.ytp-button[aria-label*="YouTube"]',
              '.branding-img',
              '.branding-img-container',
              '.ytp-title',
              '.ytp-title-text',
              '.ytp-show-cards-title',
              // Add more UI elements to hide
              '.ytp-settings-button', // Settings button
              '.ytp-subtitles-button', // Captions button
              '.ytp-miniplayer-button', // Miniplayer button
              '.ytp-share-button', // Share button
              '.ytp-watch-later-button', // Watch later button
              '.ytp-more-button', // More button
              '.ytp-playlist-menu-button', // Playlist button
              '.ytp-info-panel-content', // Info panel
              '.ytp-cards-button', // Cards button
              '.ytp-cards-teaser', // Cards teaser
              '.ytp-iv-player-content', // Annotations
              '.ytp-autonav-endscreen-countdown-container', // Autoplay countdown
              '.ytp-pause-overlay', // Pause overlay with recommendations
              '.ytp-spinner', // Loading spinner
              '.ytp-gradient-top', // Top gradient
              '.ytp-gradient-bottom', // Bottom gradient
              '.ytp-button', // All buttons (use with caution)
              '.ytp-chapter-marker', // Chapter markers
              '.ytp-player-content', // Player content
              '.ytp-menu-container' // Menu container
            ];
            
            // Apply to main document
            selectors.forEach(selector => {
              const elements = document.querySelectorAll(selector);
              elements.forEach(el => el.style.display = 'none');
            });
            
            // Try to access iframe if possible
            const iframe = document.querySelector('iframe');
            if (iframe && iframe.contentDocument) {
              try {
                selectors.forEach(selector => {
                  const elements = iframe.contentDocument.querySelectorAll(selector);
                  elements.forEach(el => el.style.display = 'none');
                });
              } catch (e) {
                console.error('Could not remove elements from iframe:', e);
              }
            }
          };
          
          // Run immediately
          removeElements();
          
          // Run the context menu disabler
          disableYouTubeContextMenu();
          
          // Run again after short delay to catch lazy-loaded elements
          setTimeout(removeElements, 1000);
          setTimeout(removeElements, 3000);
          setTimeout(disableYouTubeContextMenu, 1000);
          setTimeout(disableYouTubeContextMenu, 3000);
          
          // Set up an interval to periodically check for and remove branding elements
          setInterval(removeElements, 5000);
          setInterval(disableYouTubeContextMenu, 5000);
          
          // Watch for DOM changes to catch dynamically added elements
          const observer = new MutationObserver((mutations) => {
            // When DOM changes, check for logo elements again
            removeElements();
            
            // Also check for and disable context menus
            disableYouTubeContextMenu();
            
            // Check if iframe was added
            const iframe = document.querySelector('iframe');
            if (iframe && iframe.contentDocument) {
              try {
                // Add styles to iframe document
                const iframeStyle = document.createElement('style');
                iframeStyle.textContent = style.textContent;
                if (!iframe.contentDocument.querySelector('style[data-teqani-style]')) {
                  iframeStyle.setAttribute('data-teqani-style', 'true');
                  iframe.contentDocument.head.appendChild(iframeStyle);
                }
                
                // Set up observer inside iframe if possible
                const iframeObserver = new MutationObserver(() => {
                  removeElements();
                });
                
                try {
                  iframeObserver.observe(iframe.contentDocument.body, {
                    childList: true,
                    subtree: true
                  });
          } catch (e) {
                  console.error('Could not observe iframe body:', e);
                }
              } catch (e) {
                console.error('Could not inject styles into iframe:', e);
              }
            }
          });
          
          // Start observing for DOM changes
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
          } catch (e) {
          console.error('Error hiding YouTube branding:', e);
        }
      })();
    ''');
  }
  
  /// Core JavaScript setup for the player
  Future<void> _initializePlayerJavaScript() async {
    // Get default values with fallbacks
    final muted = initialConfig.muted;
    final volume = initialConfig.volume ?? 1.0;
    final playbackRate = initialConfig.playbackRate;
    
    // Batch all initial JavaScript setup into one call
    final String setupScript = '''
      // Create player interface if not exists
      if (!window.TeqaniPlayer) {
        window.TeqaniPlayer = {
          state: { 
            playing: false,
            currentTime: 0,
            duration: 0,
            buffered: 0,
            muted: $muted,
            volume: $volume,
            playbackRate: $playbackRate
          },
          ready: false,
          player: null
        };
      }
      
      // Check if player is already initialized
      if (!window.TeqaniPlayer.ready && window.YT && window.YT.Player) {
        // Initialize player functions
        window.TeqaniPlayer.play = function() {
          if (window.TeqaniPlayer.player && typeof window.TeqaniPlayer.player.playVideo === 'function') {
            window.TeqaniPlayer.player.playVideo();
          }
        };
        
        window.TeqaniPlayer.pause = function() {
          if (window.TeqaniPlayer.player && typeof window.TeqaniPlayer.player.pauseVideo === 'function') {
            window.TeqaniPlayer.player.pauseVideo();
          }
        };
        
        window.TeqaniPlayer.seekTo = function(seconds) {
          if (window.TeqaniPlayer.player && typeof window.TeqaniPlayer.player.seekTo === 'function') {
            window.TeqaniPlayer.player.seekTo(seconds, true);
          }
        };
        
        window.TeqaniPlayer.setVolume = function(volume) {
          if (window.TeqaniPlayer.player && typeof window.TeqaniPlayer.player.setVolume === 'function') {
            window.TeqaniPlayer.player.setVolume(volume * 100);
            window.TeqaniPlayer.state.volume = volume;
          }
        };
        
        window.TeqaniPlayer.setPlaybackRate = function(rate) {
          if (window.TeqaniPlayer.player && typeof window.TeqaniPlayer.player.setPlaybackRate === 'function') {
            window.TeqaniPlayer.player.setPlaybackRate(rate);
            window.TeqaniPlayer.state.playbackRate = rate;
          }
        };
        
        window.TeqaniPlayer.setMuted = function(muted) {
          if (window.TeqaniPlayer.player) {
            if (muted) {
              window.TeqaniPlayer.player.mute();
            } else {
              window.TeqaniPlayer.player.unMute();
            }
            window.TeqaniPlayer.state.muted = muted;
          }
        };
        
        window.TeqaniPlayer.ready = true;
      }
      
      true;
    ''';
    
    // Execute the batch setup script
    await webViewController.runJavaScript(setupScript);
  }
  
  /// Loads YouTube API if not already loaded
  Future<void> _loadYouTubeApi() async {
    // Use YouTube's postMessage API instead of direct script injection
    await webViewController.runJavaScript('''
      (function() {
        if (window.YT && window.YT.Player) {
          console.log('YouTube API already loaded');
          return;
        }
        
        // Create a message listener to handle YouTube iframe API events
        window.addEventListener('message', function(event) {
          // Only accept messages from YouTube
          if (event.origin.indexOf('youtube.com') === -1) return;
          
          try {
            const data = event.data;
            if (typeof data === 'string') {
              // Try to parse JSON messages
              try {
                const parsed = JSON.parse(data);
                if (parsed.event) {
                  // Handle YouTube events using the existing channel
                  window.TeqaniYTPlayer.postMessage(JSON.stringify({
                    event: parsed.event,
                    data: parsed.info || {}
                  }));
                }
              } catch(e) {
                // Not JSON, ignore
              }
            }
          } catch(e) {
            console.error('Error processing YouTube message:', e);
          }
        });
        
        // Create a simple event forwarder function
        window.TeqaniPlayer = {
          play: function() {
            const iframe = document.querySelector('iframe');
            if (iframe) {
              iframe.contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
            }
          },
          pause: function() {
            const iframe = document.querySelector('iframe');
            if (iframe) {
              iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
            }
          },
          seekTo: function(seconds) {
            const iframe = document.querySelector('iframe');
            if (iframe) {
              iframe.contentWindow.postMessage('{"event":"command","func":"seekTo","args":[' + seconds + ', true]}', '*');
            }
          },
          setVolume: function(volume) {
            const iframe = document.querySelector('iframe');
            if (iframe) {
              const vol = Math.floor(volume * 100);
              iframe.contentWindow.postMessage('{"event":"command","func":"setVolume","args":[' + vol + ']}', '*');
            }
          },
      setMute: function(mute) {
            const iframe = document.querySelector('iframe');
            if (iframe) {
              const func = mute ? 'mute' : 'unMute';
              iframe.contentWindow.postMessage('{"event":"command","func":"' + func + '","args":""}', '*');
            }
          },
          setPlaybackRate: function(rate) {
            const iframe = document.querySelector('iframe');
            if (iframe) {
              iframe.contentWindow.postMessage('{"event":"command","func":"setPlaybackRate","args":[' + rate + ']}', '*');
            }
          }
        };
      })();
    ''');
  }
  
  /// Release resources when player is disposed
  @override
  void dispose() {
    _debugLog('Disposing YouTube player controller');
    _disposeListeners();
    
    // Clean up JavaScript resources
    webViewController.runJavaScript('''
      if (window.TeqaniPlayer && window.TeqaniPlayer.player) {
        // Stop player and clean up resources
        try {
          window.TeqaniPlayer.pause();
          window.TeqaniPlayer.player = null;
          window.TeqaniPlayer = null;
          window.TeqaniFlutterCallback = null;
        } catch(e) {
          console.error('Error cleaning up player:', e);
        }
      }
    ''').catchError((e) {
      _debugLog('Error during JavaScript cleanup: $e');
    });
    
    _isDisposed = true;
    super.dispose();
  }
  
  /// Player control methods
  
  /// Play the video
  Future<void> play() async {
    // Use both postMessage API and direct video element approach for maximum compatibility
    await webViewController.runJavaScript('''
      (function() {
        // Try using proper YouTube API via postMessage
        try {
          const iframe = document.querySelector('iframe');
          if (iframe) {
            // Send message to YouTube player with play command
            iframe.contentWindow.postMessage(JSON.stringify({
              "event": "command",
              "func": "playVideo"
            }), '*');
          }
        } catch(e) {
          console.error('YouTube postMessage play failed:', e);
        }
        
        // Also try finding and playing the video element directly
        try {
          const video = document.querySelector('video');
          if (video) {
            // Create an invisible button to capture user interaction
            const btn = document.createElement('button');
            btn.style.position = 'fixed';
            btn.style.top = '0';
            btn.style.left = '0';
            btn.style.width = '100%';
            btn.style.height = '100%';
            btn.style.zIndex = '999999';
            btn.style.opacity = '0.01';
            btn.style.cursor = 'pointer';
            btn.style.border = 'none';
            btn.style.background = 'transparent';
            
            // Add button to DOM
            document.body.appendChild(btn);
            
            // Set up click handler that will play video
            btn.onclick = function() {
              // Immediately try to play on user interaction
              if (video && video.paused) {
                const playPromise = video.play();
                if (playPromise !== undefined) {
                  playPromise.then(() => {
                    console.log('Video play success via direct interaction');
                  }).catch(e => {
                    console.log('Video play failed:', e);
                  });
                }
              }
              
              // Remove button after use
              setTimeout(() => {
                if (document.body.contains(btn)) {
                  document.body.removeChild(btn);
                }
              }, 300);
            };
            
            // Trigger the click after a small delay
            setTimeout(() => {
              btn.click();
            }, 50);
            
            // Auto-remove the button after 3 seconds if not clicked
            setTimeout(() => {
              if (document.body.contains(btn)) {
                document.body.removeChild(btn);
              }
            }, 3000);
          }
        } catch(e) {
          console.error('Direct video play failed:', e);
        }
      })();
    ''');
    
    // Update player state locally for better responsiveness
    _playerState = PlayerState.playing;
    onStateChanged?.call(_playerState);
    notifyListeners();
  }
  
  /// Pause the video
  Future<void> pause() async {
    await webViewController.runJavaScript('''
      (function() {
        const iframe = document.querySelector('iframe');
        if (iframe) {
          iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}', '*');
        }
      })();
    ''');
  }
  
  /// Seek to a specific position in seconds
  Future<void> seekTo(double seconds) async {
    await _runJavaScript('window.TeqaniController.seekTo($seconds)');
  }
  
  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _runJavaScript('window.TeqaniController.setVolume(${volume.clamp(0.0, 1.0)})');
  }
  
  /// Mute the video
  Future<void> mute() async {
    await _runJavaScript('window.TeqaniController.setMute(true)');
  }
  
  /// Unmute the video
  Future<void> unmute() async {
    await _runJavaScript('window.TeqaniController.setMute(false)');
  }
  
  /// Set playback rate (0.25 to 2.0)
  Future<void> setPlaybackRate(double rate) async {
    await _runJavaScript('window.TeqaniController.setPlaybackRate(${rate.clamp(0.25, 2.0)})');
  }
  
  /// Fast forward video by specified number of seconds
  Future<void> fastForward([int seconds = 10]) async {
    final newPosition = _currentPosition + seconds;
    await seekTo(newPosition > _videoDuration ? _videoDuration : newPosition);
  }

  /// Rewind video by specified number of seconds
  Future<void> rewind([int seconds = 10]) async {
    final newPosition = _currentPosition - seconds;
    await seekTo(newPosition < 0 ? 0 : newPosition);
  }
  
  /// Enter fullscreen mode
  Future<void> enterFullscreen() async {
    _isFullscreen = true;
    notifyListeners();
  }

  /// Exit fullscreen mode
  Future<void> exitFullscreen() async {
    _isFullscreen = false;
    notifyListeners();
  }

  /// Get whether the player is in fullscreen mode
  bool get isFullscreen => _isFullscreen;
  
  // Getters for private members
  
  /// Whether the player is ready for playback
  bool get isReady => _isReady;
  
  /// Current state of the player
  PlayerState get playerState => _playerState;
  
  /// Current position in the video (seconds)
  double get currentPosition => _currentPosition;
  
  /// Duration of the video (seconds)
  double get videoDuration => _videoDuration;
  
  /// Current playback rate
  double get playbackRate => _playbackRate;
  
  /// Check if video is playing
  bool get isPlaying => _playerState == PlayerState.playing;
  
  /// Check if video is paused
  bool get isPaused => _playerState == PlayerState.paused;
  
  /// Check if video has ended
  bool get isEnded => _playerState == PlayerState.ended;
  
  /// Run JavaScript code in the WebView
  Future<void> _runJavaScript(String js) async {
    await webViewController.runJavaScript(js);
  }
  
  /// Public method to run JavaScript code in the WebView
  Future<void> runJavaScript(String js) async {
    await _runJavaScript(js);
  }
  
  /// Generate the YouTube embed URL with proper parameters
  String _buildYoutubeEmbedUrl() {
    final showControls = initialConfig.showControls;
    
    return 'https://www.youtube.com/embed/${initialConfig.videoId}'
        '?enablejsapi=1'
        '&autoplay=1' // Always auto-play to prevent showing YouTube's initial play button
        '&mute=1' // Muted by default to enable autoplay in most browsers
        '&loop=${initialConfig.loop ? 1 : 0}'
        '&playsinline=1'
        '&controls=${showControls ? 1 : 0}' // Show controls based on configuration
        '&rel=0' // Disable related videos
        '&fs=${initialConfig.allowFullscreen ? 1 : 0}'
        '&modestbranding=1' // Minimal YouTube branding
        '&showinfo=0' // Hide video title and uploader info
        '&iv_load_policy=3' // Hide video annotations
        '&color=white' // Use white progress bar to reduce branding
        '&disablekb=1' // Disable keyboard controls
        '&cc_load_policy=0' // Disable closed captions by default
        '&hl=en' // Set language to English
        '&widget_referrer=${Uri.encodeComponent(Uri.base.toString())}' // Set widget referrer
        '&enablejsapi=1' // Enable JS API
        '&origin=${Uri.encodeComponent("https://www.youtube.com")}'
        '&widgetid=1';
  }
  
  /// Hide all control elements completely
  Future<void> hideAllControls() async {
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Create a style element to hide all controls
          const style = document.createElement('style');
          style.textContent = `
            /* Hide all YouTube controls */
            .ytp-chrome-bottom, 
            .ytp-chrome-controls, 
            .ytp-progress-bar-container, 
            .ytp-volume-panel, 
            .ytp-time-display,
            .ytp-play-button,
            .ytp-mute-button {
              display: none !important;
            }
            
            /* Also hide any control bar that appears on hover */
            .ytp-gradient-bottom {
              display: none !important;
            }
          `;
          
          document.head.appendChild(style);
          
          // Also try to add styles to iframe
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              const iframeStyle = document.createElement('style');
              iframeStyle.textContent = style.textContent;
              iframe.contentDocument.head.appendChild(iframeStyle);
            } catch (e) {
              console.error('Could not apply styles to iframe:', e);
            }
          }
        } catch (e) {
          console.error('Error hiding controls:', e);
        }
      })();
    ''');
  }
  
  
  
  
  /// Get the last error that occurred
  PlayerError? get lastError => _lastError;

  /// Clear any errors
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Toggle YouTube controls visibility
  Future<void> toggleControls(bool show) async {
    if (show) {
      // Show controls by removing the hide styles
      await webViewController.runJavaScript('''
        (function() {
          try {
            // Find and remove the style element that hides controls
            const styles = document.querySelectorAll('style');
            for (let i = 0; i < styles.length; i++) {
              const style = styles[i];
              if (style.textContent.includes('.ytp-chrome-bottom') || 
                  style.textContent.includes('.ytp-chrome-controls')) {
                style.remove();
              }
            }
            
            // Also try to apply to iframe
            const iframe = document.querySelector('iframe');
            if (iframe && iframe.contentDocument) {
              try {
                const iframeStyles = iframe.contentDocument.querySelectorAll('style');
                for (let i = 0; i < iframeStyles.length; i++) {
                  const style = iframeStyles[i];
                  if (style.textContent.includes('.ytp-chrome-bottom') || 
                      style.textContent.includes('.ytp-chrome-controls')) {
                    style.remove();
                  }
                }
              } catch (e) {
                console.error('Could not modify iframe styles:', e);
              }
            }
          } catch (e) {
            console.error('Error showing controls:', e);
          }
        })();
      ''');
    } else {
      // Hide controls by calling hideAllControls
      await hideAllControls();
    }
  }

  /// Apply custom style options to the YouTube player
  Future<void> applyStyleOptions(YouTubeStyleOptions options) async {
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Create a style element for our custom styles
          const styleId = 'teqani-youtube-custom-styles';
          let styleEl = document.getElementById(styleId);
          
          // Remove existing style if it exists
          if (styleEl) {
            styleEl.remove();
          }
          
          // Create new style element
          styleEl = document.createElement('style');
          styleEl.id = styleId;
          
          // Build style content based on options
          let css = '';
          
          // Play button
          if (!${options.showPlayButton}) {
            css += '.ytp-play-button { display: none !important; }\\n';
          }
          
          // Pause button is actually the same element as play button in YouTube's UI
          
          // Volume controls
          if (!${options.showVolumeControls}) {
            css += '.ytp-mute-button, .ytp-volume-panel { display: none !important; }\\n';
          }
          
          // Progress bar
          if (!${options.showProgressBar}) {
            css += '.ytp-progress-bar-container { display: none !important; }\\n';
          }
          
          // Fullscreen button
          if (!${options.showFullscreenButton}) {
            css += '.ytp-fullscreen-button { display: none !important; }\\n';
          }
          
          // YouTube logo
          if (!${options.showYouTubeLogo}) {
            css += '.ytp-youtube-button, .ytp-button[aria-label*="YouTube"], .ytp-watermark { display: none !important; }\\n';
          }
          
          // Settings button
          if (!${options.showSettingsButton}) {
            css += '.ytp-settings-button { display: none !important; }\\n';
          }
          
          // Captions button
          if (!${options.showCaptionsButton}) {
            css += '.ytp-subtitles-button { display: none !important; }\\n';
          }
          
          // Title
          if (!${options.showTitle}) {
            css += '.ytp-chrome-top, .ytp-title { display: none !important; }\\n';
          }
          
          // Top controls
          if (!${options.showTopControls}) {
            css += '.ytp-chrome-top { display: none !important; }\\n';
          }
          
          // Bottom controls
          if (!${options.showBottomControls}) {
            css += '.ytp-chrome-bottom { display: none !important; }\\n';
          }
          
          // Add any custom CSS if provided
          ${options.customCSS != null ? "css += `${options.customCSS}`;" : ""}
          
          // Set the CSS content
          styleEl.textContent = css;
          
          // Add style to document
          document.head.appendChild(styleEl);
          
          // Also try to add to iframe if possible
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              const iframeStyleEl = document.createElement('style');
              iframeStyleEl.id = styleId + '-iframe';
              iframeStyleEl.textContent = css;
              iframe.contentDocument.head.appendChild(iframeStyleEl);
            } catch (e) {
              console.error('Could not apply styles to iframe:', e);
            }
          }
        } catch (e) {
          console.error('Error applying custom styles:', e);
        }
      })();
    ''');
    
    // Also handle fullscreen functionality based on options
    if (!options.showFullscreenButton) {
      // If fullscreen button is hidden, also disable double-click fullscreen
      await disableFullscreen();
    } else {
      // If fullscreen button is shown, ensure fullscreen functionality is enabled
      await enableFullscreen();
    }
  }
  
  /// Set the video quality (resolution)
  /// 
  /// Available quality options:
  /// - 'small': 240p
  /// - 'medium': 360p
  /// - 'large': 480p
  /// - 'hd720': 720p
  /// - 'hd1080': 1080p
  /// - 'highres': 1440p/2160p
  /// - 'default': Let YouTube decide based on user's connection
  Future<void> setVideoQuality(String quality) async {
    final validQualities = ['default', 'tiny', 'small', 'medium', 'large', 'hd720', 'hd1080', 'highres'];
    
    if (!validQualities.contains(quality)) {
      throw ArgumentError('Invalid quality value. Must be one of: ${validQualities.join(', ')}');
    }
    
    // Save the current quality setting
    _currentQuality = quality;
    
    // First hide YouTube's quality menu elements to prevent them from appearing
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Create or update style to hide YouTube's quality menu
          let styleEl = document.getElementById('teqani-hide-quality-menu');
          if (!styleEl) {
            styleEl = document.createElement('style');
            styleEl.id = 'teqani-hide-quality-menu';
            document.head.appendChild(styleEl);
          }
          
          // CSS to hide all YouTube menu elements
          styleEl.textContent = `
            /* Hide all YouTube menus */
            .ytp-popup,
            .ytp-settings-menu,
            .ytp-panel-menu,
            .ytp-quality-menu,
            .ytp-panel {
              display: none !important;
              opacity: 0 !important;
              pointer-events: none !important;
            }
          `;
          
          // Also try to hide in iframe
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              let iframeStyleEl = iframe.contentDocument.getElementById('teqani-hide-quality-menu');
              if (!iframeStyleEl) {
                iframeStyleEl = document.createElement('style');
                iframeStyleEl.id = 'teqani-hide-quality-menu';
                iframe.contentDocument.head.appendChild(iframeStyleEl);
              }
              iframeStyleEl.textContent = styleEl.textContent;
            } catch (e) {
              console.error('Could not hide YouTube quality menu in iframe:', e);
            }
          }
          
          console.log('YouTube quality menu hidden for quality change');
          return true;
        } catch (e) {
          console.error('Error hiding YouTube quality menu:', e);
          return false;
        }
      })();
    ''');
    
    // Now try the direct API approach
    await webViewController.runJavaScript('''
      (function() {
        try {
          // For debugging
          console.log('Setting quality to: $quality');
          
          // Method 1: Using player API directly
          if (window.TeqaniPlayer && window.TeqaniPlayer.player && 
              typeof window.TeqaniPlayer.player.setPlaybackQuality === 'function') {
            window.TeqaniPlayer.player.setPlaybackQuality('$quality');
            console.log('Quality set via TeqaniPlayer API');
            return true; // Indicate success
          }
          
          // Method 2: Using iframe postMessage API
          const iframe = document.querySelector('iframe');
          if (iframe) {
            iframe.contentWindow.postMessage(JSON.stringify({
              'event': 'command',
              'func': 'setPlaybackQuality',
              'args': ['$quality']
            }), '*');
            console.log('Quality set message sent to iframe');
            return true; // Indicate success
          }
          
          return false; // Indicate that we need to try UI method
        } catch (e) {
          console.error('Error in API quality setting methods:', e);
          return false; // Need to try UI method
        }
      })();
    ''');
    
    // Only use UI interaction as a last resort, with steps to close the menu
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Try clicking on the settings button to open menu
          const settingsButton = document.querySelector('.ytp-settings-button');
          if (!settingsButton) return;
          
          // Function to close any open menus by clicking the video
          const closeMenus = function() {
            try {
              // Click outside to close any open menus
              const video = document.querySelector('video');
              if (video) {
                video.click();
              } else {
                document.body.click();
              }
            } catch (e) {
              console.error('Error closing menus:', e);
            }
          };
          
          // Click to open settings
          settingsButton.click();
          
          // Wait for menu to open
          setTimeout(function() {
            try {
              // Find and click quality option
              const menuItems = document.querySelectorAll('.ytp-menuitem');
              let qualityMenuItem;
              
              for (const item of menuItems) {
                const text = item.textContent || '';
                if (text.includes('Quality')) {
                  qualityMenuItem = item;
                  break;
                }
              }
              
              if (qualityMenuItem) {
                qualityMenuItem.click();
                
                // Wait for submenu
                setTimeout(function() {
                  try {
                    // Find the right quality option
                    const qualityOptions = document.querySelectorAll('.ytp-menuitem');
                    let targetOption;
                    
                    // Map quality values to what appears in the UI
                    const qualityLabels = {
                      'tiny': '144p',
                      'small': '240p',
                      'medium': '360p',
                      'large': '480p',
                      'hd720': '720p',
                      'hd1080': '1080p',
                      'highres': ['1440p', '2160p', '4K'],
                      'default': 'Auto'
                    };
                    
                    const targetLabel = qualityLabels['$quality'];
                    const targetLabelArray = Array.isArray(targetLabel) ? targetLabel : [targetLabel];
                    
                    for (const option of qualityOptions) {
                      const text = option.textContent || '';
                      for (const label of targetLabelArray) {
                        if (text.includes(label)) {
                          targetOption = option;
                          break;
                        }
                      }
                      if (targetOption) break;
                    }
                    
                    if (targetOption) {
                      targetOption.click();
                      console.log('Quality set via UI interaction');
                      
                      // Close menu by clicking elsewhere after a short delay
                      setTimeout(closeMenus, 100);
                    } else {
                      // Quality option not found, just close the menu
                      closeMenus();
                    }
                  } catch (e) {
                    console.error('Error selecting quality option:', e);
                    // Close menu
                    closeMenus();
                  }
                }, 200);
              } else {
                // Quality menu item not found, close the menu
                closeMenus();
              }
            } catch (e) {
              console.error('Error finding quality menu item:', e);
              // Close menu
              closeMenus();
            }
          }, 200);
        } catch (e) {
          console.error('Error in UI quality setting:', e);
        }
      })();
    ''');
    
    // Wait a bit before removing the menu hiding style
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Remove the style that hides YouTube's quality menu
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Remove the style element that hides menus
          const styleEl = document.getElementById('teqani-hide-quality-menu');
          if (styleEl) {
            styleEl.remove();
          }
          
          // Also try in iframe
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              const iframeStyleEl = iframe.contentDocument.getElementById('teqani-hide-quality-menu');
              if (iframeStyleEl) {
                iframeStyleEl.remove();
              }
            } catch (e) {}
          }
          
          // Final attempt to close any open menus
          const video = document.querySelector('video');
          if (video) {
            video.click();
          } else {
            document.body.click();
          }
        } catch (e) {}
      })();
    ''');
  }
  
  
  /// Apply visual filters to enhance video appearance
  /// 
  /// Parameters:
  /// - sharpness: 0-300 (100 is normal, higher values increase sharpness)
  /// - brightness: 0-200 (100 is normal)
  /// - contrast: 0-200 (100 is normal)
  /// - saturation: 0-200 (100 is normal)
  Future<void> applyVideoFilters({
    double? sharpness,
    double? brightness,
    double? contrast,
    double? saturation,
  }) async {
    // Validate and set defaults
    _currentSharpness = (sharpness ?? _currentSharpness).clamp(0, 300);
    _currentBrightness = (brightness ?? _currentBrightness).clamp(0, 200);
    _currentContrast = (contrast ?? _currentContrast).clamp(0, 200);
    _currentSaturation = (saturation ?? _currentSaturation).clamp(0, 200);
    
    // Convert to filter values
    final sharpnessValue = _currentSharpness > 100 ? (_currentSharpness / 100) : 1.0;
    final brightnessValue = _currentBrightness / 100;
    final contrastValue = _currentContrast / 100;
    final saturationValue = _currentSaturation / 100;
    
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Create or get the style element for filters
          const styleId = 'teqani-video-filters';
          let styleEl = document.getElementById(styleId);
          
          if (!styleEl) {
            styleEl = document.createElement('style');
            styleEl.id = styleId;
            document.head.appendChild(styleEl);
          }
          
          // Build the filter CSS
          const filters = [];
          ${_currentBrightness != 100 ? "filters.push(`brightness(\${$brightnessValue})`);" : ""}
          ${_currentContrast != 100 ? "filters.push(`contrast(\${$contrastValue})`);" : ""}
          ${_currentSaturation != 100 ? "filters.push(`saturate(\${$saturationValue})`);" : ""}
          
          // For sharpness, we need to use a matrix filter if it's not the default
          ${_currentSharpness != 100 ? """
          if ($sharpnessValue !== 1) {
            // Higher values make the image sharper
            // This is a 3x3 convolution matrix for sharpening
            if ($sharpnessValue > 1) {
              const matrix = [
                0, -1 * ($sharpnessValue - 1), 0,
                -1 * ($sharpnessValue - 1), 1 + 4 * ($sharpnessValue - 1), -1 * ($sharpnessValue - 1),
                0, -1 * ($sharpnessValue - 1), 0
              ].join(' ');
              filters.push(`url(data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg"><filter id="sharpen"><feConvolveMatrix order="3" preserveAlpha="true" kernelMatrix="\${matrix}" /></filter></svg>#sharpen)`);
            } else {
              // For reducing sharpness (making softer), we use a blur
              const blurAmount = (1 - $sharpnessValue) * 5;
              filters.push(`blur(\${blurAmount}px)`);
            }
          }
          """ : ""}
          
          // Combine all filters
          const filterString = filters.join(' ');
          
          // Apply filters to video elements
          styleEl.textContent = `
            video, 
            .html5-main-video,
            .html5-video-container {
              filter: \${filterString} !important;
            }
          `;
          
          // Also try to apply to iframe
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              let iframeStyleEl = iframe.contentDocument.getElementById(styleId);
              
              if (!iframeStyleEl) {
                iframeStyleEl = document.createElement('style');
                iframeStyleEl.id = styleId;
                iframe.contentDocument.head.appendChild(iframeStyleEl);
              }
              
              iframeStyleEl.textContent = styleEl.textContent;
            } catch (e) {
              console.error('Could not apply video filters to iframe:', e);
            }
          }
          
          console.log('Applied video filters: sharpness=$_currentSharpness, brightness=$_currentBrightness, contrast=$_currentContrast, saturation=$_currentSaturation');
        } catch (e) {
          console.error('Error applying video filters:', e);
        }
      })();
    ''');
  }
  
  /// Get the current filter settings
  Map<String, double> get currentFilterSettings => {
    'sharpness': _currentSharpness,
    'brightness': _currentBrightness,
    'contrast': _currentContrast,
    'saturation': _currentSaturation,
  };
  
  /// Get the current quality setting
  String get currentQuality => _currentQuality;
  
  /// Get available quality levels from the YouTube player
  Future<List<String>> getAvailableQualityLevels() async {
    try {
      final result = await webViewController.runJavaScriptReturningResult('''
        (function() {
          try {
            if (window.TeqaniPlayer && window.TeqaniPlayer.player && 
                typeof window.TeqaniPlayer.player.getAvailableQualityLevels === 'function') {
              return window.TeqaniPlayer.player.getAvailableQualityLevels();
            } else {
              // Fallback to static list if API not available
              return ['default', 'small', 'medium', 'large', 'hd720', 'hd1080'];
            }
          } catch (e) {
            console.error('Error getting quality levels:', e);
            return ['default', 'small', 'medium', 'large', 'hd720', 'hd1080'];
          }
        })();
      ''');
      
      if (result is List) {
        return result.map((item) => item.toString()).toList();
      } else if (result is String) {
        // Handle if the result is a JSON string
        try {
          final List<dynamic> parsed = jsonDecode(result);
          return parsed.map((item) => item.toString()).toList();
        } catch (e) {
          // If it's a simple string, return as a single item list
          return [result.toString()];
        }
      }
      
      return ['default', 'small', 'medium', 'large', 'hd720', 'hd1080'];
    } catch (e) {
      _debugLog('Error getting available quality levels: $e');
      // Return default quality options if there's an error
      return ['default', 'small', 'medium', 'large', 'hd720', 'hd1080'];
    }
  }
  
  /// Disable fullscreen functionality for the YouTube player
  Future<void> disableFullscreen() async {
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Create a style element to disable fullscreen elements
          const style = document.createElement('style');
          style.id = 'teqani-disable-fullscreen';
          style.textContent = `
            /* Hide fullscreen button */
            .ytp-fullscreen-button {
              display: none !important;
            }
            
            /* Prevent double-click fullscreen */
            video::-webkit-media-controls-fullscreen-button {
              display: none !important;
            }
            
            /* Disable fullscreen on double click */
            .html5-video-player, video {
              pointer-events: auto !important;
            }
          `;
          
          document.head.appendChild(style);
          
          // Override fullscreen functions
          document.documentElement.addEventListener('dblclick', function(e) {
            e.preventDefault();
            e.stopPropagation();
            return false;
          }, true);
          
          // Try to disable fullscreen in iframe
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              let iframeStyle = iframe.contentDocument.getElementById('teqani-disable-fullscreen');
              if (!iframeStyle) {
                iframeStyle = document.createElement('style');
                iframeStyle.id = 'teqani-disable-fullscreen';
                iframeStyle.textContent = style.textContent;
                iframe.contentDocument.head.appendChild(iframeStyle);
              }
              
              iframe.contentDocument.addEventListener('dblclick', function(e) {
                e.preventDefault();
                e.stopPropagation();
                return false;
              }, true);
            } catch (e) {
              console.error('Could not disable fullscreen in iframe:', e);
            }
          }
        } catch (e) {
          console.error('Error disabling fullscreen:', e);
        }
      })();
    ''');
  }
  
  /// Enable fullscreen functionality for the YouTube player
  Future<void> enableFullscreen() async {
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Remove the style element that disables fullscreen
          const style = document.getElementById('teqani-disable-fullscreen');
          if (style) {
            style.remove();
          }
          
          // Try to enable fullscreen in iframe
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              const iframeStyle = iframe.contentDocument.getElementById('teqani-disable-fullscreen');
              if (iframeStyle) {
                iframeStyle.remove();
              }
            } catch (e) {
              console.error('Could not enable fullscreen in iframe:', e);
            }
          }
        } catch (e) {
          console.error('Error enabling fullscreen:', e);
        }
      })();
    ''');
  }
  
  /// Reset video filters to default
  Future<void> resetVideoFilters() async {
    _currentSharpness = 100;
    _currentBrightness = 100;
    _currentContrast = 100;
    _currentSaturation = 100;
    
    await applyVideoFilters(
      sharpness: 100,
      brightness: 100,
      contrast: 100,
      saturation: 100,
    );
  }
  
  /// Apply custom CSS to the YouTube player
  Future<void> applyCustomCSS(String css) async {
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Create or update custom CSS style element
          const styleId = 'teqani-custom-css';
          let styleEl = document.getElementById(styleId);
          
          if (!styleEl) {
            styleEl = document.createElement('style');
            styleEl.id = styleId;
            document.head.appendChild(styleEl);
          }
          
          // Set the CSS content
          styleEl.textContent = `$css`;
          
          // Also try to add to iframe if possible
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              let iframeStyleEl = iframe.contentDocument.getElementById(styleId);
              
              if (!iframeStyleEl) {
                iframeStyleEl = document.createElement('style');
                iframeStyleEl.id = styleId;
                iframe.contentDocument.head.appendChild(iframeStyleEl);
              }
              
              iframeStyleEl.textContent = styleEl.textContent;
            } catch (e) {
              console.error('Could not apply custom CSS to iframe:', e);
            }
          }
        } catch (e) {
          console.error('Error applying custom CSS:', e);
        }
      })();
    ''');
  }
  
  /// Set visibility of a specific YouTube UI element
  Future<void> setUIElementVisibility(String elementName, bool visible) async {
    // Map element names to CSS selectors
    final Map<String, String> elementSelectors = {
      'playButton': '.ytp-play-button',
      'volumeControls': '.ytp-mute-button, .ytp-volume-panel',
      'progressBar': '.ytp-progress-bar-container',
      'fullscreenButton': '.ytp-fullscreen-button',
      'settingsButton': '.ytp-settings-button',
      'captionsButton': '.ytp-subtitles-button',
      'title': '.ytp-chrome-top, .ytp-title',
      'topControls': '.ytp-chrome-top',
      'bottomControls': '.ytp-chrome-bottom',
      'youtubeButton': '.ytp-youtube-button, .ytp-button[aria-label*="YouTube"], .ytp-watermark',
    };
    
    final selector = elementSelectors[elementName];
    if (selector == null) {
      throw ArgumentError('Unknown element name: $elementName');
    }
    
    final displayValue = visible ? 'block' : 'none';
    
    await webViewController.runJavaScript('''
      (function() {
        try {
          // Apply visibility to selected elements
          const elements = document.querySelectorAll('$selector');
          for (const element of elements) {
            element.style.display = '$displayValue';
          }
          
          // Try to apply to iframe elements
          const iframe = document.querySelector('iframe');
          if (iframe && iframe.contentDocument) {
            try {
              const iframeElements = iframe.contentDocument.querySelectorAll('$selector');
              for (const element of iframeElements) {
                element.style.display = '$displayValue';
              }
            } catch (e) {
              console.error('Could not modify iframe elements:', e);
            }
          }
          
          console.log('Set visibility of $elementName to $visible');
        } catch (e) {
          console.error('Error setting element visibility:', e);
        }
      })();
    ''');
  }

  /// Set up JavaScript to sync our settings button visibility with YouTube's controls
  Future<void> _setupSettingsButtonSync() async {
    await webViewController.runJavaScript('''
      (function() {
        // Create or update CSS to manipulate the settings button
        let styleEl = document.getElementById('teqani-settings-button-style');
        if (!styleEl) {
          styleEl = document.createElement('style');
          styleEl.id = 'teqani-settings-button-style';
          document.head.appendChild(styleEl);
        }
        
        // Create global state for settings button visibility
        window.TeqaniSettingsButtonVisible = true;
        
        // Create a function to manipulate settings button visibility through CSS
        window.hideTeqaniSettingsButton = function(hide) {
          window.TeqaniSettingsButtonVisible = !hide;
          
          // Find the settings button container by its position
          const settingsContainer = document.querySelector('.settings-button-container');
          
          // Use CSS to control visibility
          styleEl.textContent = hide ? 
            `
            /* Hide our settings button */
            .flutter-widget-platform-view-container div[style*="top: 8px"][style*="right: 8px"],
            .flutter-view div[style*="top: 8px"][style*="right: 8px"],
            .settings-button-container {
              opacity: 0 !important;
              pointer-events: none !important;
            }
            ` : 
            `
            /* Show our settings button */
            .flutter-widget-platform-view-container div[style*="top: 8px"][style*="right: 8px"],
            .flutter-view div[style*="top: 8px"][style*="right: 8px"],
            .settings-button-container {
              opacity: 1 !important;
              pointer-events: auto !important;
            }
            `;
        };
        
        // Function to check YouTube controls and sync our button
        function checkYouTubeControls() {
          try {
            const ytControls = document.querySelector('.ytp-chrome-bottom');
            const ytTopControls = document.querySelector('.ytp-chrome-top');
            
            // Check if controls are visible
            const ytControlsHidden = 
              (ytControls && ytControls.style.display === 'none') || 
              (ytTopControls && ytTopControls.style.display === 'none');
              
            // Hide our button if YouTube controls are hidden
            window.hideTeqaniSettingsButton(ytControlsHidden);
          } catch (e) {
            console.error('Error checking YouTube controls:', e);
          }
        }
        
        // Set up observer to watch YouTube controls
        try {
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.target.classList.contains('ytp-chrome-bottom') || 
                  mutation.target.classList.contains('ytp-chrome-top')) {
                checkYouTubeControls();
              }
            });
          });
          
          // Configure the observer
          const config = { attributes: true, attributeFilter: ['style', 'class'] };
          
          // Observe both bottom and top controls
          const bottomControls = document.querySelector('.ytp-chrome-bottom');
          const topControls = document.querySelector('.ytp-chrome-top');
          
          if (bottomControls) {
            observer.observe(bottomControls, config);
          }
          
          if (topControls) {
            observer.observe(topControls, config);
          }
          
          console.log('YouTube controls observer setup complete for settings button sync');
          
          // Also watch for interaction with the video to show/hide controls
          const video = document.querySelector('video');
          if (video) {
            video.addEventListener('click', function() {
              // Give the YouTube controls time to show/hide, then sync
              setTimeout(checkYouTubeControls, 100);
            });
          }
          
          // Watch the video player container for clicks
          const playerContainer = document.querySelector('.html5-video-player');
          if (playerContainer) {
            playerContainer.addEventListener('click', function() {
              setTimeout(checkYouTubeControls, 100);
            });
          }
          
          // Initial check
          checkYouTubeControls();
          
          // Also check periodically
          setInterval(checkYouTubeControls, 500);
        } catch (e) {
          console.error('Error setting up controls observer:', e);
        }
      })();
    ''');
    
    // Set up a periodic JavaScript execution to ensure the settings button stays in sync
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      
      webViewController.runJavaScript('''
        try {
          // Force a check of YouTube controls
          const ytControls = document.querySelector('.ytp-chrome-bottom');
          const ytTopControls = document.querySelector('.ytp-chrome-top');
          
          // Check if controls are visible
          const ytControlsHidden = 
            (ytControls && ytControls.style.display === 'none') || 
            (ytTopControls && ytTopControls.style.display === 'none');
            
          // Hide our button if YouTube controls are hidden
          window.hideTeqaniSettingsButton(ytControlsHidden);
        } catch (e) {
          // Silent error
        }
      ''');
    });
  }
}
