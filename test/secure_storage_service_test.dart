import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/exceptions/vlc_exceptions.dart';
import 'package:vlc_remote_flutter/services/secure_storage_service.dart';

/// Doppio di [FlutterSecureStorage] che non tocca la piattaforma.
///
/// [FlutterSecureStorage] non è un'interfaccia, ma implementandola qui si
/// ottiene lo stesso effetto senza i canali di piattaforma: i test possono
/// così verificare il comportamento di [SecureStorageService] anche quando il
/// keyring è assente o rotto, che è il caso interessante.
class FakeSecureStorage implements FlutterSecureStorage {
  FakeSecureStorage({Map<String, String>? backing})
    : backing = backing ?? <String, String>{};

  /// Dati "sul disco".
  final Map<String, String> backing;

  /// Se è impostato, ogni operazione lancia. Serve a simulare un keyring
  /// assente (Linux senza libsecret, Web senza HTTPS) o rotto.
  Object? failure;

  int readCount = 0;
  int writeCount = 0;
  int deleteCount = 0;

  /// Se è vero, ogni operazione funziona solo alla prima chiamata.
  bool failAfterFirstCall = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    readCount++;
    _maybeFail();
    return backing[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writeCount++;
    _maybeFail();
    if (value == null) {
      backing.remove(key);
    } else {
      backing[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deleteCount++;
    _maybeFail();
    backing.remove(key);
  }

  void _maybeFail() {
    if (failAfterFirstCall) {
      failAfterFirstCall = false;
      throw StateError('keyring non raggiungibile');
    }
    final error = failure;
    if (error != null) throw error;
  }

  // Membri non usati da SecureStorageService: devono comunque esistere per
  // poter implementare l'interfaccia.
  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _maybeFail();
    return backing.containsKey(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _maybeFail();
    return Map.of(backing);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _maybeFail();
    backing.clear();
  }

  // Campi di default esposti dalla libreria: il dopio non li usa, ma senza
  // questi membri non puo' implementare l'interfaccia.
  @override
  final IOSOptions iOptions = const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  @override
  final AndroidOptions aOptions = const AndroidOptions();

  @override
  final LinuxOptions lOptions = const LinuxOptions();

  @override
  final WindowsOptions wOptions = const WindowsOptions();

  @override
  final WebOptions webOptions = const WebOptions();

  // AppleOptions e' astratta: IOSOptions ne e' una classe concreta.
  @override
  final AppleOptions mOptions = const IOSOptions();

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => false;

  @override
  Stream<bool> get onCupertinoProtectedDataAvailabilityChanged =>
      const Stream<bool>.empty();

  @override
  Map<String, List<ValueChanged<String?>>> get getListeners => const {};

  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  void unregisterAllListeners() {}
}

void main() {
  group('SecureStorageService', () {
    late FakeSecureStorage fake;
    late SecureStorageService service;

    setUp(() {
      fake = FakeSecureStorage();
      service = SecureStorageService(storage: fake);
    });

    test('scrive e rilegge un segreto', () async {
      await service.write('k1', 'segreto');

      expect(fake.backing['k1'], 'segreto');
      expect(await service.read('k1'), 'segreto');
    });

    test('la seconda lettura non interroga il keyring (cache)', () async {
      await service.write('k1', 'segreto');
      final readsAfterWrite = fake.readCount;

      expect(await service.read('k1'), 'segreto');
      expect(await service.read('k1'), 'segreto');

      expect(fake.readCount, readsAfterWrite);
    });

    test('cancella un segreto, anche dalla cache', () async {
      await service.write('k1', 'segreto');
      expect(await service.read('k1'), 'segreto');

      await service.delete('k1');

      expect(fake.backing.containsKey('k1'), isFalse);
      // Se la cache non venisse svuotata, `read` continuerebbe a restituire il
      // valore cancellato: la connessione eliminata tornerebbe utilizzabile.
      expect(await service.read('k1'), isNull);
    });

    group('keyring non disponibile', () {
      setUp(() => fake.failure = StateError('nessun keyring'));

      test('la scrittura lancia SecretStoreException', () async {
        await expectLater(
          service.write('k1', 'segreto'),
          throwsA(isA<SecretStoreException>()),
        );
      });

      test('la cancellazione lancia SecretStoreException', () async {
        await expectLater(
          service.delete('k1'),
          throwsA(isA<SecretStoreException>()),
        );
      });

      test('l\'eccezione dice che il segreto NON e\' stato salvato', () async {
        // Il messaggio è ciò che finisce nel log e nel messaggio all'utente:
        // deve rendere chiaro che non si tratta di un salvataggio riuscito.
        try {
          await service.write('k1', 'segreto');
          fail('il write doveva fallire');
        } on SecretStoreException catch (e) {
          expect(e.key, 'k1');
          expect(e.operation, 'write');
          expect(e.toString(), contains('NON'));
        }
      });

      test('niente viene scritto, e la cache non mente sul risultato', () async {
        await expectLater(
          service.write('k1', 'segreto'),
          throwsA(isA<SecretStoreException>()),
        );

        // Il punto del fix: se la cache fosse aggiornata prima della scrittura,
        // `read` restituirebbe il segreto come se fosse salvato.
        expect(await service.read('k1'), isNull);
        expect(fake.backing.containsKey('k1'), isFalse);
      });

      test('la lettura non lancia: degradazione a "nessun segreto"', () async {
        // Scelta deliberata: se propagasse, una macchina senza keyring
        // perderebbe la lista connessioni invece di chiedere le password.
        expect(await service.read('k1'), isNull);
      });

      test(
        'un valore gia\' in cache resta leggibile se il keyring si blocca',
        () async {
          // Prima il salvataggio riesce, poi si simula il keyring che si blocca
          // a meta' esecuzione: e' il caso in cui la cache salva la sessione.
          fake.failure = null;
          await service.write('k1', 'segreto');
          expect(await service.read('k1'), 'segreto');

          fake.failure = StateError('keyring bloccato a meta\' esecuzione');

          expect(await service.read('k1'), 'segreto');
        },
      );
    });

    test(
      'un errore dopo un\'operazione riuscita non lascia la cache indietro',
      () async {
        await service.write('k1', 'segreto');
        expect(await service.read('k1'), 'segreto');

        fake.failAfterFirstCall = true;
        await expectLater(
          service.write('k1', 'nuovo valore'),
          throwsA(isA<SecretStoreException>()),
        );

        // Sul disco c'e' ancora il valore vecchio, quindi la cache deve dire il
        // valore vecchio: una cache "ottimista" mostrerebbe una password che
        // l'utente non sta usando davvero.
        expect(fake.backing['k1'], 'segreto');
        expect(await service.read('k1'), 'segreto');
      },
    );
  });

  group('InMemorySecretStore', () {
    test('write/read/delete funzionano', () async {
      final store = InMemorySecretStore();

      expect(await store.read('k'), isNull);
      await store.write('k', 'v');
      expect(await store.read('k'), 'v');
      await store.delete('k');
      expect(await store.read('k'), isNull);
      expect(store.values, isEmpty);
    });
  });

  group('secretKeyFor', () {
    test('il nome della connessione resta leggibile e non si collide', () {
      expect(
        secretKeyFor('abc123', 'vlc_password'),
        'vlcremote_abc123_vlc_password',
      );
      expect(
        secretKeyFor('abc123', 'my_playlist_secret'),
        'vlcremote_abc123_my_playlist_secret',
      );
    });

    test('due connessioni diverse non condividono chiavi', () {
      // Il pericolo di una chiave costruita per concatenazione e' che due coppie
      // diverse producano la stessa stringa: "a" + "bc" e "ab" + "c".
      expect(secretKeyFor('a', 'bc'), isNot(secretKeyFor('ab', 'c')));
    });
  });
}
