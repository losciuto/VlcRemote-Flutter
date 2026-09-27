import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/services/connection_service.dart';
import 'package:vlc_remote_flutter/services/secure_storage_service.dart';

void main() {
  Map<String, dynamic> validJson(String id) => {
    'id': id,
    'name': 'Sala $id',
    'ipAddress': '192.168.1.$id',
    'port': 8080,
    'lastUsed': DateTime(2026, 9, 26).toIso8601String(),
    'isFavorite': false,
  };

  group('VlcConnection.fromJson', () {
    test('legge una connessione completa', () {
      final connection = VlcConnection.fromJson({
        ...validJson('1'),
        'isFavorite': true,
        'myPlaylistIp': '192.168.1.2',
        'myPlaylistPort': 9090,
        'myPlaylistSecretKey': 'chiave',
        'vlcPassword': 'password',
      });

      expect(connection.id, '1');
      expect(connection.isFavorite, isTrue);
      expect(connection.myPlaylistPort, 9090);
      expect(connection.vlcPassword, 'password');
    });

    test('non lancia con campi mancanti', () {
      // Regressione: i cast rigidi facevano saltare l'intera lista.
      final connection = VlcConnection.fromJson({'id': '1'});

      expect(connection.id, '1');
      expect(connection.name, isNotEmpty);
      expect(connection.port, greaterThan(0));
      expect(connection.lastUsed, isA<DateTime>());
    });

    test('non lancia con tipi sbagliati', () {
      final connection = VlcConnection.fromJson({
        'id': 7,
        'port': '8080',
        'isFavorite': 1,
        'lastUsed': 'non-una-data',
        'myPlaylistPort': 1.5,
      });

      expect(connection.id, '7');
      expect(connection.port, 8080);
      expect(connection.isFavorite, isTrue);
      expect(connection.myPlaylistPort, 2);
    });

    test('ignora i campi opzionali di tipo errato', () {
      final connection = VlcConnection.fromJson({
        ...validJson('1'),
        'myPlaylistSecretKey': 42,
        'vlcPassword': ['a'],
      });

      expect(connection.myPlaylistSecretKey, isNull);
      expect(connection.vlcPassword, isNull);
    });
  });

  group('ConnectionService.getConnections', () {
    late ConnectionService service;
    late InMemorySecretStore secrets;

    Future<void> initWith(String json) async {
      SharedPreferences.setMockInitialValues({'vlc_connections': json});
      secrets = InMemorySecretStore();
      service = ConnectionService(secrets: secrets);
      await service.init();
    }

    test('restituisce tutte le connessioni valide', () async {
      await initWith(jsonEncode([validJson('1'), validJson('2')]));

      final connections = await service.getConnections();

      expect(connections.length, 2);
    });

    test('scarta il record illeggibile senza perdere gli altri', () async {
      // Regressione: un solo cast errato faceva fallire tutta la lista e il
      // catch restituiva un array vuoto, facendo perdere tutte le connessioni.
      await initWith(
        jsonEncode([validJson('1'), 'record-rotto', validJson('2')]),
      );

      final connections = await service.getConnections();

      expect(connections.length, 2);
      expect(connections.map((c) => c.id), containsAll(['1', '2']));
    });

    test('un record incompleto non azzera le altre connessioni', () async {
      await initWith(
        jsonEncode([
          {'id': '9'},
          validJson('1'),
        ]),
      );

      final connections = await service.getConnections();

      expect(connections.length, 2);
    });

    test('JSON non valido restituisce lista vuota senza lanciare', () async {
      await initWith('non-e-json');

      expect(await service.getConnections(), isEmpty);
    });
  });

  group('ConnectionService - segreti in storage sicuro', () {
    late ConnectionService service;
    late InMemorySecretStore secrets;
    late SharedPreferences prefs;

    Future<void> initWith(String json) async {
      SharedPreferences.setMockInitialValues({'vlc_connections': json});
      secrets = InMemorySecretStore();
      service = ConnectionService(secrets: secrets);
      await service.init();
      prefs = await SharedPreferences.getInstance();
    }

    /// Il JSON effettivamente scritto in SharedPreferences.
    String storedJson() => prefs.getString('vlc_connections')!;

    test('i segreti non vengono scritti in SharedPreferences', () async {
      await initWith('[]');

      await service.saveConnection(
        VlcConnection(
          id: '1',
          name: 'Sala',
          ipAddress: '192.168.1.10',
          port: 8080,
          lastUsed: DateTime(2026, 9, 26),
          vlcPassword: 'password-vlc',
          myPlaylistSecretKey: 'chiave-mp',
        ),
      );

      expect(storedJson(), isNot(contains('password-vlc')));
      expect(storedJson(), isNot(contains('chiave-mp')));
      expect(storedJson(), contains('"ipAddress":"192.168.1.10"'));
      // ma i dati non sensibili restano salvati
      expect(storedJson(), contains('"id":"1"'));
    });

    test('i segreti sono nel negozio sicuro', () async {
      await initWith('[]');

      await service.saveConnection(
        VlcConnection(
          id: '1',
          name: 'Sala',
          ipAddress: '192.168.1.10',
          port: 8080,
          lastUsed: DateTime(2026, 9, 26),
          vlcPassword: 'password-vlc',
          myPlaylistSecretKey: 'chiave-mp',
        ),
      );

      expect(secrets.values[secretKeyFor('1', 'vlc_password')], 'password-vlc');
      expect(
        secrets.values[secretKeyFor('1', 'my_playlist_secret')],
        'chiave-mp',
      );
    });

    test('i segreti vengono riletti al caricamento', () async {
      await initWith('[]');

      await service.saveConnection(
        VlcConnection(
          id: 'abc',
          name: 'Sala',
          ipAddress: '192.168.1.10',
          port: 8080,
          lastUsed: DateTime(2026, 9, 26),
          vlcPassword: 'password-vlc',
          myPlaylistSecretKey: 'chiave-mp',
        ),
      );

      final connections = await service.getConnections();

      expect(connections.single.vlcPassword, 'password-vlc');
      expect(connections.single.myPlaylistSecretKey, 'chiave-mp');
    });

    test('migra i segreti in chiaro di una versione precedente', () async {
      // JSON come lo scriveva la versione precedente: segreti in chiaro.
      await initWith(
        jsonEncode([
          {
            ...validJson('1'),
            'vlcPassword': 'vecchia-password',
            'myPlaylistSecretKey': 'vecchia-chiave',
          },
        ]),
      );

      final connections = await service.getConnections();

      // L'utente non perde nulla...
      expect(connections.single.vlcPassword, 'vecchia-password');
      expect(connections.single.myPlaylistSecretKey, 'vecchia-chiave');
      // ...ma il file non li contiene più e i segreti sono nel negozio sicuro
      expect(storedJson(), isNot(contains('vecchia-password')));
      expect(storedJson(), isNot(contains('vecchia-chiave')));
      expect(
        secrets.values[secretKeyFor('1', 'vlc_password')],
        'vecchia-password',
      );
    });

    test('se lo store sicuro non risponde i dati non si perdono', () async {
      // Store vuoto e JSON senza segreti: la connessione resta valida, i
      // segreti saranno semplicemente da reinserire.
      await initWith(jsonEncode([validJson('1')]));

      final connections = await service.getConnections();

      expect(connections.length, 1);
      expect(connections.single.vlcPassword, isNull);
    });

    test('eliminando una connessione spariscono anche i segreti', () async {
      await initWith('[]');
      await service.saveConnection(
        VlcConnection(
          id: '1',
          name: 'Sala',
          ipAddress: '192.168.1.10',
          port: 8080,
          lastUsed: DateTime(2026, 9, 26),
          vlcPassword: 'password-vlc',
        ),
      );
      expect(secrets.values, isNotEmpty);

      await service.deleteConnection('1');

      expect(secrets.values, isEmpty);
      expect(await service.getConnections(), isEmpty);
    });

    test('cancellando tutto spariscono anche i segreti', () async {
      await initWith('[]');
      await service.saveConnection(
        VlcConnection(
          id: '1',
          name: 'Sala',
          ipAddress: '192.168.1.10',
          port: 8080,
          lastUsed: DateTime(2026, 9, 26),
          myPlaylistSecretKey: 'chiave-mp',
        ),
      );
      expect(secrets.values, isNotEmpty);

      await service.clearAllConnections();

      expect(secrets.values, isEmpty);
    });

    group('store sicuro che non funziona', () {
      /// Prepara il servizio con uno store che fallisce su ogni scrittura, come
      /// su una macchina senza keyring: il caso in cui la Fase 0 perdeva le
      /// password dell'utente.
      ///
      /// Il flag va impostato dopo [initWith], che crea uno store nuovo: prima
      /// verrebbe perso.
      Future<void> initWithFailingStore(String json) async {
        await initWith(json);
        secrets.failWrites = true;
      }

      test('la migrazione NON cancella i segreti dalle preferenze', () async {
        await initWithFailingStore(
          jsonEncode([
            {
              ...validJson('1'),
              'vlcPassword': 'vecchia-password',
              'myPlaylistSecretKey': 'vecchia-chiave',
            },
          ]),
        );

        final connections = await service.getConnections();

        // L'utente rivede le sue credenziali...
        expect(connections.length, 1);
        expect(connections.single.vlcPassword, 'vecchia-password');
        expect(connections.single.myPlaylistSecretKey, 'vecchia-chiave');
        // ...e il JSON le contiene ancora: la migrazione non è andata a buon
        // fine, quindi non ha cancellato nulla. Se le avesse rimosse senza
        // poterle spostare, la password sarebbe sparita senza rimedio.
        expect(storedJson(), contains('vecchia-password'));
        expect(storedJson(), contains('vecchia-chiave'));
        expect(secrets.values, isEmpty);
      });
      test('salvare una connessione nuova fallisce invece di mentire', () async {
        await initWithFailingStore('[]');

        final ok = await service.saveConnection(
          VlcConnection(
            id: '1',
            name: 'Sala',
            ipAddress: '192.168.1.10',
            port: 8080,
            lastUsed: DateTime(2026, 9, 26),
            vlcPassword: 'password-vlc',
          ),
        );

        // Il risultato deve essere fallito: senza questo la UI direbbe "salvata"
        // e la password si perderebbe al primo riavvio.
        expect(ok, isFalse);
        expect(await service.getConnections(), isEmpty);
      });

      test('un segreto non cancellabile non viene dato per rimosso', () async {
        await initWith('[]');
        await service.saveConnection(
          VlcConnection(
            id: '1',
            name: 'Sala',
            ipAddress: '192.168.1.10',
            port: 8080,
            lastUsed: DateTime(2026, 9, 26),
            vlcPassword: 'password-vlc',
          ),
        );
        expect(await service.getConnections(), hasLength(1));

        secrets.failDeletes = true;
        final ok = await service.saveConnection(
          (await service.getConnections()).single.copyWith(name: 'Sala TV'),
        );

        // Se la cancellazione di un segreto non riesce, il salvataggio è
        // dichiarato fallito e il JSON non viene riscritto: non si afferma
        // che il segreto è stato rimosso mentre è ancora lì.
        expect(ok, isFalse);
        expect(storedJson(), contains('"name":"Sala"'));
      });
    });
  });
}
