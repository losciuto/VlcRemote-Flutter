# Piano di refactoring VlcRemote — TODO

> Stato: da discutere. Generato il 2026-09-26.
> Progetto: `VlcRemote` (client) · Server: `MyPlaylist` (`lib/services/remote_control_service.dart`)
> Vincolo: ogni modifica deve restare **compatibile con il server MyPlaylist** (v3.14.1).

## Legenda

**Impatto server** — `ok` = nessun impatto, puoi farlo da solo · `⚠️` = richiede modifica coordinata in MyPlaylist, non farlo finché non è deciso · `⛔` = vietato per ora

**Stato** — `fatto` · `da fare` · `decisione` (serve una tua risposta) · `bloccato` (dipende da una decisione)

---

## 0. Contratto server da NON rompere

Regole emerse dal codice di `remote_control_service.dart`. Ogni item sotto che tocca I/O deve rispettarle.

| # | Invariante | Riferimento server |
|---|---|---|
| C1 | Header 4 byte uint32 **big-endian** con la lunghezza del payload cifrato, obbligatorio | `remote_control_service.dart:216-217` |
| C2 | Payload = `nonce(12) \|\| mac(16) \|\| ciphertext`, AES-GCM **256 bit** | `remote_control_service.dart:238-240` |
| C3 | Payload minimo **28 byte**, sotto = `Message too short` | `remote_control_service.dart:234` |
| C4 | Chiave = secret key UTF-8 **zero-padded o troncata a 32 byte** (identica a `my_playlist_service.dart:21-26`) | `remote_control_service.dart:264-270` |
| C5 | Comandi ammessi: `generate_random`, `generate_recent`, `generate_filtered`, `play`, `stop`, `kill_vlc` | `remote_control_service.dart:298-358` |
| C6 | Chiavi `args` di `generate_filtered`: `genres`, `years`, `min_rating`, `actors`, `directors`, `excluded_*`, `limit`, `preview` | `remote_control_service.dart:323-342` |
| C7 | Risposta = **JSON grezza senza header**, socket chiuso subito dopo; niente chunking | `remote_control_service.dart:247,252` |
| C8 | Campi risposta: `status` (`success`/`error`), `message`, `command`, `playlist` | `remote_control_service.dart:250, 360-365` |
| C9 | `playlist[]` = `Video.toMap()`: `id, path, mtime, title, genres, year, directors, directorThumbs, plot, actors, actorThumbs, duration, rating, isSeries, posterPath, saga, sagaIndex, date_added` | `MyPlaylist/lib/models/video.dart:72-92` |
| C10 | **One-shot**: una nuova connessione TCP per comando, poi chiusura | `my_playlist_service.dart:99` |
| C11 | Timeout lettura server **5 s**: il client deve inviare tutto entro 5 s dalla connessione | `remote_control_service.dart:211` |
| C12 | Endpoint poster `GET /poster/<id>` su **porta + 1** (8081 se TCP=8080), **senza autenticazione**, 302 se il poster è URL remoto | `remote_control_service.dart:142-189` |
| C13 | Nessun campo di versione protocollo nel payload: **la compatibilità è manuale**, via CHANGELOG |

---

## 1. Tabella TODO

### Fase 0 — Sicurezza urgente (bloccanti)

| # | Cosa | File | Sev | Impatto server | Stato |
|---|---|---|---|---|---|
| 1.0 | Ruotare il token GitHub esposto nel `git remote` di MyPlaylist | `.git/config` di MyPlaylist | Bloccante | ok | da fare |
| 1.1 | Spostare `vlcPassword` e `myPlaylistSecretKey` da SharedPreferences a storage sicuro | `lib/services/secure_storage_service.dart`, `connection_service.dart` | Bloccante | ok | **fatto** |
| 1.2 | Firmare la release con chiave di produzione invece che `debug` | `android/app/build.gradle.kts` | Bloccante | ok | **fatto** |
| 1.3 | Verificare l'APK scaricato (SHA-256) prima di installarlo | `lib/services/update_service.dart` | Bloccante | ok | **fatto** |
| 1.4 | Smettere di inviare la password VLC a ogni richiesta: usarla solo dove serve davvero (elimina la copia nel widget) | `lib/providers/vlc_provider.dart` (`artworkFor`) | Alto | ok | **fatto** |
| 1.5 | Limitare dimensione e timeout del download APK, chiudere l'`http.Client` | `lib/services/update_service.dart` | Medio | ok | **fatto** |
| 1.6 | **NOTA**: TLS non è applicabile — l'interfaccia HTTP di VLC non supporta HTTPS. Le alternative realistiche sono (a) storage sicuro, (b) ridurre l'esposizione, (c) tunnel/proxy locale, (d) binding su loopback | `vlc_http_service.dart` | — | ok | **fatto (a)** |
| 1.7 | Derivare la chiave AES con un KDF (PBKDF2/scrypt) invece di zero-padding | `lib/services/my_playlist_service.dart` | Alto | **⚠️ rompe C4** | **fatto (A)** |
| 1.8 | Smettere di eseguire `pkill -f vlc` in locale quando il server è remoto | `lib/providers/vlc_provider.dart` | Alto | ok | **fatto** |
| 1.9 | Validare/incapsulare gli URL costruiti con dati del server (`Uri.encodeComponent`, allowlist di host) | `vlc_http_service.artworkUri`, `my_playlist_service.posterUri` | Alto | ok | **fatto** |
| 1.10 | **Seguito di 1.1**: `SecureStorageService.write`/`delete` ingoiano l'errore con `print` e restituiscono `void`, quindi `ConnectionService` non sa se il segreto e' stato salvato | `secure_storage_service.dart`, `connection_service.dart` | Alto | ok | **fatto** |
| 1.11 | Lavoro a meta' in MyPlaylist: `update_service.dart` (nuovo) piu' modifiche a `github_service.dart` e `update_dialog.dart` erano **fuori da ogni commit** e non compilavano (9 errori) | MyPlaylist | Alto | ok | **fatto** (2 commit) |

