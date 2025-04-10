import 'dart:async';

import 'package:flutter/material.dart';

import 'package:teqani_youtube_player/src/teqani_youtube_player_controller.dart';

/// Custom player controls for the TeqaniYoutubePlayer.
class CustomControls extends StatefulWidget {

  /// Creates a CustomControls widget
  const CustomControls({
    super.key,
    required this.controller,
    required this.isLandscape,
    this.allowFullscreen = true,
  });
  /// The controller for the player
  final TeqaniYoutubePlayerController controller;
  
  /// Whether the device is in landscape mode
  final bool isLandscape;
  
  /// Whether to allow fullscreen mode
  final bool allowFullscreen;

  @override
  State<CustomControls> createState() => _CustomControlsState();
}

class _CustomControlsState extends State<CustomControls> {
  /// Timer for auto-hiding controls
  Timer? _hideTimer;
  
  /// Whether controls are visible
  bool _controlsVisible = true;
  
  /// Whether user is dragging the progress bar
  bool _dragging = false;
  
  /// Current position as a double between 0.0 and 1.0 during dragging
  double _dragPosition = 0.0;
  
  /// Dropdown controller for playback speed menu
  final _playbackRateMenuController = OverlayPortalController();

  /// Available playback rates
  final List<double> _playbackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  
  /// Throttle timer for position updates
  Timer? _positionUpdateTimer;
  
  /// Cached values to reduce rebuilds
  double _cachedPosition = 0.0;
  double _cachedDuration = 0.0;
  String _formattedPosition = '0:00';
  String _formattedDuration = '0:00';

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _updateCachedPositions();
  }
  
  @override
  void didUpdateWidget(CustomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Schedule position update with debouncing
    if (_positionUpdateTimer?.isActive != true) {
      _positionUpdateTimer = Timer(const Duration(milliseconds: 250), () {
        _updateCachedPositions();
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }
  
  /// Update cached position and duration values
  void _updateCachedPositions() {
    final currentPosition = _dragging 
        ? _dragPosition * widget.controller.videoDuration 
        : widget.controller.currentPosition;
        
    final duration = widget.controller.videoDuration;
    
    // Only update if values changed significantly
    if ((_cachedPosition - currentPosition).abs() > 0.5 || 
        (_cachedDuration - duration).abs() > 0.5) {
      
      setState(() {
        _cachedPosition = currentPosition;
        _cachedDuration = duration;
        _formattedPosition = _formatDuration(currentPosition);
        _formattedDuration = _formatDuration(duration);
      });
    }
  }

  /// Start the timer to hide controls
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_dragging) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  /// Show controls and reset the hide timer
  void _showControls() {
    setState(() {
      _controlsVisible = true;
    });
    _startHideTimer();
  }

  /// Format duration in seconds to mm:ss format
  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds - minutes * 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress value between 0.0 and 1.0
    final progress = _cachedDuration > 0 
        ? (_dragging ? _dragPosition : _cachedPosition / _cachedDuration).clamp(0.0, 1.0)
        : 0.0;
        
    return GestureDetector(
      onTap: () {
        if (_controlsVisible) {
          setState(() {
            _controlsVisible = false;
          });
          _hideTimer?.cancel();
        } else {
          _showControls();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: _controlsVisible ? RepaintBoundary(
          child: Container(
            color: Colors.black38,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top controls (title, close button, etc.)
                _buildTopControls(),
                
                // Center controls (play/pause, rewind, fast forward)
                _buildCenterControls(),
                
                // Bottom controls (progress bar, time, fullscreen)
                _buildBottomControls(progress),
              ],
            ),
          ),
        ) : const SizedBox.shrink(),
      ),
    );
  }

  /// Build the top controls section
  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Playback rate dropdown
          _buildPlaybackRateButton(),
          
          // Fullscreen button (only shown if not in landscape and allowed)
          if (!widget.isLandscape && widget.allowFullscreen)
            IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: () {
                widget.controller.enterFullscreen();
              },
            ),
        ],
      ),
    );
  }

  /// Build the center controls section with RepaintBoundary for performance
  Widget _buildCenterControls() {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rewind button
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: () {
              widget.controller.rewind(10);
              _startHideTimer();
            },
          ),
          
          // Play/Pause button
          IconButton(
            iconSize: 50,
            icon: Icon(
              widget.controller.isPlaying 
                  ? Icons.pause_circle_filled 
                  : Icons.play_circle_filled,
              color: Colors.white,
            ),
            onPressed: () {
              if (widget.controller.isPlaying) {
                widget.controller.pause();
              } else {
                widget.controller.play();
              }
              _startHideTimer();
            },
          ),
          
          // Fast forward button
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.forward_10, color: Colors.white),
            onPressed: () {
              widget.controller.fastForward(10);
              _startHideTimer();
            },
          ),
        ],
      ),
    );
  }

  /// Build the bottom controls section with progress
  Widget _buildBottomControls(double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
              thumbColor: Colors.red,
              activeTrackColor: Colors.red,
              inactiveTrackColor: Colors.grey[700],
              overlayColor: Colors.red.withValues(alpha:0.3),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                setState(() {
                  _dragging = true;
                  _dragPosition = value;
                });
              },
              onChangeStart: (value) {
                setState(() {
                  _dragging = true;
                  _dragPosition = value;
                });
                _hideTimer?.cancel();
              },
              onChangeEnd: (value) {
                final newPosition = value * _cachedDuration;
                widget.controller.seekTo(newPosition);
                
                // Slight delay before turning off dragging to let animation complete
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) {
                    setState(() {
                      _dragging = false;
                    });
                  }
                });
                
                _startHideTimer();
              },
            ),
          ),
          
          // Time display and fullscreen button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Time display
              Text(
                '$_formattedPosition / $_formattedDuration',
                style: const TextStyle(color: Colors.white),
              ),
              
              // Fullscreen button (only shown if in landscape and allowed)
              if (widget.isLandscape && widget.allowFullscreen)
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  onPressed: () {
                    widget.controller.exitFullscreen();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build playback rate dropdown button
  Widget _buildPlaybackRateButton() {
    return OverlayPortal(
      controller: _playbackRateMenuController,
      overlayChildBuilder: (context) {
        return Positioned(
          top: 50,
          right: 10,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Colors.black87,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _playbackRates.map((rate) {
                  final isSelected = widget.controller.playbackRate == rate;
                  return InkWell(
                    onTap: () {
                      widget.controller.setPlaybackRate(rate);
                      _playbackRateMenuController.hide();
                      _startHideTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      width: 100,
                      color: isSelected ? Colors.red.withValues(alpha:0.3) : Colors.transparent,
                      child: Text(
                        '${rate}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
      child: IconButton(
        icon: const Icon(Icons.speed, color: Colors.white),
        onPressed: () {
          if (_playbackRateMenuController.isShowing) {
            _playbackRateMenuController.hide();
          } else {
            _playbackRateMenuController.show();
          }
          _startHideTimer();
        },
      ),
    );
  }
}
