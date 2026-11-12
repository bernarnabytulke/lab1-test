/// Лабораторна робота 1. Функції та обробка колекцій.
/// Варіант 11. Предметна область: показання лічильників.
/// Класи не використовуються: дані — записи, обробка — функції.

/// Одне показання лічильника.
typedef Reading = ({
  DateTime date,
  String service,
  double previous,
  double current,
  double tariff,
  String meter,
});

/// Результат розбору: або показання, або опис помилки.
typedef ParseResult = ({Reading? reading, String? error});

/// Формат рядка: дата;послуга;попереднє;поточне;тариф;номер лічильника
const rawData = <String>[
  '2024-01-31;Електроенергія;12000.0;12150.5;4.32;EL-100231',
  '2024-02-29;Електроенергія;12150.5;12290.0;4.32;EL-100231',
  '2024-03-31;Електроенергія;12290.0;12410.0;4.32;EL-100231',
  '2024-04-30;Електроенергія;12410.0;12500.0;4.32;EL-100231',
  '2024-01-31;Вода;350.2;358.7;42.50;WT-204518',
  '2024-02-29;Вода;358.7;366.1;42.50;WT-204518',
  '2024-03-31;Вода;366.1;373.9;42.50;WT-204518',
  '2024-04-30;Вода;373.9;380.2;42.50;WT-204518',
  '2024-01-31;Газ;800.0;880.0;7.96;GS-310774',
  '2024-02-29;Газ;880.0;950.0;7.96;GS-310774',
  '2024-03-31;Газ;950.0;1000.0;7.96;GS-310774',
  '2024-04-30;Газ;1000.0;1030.0;7.96;GS-310774',
  '2024-01-31;Опалення;45.0;52.0;1900.00;HT-408812',
  '2024-02-29;Опалення;52.0;61.5;1900.00;HT-408812',
  '2024-03-31;Опалення;61.5;68.0;1900.00;HT-408812',
  // Пошкоджені рядки:
  '2024-05-31;Вода;380.2;388.0', // відсутні поля
  '2024-05-31;Газ;1030.0;багато;7.96;GS-310774', // нечислове значення
  '31.05.2024;Електроенергія;12500.0;12600.0;4.32;EL-100231', // дата
  // Розібраний, але не пройде валідацію:
  '2024-05-31;Електроенергія;12600.0;12400.0;-4.32;el-1',
];

final meterPattern = RegExp(r'^(?<kind>[A-Z]{2})-(?<number>\d{6})$');
final _maskPattern = RegExp(r'(?<head>[A-Z]{2}-\d{2})\d{4}');

/// Розбирає рядок [line] у показання. Без try/catch: використовується tryParse.
ParseResult parseLine(String line) {
  final parts = line.split(';').map((p) => p.trim()).toList();
  if (parts.length != 6) {
    return (reading: null, error: 'Очікувалось 6 полів, знайдено ${parts.length}');
  }
  final date = DateTime.tryParse(parts[0]);
  if (date == null) {
    return (reading: null, error: 'Некоректна дата "${parts[0]}"');
  }
  if (parts[1].isEmpty) {
    return (reading: null, error: 'Порожній тип послуги');
  }
  final previous = double.tryParse(parts[2]);
  if (previous == null) {
    return (reading: null, error: 'Попереднє значення "${parts[2]}" не є числом');
  }
  final current = double.tryParse(parts[3]);
  if (current == null) {
    return (reading: null, error: 'Поточне значення "${parts[3]}" не є числом');
  }
  final tariff = double.tryParse(parts[4]);
  if (tariff == null) {
    return (reading: null, error: 'Тариф "${parts[4]}" не є числом');
  }
  return (
    reading: (
      date: date,
      service: parts[1],
      previous: previous,
      current: current,
      tariff: tariff,
      meter: parts[5],
    ),
    error: null,
  );
}

String formatDate(DateTime d) => d.toIso8601String().substring(0, 10);

/// Перевіряє діапазони значень і повертає перелік порушень.
List<String> validate(Reading r, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return [
    if (!meterPattern.hasMatch(r.meter))
      'Номер лічильника "${r.meter}" не відповідає формату',
    if (r.date.year < 2000 || r.date.isAfter(today))
      'Дата ${formatDate(r.date)} поза допустимим діапазоном',
    if (r.previous < 0) 'Попереднє значення ${r.previous} від’ємне',
    if (r.current < r.previous)
      'Поточне (${r.current}) менше за попереднє (${r.previous})',
    if (r.tariff <= 0) 'Тариф ${r.tariff} має бути додатним',
  ];
}

/// Спожито за період.
double consumption(Reading r) => r.current - r.previous;

/// Вартість = спожито × тариф.
double cost(Reading r) => consumption(r) * r.tariff;

/// Загальна вартість (fold).
double totalCost(List<Reading> items) =>
    items.fold(0.0, (sum, r) => sum + cost(r));

