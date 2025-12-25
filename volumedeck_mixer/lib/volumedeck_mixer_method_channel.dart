import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'volumedeck_mixer_platform_interface.dart';

/// An implementation of [VolumedeckMixerPlatform] that uses method channels.
class MethodChannelVolumedeckMixer extends VolumedeckMixerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('volumedeck_mixer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
