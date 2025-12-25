import 'package:flutter_test/flutter_test.dart';
import 'package:volumedeck_mixer/volumedeck_mixer.dart';
import 'package:volumedeck_mixer/volumedeck_mixer_platform_interface.dart';
import 'package:volumedeck_mixer/volumedeck_mixer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVolumedeckMixerPlatform
    with MockPlatformInterfaceMixin
    implements VolumedeckMixerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VolumedeckMixerPlatform initialPlatform = VolumedeckMixerPlatform.instance;

  test('$MethodChannelVolumedeckMixer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVolumedeckMixer>());
  });

  test('getPlatformVersion', () async {
    VolumedeckMixer volumedeckMixerPlugin = VolumedeckMixer();
    MockVolumedeckMixerPlatform fakePlatform = MockVolumedeckMixerPlatform();
    VolumedeckMixerPlatform.instance = fakePlatform;

    expect(await volumedeckMixerPlugin.getPlatformVersion(), '42');
  });
}
