// In-app updates: the app's releases live on GitHub (derekurban/fitness, public). The latest release names a version
// in its tag and carries one APK per flavour. This file is the pure part: reading a release and comparing versions.
import 'dart:convert';

const updateRepo = 'derekurban/fitness';
const latestReleaseUrl = 'https://api.github.com/repos/$updateRepo/releases/latest';

/// One published build: its version (from the tag), notes, and the download URL per asset name.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.tag, required this.notes, required this.assets, this.at});
  final String version;
  final String tag;
  final String notes;
  final Map<String, String> assets;
  final DateTime? at;
}

/// The asset a flavour installs.
String assetFor(String? flavor) => flavor == 'staging' ? 'fitness-staging.apk' : 'fitness.apk';

/// "v0.13.5", "0.13.5+19" or "0.13.5-staging" -> [0, 13, 5]. Anything unparsable is an empty list.
List<int> versionParts(String v) {
  final core = v.trim().replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[+\-\s]')).first;
  final parts = core.split('.');
  final out = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null) return const [];
    out.add(n);
  }
  return out;
}

/// Negative when [a] is older than [b], zero when equal, positive when newer. Missing parts count as zero.
int compareVersions(String a, String b) {
  final x = versionParts(a), y = versionParts(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// A GitHub release JSON (the /releases/latest shape) as a ReleaseInfo, or null when it has no usable tag.
ReleaseInfo? parseRelease(String body) {
  final dynamic j;
  try { j = jsonDecode(body); } catch (_) { return null; }
  if (j is! Map<String, dynamic>) return null;
  final tag = j['tag_name'] as String?;
  if (tag == null || versionParts(tag).isEmpty) return null;
  final assets = <String, String>{};
  for (final a in (j['assets'] as List? ?? const [])) {
    if (a is Map && a['name'] is String && a['browser_download_url'] is String) assets[a['name'] as String] = a['browser_download_url'] as String;
  }
  return ReleaseInfo(
    version: tag.replaceFirst(RegExp(r'^v'), ''),
    tag: tag,
    notes: (j['body'] as String? ?? '').trim(),
    assets: assets,
    at: DateTime.tryParse(j['published_at'] as String? ?? ''),
  );
}
