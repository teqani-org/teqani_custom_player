import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:teqani_youtube_player/teqani_youtube_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teqani YouTube Player Demo',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const PlayerDemoPage(),
    );
  }
}

class PlayerDemoPage extends StatefulWidget {
  const PlayerDemoPage({super.key});

  @override
  PlayerDemoPageState createState() => PlayerDemoPageState();
}

class PlayerDemoPageState extends State<PlayerDemoPage> {
  late TeqaniYoutubePlayerController _controller;

  // Demo video ID (YouTube sample video)
  final String _videoId = 'aKq8bkY5eTU';

  // Track player state
  bool isPlaying = false;
  bool showQualitySettings = true;
  bool showFilterSettings = true;

  @override
  void initState() {
    super.initState();

    // Initialize the controller
    _controller = TeqaniYoutubePlayerController(
      initialConfig: PlayerConfig(
        videoId: _videoId,
        autoPlay: false, // Explicitly disable autoplay
        showControls: false, // Hide YouTube's native controls
        enableJsApi: true,
        muted: false,
        loop: false,
        allowFullscreen: false,

        // --- Example Ad Configuration (COMMENTED OUT - Linter Error) ---
        ads: [
          // Ad 1: Image at the start
          const AdConfig(
            id: 'ad-start-image',
            adType: AdType.image,
            adSource:
                'https://cdn.pixabay.com/photo/2015/04/23/22/00/new-year-background-736885_1280.jpg',
            displayTime: AdDisplayTime.everyMinute,
            duration: Duration(seconds: 5),
            isSkippable: true,
          ),
          // Ad 2: Video ad at custom time (15 seconds)
          const AdConfig(
            id: 'ad-video',
            adType: AdType.video,
            adSource:
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            displayTime: AdDisplayTime.custom,
            customStartTime: Duration(seconds: 15),
            duration: Duration(seconds: 5),
            isSkippable: true,
          ),
          // Ad 3: Image near the end (placeholder logic)
          // const AdConfig(
          //   id: 'ad-end-image',
          //   adType: AdType.image,
          //   adSource: 'https://cdn.pixabay.com/photo/2015/04/23/22/00/new-year-background-736885_1280.jpg',
          //   displayTime: AdDisplayTime.end,
          //   duration: Duration(seconds: 7),
          // ),
        ],

        // --- End Example Ad Configuration ---
        textWatermark: TextWatermarkConfig(
          text: 'Teqani Demo',
          position: WatermarkPosition.topRight,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
          durationType: WatermarkDuration.always,
        ),
        imageWatermark: ImageWatermarkConfig(
          image: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(4),
            child: const Text(
              'TEQANI',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          position: WatermarkPosition.bottomLeft,
          durationType: WatermarkDuration.always,
        ),
      ),
      onReady: () {
        if (kDebugMode) {
          print('Player is ready!');
        }
        // Don't auto-play - wait for user interaction
      },
      onStateChanged: (state) {
        if (kDebugMode) {
          print('Player state changed: $state');
        }
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      },
      onError: (error) {
        if (kDebugMode) {
          print('Player error: $error');
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teqani YouTube Player Example'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          // Player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TeqaniYoutubePlayer(
                  controller: _controller,
                  showControls: true,
                  // Demonstration of the new settings options
                  showQualitySettings: showQualitySettings,
                  showFilterSettings: showFilterSettings,
              
                  settingsButtonConfig: SettingsButtonConfig(
                    alignment: Alignment.centerLeft,
                    visible: true,
                  ),
                ),

                // Add an additional native play button for better experience
              ],
            ),
          ),
   ],
      ),
    );
  }
 }
