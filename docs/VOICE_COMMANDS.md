# Comandi vocali offline (Vosk) — progettazione, stato e tracciamento

Documento di riferimento per la funzionalita' dei **comandi vocali offline** di
VlcRemote: riconoscimento in locale con Vosk, senza alcun invio di audio a
servizi esterni.

Ha tre parti:

1. **Progettazione** — come e' fatto, perche' cosi' e non altrimenti.
2. **Stato del lavoro** — cosa e' fatto, cosa resta, come si torna indietro.
3. **Tracciamento** — le regole applicate e lo stato della sessione.

Il tracciamento generale del progetto resta in
[`REFACTORING_TODO.md`](REFACTORING_TODO.md) (Fase 6); questo documento e' il
riferimento tecnico della feature.

---

## 1. Perche' esiste

VlcRemote controlla VLC (telecomando) e il server MyPlaylist (playlist). I
comandi piu' usati — play, pausa, traccia successiva, volume — sono anche
quelli che si danno piu' spesso a voce quando si guarda un film.

Il requisito non negoziabile e' **offline**: l'audio del microfono non deve
uscire dal dispositivo. Per questo la scelta e' Vosk, che gira in locale, e non
un servizio cloud. Il prezzo e' che il motore riconosce parole chiave
italiane e inglesi, non il linguaggio naturale: si dice "alza il volume", non
"potresti alzare un po' il volume?".

L'implementazione nasce in **MyPlaylist** (scheda "Voce") ed e' stata portata
qui: il motore, il parser e il modello sono gli stessi, l'esecuzione no (vedi
§ 11).

## 2. Cosa fa

- Trascrive in locale l'audio del microfono (Vosk, modello "small" per la
  lingua scelta).
- Riconosce un catalogo di comandi e li esegue:
  - sul **player VLC**: play, pausa, stop, traccia successiva/precedente, volume
    (su/giu/valore), spostamento nella traccia (avanti/indietro di N secondi);
  - sulle **playlist MyPlaylist**: generazione casuale, generazione dei recenti,
    avvio della playlist corrente.
- Mostra in un pannello: stato del motore, modello e sua presenza in locale,
  lingua, microfono scelto, livello audio in ingresso, cronologia dei comandi
  con esito, ed elenco dei comandi riconosciuti.
- E' tutto **facoltativo**: nessun comando parte senza che l'utente prema il
  pulsante del microfono.

## 3. Architettura

```
lib/services/voice/
├── voice_language.dart        lingue supportate, modello Vosk e URL
├── voice_command.dart         catalogo dei comandi (enum) e voci di cronologia
├── voice_command_parser.dart  frase -> comando (regole per lingua)
├── voice_command_service.dart motore: modello, microfono, riconoscimento
└── voice_command_executor.dart interfaccia + esecutore che parla col provider
lib/widgets/voice_panel.dart   pannello con mic, livello, cronologia, comandi
```

Flusso di un comando:

```
microfono --(PCM 16k mono)--> Vosk --(testo)--> VoiceCommandParser
          --> VoiceCommand --(VoiceCommandExecutor)--> VlcProvider
          --> VlcService / MyPlaylistService --> VLC + MyPlaylist
```

Il motore **non conosce** `VlcProvider`: riceve un `VoiceCommandExecutor`. Il
motivo e' pratico, non estetico: cosi' il riconoscimento si prova con
un esecutore finto, senza aprire una socket e senza toccare VLC.

### 3.1 Composizione (composition root)

`lib/main.dart` monta tre provider:

| Provider | Ruolo |
|---|---|
| `Provider<SettingsService>` | impostazioni condivise (lingua, microfono) |
| `ChangeNotifierProvider<VlcProvider>` | stato dell'app, unica fonte dei comandi VLC |
| `ChangeNotifierProxyProvider<VlcProvider, VoiceCommandService>` | motore vocale, agganciato al provider |

