// Builds assets/foods.bin, the food list bundled with the app, from
// USDA FoodData Central "SR Legacy" (public domain).
//
// 1. Download and unzip
//    https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip
// 2. dart run tool/build_foods.dart <folder with the CSV files>
// 3. Bump `bundledFoodsVersion` in lib/services/food_seed.dart.
//
// Output rows: [id, name, category, kcal, protein, carbs, fat, fiber, sugar,
// sodiumMg, servingG, servingLabel], nutrients per 100 g.

import 'dart:convert';
import 'dart:io';

/// Parses RFC 4180 CSV (quoted fields, doubled quotes, embedded newlines).
Iterable<List<String>> parseCsv(String text) sync* {
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n') {
      row.add(field.toString());
      field.clear();
      yield row;
      row = <String>[];
    } else if (ch != '\r') {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    yield row;
  }
}

/// Rows of [file] as maps keyed by the header line.
Iterable<Map<String, String>> table(String dir, String file) sync* {
  final rows = parseCsv(File('$dir/$file').readAsStringSync()).iterator;
  if (!rows.moveNext()) return;
  final header = rows.current;
  while (rows.moveNext()) {
    final r = rows.current;
    if (r.length < header.length) continue;
    yield {for (var i = 0; i < header.length; i++) header[i]: r[i]};
  }
}

double? round1(double? v) => v == null ? null : (v * 10).round() / 10;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/build_foods.dart <csv folder>');
    exit(64);
  }
  final dir = args.first;

  final categories = {
    for (final r in table(dir, 'food_category.csv'))
      r['id']!: r['description']!,
  };

  // Nutrient ids in FoodData Central.
  const wanted = {
    '1008': 'kcal',
    '1003': 'protein',
    '1005': 'carbs',
    '1004': 'fat',
    '1079': 'fiber',
    '2000': 'sugar',
    '1093': 'sodium',
  };
  final nutrients = <String, Map<String, double>>{};
  for (final r in table(dir, 'food_nutrient.csv')) {
    final key = wanted[r['nutrient_id']];
    final amount = double.tryParse(r['amount'] ?? '');
    if (key == null || amount == null) continue;
    (nutrients[r['fdc_id']!] ??= {})[key] = amount;
  }

  // First listed portion of each food: its most typical serving.
  final portions = <String, (double, String)>{};
  for (final r in table(dir, 'food_portion.csv')) {
    final id = r['fdc_id']!;
    final grams = double.tryParse(r['gram_weight'] ?? '');
    if (grams == null || grams <= 0) continue;
    final seq = int.tryParse(r['seq_num'] ?? '') ?? 99;
    if (portions.containsKey(id) && seq != 1) continue;
    final amount = double.tryParse(r['amount'] ?? '') ?? 1;
    final what = [
      r['portion_description'],
      r['modifier'],
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    final count = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toString();
    portions[id] = (grams, amount == 1 ? what : '$count $what');
  }

  final foods = <List<Object?>>[];
  for (final r in table(dir, 'food.csv')) {
    final id = r['fdc_id']!;
    final n = nutrients[id];
    if (n == null || n['kcal'] == null) continue;
    final portion = portions[id];
    foods.add([
      id,
      r['description']!.trim(),
      categories[r['food_category_id']],
      n['kcal']!.round(),
      round1(n['protein'] ?? 0),
      round1(n['carbs'] ?? 0),
      round1(n['fat'] ?? 0),
      round1(n['fiber']),
      round1(n['sugar']),
      n['sodium']?.round(),
      round1(portion?.$1),
      portion?.$2,
    ]);
  }
  foods.sort((a, b) => (a[1] as String).compareTo(b[1] as String));

  final json = jsonEncode({
    'source': 'USDA FoodData Central, SR Legacy (April 2018)',
    'foods': foods,
  });
  final out = File('assets/foods.bin')
    ..createSync(recursive: true)
    ..writeAsBytesSync(gzip.encode(utf8.encode(json)));
  stdout.writeln(
    '${foods.length} foods, '
    '${(out.lengthSync() / 1024).round()} KB -> ${out.path}',
  );
}
