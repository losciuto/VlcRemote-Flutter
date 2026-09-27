import 'dart:io';

/// Esegue i comandi di sistema che l'app deve lanciare.
///
/// Vive in un servizio e non nel provider per una ragione precisa: il provider
/// descrive lo stato dell'app, avviare un processo e' un'azione. Mescolarle
/// rende il provider dipendente da `dart:io`, e di conseguenza non testabile
/// senza un sistema operativo sotto.
///
/// Espone solo il codice di uscita, non il `ProcessResult`: cosi' `dart:io`
/// non attraversa la firma e chi chiama non deve saperne qualcosa.
class LocalProcessService {
  /// Uccide il VLC di questa macchina e restituisce il codice di uscita.
  ///
  /// Restituisce 1 quando non c'era nessun processo da uccidere: e' quello che
  /// fanno `pkill` e `taskkill` quando il nome non corrisponde a niente, e
  /// non e' un errore.
  ///
  /// Il `-x` di `pkill` e' voluto: senza, il nome del processo viene cercato
  /// come motivo, e anche i processi che nel nome hanno 'vlc' verrebbero
  /// uccisi. Il `/T` di `taskkill` uccide anche i figli.
  Future<int> killVlc() async {
    final ProcessResult result = Platform.isWindows
        ? await Process.run('taskkill', ['/F', '/IM', 'vlc.exe', '/T'])
        : await Process.run('pkill', ['-x', 'vlc']);
    return result.exitCode;
  }

  /// Vero se questa macchina e' un desktop, cioe' se ha un VLC da uccidere.
  ///
  /// Su Android e iOS non c'e' niente da fare: l'app non gira processi, e la
  /// verifica evita di importare `dart:io` in un ramo che su quelle piattaforme
  /// non deve esistere.
  bool get isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
}
