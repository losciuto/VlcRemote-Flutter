import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/models/vlc_status.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';

void main() {
  group('VlcStatus Tests', () {
    test('Format time correctly', () {
      expect(VlcStatus.formatTime(0), '00:00');
      expect(VlcStatus.formatTime(65), '01:05');
      expect(VlcStatus.formatTime(3600), '60:00'); // Simple mm:ss implementation
    });

    test('Progress calculation is correct', () {
      final status = VlcStatus(currentTime: 50, totalTime: 100);
      expect(status.progress, 50.0);

      final statusZero = VlcStatus(currentTime: 0, totalTime: 0);
      expect(statusZero.progress, 0.0);

      final statusClamp = VlcStatus(currentTime: 150, totalTime: 100);
      expect(statusClamp.progress, 100.0);
    });

    test('CopyWith updates fields correctly', () {
      final status = VlcStatus(isPlaying: false, volume: 50);
      final newStatus = status.copyWith(isPlaying: true);

      expect(newStatus.isPlaying, true);
      expect(newStatus.volume, 50); // Should remain same
    });
  });

  group('VlcConnection Tests', () {
    test('Json Serialization Cycle', () {
      final connection = VlcConnection(
        id: '123',
        name: 'Test TV',
        ipAddress: '192.168.1.5',
        port: 8080,
        lastUsed: DateTime(2025, 1, 1),
        isFavorite: true,
        myPlaylistIp: '10.0.0.1',
      );

      final json = connection.toJson();
      final fromJson = VlcConnection.fromJson(json);

      expect(fromJson.id, connection.id);
      expect(fromJson.name, connection.name);
      expect(fromJson.isFavorite, true);
      expect(fromJson.myPlaylistIp, '10.0.0.1');
      expect(fromJson.lastUsed, connection.lastUsed);
    });

    test('Equality based on ID', () {
      final conn1 = VlcConnection(
        id: 'abc',
        name: 'Name 1',
        ipAddress: '1.1.1.1',
        port: 80,
        lastUsed: DateTime.now(),
      );
      
      final conn2 = VlcConnection(
        id: 'abc',
        name: 'Name 2', // Different name
        ipAddress: '2.2.2.2',
        port: 90,
        lastUsed: DateTime.now(),
      );

      final conn3 = VlcConnection(
        id: 'xyz',
        name: 'Name 1',
        ipAddress: '1.1.1.1',
        port: 80,
        lastUsed: DateTime.now(),
      );

      expect(conn1, equals(conn2)); // Same ID -> Equal
      expect(conn1, isNot(equals(conn3))); // Different ID -> Not Equal
    });
  });
}
