import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/services/vlc_http_service.dart';

void main() {
  group('VlcHttpService - configurazione', () {
    test('non è configurata prima di configure', () {
      final service = VlcHttpService();
      expect(service.isConfigured, isFalse);
    });

    test('configure abilita le richieste', () {
      final service = VlcHttpService()
        ..configure('192.168.1.10', 8080, 'secret');
      expect(service.isConfigured, isTrue);
    });

    test('clear rimuove host, porta e password', () {
      // Regressione: senza clear(), isConfigured restava vero dopo la
      // disconnessione e il polling interrogava il vecchio server con la
      // vecchia password.
      final service = VlcHttpService()
        ..configure('192.168.1.10', 8080, 'secret');
      expect(service.isConfigured, isTrue);

      service.clear();

      expect(service.isConfigured, isFalse);
    });

    test('clear su un servizio non configurato non fallisce', () {
      final service = VlcHttpService()..clear();
      expect(service.isConfigured, isFalse);
    });

    test('una password vuota non abilita le richieste', () {
      final service = VlcHttpService()..configure('192.168.1.10', 8080, '');
      expect(service.isConfigured, isFalse);
    });

    test('senza configurazione i metodi non tentano la rete', () async {
      final service = VlcHttpService();
      expect(await service.getStatus(), isNull);
      expect(await service.getPlaylist(), isEmpty);
      expect(await service.sendCommand('play'), isFalse);
    });
  });
}