`SettingsService` e' una sola istanza perche' venga inizializzata una volta
sola: il provider la usa per le sue impostazioni, il motore vocale per le sue.

Il pannello si apre dall'icona del microfono nella `AppBar` di
`lib/screens/home_screen.dart` (`showVoicePanel`).

### 3.2 Stati del motore

```
idle ──prepare()──> preparing ──> ready ──startListening()──> listening
                        │                                   │
                        └──────── error <──────────────────┘
```

- `idle` — il motore non e' ancora stato preparato.
- `preparing` — modello in caricamento (o in download, se non presente).
- `ready` — modello caricato, in attesa.
- `listening` — microfono attivo.
- `error` — ultimo errore, con dettaglio in `errorDetails`.

Gli errori tipizzati sono in `VoiceError`: `unsupportedPlatform`,
`nativeLibraryMissing`, `modelDownloadFailed`, `modelLoadFailed`,
`microphoneDenied`, `recorderUnavailable`.

### 3.3 Il modello Vosk

- Due lingue: **italiano** (`vosk-model-small-it-0.22`, 47,4 MiB compresso) e
  **inglese** (`vosk-model-small-en-us-0.15`, 39,3 MiB compresso).
- I modelli si scaricano **alla prima preparazione** e si conservano nella
  cartella dati dell'applicazione (`getApplicationSupportDirectory()/models`),
  non nella cartella documenti: sono file di programma, non dell'utente.
- `prepareIfModelPresent()` prepara il motore **senza rete**: se il modello e'
  gia' in locale lo carica, altrimenti non fa nulla e lascia il pulsante di
  download all'utente. Serve a non tenere il microfono spento quando il
  modello c'e' gia' ma il motore non e' mai stato avviato.
- Cambiando lingua il riconoscitore viene chiuso e ricreato: un modello Vosk
  riconosce una sola lingua per volta.

## 4. Il catalogo dei comandi

Il parser non usa una grammatica vincolata: le frasi arrivano approssimate,
quindi il lavoro e' su parole chiave e sinonimi. L'ordine delle regole conta,
dalla piu' specifica alla piu' generica.

| Comando | Italiano | Inglese | Numero |
|---|---|---|---|
| Volume su | "alza il volume", "volume su", "aumenta il volume", "tira su il volume" | "volume up", "raise the volume", "turn up the volume", "louder" | — |
| Volume giu | "abbassa il volume", "volume giu" | "volume down", "lower the volume", "quieter" | — |
| Volume a valore | "volume 50", "volume" + numero | "volume 50" | obbligatorio, 0-100 |
| Playlist casuale | "playlist casuale", "genera casuale", "lista casuale" | "random playlist", "shuffle playlist" | facoltativo |
| Playlist recenti | "playlist recenti", "video recenti", "ultimi video" | "recent playlist", "latest videos" | facoltativo |
| Avvia playlist | "riproduci la playlist", "avvia la playlist", "suona la playlist" | "play the playlist" | — |
| Traccia successiva | "traccia successiva", "prossima traccia", "salta traccia" | "next track" | — |
| Traccia precedente | "traccia precedente", "precedente" | "previous track" | — |
| Avanti nella traccia | "salta avanti", "avanti", "inoltra" | "skip forward" | facoltativo, default 30 s |
| Indietro nella traccia | "salta indietro", "indietro", "torna indietro" | "skip backward" | facoltativo, default 30 s |
| Pausa | "pausa", "sospendi" | "pause" | — |
| Riprendi | "riprendi", "riproduci", "continua" | "resume", "continue" | — |
| Stop | "ferma", "ferma tutto", "chiudi vlc", "spegni vlc" | "stop", "close vlc" | — |

Dettagli del riconoscimento:

- La frase viene **normalizzata**: minuscole, senza accenti, senza
  punteggiatura, spazi normalizzati. "Alza, il volume!" e "alza il volume"
  sono la stessa frase.
