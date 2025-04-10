/// Represents an error that occurred in the YouTube player.
class PlayerError {

  /// Constructor for PlayerError
  const PlayerError({
    required this.code, 
    required this.message
  });
  /// Error code from the player
  final int code;
  
  /// Human-readable error message
  final String message;

  @override
  String toString() => 'PlayerError(code: $code, message: $message)';
}
