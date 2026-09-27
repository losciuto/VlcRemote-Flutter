# Changelog

All notable changes to this project will be documented in this file.

## [2.7.5] - 2026-09-27

Lavori di rifinitura, nessuno dei quali cambia il protocollo con MyPlaylist:
stessi pacchetti, stessi comandi, stessa chiave.

### Fixed
- **La connessione resta registrata se VLC non risponde**: prima la connessione
  veniva salvata solo dopo che la sonda su VLC era andata a buon fine, e
  MyPlaylist e' un server a se' stante. Una TV spenta bastava a far fallire
  anche le playlist, che non hanno niente a che fare con VLC, e i due problemi
  si mascheravano: il sintomo era "MyPlaylist non risponde" e la causa era VLC.
- **"Riprova" non usa piu' il contesto di uno State dismesso**: il dialogo si
  chiude prima di attendere la connessione, e il pulsante dello snack bar
  richiamava `_connectTo` su uno State smontato, dove `if (!mounted)` non
  arrivava in tempo perche' l'eccezione nasceva alla lettura di `context`.
- **La chiave segreti accetta meno di 32 caratteri**: il form rifiutava
  qualunque chiave che non fosse lunga esattamente 32 caratteri, ma nessun
  lato del protocollo lo richiede, la chiave viene completata con zeri e
  MyPlaylist fa lo stesso (C4). Il vincolo che serve e' solo il massimo.
- **Le icone del launcher**: su macOS era ancora il logo di default di Flutter,
  intatto dal primo commit, perche' la sezione `macos` mancava in
  `flutter_launcher_icons` e il tool non guardava quella piattaforma. Su Linux
  non c'era un desktop entry ne un'icona installabile, quindi l'app non aveva
  una voce nel menu. Aggiunti entrambi, e `linux/share` contiene il desktop
  entry e il set hicolor a otto taglie con le regole di installazione.
- **Icona della finestra su Linux**: `gtk_window_set_icon` va chiamata due
  volte, perche' GTK non pubblica `_NET_WM_ICON` finche' la finestra non e'
  realizzata, e la barra delle applicazioni mostra l'icona generica dei
  programmi.
- **Segreti non piu' persi**: `SecureStorageService` non nasconde piu' gli
  errori di scrittura. Prima, un secure storage non disponibile faceva perdere
  le password salvate senza dirlo, e i segreti finivano nel JSON in chiaro.
- **Aggiornamenti verificati**: un binario senza checksum non viene piu'
  eseguito, e il download va su file temporaneo con rinomina atomica.
- **Dispose**: i nove campi del dialogo filtri e i tre campi MyPlaylist del
  dialogo di connessione non venivano distrutti. Ogni apertura lasciava
  controller vivi con i loro listener per tutta la sessione.
- **`VlcService.dispose` non era sicuro da ripetere** e chiudere una socket gia'
  distrutta faceva fallire lo smontaggio, per esempio dopo una riconnessione.
- **Indirizzi IP**: la validazione contava quattro parti e basta, quindi
  `999.999.999.999` passava. Ora controlla gli ottetti, e i campi MyPlaylist
  (IP, porta, chiave) non erano affatto validati.

### Changed
- **Log con livelli** al posto dei `print` sparsi. Non era solo pulizia: una
  riga per voce in playlist e una per ogni chunk costavano piu' del lavoro che
  le generava. `getPlaylist` su 6000 voci passa da 1057 ms a 582 ms ed e'
  piatto rispetto alla dimensione.
- **I comandi di sistema non stanno piu' nel provider**, e nemmeno la sonda
  di MyPlaylist: il provider non usa piu' `dart:io` ed e' testabile senza un
  sistema operativo sotto.
- **Le risposte MyPlaylist non dipendono piu' dalla chiusura della socket**:
  con un server che non chiude, un messaggio gia' arrivato e valido veniva
  scartato e tornava un errore dopo 10 secondi. Ora arriva in 31 ms.
- **Le costanti inutilizzate sono state usate, non cancellate**: erano gia' la
  risposta a numeri scritti a mano altrove, incluso un `5` che avrebbe
  continuato a mentire se il ritmo del polling fosse cambiato.
- **Dialogi estratti in file propri**: filtro, anteprima e barra di stato.
  `my_playlist_panel.dart` da 865 a 364 righe, `home_screen.dart` da 581 a 458.
- **La versione arriva da `pubspec.yaml`**: era scritta in due posti e il
  dialogo delle informazioni mostrava 2.7.4 quando l'app era 2.7.5.
- **Testi in italiano**: il dialogo che ferma VLC sul PC remoto era in
  inglese, su un'azione distruttiva.
- **Aggiornamento Dipendenze**: 35 pacchetti inclusi `package_info_plus`
  (9.0.0 -> 9.0.1), `path_provider` (2.1.5 -> 2.1.6), `xml` (6.6.1 -> 7.0.1),
  `intl` (0.20.2 -> 0.20.3), e dipendenze transitive.