- I numeri si cercano come **cifre** ("50") o come **parole** ("cinquanta").
  In italiano i termini ambigui ("uno", "sei", "sette", "otto", "nove") sono
  esclusi: compaiono troppo spesso nel parlato e falsificano il numero
  ("salta avanti di otto" verrebbe letto come 8 secondi invece di "otto
  track"). In inglese "twenty five" vale 25.
- Le regole hanno un ordine: "volume 50" e' valutato **prima** di "volume su",
  altrimenti "volume su 50" diventerebbe un aumento di volume.

## 5. L'esecutore

`VlcVoiceCommandExecutor` riusa i metodi gia' presenti in `VlcProvider`:
socket unica, stato della UI aggiornato come per un pulsante premuto a mano.
**Nessun side effect nuovo e' stato introdotto nel provider.**

| Comando | Metodo del provider | Precondizione |
|---|---|---|
| play / pausa / stop | `play()`, `pause()`, `stop()` | server VLC collegato |
| traccia successiva / precedente | `next()`, `previous()` | server VLC collegato |
| volume su/giu/valore | `volumeUp()`, `volumeDown()`, `setVolume()` | server VLC collegato |
| spostamento nella traccia | `seekTo()` | server VLC collegato e `totalTime > 0` |
| playlist casuale / recenti / avvio | `mpGenerateRandom()`, `mpGenerateRecent()`, `mpPlay()` | MyPlaylist configurato |

Lo spostamento nella traccia e' l'unico caso non banale: il comando RC `seek`
di VLC e' **assoluto**, quindi la posizione di partenza si legge dallo stato
corrente (`status.currentTime`) e si somma il numero di secondi richiesto. Se il
target esce dalla durata della traccia il comando non viene eseguito e finisce
in cronologia come "non eseguito".

## 6. Integrazione nativa

| Piattaforma | Stato | Note |
|---|---|---|
| **Linux** | funzionante | la libreria `libvosk.so` e' accanto all'eseguibile; il runner ne imposta `LIBVOSK_PATH` prima che parta la VM Dart |
| **Android** | funzionante | il plugin Vosk porta con se' `libvosk.so` per ogni ABI; serve `RECORD_AUDIO` |
| **Windows** | supportata | il pacchetto `vosk_flutter_fixed` fornisce la DLL |
| **macOS** | non supportata | il plugin non espone l'interfaccia nativa: `isPlatformSupported` e' falso e il pannello lo segnala |
| **web** | non supportata | gia' esclusa dal progetto (vedi README) |

### 6.1 Linux: due dettagli non banali

1. **Le intestazioni del plugin.** Il pacchetto pubblica le intestazioni in
   `linux/include/vosk_flutter/`, mentre il registrant generato dal tool
   Flutter le cerca in `vosk_flutter_fixed/vosk_flutter_plugin.h`. Senza una
   copia, la compilazione fallisce. La copia e' fatta in
   `linux/CMakeLists.txt`, senza toccare il pacchetto.
2. **Il percorso della libreria.** Il plugin cerca la libreria nativa nella
   variabile d'ambiente `LIBVOSK_PATH`. Dart legge l'ambiente **una volta
   sola**, al primo accesso: la variabile deve quindi esistere gia' quando
   parte l'applicazione, non quando viene richiesto il modello. Per questo la
   imposta `linux/runner/my_application.cc`, che gira prima della VM Dart,
   leggendo `/proc/self/exe` e puntando alla cartella `lib` accanto
   all'eseguibile.

Il pacchetto usato e' `vosk_flutter_fixed` (0.1.4) e non
`vosk_flutter_service`: quest'ultimo usa ancora il vecchio nome del plugin
nel CMake e nella CLI di installazione, quindi la build Linux fallisce.

## 7. Permessi e privacy

- **Android**: `RECORD_AUDIO` e `<uses-feature android:name="android.hardware.microphone" android:required="false" />`.
  Il permesso del microfono e' opzionale, quindi l'app resta installabile su
  dispositivi senza microfono.
- **Linux**: il plugin `record` usa PulseAudio; serve un utente con accesso a
  PipeWire/PulseAudio.
- **L'audio non lascia il dispositivo**: il riconoscimento e' locale, non
  c'e' alcuna chiamata di rete verso servizi di trascrizione. L'unica rete
  usata e' il download del modello, al primo uso.

## 8. Impostazioni

Due chiavi in `SettingsService` (SharedPreferences):

| Chiave | Contenuto | Default |
|---|---|---|
| `voice_language` | codice lingua (`it`, `en`) | italiano |
| `voice_input_device` | id del microfono scelto | quello predefinito |

L'id del microfono viene **normalizzato**: il backend PulseAudio restituisce i
valori tra virgolette (`"alsa_input..."`), senza la pulizia l'id salvato non
combacia piu' con quello restituito e la scelta viene persa. Se il microfono
salvato non e' piu' presente, si torna al predefinito e la chiave viene
rimossa.

## 9. Test

| File | Che cosa copre |
|---|---|
| `test/voice_command_parser_test.dart` | normalizzazione, numeri in cifre e in parole, regole per lingua, esclusioni |
| `test/voice_command_service_test.dart` | motore con esecutore finto: cronologia, esiti, cambio lingua, dispose |
| `test/voice_panel_test.dart` | pannello: apertura, stato, lingua, microfono, cronologia |
| `integration_test/voice_panel_test.dart` | percorso reale: apre il pannello, il modello si prepara, il microfono parte, lo stato passa a `listening`, il pulsante diventa "ferma", poi torna a `ready` |

I test di integrazione si eseguono **con un dispositivo**:

```bash
flutter test integration_test/voice_panel_test.dart -d linux
```

`flutter test` (senza `-d`) esegue solo `test/`: la cartella `integration_test/`
non finisce nella CI, che continua a girare senza un display.

Nota operativa: i click manuali su X11 non sono affidabili perche' il gestore
delle finestre sposta continuamente la finestra dell'app sul secondo monitor.
Il test di integrazione e' il riferimento.

## 10. Limiti noti

- **macOS non e' supportato** (manca l'interfaccia nativa del plugin).
- Il riconoscimento e' a **parole chiave**, non a linguaggio naturale.
- Il modello "small" e' piu' leggero ma meno accurato di uno "large": con
  musica di sotto o un accento forte le frasi possono non essere riconosciute.
