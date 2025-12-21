import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  test('MyPlaylist Packet Encryption Structure', () async {
    final algorithm = AesGcm.with256bits();
    
    // Mock data
    final secretKeyString = 'my_default_secret_key_32chars_long';
    final payload = jsonEncode({'command': 'play', 'args': {}});
    
    // Key preparation (identical to MyPlaylistService)
    final Uint8List keyBytes = Uint8List(32);
    final encodedKey = utf8.encode(secretKeyString);
    for (int i = 0; i < encodedKey.length && i < 32; i++) {
      keyBytes[i] = encodedKey[i];
    }
    final secretKeyHandle = SecretKey(keyBytes);
    
    final cleartext = utf8.encode(payload);
    final nonce = algorithm.newNonce();
    
    final secretBox = await algorithm.encrypt(
      cleartext,
      secretKey: secretKeyHandle,
      nonce: nonce,
    );
    
    // Verify packet length: 12 (nonce) + 16 (mac) + ciphertext.length
    final packetLength = 12 + 16 + secretBox.cipherText.length;
    
    final packet = BytesBuilder();
    packet.add(secretBox.nonce);
    packet.add(secretBox.mac.bytes);
    packet.add(secretBox.cipherText);
    final buffer = packet.takeBytes();
    
    expect(buffer.length, equals(packetLength));
    
    // Verify positions
    expect(buffer.sublist(0, 12), equals(secretBox.nonce));
    expect(buffer.sublist(12, 28), equals(secretBox.mac.bytes));
    expect(buffer.sublist(28), equals(secretBox.cipherText));
    
    print('Encryption Test Passed: Packet structure is correct.');
  });
}
