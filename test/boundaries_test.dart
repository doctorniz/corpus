// Import boundaries from CLAUDE.md, checked on every test run (Mentis does
// the same with ESLint's no-restricted-imports).
//
//   - core/ imports nothing above it: not data/, services/, ui/, app/, features/.
//   - data/ imports only core/ (and other data/ files).
//   - A feature never imports another feature. The exceptions below are
//     known debts, listed in docs/LAUNCH_DEFERRALS.md (B1, B2); do not add
//     to them.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowedCrossFeature = {
  // B1: the + sheet opens each area's own forms.
  'capture': {'fitness', 'habits', 'health', 'nutrition', 'sleep', 'womens'},
  // B2: Fitness shows the weight trend from Health's vitals.
  'fitness': {'health'},
};

/// Every `lib/` file's imports, resolved to paths under `lib/`.
Map<String, List<String>> _imports() {
  final result = <String, List<String>>{};
  final importRe = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final path = f.path.replaceAll('\\', '/');
    final dir = File(path).parent.uri;
    result[path] = [
      for (final m in importRe.allMatches(f.readAsStringSync()))
        if (m[1]!.startsWith('package:corpus/'))
          'lib/${m[1]!.substring('package:corpus/'.length)}'
        else if (!m[1]!.contains(':'))
          dir.resolve(m[1]!).path,
    ];
  }
  return result;
}

String? _area(String path) {
  final parts = path.split('/');
  final i = parts.indexOf('lib');
  return i >= 0 && i + 1 < parts.length - 1 ? parts[i + 1] : null;
}

String? _feature(String path) {
  final parts = path.split('/');
  final i = parts.indexOf('features');
  return i >= 0 && i + 1 < parts.length ? parts[i + 1] : null;
}

void main() {
  final imports = _imports();

  test('core/ and data/ stay below the UI', () {
    final bad = <String>[];
    for (final MapEntry(key: file, value: deps) in imports.entries) {
      final area = _area(file);
      final allowed = switch (area) {
        'core' => {'core'},
        'data' => {'core', 'data'},
        _ => null,
      };
      if (allowed == null) continue;
      for (final d in deps) {
        if (!allowed.contains(_area(d))) bad.add('$file -> $d');
      }
    }
    expect(bad, isEmpty);
  });

  test('no feature imports another feature', () {
    final bad = <String>[];
    for (final MapEntry(key: file, value: deps) in imports.entries) {
      final from = _feature(file);
      if (from == null) continue;
      for (final d in deps) {
        final to = _feature(d);
        if (to == null || to == from) continue;
        if (_allowedCrossFeature[from]?.contains(to) ?? false) continue;
        bad.add('$file -> $d');
      }
    }
    expect(bad, isEmpty);
  });
}
