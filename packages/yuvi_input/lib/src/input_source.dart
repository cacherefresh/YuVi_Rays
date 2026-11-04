import 'mixer_command.dart';

/// Anything that turns user input into [MixerCommand]s.
abstract interface class InputSource {
  /// Broadcast stream of commands. Subscribe before calling [start].
  Stream<MixerCommand> get commands;

  /// Begin listening to the underlying device.
  Future<void> start();

  /// Stop listening. [start] may be called again later.
  Future<void> stop();

  /// Release resources. The source can't be used afterwards.
  Future<void> dispose();
}
