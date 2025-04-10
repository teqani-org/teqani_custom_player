import 'package:flutter/material.dart';
// Ensure AdConfig is accessible, adjust path if needed
// Assuming AdConfig is in teqani_youtube_player_widget.dart for now
import 'package:teqani_youtube_player/src/models/ad_config.dart';  // Fix the import path
import 'package:video_player/video_player.dart';

/// A widget that displays an advertisement overlay.
class AdOverlay extends StatefulWidget { // Callback for skip functionality

  const AdOverlay({
    super.key,
    required this.adConfig,
    this.onAdComplete,
    this.onSkipAd,
  });
  final AdConfig adConfig;
  final VoidCallback? onAdComplete; // Callback when ad finishes (e.g., called by timer)
  final VoidCallback? onSkipAd;

  @override
  State<AdOverlay> createState() => _AdOverlayState();
}

class _AdOverlayState extends State<AdOverlay> {
  // Video player controller for video ads
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoError = false;
  String _videoErrorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.adConfig.adType == AdType.video) {
      _initializeVideoPlayer();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer() async {
    final String videoUrl = widget.adConfig.adSource;
    
    // Check if it's a valid URL or asset path
    if (videoUrl.isEmpty) {
      setState(() {
        _isVideoError = true;
        _videoErrorMessage = 'Empty video source';
      });
      return;
    }

    try {
      // Check if it's a network URL
      final bool isNetwork = videoUrl.startsWith('http://') || videoUrl.startsWith('https://');
      
      if (isNetwork) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      } else {
        // For local assets, ensure the path is properly formatted
        final String assetPath = videoUrl.startsWith('assets/') 
            ? videoUrl 
            : 'assets/$videoUrl';
        _videoController = VideoPlayerController.asset(assetPath);
      }

      // Initialize and play video
      await _videoController!.initialize();
      await _videoController!.setLooping(false);
      await _videoController!.play();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }

      // Listen for video completion
      _videoController!.addListener(_onVideoProgress);
      
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isVideoError = true;
          _videoErrorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  void _onVideoProgress() {
    if (_videoController != null && 
        _videoController!.value.isInitialized && 
        _videoController!.value.position >= _videoController!.value.duration) {
      // Video completed, call the completion callback
      widget.onAdComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha:0.85), // Semi-transparent background
      child: Stack(
        fit: StackFit.expand, // Ensure the stack takes the full space
        children: [
          // Ad Content in full screen
          _buildAdContent(),
          
          // Ad info banner at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Placeholder for remaining time or ad info
                  const Text(
                    'Advertisement', // Simple label
                    style: TextStyle(color: Colors.white70),
                  ),
                  // Placeholder for skip button (if enabled in future)
                  if (widget.adConfig.isSkippable && widget.onSkipAd != null)
                    ElevatedButton(
                      onPressed: widget.onSkipAd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha:0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text('Skip Ad >'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the actual ad content based on AdType.
  Widget _buildAdContent() {
    switch (widget.adConfig.adType) {
      case AdType.image:
        return _buildImageAd();
      case AdType.video:
        return _buildVideoAd();
    }
  }

  /// Builds an image ad.
  Widget _buildImageAd() {
    // Validate ad source
    if (widget.adConfig.adSource.isEmpty || widget.adConfig.adSource == 'placeholder') {
      debugPrint('Invalid ad source: ${widget.adConfig.adSource}');
      return _buildErrorFallback('Please provide a valid image URL or asset path');
    }

    // Check if it's a network URL
    final bool isNetwork = widget.adConfig.adSource.startsWith('http://') ||
                         widget.adConfig.adSource.startsWith('https://');

    debugPrint('Ad source: ${widget.adConfig.adSource}');
    debugPrint('Is network URL: $isNetwork');

    // Check if it's a local asset path
    final bool isAsset = widget.adConfig.adSource.startsWith('assets/') ||
                        widget.adConfig.adSource.startsWith('images/');

    debugPrint('Is asset path: $isAsset');

    if (!isNetwork && !isAsset) {
      debugPrint('Invalid ad source format');
      return _buildErrorFallback(
        'Invalid ad source format. Use either:\n'
        '- Network URL (starting with http:// or https://)\n'
        '- Local asset path (starting with assets/ or images/)'
      );
    }

    ImageProvider imageProvider;
    try {
      if (isNetwork) {
        debugPrint('Creating NetworkImage for: ${widget.adConfig.adSource}');
        imageProvider = NetworkImage(widget.adConfig.adSource);
      } else {
        // For local assets, ensure the path is properly formatted
        final String assetPath = widget.adConfig.adSource.startsWith('assets/') 
            ? widget.adConfig.adSource 
            : 'assets/${widget.adConfig.adSource}';
        debugPrint('Creating AssetImage for: $assetPath');
        imageProvider = AssetImage(assetPath);
      }
    } catch (e, stackTrace) {
      debugPrint('Error creating image provider for ad: $e');
      debugPrint('Stack trace: $stackTrace');
      return _buildErrorFallback(
        isNetwork 
          ? 'Failed to load network image: ${widget.adConfig.adSource}'
          : 'Failed to load local asset: ${widget.adConfig.adSource}'
      );
    }

    // Remove constraints and padding to allow the image to take full size
    return Image(
      image: imageProvider,
      fit: BoxFit.cover, // Use cover to fill the entire space
      width: double.infinity, // Take full width
      height: double.infinity, // Take full height
      loadingBuilder: (context, child, loadingProgress) {

        if (loadingProgress == null) return child;

        return _buildShimmerEffect();
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading ad image: $error');
        debugPrint('Stack trace: $stackTrace');
        return _buildErrorFallback(
          isNetwork 
            ? 'Failed to load network image: ${widget.adConfig.adSource}'
            : 'Failed to load local asset: ${widget.adConfig.adSource}'
        );
      },
    );
  }

  /// Builds a video ad.
  Widget _buildVideoAd() {
    if (_isVideoError) {
      return _buildErrorFallback(_videoErrorMessage);
    }

    if (!_isVideoInitialized || _videoController == null) {

      return _buildShimmerEffect();
    }

    // Display the video without controls - just the raw video player
    return VideoPlayer(_videoController!);
  }

  /// Builds a custom shimmer loading effect without external packages
  Widget _buildShimmerEffect() {
    // Get the brand's theme color (YouTube-like red)
    const Color brandColor = Color(0xFFFF0000);
    return ShimmerLoading(
      baseColor: Colors.black.withValues(alpha:0.3),
      highlightColor: Colors.black.withValues(alpha:0.1),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background shimmer effect covering the whole area
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
            ),
            
            // Overlay with centered loading indicator
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Loading indicator
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha:0.7),
                    ),
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: brandColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Loading text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha:0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Loading Ad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorFallback(String errorMessage) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            'Ad Loading Error',
            style: TextStyle(color: Colors.red[200]),
          ),
          const SizedBox(height: 4),
          Text(
            errorMessage,
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Custom shimmer effect widget without using external packages
class ShimmerLoading extends StatefulWidget {

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFEBEBF4),
    this.highlightColor = Colors.white,
  });
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment(_animation.value, -0.5),
              end: Alignment(_animation.value + 1, 0.5),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}