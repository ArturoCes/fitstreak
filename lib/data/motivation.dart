import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';
import 'streak.dart';

/// Where a quote comes from.
enum QuoteKind {
  /// Anime or manga.
  anime,

  /// Film.
  movie,
}

/// Which quotes the user wants to see.
enum MotivationTaste {
  /// Anime quotes only.
  anime('Anime', '🍥'),

  /// Film quotes only.
  movies('Pelis', '🎬'),

  /// Both, mixed.
  both('Ambos', '✨'),

  /// No quote card.
  none('Nada, gracias', '🙅');

  /// Creates a taste with its label and emoji.
  const MotivationTaste(this.label, this.emoji);

  /// Spanish label.
  final String label;

  /// Emoji shown next to the label.
  final String emoji;

  /// Whether quotes of kind [k] are shown with this taste.
  bool accepts(QuoteKind k) => switch (this) {
        anime => k == QuoteKind.anime,
        movies => k == QuoteKind.movie,
        both => true,
        none => false,
      };
}

/// A short motivational quote with its character and work.
class Quote {
  /// Creates a quote.
  const Quote({required this.text, required this.who, required this.from, required this.kind});

  /// The quote itself (in Spanish).
  final String text;

  /// Who says it.
  final String who;

  /// Anime or film it comes from.
  final String from;

  /// Anime or film.
  final QuoteKind kind;

  /// Reads an entry of assets/data/quotes.json.
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        text: j['t'] as String,
        who: j['who'] as String,
        from: j['from'] as String,
        kind: j['kind'] == 'anime' ? QuoteKind.anime : QuoteKind.movie,
      );
}

/// Quotes written for the app: short lines with their character and work.
final quotesProvider = FutureProvider<List<Quote>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/quotes.json');
  return [for (final q in jsonDecode(raw) as List) Quote.fromJson(q as Map<String, dynamic>)];
});

/// Quote of the day for the user's taste: it changes every day, and
/// [offset] moves to the next one when the card is tapped.
Quote? quoteOfTheDay(List<Quote> all, MotivationTaste? taste, DateTime today, {int offset = 0}) {
  if (taste == MotivationTaste.none) return null;
  // Fixed shuffle so anime and films alternate and the order doesn't change
  // between app launches.
  final pool = [for (final q in all) if ((taste ?? MotivationTaste.both).accepts(q.kind)) q]
    ..shuffle(Random(42));
  if (pool.isEmpty) return null;
  final day = daysBetween(DateTime(2026), today);
  return pool[(day + offset) % pool.length];
}

/// The quote card settings.
@immutable
class MotivationSettings {
  /// Creates the settings.
  const MotivationSettings({this.taste, this.imagePath});

  /// Quote taste; null = not asked yet.
  final MotivationTaste? taste;

  /// The user's own background image (a file copied into the app).
  final String? imagePath;
}

const _tasteKey = 'motivation_taste';
const _imageKey = 'motivation_image';

/// Quote taste and custom background image, saved in preferences.
class MotivationNotifier extends Notifier<MotivationSettings> {
  /// Loads the saved settings, dropping the image if its file is gone.
  @override
  MotivationSettings build() {
    final prefs = ref.read(prefsProvider);
    final taste = prefs.getString(_tasteKey);
    var image = prefs.getString(_imageKey);
    // If the file disappeared (data partly cleared), it is ignored.
    if (image != null && !kIsWeb && !File(image).existsSync()) image = null;
    return MotivationSettings(
      taste: taste == null ? null : MotivationTaste.values.asNameMap()[taste],
      imagePath: image,
    );
  }

  /// Saves the quote taste.
  Future<void> setTaste(MotivationTaste taste) async {
    state = MotivationSettings(taste: taste, imagePath: state.imagePath);
    await ref.read(prefsProvider).setString(_tasteKey, taste.name);
  }

  /// Opens the gallery and uses the picked image as background. Returns
  /// false if the user cancels.
  Future<bool> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return false;
    String path;
    if (kIsWeb) {
      // On the web it is a temporary URL: valid for this session only.
      path = picked.path;
    } else {
      // Copied into the app so it doesn't depend on the gallery.
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/motivation_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(path);
      await _deleteOld();
    }
    state = MotivationSettings(taste: state.taste, imagePath: path);
    if (!kIsWeb) await ref.read(prefsProvider).setString(_imageKey, path);
    return true;
  }

  /// Goes back to the app's drawn backgrounds and deletes the image file.
  Future<void> clearImage() async {
    await _deleteOld();
    state = MotivationSettings(taste: state.taste);
    await ref.read(prefsProvider).remove(_imageKey);
  }

  /// Deletes the current image file, ignoring errors.
  Future<void> _deleteOld() async {
    final old = state.imagePath;
    if (old == null || kIsWeb) return;
    try {
      await File(old).delete();
    } catch (_) {}
  }
}

/// The quote card settings.
final motivationProvider = NotifierProvider<MotivationNotifier, MotivationSettings>(
  MotivationNotifier.new,
);
