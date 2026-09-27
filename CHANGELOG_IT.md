# Changelog

Tutti i cambiamenti significativi a questo progetto saranno documentati in questo file.


## [2.7.5] - 27/09/2026

Lavori di rifinitura, nessuno dei quali cambia il protocollo con MyPlaylist:
stessi pacchetti, stessi comandi, stessa chiave.

### Correzioni
- **La connessione resta registrata se VLC non risponde**: prima veniva salvata
  solo dopo che la sonda su VLC era andata a buon fine, e MyPlaylist e' un
  server a se' stante. Una TV spenta bastava a far fallire anche le playlist,
  che non hanno niente a che fare con VLC, e i due problemi si mascheravano.
- **"Riprova" non usa piu' il contesto di uno State dismesso**: il dialogo si
  chiude prima di attendere la connessione, e `if (!mounted)` non arrivava in
  tempo perche' l'eccezione nasceva alla lettura di `context`.
- **La chiave segreti accetta meno di 32 caratteri**: il form rifiutava
  qualunque chiave non lunga esattamente 32 caratteri, ma nessun lato del
  protocollo lo richiede: viene completata con zeri, e MyPlaylist fa lo stesso
  (C4). Il vincolo che serve e' solo il massimo.
- **Le icone del launcher**: su macOS era ancora il logo di default di Flutter,
  perche' la sezione `macos` mancava in `flutter_launcher_icons`. Su Linux non
  c'era un desktop entry ne un'icona installabile, quindi l'app non aveva una
  voce nel menu. Aggiunti entrambi, con il set hicolor a otto taglie.
- **Icona della finestra su Linux**: `gtk_window_set_icon` va chiamata due
  volte, perche' GTK non pubblica `_NET_WM_ICON` finche' la finestra non e'
  realizzata.
- **Segreti non piu' persi**: `SecureStorageService` non nasconde piu' gli
  errori di scrittura, e i segreti non finiscono piu' nel JSON in chiaro.
- **Aggiornamenti verificati**: un binario senza checksum non viene piu'
  eseguito, e il download va su file temporaneo con rinomina atomica.
- **Dispose**: i nove campi del dialogo filtri e i tre campi MyPlaylist del
  dialogo di connessione non venivano distrutti.
- **Indirizzi IP**: la validazione contava quattro parti e basta, quindi
  `999.999.999.999` passava. I campi MyPlaylist non erano affatto validati.

### Modificato
- **Log con livelli** al posto dei `print` sparsi: `getPlaylist` su 6000 voci
  passa da 1057 ms a 582 ms.
- **I comandi di sistema non stanno piu' nel provider**, che non usa piu'
  `dart:io` ed e' testabile senza un sistema operativo sotto.
- **Le risposte MyPlaylist non dipendono piu' dalla chiusura della socket**: con
  un server che non chiude, un messaggio gia' arrivato e valido veniva scartato
  e tornava un errore dopo 10 secondi. Ora arriva in 31 ms.
- **La versione arriva da `pubspec.yaml`**: il dialogo delle informazioni
  mostrava 2.7.4 quando l'app era 2.7.5.
- **Aggiornamento Dipendenze**: 35 pacchetti inclusi `package_info_plus`
  (9.0.0 → 9.0.1), `path_provider` (2.1.5 → 2.1.6), `xml` (6.6.1 → 7.0.1),
  `intl` (0.20.2 → 0.20.3), e dipendenze transitive.

### Aggiunto
- **Copertura Test**: `test/playlist_item_test.dart` (6 test) e
  `test/filter_settings_test.dart` (4 test) sui rispettivi modelli, piu' i test
  del layer servizi con un server RC finto. Totale da 17 a 215 test.

### Rimosso
- Dieci ricostruzioni dell'albero che non mostravano nulla.
- `lib/config/app_config.dart`: quaranta righe di costanti mai usate.
- `docs/CRITICAL_FIXES.md`: quattro fix gia' applicati, con numeri di riga
  invecchiati.


## [2.7.4] - 31/03/2026

### Nuove Funzionalità
- **Persistenza Filtri Smart Playlist**: L'app ora memorizza l'ultimo set di filtri (generi, anni, rating, ecc.) utilizzato per generare le playlist.
- **Reset Filtri**: Aggiunto un pulsante "Reset" nel dialogo dei filtri per pulire rapidamente tutti i campi e la memoria persistente.

## [2.7.3] - 29/03/2026

### Nuove Funzionalità
- **Trigger Release Manuale**: Aggiunta la possibilità di avviare il build e la creazione della release direttamente dalla UI di GitHub via `workflow_dispatch`, con inserimento manuale della versione.
- **Controllo Aggiornamenti Automatico**: L'app ora verifica automaticamente la presenza di nuove versioni su GitHub all'avvio e suggerisce l'aggiornamento.

### Correzioni e Manutenzione
- **Ottimizzazione CI/CD**: Risolti i problemi di formattazione e linting (parentesi graffe mancanti) che bloccavano la pipeline di test.
- **Affidabilità Workflow**: Migliorata la stabilità delle GitHub Actions e aggiunto il tasto "Run workflow" per test manuali.


## [2.7.0] - 27/03/2026

