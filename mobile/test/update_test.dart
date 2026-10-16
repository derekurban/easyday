import 'package:fitness/logic/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('updates', () {
    test('versions parse from tags, pubspec strings and flavour suffixes', () {
      expect(versionParts('v0.13.5'), [0, 13, 5]);
      expect(versionParts('0.13.5+19'), [0, 13, 5]);
      expect(versionParts('0.13.5-staging'), [0, 13, 5]);
      expect(versionParts('nope'), isEmpty);
    });

    test('newer means a higher part, left to right, with missing parts as zero', () {
      expect(compareVersions('0.14.0', '0.13.9'), greaterThan(0));
      expect(compareVersions('0.13.5', '0.13.5+19'), 0);
      expect(compareVersions('0.13', '0.13.0'), 0);
      expect(compareVersions('v0.13.4', '0.13.5-staging'), lessThan(0));
      expect(compareVersions('1.0.0', '0.99.99'), greaterThan(0));
    });

    test('a GitHub release gives the version, notes and one URL per asset', () {
      final r = parseRelease('{"tag_name":"v0.13.5","body":"body map\\n","published_at":"2026-10-16T14:00:00Z",'
          '"assets":[{"name":"fitness.apk","browser_download_url":"https://x/fitness.apk"},{"name":"fitness-staging.apk","browser_download_url":"https://x/s.apk"}]}')!;
      expect(r.version, '0.13.5');
      expect(r.notes, 'body map');
      expect(r.assets[assetFor('prod')], 'https://x/fitness.apk');
      expect(r.assets[assetFor('staging')], 'https://x/s.apk');
      expect(r.at!.year, 2026);
      expect(parseRelease('{"message":"Not Found"}'), isNull);
      expect(parseRelease('not json'), isNull);
    });

    test('a staging tag carries its build number, and a later build of the same version is newer', () {
      expect(tagBuild('v0.13.6-staging.20042'), 20042);
      expect(tagBuild('v0.13.6'), isNull);
      expect(tagBuild('v0.13.7-prod.100043'), 100043);
      final p = parseRelease('{"tag_name":"v0.13.7-prod.100043","assets":[]}')!;
      expect(isNewer(p, '0.13.7', 100042), isTrue);
      expect(isNewer(p, '0.13.7', 100043), isFalse);
      expect(isNewer(p, '0.13.6', 20), isTrue);
      expect(releaseLabel(p), '0.13.7 (build 100043)');
      expect(releaseLabel(parseRelease('{"tag_name":"v0.13.6","assets":[]}')!), '0.13.6');
      final r = parseRelease('{"tag_name":"v0.13.6-staging.20042","assets":[]}')!;
      expect(r.version, '0.13.6-staging.20042');
      expect(r.build, 20042);
      expect(isNewer(r, '0.13.6-staging', 20041), isTrue);
      expect(isNewer(r, '0.13.6-staging', 20042), isFalse);
      expect(isNewer(r, '0.13.7-staging', 1), isFalse);
      expect(isNewer(parseRelease('{"tag_name":"v0.13.6","assets":[]}')!, '0.13.6', 1), isFalse);
      expect(isNewer(parseRelease('{"tag_name":"v0.13.7","assets":[]}')!, '0.13.6-staging', 20042), isTrue);
    });

    test('each flavour picks the newest release with its own APK from the list, skipping drafts', () {
      String rel(String tag, String at, List<String> names, {bool draft = false}) =>
          '{"tag_name":"$tag","published_at":"$at","draft":$draft,"assets":[${names.map((n) => '{"name":"$n","browser_download_url":"https://x/$n"}').join(',')}]}';
      final body = '[${[
        rel('v0.13.8-staging.21003', '2026-10-19T10:00:00Z', ['fitness-staging.apk']),
        rel('v0.13.7', '2026-10-18T10:00:00Z', ['fitness.apk']),
        rel('v0.13.6-staging.20043', '2026-10-17T10:00:00Z', ['fitness-staging.apk'], draft: true),
        rel('v0.13.6-staging.20042', '2026-10-17T09:00:00Z', ['fitness-staging.apk']),
        rel('v0.13.6', '2026-10-16T09:00:00Z', ['fitness.apk', 'fitness-staging.apk']),
      ].join(',')}]';
      expect(pickRelease(body, 'staging')!.tag, 'v0.13.8-staging.21003');
      expect(pickRelease(body, 'prod')!.tag, 'v0.13.7');
      expect(pickRelease('[]', 'staging'), isNull);
      expect(pickRelease('{"message":"x"}', 'staging'), isNull);
    });
  });
}