### Added
- **Copertura test**: `test/playlist_item_test.dart` (6 test) e
  `test/filter_settings_test.dart` (4 test) sui rispettivi modelli, piu' i test
  del layer servizi con un server RC finto. Il totale e' passato da 17 a 215.

### Removed
- Dieci ricostruzioni dell'albero che non mostravano nulla: il valore del
  progresso della riconnessione non era letto da nessuna parte.
- `lib/config/app_config.dart`: quaranta righe di costanti mai usate, delle
  quali una sola contava, ed era quella sbagliata.
- `docs/CRITICAL_FIXES.md`: quattro fix gia' applicati, con numeri di riga
  invecchiati. L'unico ancora mancante, la validazione degli IP, e' stato
  completato.


## [2.7.4] - 2026-03-31

### Added
- **Smart Playlist Filter Persistence**: The app now remembers the last set of filters (genres, years, rating, etc.) used to generate playlists.
- **Filter Reset**: Added a "Reset" button in the filter dialog to quickly clear all fields and persistent memory.

## [2.7.3] - 2026-03-29

### Added
- **Manual Release Trigger**: Added `workflow_dispatch` to GitHub Actions, allowing users to trigger a build and release with a custom version tag directly from the GitHub UI.
- **Auto-Update Checker**: The app now automatically checks for new versions on GitHub at startup and prompts the user to update.

### Fixed
- **CI/CD Optimization**: Fixed code formatting and linting issues (missing curly braces) that were blocking the automated test pipeline.
- **Workflow Reliability**: Improved GitHub Actions stability and added a "Run workflow" button for manual testing.

## [2.7.0] - 2026-03-27

### Added
- **Poster & Zoom Support**: Added rich visual playlists using `cached_network_image`. The app now renders movie posters injected from MyPlaylist's proxy server and leverages VLC's native `/art` API.
- **Interactive Zoom**: Users can now tap on posters to view a full-screen, high-resolution version with a smooth zoom animation.


## [2.5.0] - 2026-03-27

### Added
- **VLC HTTP API Support**: Completely rewrote the connection provider.

## [2.4.0] - 2026-03-26

### Added
- **Kill VLC**: Added functionality to force-stop all VLC instances (both local and remote via MyPlaylist).
- **New Button**: Inserted "Kill VLC" action in both the Info Dialog and the "Smart Actions" panel.
- **Maintenance**: Added support for critical system commands during control sessions.

## [2.3.0] - 2026-01-21

### Synchronization
- **MyPlaylist v3.4.0 Compatibility**: Fully synchronized protocol to support the latest playlist generation logic.
- **Improved Series Support**: Enhanced metadata handling for TV series and episodes, including better badge rendering in previews.

### Maintenance
- Updated internal protocol definitions for improved stability during remote control sessions.
- General performance improvements and documentation synchronization.


### MyPlaylist Synchronization (v3.0.0)
- **Exclusion Filters**: Added support for excluded genres and years in smart playlist generation.
- **Actor & Director Filters**: Added new input fields for including/excluding specific actors and directors.
- **Rich Metadata Preview**: Preview playlist now displays series indicators (TV icon and "SERIE" badge) to match MyPlaylist v3.0.0.
- **Protocol Extension**: Updated communication protocol to handle complex metadata and advanced filter arguments.

## [1.3.0] - 2025-12-23

### Performance & Efficiency
- **Optimized Polling**: Reduced status update interval from 500ms to 1000ms (-50% network traffic)
- **Command Delays**: Replaced hardcoded delays with named constants (100ms/300ms)
- **Volume Debouncing**: Added 300ms debounce to prevent command flooding during slider interaction
- **Seek Debouncing**: Implemented debounce mechanism for seek operations

### Error Handling & Resilience
- **Auto-Reconnect**: Exponential backoff strategy (1s → 2s → 4s → 8s → 16s, max 5 attempts)
- **Retry Logic**: 3 retry attempts for status updates before triggering reconnect
- **Improved Stability**: Status timer continues running during temporary failures

### Code Quality
- **Centralized Constants**: All magic numbers replaced with named constants in `AppConstants`
- **Resource Cleanup**: Proper disposal of debounce timers
- **Maintainability**: Single source of truth for all timing configurations

### UX Enhancements
- **Progress Feedback**: 10-step progress updates during MyPlaylist reconnection
- **Better Messages**: Enhanced status messages for user awareness

## [1.2.1] - 2025-12-21


- Documentation update and version synchronization.
- Expanded English README with full features and configuration guide.

## [1.2.0] - 2025-12-14

### Added
- **Interactive UI Controls**: Replaced static volume and playback progress displays with interactive sliders in the `ControlPanel`.
- **Redesigned Playlist Access**: Moved the playlist from a permanently visible panel to a separate, button-triggered modal view (bottom sheet).
- **New Branding**: Modern application icon applied across all platforms.
- **Improved Now Playing**: Removed redundant bars and improved visual clarity.
- **Optimization**: Better responsiveness for UI updates and seeking.

## [1.1.0] - 2025-12-11
- Initial release with basic VLC control functionality.
