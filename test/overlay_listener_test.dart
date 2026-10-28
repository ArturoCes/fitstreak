import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('se puede volver a escuchar la burbuja tras reiniciar la app', () async {
    final first = FlutterOverlayWindow.overlayListener.listen((_) {});
    // The restarted tree listens before the old one has cancelled.
    final second = FlutterOverlayWindow.overlayListener.listen((_) {});
    await first.cancel();
    await second.cancel();
  });
}
