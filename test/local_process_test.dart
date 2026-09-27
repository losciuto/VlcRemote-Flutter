import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/services/local_process_service.dart';
import 'package:vlc_remote_flutter/services/vlc_service.dart';

import 'support/fake_vlc_server.dart';

/// Servizio finto che registra le chiamate invece di avviare processi.
class _ProcessiFinti implements LocalProcessService {
  _ProcessiFinti({
    this.codiceUscita = 0,
    this.deveFallire = false,
    this.desktop = true,
  });

  final int codiceUscita;
  final bool deveFallire;
  final bool desktop;

  int chiamate = 0;

  @override
  bool get isDesktop => desktop;

  @override
  Future<int> killVlc() async {
    chiamate++;
    if (deveFallire) throw const ProcessFailure('comando non trovato');
    return codiceUscita;
  }
}

/// Errore finto, per non dipendere da `dart:io` anche nel test.
class ProcessFailure implements Exception {
  const ProcessFailure(this.messaggio);
  final String messaggio;
  @override
  String toString() => messaggio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ProcessiFinti processi;

  /// Provider connesso a un server VLC finto, con l'indirizzo MyPlaylist
  /// indicato. Il kill locale guarda l'indirizzo dichiarato per MyPlaylist e
  /// confronta con gli indirizzi di questa macchina, quindi la connessione a
  /// VLC serve solo perche' il provider la tenga come connessione corrente.
  Future<VlcProvider> providerCon(String myPlaylistIp) async {
    SharedPreferences.setMockInitialValues({});
    final server = await FakeVlcServer.start((_) => []);
    addTearDown(server.close);

    final provider = VlcProvider(
      vlcService: VlcService(),
      localProcessService: processi,
    );
    addTearDown(provider.dispose);

    final ok = await provider.connect(
      VlcConnection(
        id: '1',
        name: 'Sala',
        ipAddress: server.host,
        port: server.port,
        myPlaylistIp: myPlaylistIp,
        myPlaylistPort: 4242,
        myPlaylistSecretKey: 'chiave',
        lastUsed: DateTime(2026, 9, 27),
      ),
    );
    expect(ok, isTrue, reason: 'la connessione al server finto deve riuscire');
    return provider;
  }

  group('kill locale di VLC (5.5)', () {
    test('non esegue nulla se il server e\' su un\'altra macchina', () async {
      // Il caso piu' importante: uccidere il VLC del portatile mentre si
      // comanda quello del salotto lascerebbe l'utente senza riproduzione.
      processi = _ProcessiFinti();
      final provider = await providerCon('192.168.1.50');

      final esito = await provider.killLocalVlcIfSameMachine();

      expect(esito, isNull);
      expect(
        processi.chiamate,
        0,
        reason: 'nessun processo deve essere avviato verso un server remoto',
      );
    });

    test('non esegue nulla se non c\'e\' MyPlaylist configurato', () async {
      processi = _ProcessiFinti();
      final provider = await providerCon('');

      expect(await provider.killLocalVlcIfSameMachine(), isNull);
      expect(processi.chiamate, 0);
    });

    test('non esegue nulla su una piattaforma senza processi', () async {
      // Su Android e iOS l'app non avvia processi: la piattaforma va
      // controllata prima di arrivare al comando.
      processi = _ProcessiFinti(desktop: false);
      final provider = await providerCon('127.0.0.1');

      expect(await provider.killLocalVlcIfSameMachine(), isNull);
      expect(processi.chiamate, 0);
    });

    test('uccide il VLC quando il server gira su questa macchina', () async {
      processi = _ProcessiFinti(codiceUscita: 0);
      final provider = await providerCon('127.0.0.1');

      final esito = await provider.killLocalVlcIfSameMachine();

      expect(esito, 'Comando kill locale eseguito');
      expect(processi.chiamate, 1);
    });

    test('nessun processo da uccidere non e\' un errore', () async {
      // pkill e taskkill restituiscono 1 quando il nome non corrisponde a
      // niente: e' il caso normale se VLC non era aperto.
      processi = _ProcessiFinti(codiceUscita: 1);
      final provider = await providerCon('localhost');

      expect(
        await provider.killLocalVlcIfSameMachine(),
        'Nessun processo VLC su questa macchina',
      );
    });

    test('un codice diverso da 0 e 1 viene riportato', () async {
      processi = _ProcessiFinti(codiceUscita: 3);
      final provider = await providerCon('127.0.0.1');

      expect(
        await provider.killLocalVlcIfSameMachine(),
        'Kill locale fallito (codice 3)',
      );
    });

    test('un comando che non parte viene riportato, non propagato', () async {
      processi = _ProcessiFinti(deveFallire: true);
      final provider = await providerCon('127.0.0.1');

      final esito = await provider.killLocalVlcIfSameMachine();

      expect(esito, startsWith('Errore kill locale:'));
    });
  });
}