**Risolto — 1.7 (KDF), scelta A.** Le alternative che ci sono state:
- **(A) Compatibilità totale** ✅ scelta: non si tocca la derivazione. Mitigazione solo lato client (allungare la secret key, avviso all'utente). Rischio accettato.
- **(B) Sicurezza vera**: si introduce un KDF **identico su entrambi i lati**. Serve rilasciare MyPlaylist per primo, poi VlcRemote. I client VlcRemote vecchi non potranno più parlare con i server nuovi → serve o un flag di versione, o accettare la rottura e aggiornare insieme.
- **(C) Ibrido**: accettare *entrambe* le derivazioni in MyPlaylist (prova la nuova, se fallisce ricadi sulla vecchia). Compatibile coi client vecchi, costo minimo lato server, nessun negotiation esplicito possibile per C13.

La scelta A e' quella economica: non richiede di toccare il server, quindi non rompe
C4 e non blocca la release. Il prezzo e' che il secret key non viene stirato:
vedi la sezione "Secret key MyPlaylist: lunghezza" in `AGENTS.md`.

**Risolto — 1.8 (pkill locale).** Il telecomando uccideva qualunque processo con "vlc" nel nome, e lo faceva anche puntando a un server remoto. Ora `killLocalVlcIfSameMachine()` verifica che l'IP di `myPlaylistIp` sia un indirizzo di questa macchina prima di eseguire il kill, e usa `pkill -x vlc` (nome esatto) invece di `pkill -f vlc` (corrispondenza sulla riga di comando, che agganciava anche processi non-VLC). Il comando `kill_vlc` del server resta l'unico modo per fermare VLC remoto.

**Nota su 1.9.** La codifica dei dati del server negli URL e' coperta da `Uri` con `pathSegments`/`queryParameters`, che percent-encodano i segmenti, e da un controllo sull'host. Restano fuori scope gli URL del download aggiornamenti (`update_service.dart`), che arrivano dall'API GitHub: sono protetti dal confronto SHA-256, e l'unica alternativa sarebbe un allowlist di host che romperebbe i mirror.

**Risolto — 1.11 (MyPlaylist).** Il lavoro in `working tree` non era mai stato compilato: 9 errori (`ScaffoldMessenger.showBar` e `Snack` non esistono, e tre `shape:` erano `BorderRadius` dove serve `RoundedRectangleBorder`). Il difetto serio era altro: il nuovo `UpdateService` scaricava un eseguibile (`.AppImage`, `.exe`, `.msix`, `.deb`, `.apk`) e **lo avviava senza verifica**. Ora l'impronta SHA-256 viene letta dall'asset `<file>.sha256` e confrontata, il file con impronta diversa viene cancellato, e **senza impronta pubblicata l'installazione automatica non avviene**. Download su `.part` con rinominamento, limite di dimensione, timeout.

Nota per il rilascio: l'installazione in-app di MyPlaylist resta inactive finche' `publish-precompiled.yml` e `release.yml` non pubblicano l'asset `.sha256` per ogni binario. Finche' e' cosi' l'utente scarica e apre il file a mano: comportamento corretto, ma utile sapere che il flusso automatico dipende da quel passaggio.

### Fase 1 — Correttezza (nessun impatto sul server, alto payoff)

| # | Cosa | File | Sev | Impatto server | Stato |
|---|---|---|---|---|---|
| 2.1 | Mettere `getPlaylist` sullo stesso mutex di `sendCommandAndRead` (race sul buffer) | `vlc_service.dart` | Bloccante | ok | **fatto** |
| 2.2 | Aggiungere `VlcHttpService.clear()` e chiamarlo in `disconnect()` e sui rami senza password | `vlc_http_service.dart`, `vlc_provider.dart` | Bloccante | ok | **fatto** |
| 2.3 | Correggere `isPlaying` nel fallback socket (`\|\| time > 0` riporta "in riproduzione" in pausa) | `vlc_service.dart` | Bloccante | ok | **fatto** |
| 2.4 | Gestire `notifyListeners()` dopo `dispose()` in `_runMpCommand` | `vlc_provider.dart` | Alto | ok | **fatto** (guardia in `notifyListeners()`) |
| 2.5 | Non far fallire tutta la lista connessioni se un record è malformato (parsing tollerante) | `vlc_connection.dart`, `connection_service.dart` | Alto | ok | **fatto** |
| 2.6 | Non distruggere i titoli con parentesi nel parsing della playlist | `vlc_service.dart` | Alto | ok | **fatto** (si rimuove solo l'anno in coda) |
| 2.7 | Riassemblare le risposte multi-chunk usando il buffer che già esiste | `vlc_service.dart` | Alto | ok | **fatto** (silenzio di 100 ms) |
| 2.8 | `try/catch` muti che nascondono errori (parsing metadati, await previous, kill) | `vlc_http_service.dart`, `vlc_service.dart`, `vlc_provider.dart` | Medio | ok | **fatto** |
| 2.9 | `_isVersionGreater` non gestisce `2.7.4+1` (`int.tryParse("4+1")` → 0) | `update_service.dart` | Medio | ok | **fatto** |
| 2.10 | Clampare volume e seek nel layer servizi, non solo in `seekTo` | `vlc_service.dart` | Medio | ok | **fatto** |
| 2.11 | Copertura di test per il layer servizi con un server RC finto | `test/support/fake_vlc_server.dart`, `test/vlc_service_test.dart` | Bloccante | ok | **fatto** (14 test) |
| 2.12 | Verificare che i nuovi test **falliscano** col codice vecchio (test di regressione veri) | — | — | ok | **fatto**: 2.1, 2.3, 2.4, 2.5, 2.6, 2.7 rivoltati e confermati |

**Test in circolazione** (da 17 a **109** dopo Fase 0, 1.10 e 3.16): `vlc_service_test.dart` (19), `connection_service_test.dart` (18), `my_playlist_service_test.dart` (14), `secure_storage_service_test.dart` (13), `update_service_test.dart` (12), `update_dialog_test.dart` (10), `vlc_http_service_test.dart` (6), `vlc_provider_test.dart` (2), piu' i 16 preesistenti su modelli e widget. Infrastruttura di test: `test/support/fake_vlc_server.dart`, `fake_my_playlist_server.dart` e `fake_release_server.dart` (aggiunto in Fase 0).

Copertura per file, misurata il 27/09/2026 con un `lcov.info` pulito. Serve a distinguere il debito della UI da quello dei servizi: la colonna di sinistra e' il codice di cui mi fido, quella di destra il debito da affrontare.

| Coperto bene | % | Da colmare | % |
|---|---|---|---|
| `filter_settings` | 100.0 | ~~`app_config`~~ | rimosso |
| `secure_storage_service` | 96.2 | `my_playlist_panel` | 0.3 |
| `vlc_connection` | 93.7 | `connection_dialog` | 0.4 |
| `main` | 91.3 | `playlist_panel` | 0.7 |
| `my_playlist_service` | 86.2 | `control_panel` | 1.0 |
| `vlc_service` | 83.6 | `now_playing_card` | 4.5 |
| `vlc_status` | 78.3 | `vlc_provider` | 7.2 |
| `playlist_item` | 73.9 | `vlc_http_service` | 21.6 |
| `update_dialog` | 73.1 | `settings_service` | 33.3 |
| `update_service` | 68.6 | `home_screen` | 47.0 |
| `connection_service` | 67.8 | | |
| `vlc_exceptions` | 64.3 | | |

`vlc_http_service` al 21.6% e `vlc_provider` al 7.2% sono i due buchi che pesano di piu' fra i servizi: entrambi coprono I/O e stato, e sono lapriorita' della Fase 2. `home_screen` al 47% e' il punto migliore in cui iniziare i test di widget, perche' e' gia' a meta' strada.

**Risolto — 1.10 e 3.15.** Il difetto era piu' grave di una segnalazione mancante. Con il comportamento precedente, su una macchina senza keyring la migrazione dei segreti **li cancellava da SharedPreferences senza riuscire a spostarli**: la password dell'utente spariva senza rimedio. Tre correzioni:

1. `SecureStorageService` lancia `SecretStoreException` invece di stampare e proseguire, e aggiorna la cache **solo dopo** il successo: prima la cache poteva far leggere come salvato un segreto che sul disco non c'era.
2. `_persist` scrive i segreti prima del JSON, quindi un fallimento interrompe prima della riscrittura e la migrazione resta coerente. Il blocco di migrazione in `getConnections()` intercetta l'eccezione per conto proprio: propagarla arrivava al catch esterno, che restituiva una lista connessioni **vuota**.
3. `return _persist(...)` dentro un `try` non cattura l'errore asincrono in Dart. Senza `await` i quattro `try/catch` di `saveConnection`, `deleteConnection`, `updateLastUsed` e `toggleFavorite` erano inerti e il fallimento sfuggiva come eccezione non gestita.

`read` continua a non propagare, per scelta: su una macchina senza keyring far fallire il caricamento di tutte le connessioni sarebbe peggio che chiedere le password all'utente.

I 5 test nuovi sono stati verificati col codice precedente: falliscono senza il fix. Il debito principale resta la UI, da affrontare in Fase 4 con test di widget.

### Fase 2 — Resilienza e test

| # | Cosa | File | Sev | Impatto server | Stato |
|---|---|---|---|---|---|| 3.1 | Propagare gli errori invece di stamparli: oggi il retry/reconnect è **inerte** | `vlc_provider.dart`, `vlc_service.dart` | Bloccante | ok | **fatto** |
| 3.2 | Adottare `lib/exceptions/vlc_exceptions.dart` (5 classi, **zero usi**) invece di `print` + `return null` | `vlc_exceptions.dart` | Alto | ok | **parziale**: usate in `VlcService.getStatus`/`getPlaylist` e nel provider. Restano i servizi di persistenza e `UpdateService`, dove `print` + fallback è ancora accettabile |
| 3.3 | Guard di re-entranza sul `Timer.periodic` + avviare il timer dopo la playlist | `vlc_provider.dart` | Alto | ok | **fatto** (`_isUpdatingStatus`, `_isRefreshingPlaylist`, timer avviato dopo `refreshPlaylist`) |
| 3.4 | Test del layer servizi: **oggi 0 righe** su `VlcService`, `VlcHttpService`, `VlcProvider`, `ConnectionService`, `UpdateService` | `test/` | Bloccante | ok | **fatto** (71 test; `SettingsService` e `UpdateService` hanno solo test parziali) |
| 3.5 | Riscrivere `my_playlist_encryption_test.dart`: oggi copia la logica e verifica un pacchetto costruito lì, non il codice di produzione | `test/my_playlist_encryption_test.dart` | Alto | ok | **fatto**: file rimosso, il pacchetto è ora verificato sul codice di produzione in `my_playlist_service_test.dart` |
| 3.6 | Test di contratto contro il server reale: header BE, min 28 byte, `nonce\|\|mac\|\|ciphertext`, chiave zero-padded | `test/support/fake_my_playlist_server.dart` | Alto | ok | **fatto** (14 test) — **limite**: replica fedele del lato server in un helper di test, non importa il codice reale di MyPlaylist (progetto separato) |
| 3.7 | Fixare `release.sh`: oggi `flutter test \|\| echo Warning` con `set -e` → una release con test rotti parte lo stesso | `scripts/release.sh:22-23` | Alto | ok | **fatto** |
| 3.8 | Aggiungere `flutter test` a `check_code.sh` (oggi solo format + analyze) | `scripts/check_code.sh` | Medio | ok | **fatto** |
| 3.9 | Coverage in CI (`test.yml` oggi non la calcola) | `.github/workflows/test.yml` | Medio | ok | **fatto**: `flutter test --coverage`, riepilogo in `$GITHUB_STEP_SUMMARY`, `lcov.info` come artifact. Baseline corrente: **33.9%** (764/2256). Attenzione: `lcov.info` si appende a ogni run, quindi in CI va rimosso prima di misurare |
| 3.10 | Test di copertura per gli scenari di errore (connessione persa, playlist vuota, aggiornamento fallito) | `test/vlc_service_test.dart`, `test/my_playlist_service_test.dart` | Medio | ok | **fatto** |
| 3.11 | **Drift di formattazione che faceva fallire la CI**: `test/filter_settings_test.dart` e `test/playlist_item_test.dart` non passavano `dart format --set-exit-if-changed`, quindi il workflow `test.yml` su `main` è rosso dalla commit `4dce47f` | due file di test | Alto | ok | **fatto** (nel working tree, non committato) |
| 3.12 | Test per `isVersionGreater` (build metadata, prerelease, prefisso `v`) | `test/update_service_test.dart` | Medio | ok | **fatto** (6 test) |
| 3.13 | `release.sh` compila iOS, Windows e Linux sulla stessa macchina: fallisce sempre su un sistema senza quegli SDK | `scripts/release.sh` | Medio | ok | **fatto**: ogni piattaforma viene saltata con avviso se manca l'SDK, i fallimenti veri escono con codice 1 |
| 3.14 | Con VLC "connesso ma morto" il primo retry arriva dopo ~22 s (5 comandi × 1,5 s di timeout × 3 tentativi) | `vlc_service.dart`, `app_constants.dart` | Medio | ok | **decisione** (D10): i timeout sono già brevi per impostazione, ridurli cambia il comportamento su reti lente |
| 3.15 | Test per `SecureStorageService`: era a **0%** pur essendo il codice che protegge i segreti | `test/secure_storage_service_test.dart` | Alto | ok | **fatto** (13 test) |
| 3.16 | Test per `update_dialog.dart` (era a 0% dopo la riscrittura della Fase 0) | `test/update_dialog_test.dart` | Medio | ok | **fatto** (10 test, 73.1%) |

### Fase 3 — Performance

| # | Cosa | File | Sev | Impatto server | Stato |
|---|---|---|---|---|---|
| 4.1 | `notifyListeners()` granulari o `Selector` al posto dei `Consumer` grossolani (AppBar, body, FAB ricostruiti 1×/s) | **Molto basso** (era Alto) | Alto | **non serve** | da fare |
| 4.2 | Sospendere il polling in background (`WidgetsBindingObserver` assente in tutto `lib/`) | `vlc_provider.dart` | Alto | ok | **fatto** (3 test) |
| 4.3 | `http.Client` singleton invece di uno nuovo per richiesta (niente keep-alive) | `vlc_http_service.dart` | Medio | ok | **fatto** |
| 4.4 | Cache in memoria di `getConnections()` (oggi `jsonDecode` a ogni chiamina, 10 call site) | `connection_service.dart` | Medio | ok | **fatto** (5 test) |
| 4.5 | Rimuovere il busy-wait sul main isolate in `getPlaylist` (50 wake-up/s per 5 s, O(n²)) | `vlc_service.dart` | **Basso** (era Medio) | ok | **fatto, guadagno non misurabile** |
| 4.6 | Spostare parsing XML/JSON pesanti fuori dal main isolate | `vlc_http_service.dart`, `my_playlist_service.dart` | **Molto basso** (era Medio) | ok | **non serve** |
| 4.7 | Fermare la barra di progresso animata da 10 `notifyListeners()` in 2 s | `vlc_provider.dart:590-598` | Basso | ok | **fatto** |

**5.9, la versione dell'app era in due posti, e quello sbagliato era quello che si leggeva.** `AppConfig` serviva per una cosa sola: mostrare la versione nel dialogo delle informazioni. Tutto il resto del file erano quaranta righe di costanti mai usate, e la versione era scritta a mano mentre `pubspec.yaml` era gia' su 2.7.5: l'info diceva 2.7.4, quindi l'utente vedeva una versione che non era la sua.

Eliminato il file. La versione ora arriva da `pubspec.yaml` con `package_info_plus`, che e' gia' una dipendenza e che il controllo degli aggiornamenti stava gia' leggendo: due letture dello stesso valore che non possono divergere. Il file era anche l'unica cosa che la tabella della copertura indicasse come "da colmare", e non esiste piu'.

**5.8, non era un timeout troppo corto: era una risposta che veniva buttata.** Il client attendeva `onDone`, cioe' la chiusura della socket, e la risposta non e' arrivata finche' il server non chiudeva. Il server vero chiude sempre, quindi la cosa sembrava non succedere mai. Con un server che non chiude, pero', un messaggio gia' arrivato e valido veniva scartato e tornava un errore dopo **10 secondi**.

La correzione non e' allungare il timeout, che costerebbe identico: e' smettere di usare la chiusura come segnale di fine messaggio. Quando il buffer finisce con una graffa e il decodifica riesce, la risposta e' completa, e si va avanti. Un JSON troncato non parsesce, quindi non si puo' sbagliare. Stesso tempo di prima, 31 ms invece di 10.028.

Nello stesso posto c'era un `10` scritto a mano per l'attesa, diverso dalla costante che l'item indicava: `myPlaylistTimeoutMs` e' il timeout di connessione, non di risposta. Ora i due hanno due nomi, e si capisce quale dei due e' quale.

Il protocollo non e' cambiato: stessi pacchetti, stesso header a 4 byte, stessa chiave. Il server continua a chiudere, e quel percorso funziona come prima.

**6.7, il test per i bordi ha trovato un altro difetto.** Il corpo della schermata non aveva `SafeArea`: su un telefono con barra dei gesti l'ultimo pannello, quello con i comandi, finiva sotto la barra e i pulsanti restavano premibili a meta'. Ora e' protetto, con `top: false` perche' la `AppBar` copra gia' il bordo superiore.

Scrivendo il test su uno schermo di 360 pixel di larghezza e' emerso che il titolo della `AppBar` non ci stava: 32 pixel di iconetta, 12 di distanza e il titolo a 22 punti finivano sopra il pulsante di connessione. Ora il titolo si accorcia con i puntini.

Quattro `IconButton` senza `Tooltip`: chiudi e l'occhio della chiave. Un pulsante solo icona non dice niente a chi non lo conosce, e senza tooltip non e' nemmeno raggiungibile con il lettore di schermo. I `Semantics` veri restano da fare: sono un lavoro diverso e non li ho mescolati a questa rimozione.

**6.5, il documento propose fix gia' applicati, e l'unico che mancava era a meta'.** `CRITICAL_FIXES.md` elencava quattro bug con il codice "attuale (BUGGY)" e i numeri di riga. Tre erano gia' risolti da tempo, quindi il file insegnava a intervenire su roba a posto. Il quarto, la validazione dell'indirizzo IP, esisteva ma controllava solo che ci fossero quattro parti: `999.999.999.999` e `abc.def.ghi.jkl` passavano, e l'app falliva solo al connettersi, con un errore che parlava di rete.

Completata, e insieme a lei i tre campi di MyPlaylist che non avevano nessun controllo: IP, porta e secret key. Quest'ultimo e' il caso serio: l'etichetta prometteva 32 caratteri e non li controllava, e la chiave viene completata o troncata a 32 byte in silenzio, quindi un refuso produceva una chiave diversa e un errore di decifratura che non spiegava niente. Ora la validazione e' in `Validators`, con test su ogni caso incluso quello che nessuno scriverebbe a mano.

Tolto il file invece di correggerlo: le correzioni sono nel codice, e i numeri di riga di un documento del genere invecchiano prima del primo colpo.

**6.3, la meta' delle costanti "morte" era la risposta giusta a un numero magico.** Le costanti mai usate erano 16, non 9. Nove erano un catalogo di messaggi in italiano che nessuno leggeva e che la localizzazione (6.6) rendera' inutile: cancellate. Le altre sette no: erano gia' la risposta giusta a numeri scritti a mano altrove, e la domanda vera non era "sono inutilizzate" ma "perche' il numero e' ancora li'".

I timeout erano il caso peggiore: `VlcService` aveva `final int _timeout = 2000` e `AppConstants.connectionTimeoutMs` valeva 2000. Due numeri uguali in due posti, con quello giusto ignorato. Idem la conversione del volume, che scriveva `100 / 256` in due servizi diversi. Ora i numeri hanno un nome solo e le conversioni usano gli estremi di `AppConstants`, cosi' se VLC cambiasse scala si cambia in un posto.

Il `5` del controllo periodico era il peggiore di tutti, perche' era invisibile: `timer.tick % 5` con un timer da 1000 ms e una costante `playlistRefreshMs` da 5000 che nessuno usava. Se il ritmo del polling fosse cambiato, il `5` avrebbe continuato a mentire. Ora i giri si ricavano dalle due costanti.

Una costante era un duplicato (`retryDelayMs` e `reconnectBackoffBaseMs` valgono entrambe 1000) e una non corrispondeva a niente (`seekDebounceMs`, il pannello usa un margine di 2 s): cancellate. Dopo questo, ogni costante in `AppConstants` e' usata da almeno un punto.

**5.2, lo stesso difetto di 5.1 anche qui.** Il dialogo di connessione aveva sette campi e ne distruggeva quattro: le tre righe per i campi di MyPlaylist non c'erano, quindi ogni apertura lasciava tre controller vivi, con i loro listener, per tutta la sessione. Il test copre tutti e sette e non solo qualcuno, perche' il difetto era proprio guardare i primi quattro e non gli altri tre.

**5.5, spostare il comando ha reso testabile la parte piu' pericolosa del provider.** `Process.run` stava dentro `killLocalVlcIfSameMachine`, cioe' nel provider. Ora c'e' `LocalProcessService`, che espone solo il codice di uscita: `dart:io` non attraversa la firma e chi chiama non deve saperne qualcosa. Il servizio e' iniettabile, quindi la logica si puo' provare senza un sistema operativo sotto.

I sette test coprono soprattutto il caso in cui non si deve fare niente: server su un'altra macchina, MyPlaylist non configurato, piattaforma senza processi. Uccidere il VLC del portatile mentre si comanda quello del salotto lascerebbe l'utente senza riproduzione, ed e' il motivo per cui quel codice esiste. Tolto il controllo che confronta l'indirizzo con quelli locali, il test lo segnala.

**5.6, il provider non usa piu' `dart:io`.** Eliminando `Process.run` restava una `Socket.connect` per la sonda di MyPlaylist, ed e' finita anche lei in `MyPlaylistService.isReachable`, che risponde con un booleano invece di far lanciare. Restano `dart:io` nei servizi che devono davvero aprire socket e file: la build web resta fuori discussione e va decisa, non aggirata.

**5.1, la prima parte ha eliminato una fuga di risorse.** Il dialogo dei filtri creava nove `TextEditingController` nel metodo che lo apriva e non li liberava mai: ogni apertura ne lasciava nove in giro, ognuno con i suoi listener. Ora e' un `State` che li crea in `initState` e li distruisce in `dispose`, e il `StatefulBuilder` che serviva solo per chiamare `setState` non serve piu'. Il file passa da 865 a 599 righe.

Un test lo verifica davvero invece di fidarsi: chiude il dialogo, prende un controller dall'albero e prova ad aggiungere un listener. Su un controller distrutto questo lancia, ed e' esattamente cio' che deve succedere. Tolta la riga che lo distrugge, il test fallisce.

**4.1 e' stata scartata dopo aver misurato il costo reale.** Con l'albero che ascolta il provider (icona nella AppBar, corpo con il pannello dei comandi, FAB), una ricostruzione completa costa **0,24 ms**. Il polling gira una volta al secondo, quindi si tratta di 0,24 ms al secondo: invisibile.

La correzione proposta, `Selector` al posto dei `Consumer` grossolani, e' stata implementata e misurata a parte: porta 0,24 ms a 0,21 ms. Sono 25 microsecondi per notifica, il 10% di un costo gia' invisibile. Non vale la pena ristrutturare la UI per questo, e i `Consumer` sono piu' facili da leggere.

C'era anche un'altra ragione per aspettarsi un guadagno, e non c'era: la parte pesante, la lista delle voci, e' dentro `_showPreviewDialog`, cioe' in un `showDialog` con `ListView.builder`, e quindi non viene ricostruita dal polling. Il `Consumer` del pannello non la tocca.

Se in futuro il pannello cresce fino a pesare qualche millisecondo, la misura va rifatta: il numero qui vale per l'albero di oggi, non in generale.

**4.7, la barra di progresso non esisteva.** Il valore `reconnectionProgress` era scritto a dieci tappe durante l'attesa per l'avvio di VLC, e non era letto da nessuna parte: non in `lib/`, non nei test. Le dieci `notifyListeners` ricostruivano l'albero duecento volte al secondo per due secondi, e non mostravano nulla. Tolto il campo, il getter e il ciclo; la pausa di due secondi resta, perche' quella e' vera.

**Da li' e' uscito un bug vero.** Il test che ho scritto per la rimozione ha fatto emergere `Bad state: StreamSink is bound to a stream` da `VlcService.dispose()`: chiudere una socket gia' distrutta lancia, e l'errore usciva da `dispose`, che non e' il posto giusto per far fallire lo smontaggio. `dispose` ora e' idempotente, mette a posto la socket prima di chiuderla, e `connect` su un servizio smontato viene rifiutato con un messaggio che dice il perche'.

**6.1 e 6.2, quello che sembrava cosmetica era un costo.** Togliere i `print` era elencato come pulizia, perche' filtravano titoli di file e percorsi. La misura su `getPlaylist` ha mostrato che erano anche il lavoro piu' pesante dell'app: una riga per voce e una per chunk, con tutto il testo che finiva a schermo sul main isolate. Con il logger, `getPlaylist` su 6000 voci passa da 1057 ms a 582 ms ed e' piatto rispetto alla dimensione. La privacy era il motivo giusto, ma quello piccolo rispetto a questo.

**4.6 e' caduta perche' il problema non era dove sembrava.** Spostare il parsing fuori dal main isolate e' stato scartato dopo aver misurato il costo reale della lettura di una playlist: togliendo i `print`, che erano l'unica parte del lavoro che cresceva con i dati, il tempo e' diventato **575 ms a 1000 voci, 576 ms a 3000, 582 ms a 6000**. Praticamente piatto. Il parsing in se' non blocca il main isolate: il lavoro vero era stampare.

Restare con un `compute()` avrebbe spostato in un altro isolate circa trenta millisecondi, al costo di un isolate da avviare, della stringa da copiare due volte e del risultato da rimandare indietro. Il guadagno era reale solo per playlist enormi, e a quel punto il costo e' tornerebbe con la copia.

**4.5, il guadagno non c'era.** La ricostruzione del buffer a ogni giro e' stata eliminata (il marcatore di fine viene notato dal listener del socket, e il ciclo confronta solo orari e un booleano), ma la misura dice che **non serve a nulla alle dimensioni reali**: con 3000 voci `getPlaylist` richiede 1016ms, e 1021ms con il codice di prima. La differenza e' rumore.

Il motivo e' che il ciclo dura quanto il periodo di silenzio (500 ms), quindi gira cinque o sei volte, non cinquanta: l'attesa di 5 s si usa solo se il server tace, e in quel caso il buffer e' quasi vuoto e copiarlo e' gratis. Il O(n²) descritto nell'item esiste solo nel caso patologico di una playlist molto grande che arriva a gocce per secondi, che non ho misurato. Severita' abbassata da Medio a Basso perche' il merito reale e' fare meno lavoro inutile, non velocizzare.

**4.4, la cache va invalidata, non solo riempita.** `getConnections()` restituisce sempre una copia nuova: dieci call site e quasi tutti la modificano (`sort`, `removeWhere`, `add`), quindi restituire l'istanza in cache avrebbe fatto finire quelle modifiche dentro la cache e cambiato l'ordine con cui la lista viene riletta. La cache vale solo per cio' che e' stato scritto: se `setString` fallisce viene invalidata, e `clearAllConnections` la svuota.

**4.3, attenzione al ciclo di vita.** Un client condiviso tiene una connessione TCP aperta: senza `dispose()` sopravvive al provider. Chiamato da `dispose()` del provider, non da `disconnect()`: staccarsi da un server non deve costringere a riaprire la connessione al successivo.

**Nota su 4.2 e 5.4.** I due item erano bloccati a vicenda: senza 5.4 il provider non era testabile quando connesso, quindi 4.2 non aveva test. Risolvendo 5.4 (i servizi sono iniettabili, i default sono gli stessi di prima) i tre test di 4.2 sono diventati scrivibili e coprono davvero il comportamento: sono stati verificati fallire quando la sospensione viene rimossa.

### Fase 4 — Architettura e UI

| # | Cosa | File | Sev | Impatto server | Stato |
|---|---|---|---|---|---|
| 5.1 | Scomporre `my_playlist_panel.dart`: il dialogo dei filtri e' gia' stato estratto (865 -> 599 righe), restano i dialog di anteprima e di conferma | `my_playlist_panel.dart` | `my_playlist_panel.dart:305-579,581-823` | Alto | ok | **parziale** |
| 5.2 | Scomporre `connection_dialog.dart` (641 righe, build da 290 righe) | `connection_dialog.dart:70-360` | Alto | ok | **parziale** (dispose dei campi) |
| 5.3 | Scomporre `home_screen.dart` (554 righe, `_buildMainContent` da 120) | `home_screen.dart:234-356` | Medio | ok | da fare |
| 5.4 | Dependency injection dei servizi (oggi `final` creati dentro il provider) | `vlc_provider.dart` | Medio | ok | **fatto** (sblocca i test sul provider connesso) |
| 5.5 | Spostare `Process.run` fuori dal layer di stato (fatto); il download APK era gia' in `UpdateService` | `vlc_provider.dart`, `local_process_service.dart` | `vlc_provider.dart:508-549`, `update_dialog.dart:4,50-71` | Medio | ok | **fatto** |
| 5.6 | Rimuovere `dart:io` dal provider e dai servizi, o dichiarare la build web non supportata | il provider e' pulito; restano i servizi che parlano davvero via socket e file | | `vlc_provider.dart:2`, `vlc_service.dart:2`, `my_playlist_service.dart:2` | Medio | **⚠️** tocca le scelte di piattaforma, non il protocollo | **parziale** |
| 5.7 | Tipizzare `dynamic item` nel widget playlist | `playlist_panel.dart:123` | Basso | ok | **fatto** |
| 5.8 | Estendere il timeout di attesa risposta, o fare in modo che il server chiuda sempre (fatto lato client: la risposta non dipende piu' dalla chiusura) | `my_playlist_service.dart:81-93` | Medio | **⚠️** comportamento server | **fatto** |
| 5.9 | Allineare `AppConfig` con la realtà (fatto: il file e' stato eliminato) | `home_screen.dart` | Basso | ok | **fatto** |

### Fase 5 — Igiene, log, documentazione

| # | Cosa | File | Sev | Impatto server | Stato |
|---|---|---|---|---|---|
| 6.1 | Togliere i 42 `print` di produzione che filtrano titoli e percorsi dei tuoi file | `vlc_service.dart:77-79,431-434,527` | Alto | ok | **fatto** |
| 6.2 | Conditionali `kDebugMode` o logger strutturato al posto di `print` | ovunque in `lib/` | Medio | ok | **fatto** |
| 6.3 | Rimuovere codice morto: 16 costanti mai usate, non 9 | `vlc_service.dart`, `vlc_provider.dart`, `app_constants.dart` | Basso | ok | **fatto** |
| 6.4 | Allineare le versioni: README dice 2.7.4 (Marzo 2026), `pubspec` 2.7.4+1, CHANGELOG documenta 2.7.5 (25/09/2026) | `README.md:350`, `pubspec.yaml:5` | Basso | ok | **decisione** (D9) |
| 6.5 | `docs/CRITICAL_FIXES.md` eliminato: i quattro fix che proponeva sono nel codice, l'unico che mancava era completato adesso | | `docs/CRITICAL_FIXES.md` | Basso | ok | **fatto** |
| 6.6 | `intl` è già dipendenza ma non c'è localizzazione: testo hardcoded IT, con qualche leak EN ("Kill all VLC instances") | tutto `lib/` | Basso | ok | da fare |
| 6.7 | `SafeArea` assente ovunque; `Tooltip`/`Semantics` mancanti sui controlli principali (corpo protetto e 4 tooltip aggiunti; i `Semantics` restano da fare) | `control_panel.dart:112-118,189-196` | Basso | ok | **parziale** |
| 6.8 | Costanti hardcoded (`?? 8080` ripetuto 7 volte, `'8000'` 3 volte) sostituite da `AppConstants` | `app_constants.dart`, 3 file | Basso | ok | **fatto** |

---

## 2. Decisioni aperte — le tue domande

Compila questa sezione man mano che ne parliamo, così non le perdiamo.

| # | Domanda | Scelte | Risposta | Data |
|---|---|---|---|---|
| D1 | **1.7 — KDF della chiave AES.** Il server fa la stessa derivazione zero-padded. Che strada? | A = compatibilità totale / B = KDF su entrambi i lati / C = ibrido con fallback | **A — nessun KDF**: la derivazione zero-padding resta identica per non rompere C4. Mitigazione lato client: secret key piu' lunga + guida all'utente in AGENTS.md | 2026-09-26 |
| D2 | **1.8 — `pkill` locale.** Va rimosso, reso condizionale o reso visibile con spia? | rimosso / condizionale / spia | **condizionale**: `killLocalVlcIfSameMachine()` esegue il kill solo se l'IP del server coincide con un indirizzo di questa macchina, e usa `pkill -x vlc` invece di `-f vlc`. Se l'IP non e' noto si assume remoto | 2026-09-26 |
| D3 | **1.6 — Rischio rete LAN.** TLS impossibile con VLC. Quale mitigazione scegli? | a) storage sicuro / b) ridurre esposizione / c) tunnel locale / d) loopback | **a) storage sicuro**: i segreti non viaggiano in chiaro su disco (realizzato in 1.1). b/c/d restano al livello di configurazione del server, fuori dal client | 2026-09-26 |
| D4 | **5.6 — Piattaforme.** Il web è dichiarato in `pubspec` ma rotto da `dart:io`. Lo sistemiamo o lo dichiariamo non supportato? | sistemare / dichiarare | | |
| D5 | **5.8 — Timeout risposta MyPlaylist.** Il server scrive e chiude, il client aspetta `onDone`. Chi deve cambiare? | server / client / nessuno | | |
| D6 | **Ordine di esecuzione.** Fase 1+2 insieme (correzioni + test) oppure Fase 0 prima? | | | |
| D7 | **Dove tenere questo file.** Ora è in `VlcRemote/docs/REFACTORING_TODO.md`. Va spostato in MyPlaylist (perché è un progetto coordinato) o resta qui? | resta / sposta | | |
| D8 | **Ambito del git.** Aggiungere questo file al repository, o tenerlo fuori dal tracciamento? | tracciato / gitignored / fuori repo | **tracciato** | 2026-09-26 |
| D9 | **6.4 — Versione.** Il CHANGELOG documenta 2.7.5 (25/09/2026) ma `pubspec.yaml` è ancora 2.7.4+1 e il README 2.7.4. Si porta `pubspec` a 2.7.5+1 e si aggiorna il README, oppure 2.7.5 non è ancora stata rilasciata? | bump 2.7.5 / rimandare | | |
| D10 | **3.14 — Tempo di reazione alFallback.** Con VLC connesso ma morto, il primo retry arriva dopo ~22 s. Ridurre i timeout RC (ora 1,5 s × 5 comandi) o fare un probe veloce di connettività prima dello stato completo? | ridurre timeout / probe veloce / lasciare così | | |

---

## 3. Regola operativa per ogni intervento

1. Se l'item ha `Impatto server = ok`, si può procedere liberamente.
2. Se ha `⚠️`, non si tocca il codice finché la decisione corrispondente non è presa **e** il lato MyPlaylist è pronto.
3. Ogni item che cambia il protocollo va accompagnato da: modifica di `CHANGELOG.md`/`CHANGELOG_IT.md` **su entrambi i repos**, più un test di contratto (3.6) che dimostri la compatibilità.
4. Nessuna modifica a `remote_control_service.dart` senza un test che copra il comportamento vecchio.