### Nuove Funzionalità
- **Visualizzazione Locandine**: Integrazione avanzata con `cached_network_image` per visualizzare i poster e le cover nativamente sull'app, sia dal server proxy di MyPlaylist sia tramite l'API `/art` di VLC.
- **Poster Zoom Interattivo**: Implementata la possibilità di toccare una locandina per vederla a tutto schermo con un'animazione di zoom fluida.


## [2.5.0] - 27/03/2026

### Nuove Funzionalità
- **Supporto VLC HTTP API**: Aggiunta la possibilità di comunicare con VLC tramite l'interfaccia HTTP. Questa modalità (che richiede la configurazione di una password per VLC nel server) è notevolmente più affidabile rispetto al vecchio metodo via Socket (RC string parsing), prevenendo errori di lettura della playlist e desincronizzazioni dello stato quando il titolo o il file video contengono caratteri speciali o formati non standard.

### Manutenzione e Stabilità
- **Fix Memory Leaks**: Risolti potenziali leak nei Timer di aggiornamento stato e nelle sottoscrizioni del socket.
- **Validazione IP Avanzata**: Implementata una validazione più robusta per indirizzi IP e porte nel dialogo di connessione (previene ottetti non validi o porte fuori range).
- **Pulizia Codice**: Rimossi campi inutilizzati e riferimenti deprecati in linea con le ultime analisi Flutter.
- **Material 3 Update**: Aggiornati i componenti UI che utilizzavano membri deprecati (es. `surfaceVariant` → `surfaceContainerHighest`).

## [2.4.0] - 26/03/2026

### Aggiunto
- **Kill VLC**: Aggiunta funzionalità per terminare forzatamente tutte le istanze di VLC (sia locali che remote tramite MyPlaylist).
- **Nuovo Bottone**: Inserito il comando di "Kill" sia nel dialogo delle Informazioni che nel pannello delle "Smart Actions".
- **Manutenzione**: Aggiunto supporto per comandi di sistema critici durante le sessioni di controllo.

## [2.3.0] - 2026-01-21

### Sincronizzazione
- **Compatibilità MyPlaylist v3.4.0**: Protocollo sincronizzato per supportare le ultime logiche di generazione playlist e filtri.
- **Miglioramento Serie TV**: Gestione metadati avanzata per serie ed episodi, inclusa una migliore visualizzazione dei badge nelle anteprime.

### Manutenzione
- Aggiornate le definizioni del protocollo interno per una maggiore stabilità durante le sessioni di controllo remoto.
- Miglioramenti generali delle prestazioni e sincronizzazione della documentazione.


### Sincronizzazione MyPlaylist (v3.0.0)
- **Filtri di Esclusione**: Aggiunto supporto per escludere generi e anni nella generazione della smart playlist.
- **Filtri Attori e Registi**: Nuovi campi di input per includere/escludere specifici attori e registi.
- **Anteprima Metadati Avanzati**: La playlist di anteprima ora mostra indicatori per le serie (icona TV e badge "SERIE") in linea con MyPlaylist v3.0.0.
- **Estensione Protocollo**: Aggiornato il protocollo di comunicazione per gestire metadati complessi e argomenti di filtro avanzati.

## [1.3.0] - 2025-12-23

### Performance ed Efficienza
- **Polling Ottimizzato**: Ridotto intervallo aggiornamenti stato da 500ms a 1000ms (-50% traffico di rete)
- **Ritardi Comandi**: Sostituiti ritardi hardcoded con costanti nominate (100ms/300ms)
- **Debouncing Volume**: Aggiunto debounce di 300ms per prevenire flooding di comandi durante l'uso dello slider
- **Debouncing Seek**: Implementato meccanismo di debounce per operazioni di seek

### Gestione Errori e Resilienza
- **Auto-Riconnessione**: Strategia exponential backoff (1s → 2s → 4s → 8s → 16s, max 5 tentativi)
- **Logica Retry**: 3 tentativi di retry per aggiornamenti stato prima di attivare riconnessione
- **Stabilità Migliorata**: Il timer di aggiornamento stato continua durante fallimenti temporanei

### Qualità del Codice
- **Costanti Centralizzate**: Tutti i magic numbers sostituiti con costanti nominate in `AppConstants`
- **Pulizia Risorse**: Corretto dispose dei timer di debounce
- **Manutenibilità**: Singola fonte di verità per tutte le configurazioni di timing

### Miglioramenti UX
- **Feedback Progresso**: Aggiornamenti progresso a 10 step durante riconnessione MyPlaylist
- **Messaggi Migliorati**: Messaggi di stato potenziati per maggiore consapevolezza utente

## [1.2.1] - 2025-12-21


- Aggiornamento documentazione e sincronizzazione versioni.
- Espanso il README inglese con la guida completa alle funzionalità e configurazione.

## [1.2.0] - 2025-12-14

### Aggiunto
- **Controlli UI Interattivi**: Sostituiti i display statici di volume e progresso con slider interattivi nel `ControlPanel`.
- **Accesso Playlist Riprogettato**: Spostata la playlist da un pannello sempre visibile a una vista modale separata (bottom sheet).
- **Nuovo Branding**: Nuova icona applicazione moderna applicata su tutte le piattaforme.
- **Now Playing Migliorato**: Rimozione barre ridondanti e miglioramento della chiarezza visiva.
- **Ottimizzazione**: Migliore reattività per aggiornamenti UI e seek.

## [1.1.0] - 2025-12-11
- Versione iniziale con funzionalità base di controllo VLC.
