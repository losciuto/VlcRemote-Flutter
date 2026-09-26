import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/services/update_service.dart';

void main() {
  group('isVersionGreater', () {
    test('restituisce true quando latest è maggiore', () {
      expect(isVersionGreater('2.8.0', '2.7.4'), isTrue);
      expect(isVersionGreater('3.0.0', '2.9.9'), isTrue);
      expect(isVersionGreater('2.7.5', '2.7.4'), isTrue);
    });

    test('restituisce false quando latest è minore o uguale', () {
      expect(isVersionGreater('2.7.4', '2.7.4'), isFalse);
      expect(isVersionGreater('2.7.3', '2.7.4'), isFalse);
      expect(isVersionGreater('1.9.0', '2.0.0'), isFalse);
    });

    test('ignora il prefisso v dei tag GitHub', () {
      expect(isVersionGreater('v2.8.0', '2.7.4'), isTrue);
      expect(isVersionGreater('v2.7.4', 'v2.7.4'), isFalse);
    });

    test('ignora i metadati di build (+N)', () {
      // Regressione: '4+1' non e' un intero, il confronto deve usare solo il
      // numero di versione, non il build number di Android.
      expect(isVersionGreater('2.7.5', '2.7.4+1'), isTrue);
      expect(isVersionGreater('2.7.4+1', '2.7.4+1'), isFalse);
      expect(isVersionGreater('2.7.4+2', '2.7.4+1'), isFalse);
    });

    test('ignora i prerelease', () {
      expect(isVersionGreater('2.8.0', '2.8.0-rc1'), isFalse);
      expect(isVersionGreater('2.8.0-rc1', '2.7.4'), isTrue);
    });

    test('gestisce segmenti mancanti o non numerici', () {
      expect(isVersionGreater('2.8', '2.7.4'), isTrue);
      expect(isVersionGreater('2.8.0', '2.8'), isFalse);
      expect(isVersionGreater('2.8.x', '2.7.4'), isTrue);
      expect(isVersionGreater('', '0.0.0'), isFalse);
    });
  });
}
