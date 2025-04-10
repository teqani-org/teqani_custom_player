import Flutter
import UIKit
import WebKit

public class TeqaniYoutubePlayerPlugin: NSObject, FlutterPlugin {
  private var viewRegistry: FlutterTextureRegistry
  private var messenger: FlutterBinaryMessenger
  private var nextViewId = 0
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Setup player channel
    let playerChannel = FlutterMethodChannel(name: "com.teqani.youtube_player/player", binaryMessenger: registrar.messenger())
    
    // Setup factory channel
    let factoryChannel = FlutterMethodChannel(name: "com.teqani.youtube_player/factory", binaryMessenger: registrar.messenger())
    
    let instance = TeqaniYoutubePlayerPlugin(messenger: registrar.messenger(), viewRegistry: registrar.textures())
    registrar.addMethodCallDelegate(instance, channel: playerChannel)
    registrar.addMethodCallDelegate(instance, channel: factoryChannel)
    
    // Register view factory
    registrar.register(
      TeqaniYoutubePlayerFactory(messenger: registrar.messenger()),
      withId: "com.teqani.youtube_player/player_view"
    )
  }
  
  init(messenger: FlutterBinaryMessenger, viewRegistry: FlutterTextureRegistry) {
    self.messenger = messenger
    self.viewRegistry = viewRegistry
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Handle factory channel methods
    if call.method == "create" {
      let viewId = nextViewId
      nextViewId += 1
      result(viewId)
      return
    }
    
    // Handle player channel methods
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "initialize", "play", "pause", "seekTo", "setPlaybackRate", 
         "enterFullscreen", "exitFullscreen", "loadVideo", "mute", "unmute", "dispose":
      // These will be handled by the platform view implementation
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - YouTube Player Factory
class TeqaniYoutubePlayerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return TeqaniYoutubePlayerView(
      frame: frame,
      viewId: viewId,
      arguments: args as? [String: Any],
      messenger: messenger
    )
  }
  
  public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

// MARK: - YouTube Player View
class TeqaniYoutubePlayerView: NSObject, FlutterPlatformView, WKNavigationDelegate, WKScriptMessageHandler {
  private let webView: WKWebView
  private let frame: CGRect
  private let viewId: Int64
  private let methodChannel: FlutterMethodChannel
  
  private var isPlayerReady = false
  private var pendingVideoId: String?
  private var pendingAutoPlay: Bool?
  private var pendingStartAt: Int?
  private var pendingMuted: Bool?
  
