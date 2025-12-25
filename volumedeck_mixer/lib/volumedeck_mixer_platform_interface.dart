import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'volumedeck_mixer_method_channel.dart';

abstract class VolumedeckMixerPlatform extends PlatformInterface {
  /// Constructs a VolumedeckMixerPlatform.
  VolumedeckMixerPlatform() : super(token: _token);

  static final Object _token = Object();

  static VolumedeckMixerPlatform _instance = MethodChannelVolumedeckMixer();

  /// The default instance of [VolumedeckMixerPlatform] to use.
  ///
  /// Defaults to [MethodChannelVolumedeckMixer].
  static VolumedeckMixerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VolumedeckMixerPlatform] when
  /// they register themselves.
  static set instance(VolumedeckMixerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