- Il pannello e' pensato per il **touch** e per il mouse: su schermi molto
  piccoli la lista dei comandi e' scrollabile.
- Il **seek** relativo dipende dallo stato aggiornato dal polling: se il
  provider non ha ancora girato, la posizione corrente e' zero e lo
  spostamento parte dall'inizio.
- La cronologia tiene **50 voci** e non viene salvata: si azzera chiudendo
  l'app.

## 11. Differenze rispetto a MyPlaylist (l'origine)

Il porting ha riportato motore, parser, modello e catalogo, e ha cambiato tre
cose:

| | MyPlaylist | VlcRemote |
|---|---|---|
| **Esecutore** | `vlc_rc_client.dart`, un client RC proprio | `VlcVoiceCommandExecutor` sul `VlcProvider` gia' presente |
| **Interfaccia** | scheda a pieno schermo (`voice_tab.dart`) con stringhe localizzate | pannello a scomparsa (`voice_panel.dart`) aperto dall'AppBar, stringhe in italiano |
| **Lingua** | it/en, modello scaricato | it/en, modello scaricato, con preparazione senza rete se il modello e' gia' in locale |

Il resto e' condiviso: stessi modelli Vosk, stesso catalogo di comandi, stesso
formato dei numeri.

## 12. Rollback

