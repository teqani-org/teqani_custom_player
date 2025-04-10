import 'package:flutter/material.dart';
import 'package:teqani_youtube_player/src/teqani_youtube_player_controller.dart';

/// A widget that provides controls for adjusting video quality and appearance
class VideoQualityControls extends StatefulWidget {
  
  /// Creates a VideoQualityControls widget
  const VideoQualityControls({
    super.key,
    required this.controller,
    this.textDirection = TextDirection.ltr,
    this.onSettingsApplied,
    this.showQualitySettings = true,
    this.showFilterSettings = true,
  });
  /// The YouTube player controller
  final TeqaniYoutubePlayerController controller;
  
  /// The text direction
  final TextDirection textDirection;
  
  /// Called when settings are applied
  final VoidCallback? onSettingsApplied;
  
  /// Whether to show quality settings
  final bool showQualitySettings;
  
  /// Whether to show filter settings
  final bool showFilterSettings;

  @override
  State<VideoQualityControls> createState() => _VideoQualityControlsState();
}

class _VideoQualityControlsState extends State<VideoQualityControls> {
  late String _selectedQuality;
  late double _sharpness;
  late double _brightness;
  late double _contrast;
  late double _saturation;
  
  List<String> _availableQualities = ['default', 'small', 'medium', 'large', 'hd720', 'hd1080'];
  bool _isLoading = true;
  bool _isRefreshing = false; // Track refresh state separately
  bool _isApplyingQuality = false; // Track when quality is being applied
  
  @override
  void initState() {
    super.initState();
    
    // Initialize with current settings from controller
    _loadCurrentSettings();
    
    // Only load quality levels if quality settings are enabled
    if (widget.showQualitySettings) {
      _loadQualityLevels();
    } else {
      _isLoading = false;
    }
  }
  
  /// Load the current settings from the controller
  void _loadCurrentSettings() {
    // Get current quality setting
    _selectedQuality = widget.controller.currentQuality;
    
    // Get current filter settings
    final filterSettings = widget.controller.currentFilterSettings;
    _sharpness = filterSettings['sharpness'] ?? 100;
    _brightness = filterSettings['brightness'] ?? 100;
    _contrast = filterSettings['contrast'] ?? 100;
    _saturation = filterSettings['saturation'] ?? 100;
  }
  
