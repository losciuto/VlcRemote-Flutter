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

## Build e firma

**Firma della release.** La chiave di produzione non è nel repository. Si
genera una volta sola e si tiene fuori da git:

```bash
keytool -genkey -v -keystore ~/keys/vlcremote-release.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias vlcremote
```

Poi in `android/key.properties` (anch'esso gitignored, vedi `android/.gitignore`):

```properties
storePassword=...
keyPassword=...
keyAlias=vlcremote
storeFile=/percorso/assoluto/vlcremote-release.jks
```

Senza quel file `flutter build apk --release` **funziona comunque** e produce un
APK firmato con la chiave di debug, che è pubblica e identica su ogni
installazione al mondo: chiunque potrebbe firmare un aggiornamento sostitutivo.
Gradle stampa un avviso esplicito in quel caso. Non distribuire quell'APK.

**Dipendenza di sistema per la build Linux.** `flutter_secure_storage` usa
libsecret, quindi la build Linux richiede:

```bash
sudo apt install libsecret-1-dev
```

`linux/CMakeLists.txt` lo cerca con `pkg_check_modules` e la build si ferma con
un errore esplicito se manca. Su macOS il corrispondente è il Keychain di
sistema, su Windows DPAPI: non serve installare nulla.

**Backup Android.** I segreti stanno in `flutter_secure_storage`, che su Android
usa l'Android Keystore: le chiavi non sono esportabili. Per questo
`res/xml/data_extraction_rules.xml` e `res/xml/backup_rules.xml` escludono
`sharedpref` e `database` dal backup cloud e dal trasferimento di dispositivo.
Se in futuro un segreto finisce in SharedPreferences, va in quei domini
esclusi, altrimenti al ripristino su un altro telefono i dati cifrati sarebbero
illeggibili (le chiavi non ci sono) o, nel caso di versioni vecchie dell'app, i
segreti in chiaro finirebbero su Google Drive.

## Secret key MyPlaylist: lunghezza

La chiave AES è derivata dal secret key con **zero-padding o troncamento a 32
byte, senza KDF** (scelta D1 nel TODO: il server fa la stessa derivazione, e
introdurre un KDF romperebbe C4 senza una release coordinata dei due progetti).

Conseguenza pratica: il secret key non viene "rafforzato" da uno stiraggio, ma
l'entropia è quella della stringa. **Usare un secret key lungo** — 32 caratteri o
più, generato a caso. Con una password breve tipo `1234` la chiave AES è
prevedibile per chiunque legga il traffico. Allungare la chiave non richiede
nessuna modifica al server, quindi è la mitigazione più economica disponibile.
