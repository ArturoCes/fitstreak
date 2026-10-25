import 'dart:convert';
import 'dart:io';

import 'package:fitstreak/data/motivation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final quotes = [
    for (final q in jsonDecode(File('assets/data/quotes.json').readAsStringSync()) as List)
      Quote.fromJson(q as Map<String, dynamic>),
  ];
  final today = DateTime(2026, 10, 19);

  test('las frases están completas y hay de los dos tipos', () {
    expect(quotes.length, greaterThan(50));
    for (final q in quotes) {
      expect(q.text.trim(), isNotEmpty);
      expect(q.who.trim(), isNotEmpty);
      expect(q.from.trim(), isNotEmpty);
    }
    expect(quotes.where((q) => q.kind == QuoteKind.anime), isNotEmpty);
    expect(quotes.where((q) => q.kind == QuoteKind.movie), isNotEmpty);
  });

  test('solo salen frases del gusto elegido', () {
    for (var i = 0; i < 40; i++) {
      expect(quoteOfTheDay(quotes, MotivationTaste.anime, today, offset: i)!.kind, QuoteKind.anime);
      expect(quoteOfTheDay(quotes, MotivationTaste.movies, today, offset: i)!.kind, QuoteKind.movie);
    }
    expect(quoteOfTheDay(quotes, MotivationTaste.none, today), isNull);
  });

  test('con ambos se mezclan anime y pelis', () {
    final kinds = {
      for (var i = 0; i < quotes.length; i++) quoteOfTheDay(quotes, MotivationTaste.both, today, offset: i)!.kind,
    };
    expect(kinds, {QuoteKind.anime, QuoteKind.movie});
  });

  test('la frase es la misma todo el día y cambia al siguiente', () {
    final morning = quoteOfTheDay(quotes, MotivationTaste.both, DateTime(2026, 10, 19, 8));
    final night = quoteOfTheDay(quotes, MotivationTaste.both, DateTime(2026, 10, 19, 23));
    final tomorrow = quoteOfTheDay(quotes, MotivationTaste.both, DateTime(2026, 10, 20, 8));
    expect(morning, same(night));
    expect(tomorrow, isNot(same(morning)));
  });
}