  Future<void> _loadQualityLevels() async {
    if (_isLoading) {
      // Already loading for the first time, don't set state
    } else {
      // This is a refresh, show refresh indicator
      setState(() {
        _isRefreshing = true;
      });
    }
    
    try {
      final levels = await widget.controller.getAvailableQualityLevels();
      if (mounted) {
        setState(() {
          _availableQualities = levels;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading quality levels: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }
  
  void _applySettings() {
    // Only apply the relevant settings
    if (widget.showQualitySettings) {
      _applyQuality();
    }
    
    if (widget.showFilterSettings) {
      widget.controller.applyVideoFilters(
        sharpness: _sharpness,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
      );
    }
    
    widget.onSettingsApplied?.call();
  }
  
  // New method to apply quality with loading state
  Future<void> _applyQuality() async {
    if (_isApplyingQuality) return; // Prevent multiple simultaneous applications
    
    setState(() {
      _isApplyingQuality = true;
    });
    
    try {
      await widget.controller.setVideoQuality(_selectedQuality);
      
      // Wait a moment to allow quality to change
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      debugPrint('Error applying quality: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingQuality = false;
        });
      }
    }
  }
  
  void _resetToDefaults() {
    setState(() {
      if (widget.showQualitySettings) {
        _selectedQuality = 'default';
      }
      
      if (widget.showFilterSettings) {
        _sharpness = 100;
        _brightness = 100;
        _contrast = 100;
        _saturation = 100;
      }
    });
    
    if (widget.showFilterSettings) {
      widget.controller.resetVideoFilters();
    }
    
    if (widget.showQualitySettings) {
      widget.controller.setVideoQuality('default');
    }
    
    widget.onSettingsApplied?.call();
  }
  
  // Get a user-friendly name for quality values
  String _getQualityDisplayName(String quality) {
    switch (quality) {
      case 'tiny': return '144p';
      case 'small': return '240p';
      case 'medium': return '360p';
      case 'large': return '480p';
      case 'hd720': return '720p';
      case 'hd1080': return '1080p';
      case 'highres': return 'High Res';
      case 'default': return 'Auto';
      default: return quality;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.textDirection,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Video Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.white30),
            
            // Quality selection - only show if enabled
            if (widget.showQualitySettings) ...[
              Row(
                children: [
                  const Text(
                    'Quality',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (_isApplyingQuality)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Applying...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current quality indicator
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Text(
                                'Current: ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha:.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withValues(alpha:0.5)),
                                ),
                                child: Text(
                                  _getQualityDisplayName(widget.controller.currentQuality),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableQualities.map((quality) {
                            final displayName = _getQualityDisplayName(quality);
                            final isCurrentQuality = widget.controller.currentQuality == quality;
                            
                            return ChoiceChip(
                              label: Text(displayName),
                              selected: _selectedQuality == quality,
                              selectedColor: isCurrentQuality ? Colors.green : Colors.blue,
                              backgroundColor: isCurrentQuality ? Colors.green.withValues(alpha:0.15) : null,
                              avatar: isCurrentQuality ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                              tooltip: isCurrentQuality ? 'Current quality' : null,
                              onSelected: (selected) {
                                if (selected && !_isApplyingQuality) {
                                  setState(() {
                                    _selectedQuality = quality;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        // Quality explanation
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                          child: Text(
                            _buildQualityExplanation(_selectedQuality),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        // Add a refresh button to refetch qualities
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: (_isLoading || _isRefreshing || _isApplyingQuality) 
                                ? null 
                                : _loadQualityLevels,
                              icon: _isRefreshing 
                                ? const SizedBox(
                                    width: 16, 
                                    height: 16, 
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  ) 
                                : const Icon(Icons.refresh, size: 16),
                              label: Text(_isRefreshing ? 'Refreshing...' : 'Refresh qualities'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const Spacer(),
                            // Add direct apply quality button for immediate testing
                            if (_selectedQuality != widget.controller.currentQuality)
                              TextButton.icon(
                                onPressed: _isApplyingQuality ? null : () async {
                                  final scaffoldContext = context;
                                  await _applyQuality();
                                  if (scaffoldContext.mounted) {
                                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                      SnackBar(
                                        content: Text('Applied quality: ${_getQualityDisplayName(_selectedQuality)}'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                icon: _isApplyingQuality 
                                  ? const SizedBox(
                                      width: 16, 
                                      height: 16, 
                                      child: CircularProgressIndicator(strokeWidth: 2)
                                    )
                                  : const Icon(Icons.check, size: 16),
                                label: Text(_isApplyingQuality ? 'Applying...' : 'Apply Quality Only'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
            ],
            
            // Filter settings - only show if enabled
            if (widget.showFilterSettings) ...[
              const Text(
                'Video Enhancement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              
              // Sharpness control
              Row(
                children: [
                  const Text('Sharpness:', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _sharpness,
                      min: 0,
                      max: 200,
                      divisions: 20,
                      label: _sharpness.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _sharpness = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${_sharpness.round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              
              // Brightness control
              Row(
                children: [
                  const Text('Brightness:', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _brightness,
                      min: 50,
                      max: 150,
                      divisions: 10,
                      label: _brightness.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _brightness = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${_brightness.round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              
              // Contrast control
              Row(
                children: [
                  const Text('Contrast:', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _contrast,
                      min: 50,
                      max: 150,
                      divisions: 10,
                      label: _contrast.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _contrast = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${_contrast.round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              
              // Saturation control
              Row(
                children: [
                  const Text('Saturation:', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _saturation,
                      min: 0,
                      max: 200,
                      divisions: 20,
                      label: _saturation.round().toString(),
                      onChanged: (value) {
                        setState(() {
                          _saturation = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${_saturation.round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
            ],
            
            // Action buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isApplyingQuality ? null : _resetToDefaults,
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isApplyingQuality ? null : _applySettings,
                  child: _isApplyingQuality 
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Applying...'),
                        ],
                      )
                    : const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build quality explanation text
  String _buildQualityExplanation(String quality) {
    switch (quality) {
      case 'default':
        return 'Auto: YouTube chooses optimal quality based on connection';
      case 'tiny':
        return '144p: Lowest quality, minimizes data usage';
      case 'small':
        return '240p: Low quality, good for very slow connections';
      case 'medium':
        return '360p: Standard definition, moderate data usage';
      case 'large':
        return '480p: Standard definition, better detail';
      case 'hd720':
        return '720p: HD quality, recommended for most viewing';
      case 'hd1080':
        return '1080p: Full HD quality, requires good connection';
      case 'highres':
        return 'High Resolution: 1440p/2160p/4K, requires excellent connection';
      default:
        return '';
    }
  }
} 