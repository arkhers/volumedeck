
import 'volumedeck_mixer_platform_interface.dart';

class VolumedeckMixer {
  Future<String?> getPlatformVersion() {
    return VolumedeckMixerPlatform.instance.getPlatformVersion();
  }
}
