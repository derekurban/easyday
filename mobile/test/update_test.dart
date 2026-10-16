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
  });
}
