import 'package:bolt/services/updater.dart';
import 'package:flutter_test/flutter_test.dart';

Release release(String version, int? build) =>
    Release(title: 'BOLT $version', version: version, build: build, notes: '', apkUrl: 'u', apkBytes: 1);

void main() {
  test('tags parse with or without v and build number', () {
    expect(parseTag('v1.2.0+3'), ('1.2.0', 3));
    expect(parseTag('1.2.0'), ('1.2.0', null));
    expect(parseTag('BOLT 1.2.0'), isNull);
  });

  test('versions compare as numbers', () {
    expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('1.1.0', '1.2.0'), lessThan(0));
  });

  test('the build number decides when both sides have one', () {
    expect(isNewer(release('1.2.0', 3), const Installed('1.1.0', 2)), isTrue);
    expect(isNewer(release('1.1.0', 2), const Installed('1.1.0', 2)), isFalse);
    expect(isNewer(release('1.0.0', 5), const Installed('1.1.0', 2)), isTrue);
    expect(isNewer(release('1.2.0', null), const Installed('1.1.0', 2)), isTrue);
    expect(isNewer(release('1.2.0', null), const Installed('', null)), isTrue);
  });

  test('split APK version codes carry an ABI offset', () {
    // arm64 phones report build 2 as 2002, x86_64 as 4002.
    expect(isNewer(release('1.2.0', 3), const Installed('1.1.0', 2002)), isTrue);
    expect(isNewer(release('1.2.0', 3), const Installed('1.2.0', 2003)), isFalse);
    expect(isNewer(release('1.1.0', 2), const Installed('1.0.9', 4001)), isTrue);
  });

  test('arm64 APK is picked over others', () {
    final assets = [
      {'name': 'notes.txt', 'browser_download_url': 'x', 'size': 1},
      {'name': 'BOLT-1.2.0+3-armeabi-v7a.apk', 'browser_download_url': 'v7', 'size': 2},
      {'name': 'BOLT-1.2.0+3-arm64.apk', 'browser_download_url': 'a64', 'size': 3},
    ];
    expect(pickApk(assets), (url: 'a64', bytes: 3));
    expect(pickApk(assets.sublist(0, 2)), (url: 'v7', bytes: 2));
    expect(pickApk([]), isNull);
    expect(pickApk(null), isNull);
  });

  test('release notes read as plain text', () {
    expect(
      plainNotes('## New\r\n- **Onboarding:** pick a role\n* `Reset app`\n\n\n\nDone'),
      'New\n• Onboarding: pick a role\n• Reset app\n\nDone',
    );
  });
}
