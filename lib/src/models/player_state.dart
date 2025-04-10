/// Represents the current state of the YouTube player.
/// 
/// This enum maps directly to the YouTube IFrame API states.
/// See https://developers.google.com/youtube/iframe_api_reference#Playback_status
enum PlayerState {
  /// The player is unstarted (-1)
  unknown,
  
  /// The player is playing (1)
  playing,
  
  /// The player is paused (2)
  paused,
  
  /// The video has ended (0)
  ended,
  
  /// The video is buffering (3)
  buffering,
  
  /// The video was cued but not started (5)
  cued,
}
