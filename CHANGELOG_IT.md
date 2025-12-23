# Changelog

Tutti i cambiamenti significativi a questo progetto saranno documentati in questo file.


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
