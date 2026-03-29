# Changelog

Tutti i cambiamenti significativi a questo progetto saranno documentati in questo file.


## [2.7.3] - 2026-03-29

### Nuove Funzionalità
- **Trigger Release Manuale**: Aggiunta la possibilità di avviare il build e la creazione della release direttamente dalla UI di GitHub via `workflow_dispatch`, con inserimento manuale della versione.
- **Controllo Aggiornamenti Automatico**: L'app ora verifica automaticamente la presenza di nuove versioni su GitHub all'avvio e suggerisce l'aggiornamento.

### Correzioni e Manutenzione
- **Ottimizzazione CI/CD**: Risolti i problemi di formattazione e linting (parentesi graffe mancanti) che bloccavano la pipeline di test.
- **Affidabilità Workflow**: Migliorata la stabilità delle GitHub Actions e aggiunto il tasto "Run workflow" per test manuali.


## [2.7.0] - 2026-03-27

### Nuove Funzionalità
- **Visualizzazione Locandine**: Integrazione avanzata con `cached_network_image` per visualizzare i poster e le cover nativamente sull'app, sia dal server proxy di MyPlaylist sia tramite l'API `/art` di VLC.
- **Poster Zoom Interattivo**: Implementata la possibilità di toccare una locandina per vederla a tutto schermo con un'animazione di zoom fluida.


## [2.5.0] - 2026-03-27

### Nuove Funzionalità
- **Supporto VLC HTTP API**: Aggiunta la possibilità di comunicare con VLC tramite l'interfaccia HTTP. Questa modalità (che richiede la configurazione di una password per VLC nel server) è notevolmente più affidabile rispetto al vecchio metodo via Socket (RC string parsing), prevenendo errori di lettura della playlist e desincronizzazioni dello stato quando il titolo o il file video contengono caratteri speciali o formati non standard.

### Manutenzione e Stabilità
- **Fix Memory Leaks**: Risolti potenziali leak nei Timer di aggiornamento stato e nelle sottoscrizioni del socket.
- **Validazione IP Avanzata**: Implementata una validazione più robusta per indirizzi IP e porte nel dialogo di connessione (previene ottetti non validi o porte fuori range).
- **Pulizia Codice**: Rimossi campi inutilizzati e riferimenti deprecati in linea con le ultime analisi Flutter.
- **Material 3 Update**: Aggiornati i componenti UI che utilizzavano membri deprecati (es. `surfaceVariant` → `surfaceContainerHighest`).

## [2.4.0] - 2026-03-26

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
