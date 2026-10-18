import 'dart:io';

import 'package:fitness/logic/feedback.dart';
import 'package:flutter_test/flutter_test.dart';

ReportDraft problem() => ReportDraft(Report.problem)
  ..title = 'Timer skips a set'
  ..text.addAll({'what': 'The third set vanished.', 'expected': 'Three sets.', 'steps': '1. Start\n2. Log two sets'})
  ..often = 'Sometimes';

void main() {
  group('feedback', () {
    test('the build reads as one line, with the flavour only for staging', () {
      expect(buildLine('0.13.7', 100042, 'staging'), '0.13.7 (build 100042) · staging');
      expect(buildLine('0.13.7-staging', 100042, 'staging'), '0.13.7 (build 100042) · staging');
      expect(buildLine('0.13.7', 100043, 'prod'), '0.13.7 (build 100043)');
      expect(buildLine('0.13.7', 0, 'prod'), '0.13.7');
    });

    test('the phone reads as one line, without the maker twice and without empty parts', () {
      expect(deviceLine(maker: 'Google', model: 'Pixel 9 Pro', android: '16', sdk: 36), 'Google Pixel 9 Pro · Android 16 (API 36)');
      expect(deviceLine(maker: 'OnePlus', model: 'ONEPLUS A6003', android: '11', sdk: 30), 'ONEPLUS A6003 · Android 11 (API 30)');
      expect(deviceLine(model: 'SM-S918B', android: '14'), 'SM-S918B · Android 14');
      expect(deviceLine(), '');
    });

    test('a draft is ready with a title and every required field, and clears to empty', () {
      final d = ReportDraft(Report.idea);
      expect(d.isEmpty, isTrue);
      expect(d.ready, isFalse);
      d.title = 'Rest day reminder';
      expect(d.ready, isFalse);
      d.text['idea'] = '  ';
      expect(d.ready, isFalse);
      d.text['idea'] = 'Remind me to stretch.';
      expect(d.ready, isTrue);
      d.carried = true;
      d.clear();
      expect(d.isEmpty, isTrue);
      expect(d.carried, isFalse);
    });

    test('a problem link opens the bug form with everything written in the app filled in', () {
      final r = reportUrl(problem(), version: '0.13.7 (build 100042) · staging', device: 'Google Pixel 9 Pro · Android 16 (API 36)');
      expect(r.trimmed, isFalse);
      expect(r.url.scheme, 'https');
      expect(r.url.host, 'github.com');
      expect(r.url.path, '/derekurban/fitness/issues/new');
      expect(r.url.queryParameters, {
        'template': 'bug.yml',
        'title': 'Timer skips a set',
        'what': 'The third set vanished.',
        'expected': 'Three sets.',
        'steps': '1. Start\n2. Log two sets',
        'often': 'Sometimes',
        'version': '0.13.7 (build 100042) · staging',
        'device': 'Google Pixel 9 Pro · Android 16 (API 36)',
      });
      expect(r.url.toString(), isNot(contains(' ')));
    });

    test('an idea link takes no phone; empty fields are left out', () {
      final d = ReportDraft(Report.idea)..title = 'Stretch day'..text['idea'] = 'A day of stretching.';
      expect(reportUrl(d, version: '0.13.7', device: 'Pixel').url.queryParameters,
          {'template': 'feature.yml', 'title': 'Stretch day', 'idea': 'A day of stretching.', 'version': '0.13.7'});
      expect(reportUrl(ReportDraft(Report.problem)).url.queryParameters, {'template': 'bug.yml'});
    });

    test('a link too long for GitHub shortens the longest written field and says so', () {
      // each field is capped (1500 characters here), so plain text fits; text that encodes long, like accents, can still overflow
      final d = problem()..text['what'] = 'é' * 1500..text['steps'] = 'tap é ' * 250;
      final r = reportUrl(d, version: '0.13.7', device: 'Pixel');
      expect(r.trimmed, isTrue);
      expect(r.url.toString().length, lessThanOrEqualTo(reportUrlMax));
      expect(r.url.queryParameters['what'], endsWith('…'));
      expect(r.url.queryParameters['title'], 'Timer skips a set');
      expect(r.url.queryParameters['version'], '0.13.7');
      expect(r.url.queryParameters['expected'], 'Three sets.');
    });

    test('the copied text lays the report out like the issue', () {
      expect(reportText(problem(), version: '0.13.7', device: 'Pixel'),
          'Timer skips a set\n\n### What happened\n\nThe third set vanished.\n\n### What you expected\n\nThree sets.'
          '\n\n### How to make it happen again\n\n1. Start\n2. Log two sets\n\n### How often\n\nSometimes'
          '\n\n### App version\n\n0.13.7\n\n### Phone\n\nPixel');
    });

    test('every field the app fills is a text field of the same id in its form, with the same label', () {
      for (final kind in Report.values) {
        final form = File('../.github/ISSUE_TEMPLATE/${reportTemplate[kind]}');
        expect(form.existsSync(), isTrue, reason: form.path);
        final src = form.readAsStringSync();
        final types = {
          for (final m in RegExp(r'^  - type:\s*(\S+)\s*\n\s+id:\s*(\S+)', multiLine: true).allMatches(src)) m.group(2): m.group(1),
        };
        for (final id in reportIds(kind)) {
          expect(types[id], anyOf('input', 'textarea'), reason: '${form.path}: $id must be an input or textarea (URLs fill nothing else)');
        }
        for (final f in reportFields[kind]!) {
          expect(src, contains('label: ${f.label}\n'), reason: '${form.path} should label ${f.id} "${f.label}", as the app does');
        }
      }
    });

    test('the reports list shows open issues', () {
      expect(reportsUrl.path, '/derekurban/fitness/issues');
      expect(reportsUrl.queryParameters['q'], contains('is:open'));
    });
  });
}
