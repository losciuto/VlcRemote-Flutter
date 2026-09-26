# VlcRemote — istruzioni per gli agenti

Client Flutter per il telecomando remoto di VLC Media Player. Comunica con due
server: **VLC** (socket TCP RC + Web API HTTP) e **MyPlaylist** (server di
playlist, implementato dentro l'app Flutter `MyPlaylist`).

## Prima di iniziare: leggi il piano

Il lavoro di refactoring è tracciato in **`docs/REFACTORING_TODO.md`**.
Leggilo all'avvio di ogni sessione: contiene lo stato di ogni item, le decisioni
prese e quelle ancora aperte. Se lo modifichi, aggiorna la tabella.

## Due regole non negoziabili

1. **Compatibilità col server MyPlaylist.** Prima di modificare qualsiasi cosa
   che tocca la rete, controlla la colonna "Impatto server" nel TODO e la
   sezione "Contratto server da NON rompere" (C1-C13). Se un item è `⚠️`,
   non procedere senza una decisione presa e senza il lato MyPlaylist pronto.
   Il server è `MyPlaylist/lib/services/remote_control_service.dart`.
2. **Verifica sempre, prima di dichiarare finito.**

   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```

   I tre comandi devono essere verdi. Il workflow `.github/workflows/test.yml`
   esegue esattamente questa sequenza.

## Test: cosa scrivere e dove

Il codice di I/O si verifica con i server finti in `test/support/`:

- `fake_vlc_server.dart` — replica la socket RC di VLC (fa eco del comando,
  risponde in chunk multipli, registra i comandi ricevuti).
- `fake_my_playlist_server.dart` — replica il lato server MyPlaylist: legge
  l'header di 4 byte big-endian, decifra il pacchetto AES-GCM e risponde in
  JSON. **Usalo per qualunque modifica a `MyPlaylistService`**: se cambi il
  formato del pacchetto, i comandi o le chiavi degli `args`, i test di
  `my_playlist_service_test.dart` devono essere aggiornati insieme al server.

`MyPlaylistService` non lancia mai eccezioni verso l'esterno: in caso di errore
restituisce `{'status': 'error', 'message': ...}`. È un comportamento atteso
dai test.

## Struttura

```
lib/
  main.dart                  composition root, unico ChangeNotifierProvider
  providers/vlc_provider.dart  stato dell'app (unico ChangeNotifier)
  services/                  I/O: socket VLC, HTTP VLC, MyPlaylist, storage
  models/                    POCO con toJson/copyWith
  widgets/                   schermate e pannelli
  screens/                   home_screen
  config/, constants/        valori statici
  exceptions/                gerarchia di eccezioni (usare, non stampare)
```

## Errori: eccezioni, non `print`

`lib/exceptions/vlc_exceptions.dart` esiste ed è da preferire a
`catch (e) { print(...); return null; }`. Le eccezioni tipizzate servono a
distinguere "collegamento perso" da "playlist vuota", cosa impossibile con un
`return []` silenzioso.

I `print` di produzione che loggano dati utente (titoli, percorsi dei file) sono
debito tecnico noto: vedi item 6.1 nel TODO.