  init(frame: CGRect, viewId: Int64, arguments: [String: Any]?, messenger: FlutterBinaryMessenger) {
    self.frame = frame
    self.viewId = viewId
    
    // Configure WebView with YouTube player
    let configuration = WKWebViewConfiguration()
    configuration.allowsInlineMediaPlayback = true
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.userContentController.add(TeqaniScriptMessageHandler(), name: "teqaniYouTubePlayer")
    
    webView = WKWebView(frame: frame, configuration: configuration)
    webView.scrollView.isScrollEnabled = false
    webView.navigationDelegate = self
    
    // Setup method channel for player control
    methodChannel = FlutterMethodChannel(
      name: "com.teqani.youtube_player/player_\(viewId)",
      binaryMessenger: messenger
    )
    
    super.init()
    
    // Load the HTML with embedded YouTube player
    loadYouTubePlayerHTML()
    
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      self.handle(call, result: result)
    }
  }
  
  func view() -> UIView {
    return webView
  }
  
  // MARK: - Method Channel Handler
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      handleInitialize(call, result: result)
    case "play":
      executeScript("player.playVideo();")
      result(nil)
    case "pause":
      executeScript("player.pauseVideo();")
      result(nil)
    case "seekTo":
      if let args = call.arguments as? [String: Any], let seconds = args["seconds"] as? Double {
        executeScript("player.seekTo(\(seconds), true);")
      }
      result(nil)
    case "setPlaybackRate":
      if let args = call.arguments as? [String: Any], let rate = args["rate"] as? Double {
        executeScript("player.setPlaybackRate(\(rate));")
      }
      result(nil)
    case "enterFullscreen":
      // Fullscreen not supported directly in WebView implementation
      result(nil)
    case "exitFullscreen":
      // Fullscreen not supported directly in WebView implementation
      result(nil)
    case "loadVideo":
      handleLoadVideo(call, result: result)
    case "mute":
      executeScript("player.mute();")
      result(nil)
    case "unmute":
      executeScript("player.unMute();")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - Helper Methods
  private func loadYouTubePlayerHTML() {
    let htmlString = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>
        body { margin: 0; padding: 0; overflow: hidden; background-color: #000; }
        #player { position: absolute; width: 100%; height: 100%; }
      </style>
    </head>
    <body>
      <div id="player"></div>
      
      <script>
        // Load YouTube IFrame API
        var tag = document.createElement('script');
        tag.src = "https://www.youtube.com/iframe_api";
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
        
        var player;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            height: '100%',
            width: '100%',
            playerVars: {
              'playsinline': 1,
              'controls': 1,
              'rel': 0
            },
            events: {
              'onReady': onPlayerReady,
              'onStateChange': onPlayerStateChange,
              'onError': onPlayerError
            }
          });
        }
        
        function onPlayerReady(event) {
          window.webkit.messageHandlers.teqaniYouTubePlayer.postMessage({
            'event': 'onReady'
          });
        }
        
        function onPlayerStateChange(event) {
          window.webkit.messageHandlers.teqaniYouTubePlayer.postMessage({
            'event': 'onStateChange',
            'state': event.data
          });
        }
        
        function onPlayerError(event) {
          window.webkit.messageHandlers.teqaniYouTubePlayer.postMessage({
            'event': 'onError',
            'error': event.data
          });
        }
      </script>
    </body>
    </html>
    """
    
    webView.loadHTMLString(htmlString, baseURL: nil)
  }
  
  private func executeScript(_ script: String) {
    webView.evaluateJavaScript(script, completionHandler: nil)
  }
  
  private func handleInitialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], 
          let videoId = args["videoId"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "VideoId cannot be null", details: nil))
      return
    }
    
    let autoPlay = args["autoPlay"] as? Bool ?? false
    let showControls = args["showControls"] as? Bool ?? true
    let muted = args["muted"] as? Bool ?? false
    let startAt = args["startAt"] as? Int ?? 0
    
    if !isPlayerReady {
      // Store for later when player is ready
      pendingVideoId = videoId
      pendingAutoPlay = autoPlay
      pendingStartAt = startAt
      pendingMuted = muted
      result(nil)
      return
    }
    
    // Configure player with options
    var options = [
      "videoId": videoId,
      "controls": showControls ? 1 : 0,
    ]
    
    var loadScript = "player.cueVideoById({"
    if autoPlay {
      loadScript = "player.loadVideoById({"
    }
    
    loadScript += "videoId: '\(videoId)'"
    
    if startAt > 0 {
      loadScript += ", startSeconds: \(startAt)"
    }
    
    loadScript += "});"
    
    executeScript(loadScript)
    
    if muted {
      executeScript("player.mute();")
    }
    
    result(nil)
  }
  
  private func handleLoadVideo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], 
          let videoId = args["videoId"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "VideoId cannot be null", details: nil))
      return
    }
    
    let autoPlay = args["autoPlay"] as? Bool ?? false
    let startAt = args["startAt"] as? Int ?? 0
    
    var loadScript = "player.cueVideoById({"
    if autoPlay {
      loadScript = "player.loadVideoById({"
    }
    
    loadScript += "videoId: '\(videoId)'"
    
    if startAt > 0 {
      loadScript += ", startSeconds: \(startAt)"
    }
    
    loadScript += "});"
    
    executeScript(loadScript)
    result(nil)
  }
  
  // MARK: - WKNavigationDelegate
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    isPlayerReady = true
    
    // If we have pending player settings, apply them now
    if let videoId = pendingVideoId {
      var loadScript = "player.cueVideoById({"
      if pendingAutoPlay ?? false {
        loadScript = "player.loadVideoById({"
      }
      
      loadScript += "videoId: '\(videoId)'"
      
      if let startAt = pendingStartAt, startAt > 0 {
        loadScript += ", startSeconds: \(startAt)"
      }
      
      loadScript += "});"
      
      executeScript(loadScript)
      
      if pendingMuted ?? false {
        executeScript("player.mute();")
      }
      
      // Clear pending settings
      pendingVideoId = nil
      pendingAutoPlay = nil
      pendingStartAt = nil
      pendingMuted = nil
    }
  }
  
  // MARK: - WKScriptMessageHandler
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let dict = message.body as? [String: Any],
          let event = dict["event"] as? String else { return }
    
    switch event {
    case "onReady":
      isPlayerReady = true
      methodChannel.invokeMethod("onReady", arguments: nil)
    case "onStateChange":
      if let state = dict["state"] as? Int {
        var stateString = "unknown"
        switch state {
        case -1: stateString = "unstarted"
        case 0: stateString = "ended"
        case 1: stateString = "playing"
        case 2: stateString = "paused"
        case 3: stateString = "buffering"
        case 5: stateString = "cued"
        default: stateString = "unknown"
        }
        methodChannel.invokeMethod("onStateChange", arguments: stateString)
      }
    case "onError":
      if let error = dict["error"] as? Int {
        methodChannel.invokeMethod("onError", arguments: "Error code: \(error)")
      }
    default:
      break
    }
  }
}

// Proxy class to avoid retain cycles between WebView and message handler
class TeqaniScriptMessageHandler: NSObject, WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    // This is a proxy class - not used directly
  }
}