La funzionalita' e' **additiva**: non tocca il protocollo con MyPlaylist
(C1-C13 intatti) e non introduce side effect in `VlcProvider`. Il rollback e'
quindi semplice: basta rimuovere i file e ripristinare i file modificati.

```bash
# Sul branch feat/comandi-vocali
git checkout -- lib/main.dart lib/screens/home_screen.dart \
                lib/services/settings_service.dart \
                linux/CMakeLists.txt linux/runner/my_application.cc \
                android/app/src/main/AndroidManifest.xml \
                pubspec.yaml pubspec.lock
rm -rf lib/services/voice lib/widgets/voice_panel.dart integration_test
rm -f test/voice_command_parser_test.dart test/voice_command_service_test.dart \
      test/voice_panel_test.dart
flutter pub get
```

Uno script pronto all'uso e' in `/tmp/kilo/vlcremote-comandi-vocali/rollback.sh`
(verifica il ripristino in un worktree di prova). `main` non e' mai stato
tocato: il lavoro e' tutto sul branch `feat/comandi-vocali`.

## 13. Tracciamento

### Regole applicate

1. Lingua **italiana** in codice, commenti, log e documentazione.
2. Nessun `flutter gen-l10n`: le stringhe sono in italiano e scritte a mano,
   come nel resto del progetto.
3. Nessun side effect aggiuntivo in `VlcProvider`.
4. Contratto server C1-C13 **non toccato**: la funzionalita' e' lato client.
5. Verifica obbligatoria prima di dichiarare finito: `dart format`, `flutter
   analyze`, `flutter test`, build della piattaforma interessata.
6. Scope minimo: nessun refactoring estraneo alle funzionalita' esistenti.

### Cosa e' fatto

- [x] Servizio voice in `lib/services/voice/` (lingua, catalogo, parser,
      motore, esecutore).
- [x] Impostazioni `voiceLanguage` e `voiceInputDevice`.
- [x] Pannello `voice_panel.dart` con modello, lingua, microfono, livello
      audio, cronologia ed elenco comandi.
- [x] Integrazione nell'AppBar di `home_screen.dart`.
- [x] Composition root in `main.dart` (`SettingsService` condivisa, motore
      vocale agganciato al provider).
- [x] Integrazione nativa: shim delle intestazioni Vosk in `linux/CMakeLists.txt`,
      `LIBVOSK_PATH` in `linux/runner/my_application.cc`, permessi Android
      `RECORD_AUDIO` e microfono opzionale.
- [x] Test: parser, motore, pannello e test di integrazione.
- [x] Build verificate: `flutter build linux --release` (con `libvosk.so`
      nel bundle) e `flutter build apk --release` (con `libvosk.so` per ogni
      ABI e `RECORD_AUDIO` nel manifest).
- [x] Script di rollback scritto e provato.

### Cosa resta aperto

- [ ] macOS: il plugin Vosk non espone l'interfaccia nativa, serve un plugin
      dedicato o un'implementazione alternativa.
- [ ] Il modello potrebbe essere offerto in un formato piu' piccolo: al
      momento sono scaricati circa 47 MiB per l'italiano.
- [ ] Nessun comando "a piacere": il catalogo e' fisso, e va allargato a mano
      quando serve.
- [ ] La CI non esegue il test di integrazione: servirebbe un runner con
      display (xvfb) per farlo girare in automatico.

### Stato della sessione

- Branch: `feat/comandi-vocali` (in VlcRemote e in MyPlaylist).
- `main` intatto in entrambi i repository.
- Verifiche verdi: `dart format`, `flutter analyze` (0 problemi), `flutter test`
  (244 test), `flutter test integration_test/voice_panel_test.dart -d linux`
  (1 test), `flutter build linux --release`, `flutter build apk --release`.
- Modifiche **non committate**: il lavoro resta nel working tree, in attesa di
  una revisione esplicita prima del commit.
