# In-app updates from GitHub releases: a second channel on the Android side (app info, install permission, cache
# dir, hand an APK to the installer), the Dart bridge, the Updates panel in Settings, the release step in
# publish.sh, and tests for the pure parts.
p='android/app/build.gradle.kts'
s=open(p,encoding='utf-8').read()
old="""    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
"""
new="""    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        buildConfig = true   // BuildConfig.FLAVOR, read by the updater to pick its APK
    }
"""
assert old in s; s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

p='android/app/src/main/kotlin/dev/derekurban/fitness/MainActivity.kt'
s=open(p,encoding='utf-8').read()
old="""import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
"""
new="""import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
"""
assert old in s; s=s.replace(old,new,1)
old="""/// Hosts one small channel: the calendar permissions, today's events, the writable calendars, and writing one event."""
new="""/// Hosts two small channels: the calendar (permissions, today's events, the writable calendars, writing one event)
/// and the updater (what build this is, the install permission, and handing a downloaded APK to the installer)."""
assert old in s; s=s.replace(old,new,1)
old="""                else -> result.notImplemented()
            }
        }
    }
"""
new="""                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitness/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "appInfo" -> {
                    val pi = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong()
                    result.success(mapOf("versionName" to (pi.versionName ?: ""), "versionCode" to code, "flavor" to BuildConfig.FLAVOR, "package" to packageName))
                }
                "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= 26) startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                    result.success(true)
                }
                "cacheDir" -> result.success(File(cacheDir, "updates").apply { mkdirs() }.absolutePath)
                "install" -> result.success(installApk(call.argument<String>("path")!!))
                else -> result.notImplemented()
            }
        }
    }

    /// Opens the package installer on an APK in our cache, through the FileProvider declared in the manifest.
    private fun installApk(path: String): Boolean = try {
        val uri = FileProvider.getUriForFile(this, "$packageName.files", File(path))
        startActivity(Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }
"""
assert old in s; s=s.replace(old,new,1)
open(p,'w',encoding='utf-8').write(s)

p='lib/integrations.dart'
s=open(p,encoding='utf-8').read()
old="""import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
"""
new="""import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
"""
assert old in s; s=s.replace(old,new,1)
old="""import 'data/model.dart';
import 'logic/calendar.dart';
"""
new="""import 'data/model.dart';
import 'logic/calendar.dart';
import 'logic/update.dart';
"""
assert old in s; s=s.replace(old,new,1)
s += '''
/// What build is installed, from the package manager.
class AppInfo {
  const AppInfo({required this.versionName, required this.versionCode, required this.flavor, required this.package});
  final String versionName;
  final int versionCode;
  final String flavor;
  final String package;
}

/// The updater: GitHub's latest release, a download into the app cache, and the Android installer.
class UpdateBridge {
  static const _ch = MethodChannel('fitness/update');

  static Future<AppInfo?> appInfo() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('appInfo');
      if (m == null) return null;
      return AppInfo(versionName: m['versionName'] as String? ?? '', versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
          flavor: m['flavor'] as String? ?? 'prod', package: m['package'] as String? ?? '');
    } catch (_) { return null; }
  }

  /// The latest release on GitHub, or null when offline or the response is not a release.
  static Future<ReleaseInfo?> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(latestReleaseUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'fitness-app');
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      return parseRelease(await res.transform(const Utf8Decoder()).join());
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<bool> canInstall() async {
    try { return await _ch.invokeMethod<bool>('canInstall') ?? false; } catch (_) { return false; }
  }

  static Future<void> openInstallSettings() async {
    try { await _ch.invokeMethod<bool>('openInstallSettings'); } catch (_) {}
  }

  /// Downloads [url] into the app's update cache as [name], reporting 0..1, and returns the file path.
  static Future<String?> download(String url, String name, void Function(double) onProgress) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final dir = await _ch.invokeMethod<String>('cacheDir');
      if (dir == null) return null;
      final file = File('$dir/$name');
      final req = await client.getUrl(Uri.parse(url));
      req.followRedirects = true;
      req.headers.set(HttpHeaders.userAgentHeader, 'fitness-app');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final total = res.contentLength;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
      onProgress(1);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<bool> install(String path) async {
    try { return await _ch.invokeMethod<bool>('install', {'path': path}) ?? false; } catch (_) { return false; }
  }
}
'''
if "import 'dart:convert';" not in s:
    s = s.replace("import 'dart:io';\n", "import 'dart:convert';\nimport 'dart:io';\n", 1)
open(p,'w',encoding='utf-8').write(s)

p='lib/ui/settings.dart'
s=open(p,encoding='utf-8').read()
old="""        const SectionHeader('Prototype tools', icon: LucideIcons.wrench),"""
new="""        const SectionHeader('Updates', icon: LucideIcons.download),
        const UpdatePanel(),
        const SizedBox(height: 20),
        const SectionHeader('Prototype tools', icon: LucideIcons.wrench),"""
assert old in s; s=s.replace(old,new,1)
old="""          Text('Version 0.13.4${appFlavor == null || appFlavor == 'prod' ? '' : ' $appFlavor'} · body map: brand moss fills, group outline, tooltip, expand · ${exercises.length} exercises', style: t.labelSmall?.copyWith(color: du.inkTertiary)),"""
new="""          Text('${exercises.length} exercises built in', style: t.labelSmall?.copyWith(color: du.inkTertiary)),"""
assert old in s; s=s.replace(old,new,1)
s=s.replace("import 'package:flutter/services.dart' show appFlavor;\n","",1)
s=s.replace("import 'theme.dart';\nimport 'widgets.dart';","import 'theme.dart';\nimport 'updates.dart';\nimport 'widgets.dart';",1)
open(p,'w',encoding='utf-8').write(s)

p='tool/publish.sh'
s=open(p,encoding='utf-8').read()
old="""cat ../dist/build.txt
echo "published to ../dist/"
"""
new="""cat ../dist/build.txt
echo "published to ../dist/"

# A GitHub release carries both APKs; the app's Updates panel reads the latest one. Only when both were built.
if [ "$flavors" = "prod staging" ] && command -v gh >/dev/null; then
  tag="v${ver%%+*}"
  notes="${NOTES:-$(cat ../dist/build.txt)}"
  if gh release view "$tag" --repo derekurban/fitness >/dev/null 2>&1; then
    gh release upload "$tag" ../dist/fitness.apk ../dist/fitness-staging.apk --clobber --repo derekurban/fitness
  else
    gh release create "$tag" ../dist/fitness.apk ../dist/fitness-staging.apk --title "$tag" --notes "$notes" --repo derekurban/fitness
  fi
  echo "released $tag on github.com/derekurban/fitness"
fi
"""
assert old in s; s=s.replace(old,new,1)
s=s.replace("""#   bash tool/publish.sh                 build prod and staging, copy both""","""#   bash tool/publish.sh                 build prod and staging, copy both, and publish a GitHub release v<version>
#   NOTES="what changed" bash tool/publish.sh   with release notes (the app shows them under Update)""",1)
open(p,'w',encoding='utf-8',newline='\n').write(s)

open('test/update_test.dart','w',encoding='utf-8').write('''import 'package:fitness/logic/update.dart';
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
      final r = parseRelease('{"tag_name":"v0.13.5","body":"body map\\\\n","published_at":"2026-10-16T14:00:00Z",'
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
''')

p='pubspec.yaml'
s=open(p,encoding='utf-8').read()
s=s.replace('version: 0.13.4+18','version: 0.13.5+19',1)
open(p,'w',encoding='utf-8').write(s)
print('ok')
