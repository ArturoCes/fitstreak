import 'package:fitstreak/data/backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a backup restores every preference except the picture', () async {
    SharedPreferences.setMockInitialValues({
      'streak': '{"days":12}',
      'reminder': 20,
      'drawings': true,
      'ratio': 1.5,
      'tags': ['a', 'b'],
      'motivation_image': '/data/x.jpg',
    });
    final prefs = await SharedPreferences.getInstance();
    final json = encodeBackup(prefs);

    await prefs.clear();
    await prefs.setString('leftover', 'x');
    await restoreBackup(prefs, parseBackup(json));

    expect(prefs.getString('streak'), '{"days":12}');
    expect(prefs.getInt('reminder'), 20);
    expect(prefs.getBool('drawings'), true);
    expect(prefs.getDouble('ratio'), 1.5);
    expect(prefs.getStringList('tags'), ['a', 'b']);
    expect(prefs.containsKey('motivation_image'), false);
    expect(prefs.containsKey('leftover'), false);
  });

  test('other files are rejected', () {
    expect(() => parseBackup('{"hola":1}'), throwsFormatException);
    expect(() => parseBackup('[]'), throwsFormatException);
  });
}
