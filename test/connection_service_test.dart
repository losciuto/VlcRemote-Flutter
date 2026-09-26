import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/services/connection_service.dart';

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

    Future<void> initWith(String json) async {
      SharedPreferences.setMockInitialValues({'vlc_connections': json});
      service = ConnectionService();
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
}
