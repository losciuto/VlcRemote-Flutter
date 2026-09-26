import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notifyListeners dopo dispose non lancia', () {
    // Regressione: operazioni con attese asincrone (riconnessione, barra di
    // progresso MyPlaylist, debounce del volume) notificano anche dopo che il
    // provider è stato smontato, e ChangeNotifier in quel caso lancia.
    SharedPreferences.setMockInitialValues({});
    final provider = VlcProvider();

    provider.dispose();

    expect(provider.notifyListeners, returnsNormally);
  });

  test('dispose è idempotente rispetto alle notifiche in arrivo', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = VlcProvider();

    // Simula una notifica tardiva mentre il provider è già smontato.
    provider.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(provider.isConnected, isFalse);
    expect(provider.isMyPlaylistBusy, isFalse);
  });
}