/// Групує показання за типом послуги.
Map<String, List<Reading>> groupByService(List<Reading> items) {
  final result = <String, List<Reading>>{};
  for (final r in items) {
    result.putIfAbsent(r.service, () => []).add(r);
  }
  return result;
}

/// Сортує за критерієм [by] ('cost' або 'date'); напрям — [ascending].
List<Reading> sortReadings(
  List<Reading> items, {
  String by = 'cost',
  bool ascending = false,
}) {
  final int Function(Reading, Reading) compare = switch (by) {
    'cost' => (a, b) => cost(a).compareTo(cost(b)),
    'date' => (a, b) => a.date.compareTo(b.date),
    _ => throw ArgumentError.value(by, 'by', 'Допустимо: cost, date'),
  };
  final sorted = [...items];
  sorted.sort(ascending ? compare : (a, b) => compare(b, a));
  return sorted;
}

/// Формує текстовий звіт за списком [items].
String buildReport(
  List<Reading> items, {
  int topCount = 5,
  bool ascending = false,
  String separator = ' | ',
}) {
  final buf = StringBuffer()..writeln('=== Топ-$topCount за вартістю ===');
  final top = sortReadings(items, ascending: ascending).take(topCount);
  for (final (i, r) in top.indexed) {
    buf.writeln(
      [
        '${i + 1}',
        formatDate(r.date),
        r.service,
        consumption(r).toStringAsFixed(1),
        cost(r).toStringAsFixed(2),
      ].join(separator),
    );
  }
  return buf.toString();
}

/// Замикання №1: захоплює змінну [count] і збільшує її при кожному виклику.
int Function() makeCounter() {
  var count = 0;
  return () => ++count;
}

/// Замикання №2: фабрика предикатів; захоплює параметр [threshold].
bool Function(Reading) consumptionAbove(double threshold) =>
    (reading) => consumption(reading) > threshold;

/// Маскує останні чотири цифри номера лічильника (іменовані групи).
String maskMeter(String meter) => meter.replaceAllMapped(
      _maskPattern,
      (m) => '${m.namedGroup('head')}****',
    );

void main() {
  final counter = makeCounter();
  final readings = <Reading>[];
  final errors = <String>[];

  // 1. Розбір + валідація
  for (final (i, line) in rawData.indexed) {
    counter();
    final result = parseLine(line);
    final reading = result.reading;
    if (reading == null) {
      errors.add('Рядок ${i + 1}: ${result.error}');
      continue;
    }
    final violations = validate(reading);
    if (violations.isNotEmpty) {
      errors.add('Рядок ${i + 1}: ${violations.join('; ')}');
      continue;
    }
    readings.add(reading);
  }
  print('Оброблено рядків: ${counter() - 1}, коректних: ${readings.length}');
  print('Помилки:');
  errors.forEach(print);

  // 2. Конвеєри where → map → fold
  final heavy = readings.where(consumptionAbove(50)).toList();
  final costs = heavy.map((r) => '${r.service} ${formatDate(r.date)}').toList();
  final total = totalCost(readings);
  final maxConsumption = readings.fold<Reading?>(
    null,
    (m, r) => m == null || consumption(r) > consumption(m) ? r : m,
  );
  print('\nСпоживання понад 50: ${costs.join(', ')}');
  print('Загальна вартість: ${total.toStringAsFixed(2)} грн');
  print(
    'Середня вартість показання: '
    '${(total / readings.length).toStringAsFixed(2)} грн',
  );
  print(
    'Найбільше спожито: ${maxConsumption?.service} '
    '(${consumption(maxConsumption!).toStringAsFixed(1)})',
  );

  // 3. firstOrNull замість firstWhere без orElse
  final firstGas = readings.where((r) => r.service == 'Газ').firstOrNull;
  print('Перше показання газу: ${firstGas == null ? 'немає' : formatDate(firstGas.date)}');

  // 4. Групування
  final groups = groupByService(readings);
  final totals = groups.map((s, list) => MapEntry(s, totalCost(list)));
  print('\nВартість за послугами:');
  totals.forEach((s, sum) => print('  $s: ${sum.toStringAsFixed(2)} грн'));

  // 5. Сортування за двома критеріями
  final byDate = sortReadings(readings, by: 'date', ascending: true);
  print('\nНайраніше показання: ${formatDate(byDate.first.date)}');
  print(buildReport(readings));
  print(buildReport(readings, topCount: 3, ascending: true, separator: ' ; '));

  // 6. Регулярні вирази
  final parts = meterPattern.firstMatch(readings.first.meter);
  print('Тип: ${parts?.namedGroup('kind')}, номер: ${parts?.namedGroup('number')}');
  print('Маска: ${maskMeter(readings.first.meter)}');

  // 7. Арифметика дат
  final now = DateTime.now();
  for (final r in readings.take(3)) {
    print('${r.service}: показанню ${now.difference(r.date).inDays} дн.');
  }
  final span = byDate.last.date.difference(byDate.first.date);
  print('Період спостережень: ${span.inDays} дн.');
}
