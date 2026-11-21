// Fails when a built artifact is over its size budget in budgets.json.
//
//   dart run tool/check_budgets.dart androidApk build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: check_budgets.dart <budget key> <file>');
    exit(64);
  }
  final [key, path] = args;
  final budgets = jsonDecode(File('budgets.json').readAsStringSync()) as Map;
  final budget = (budgets['size'] as Map)[key] as Map?;
  if (budget == null) {
    stderr.writeln('No size budget named "$key" in budgets.json');
    exit(64);
  }
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('$path does not exist');
    exit(66);
  }
  final size = file.lengthSync();
  final max = budget['maxBytes'] as int;
  String mb(int b) => (b / 1e6).toStringAsFixed(2);
  final over = size > max;
  stdout.writeln(
    '[budgets] ${budget['label']}: ${mb(size)} MB (budget ${mb(max)} MB)'
    '${over ? ' — OVER' : ''}',
  );
  if (over && budget['enforce'] == true) exit(1);
}
