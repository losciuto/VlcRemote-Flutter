# VLC Remote Flutter 🎵

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**Telecomando remoto moderno per VLC Media Player**

Un'applicazione Flutter cross-platform per controllare VLC Media Player da remoto tramite rete locale.

[Caratteristiche](#caratteristiche) • [Installazione](#installazione) • [Utilizzo](#utilizzo) • [Configurazione VLC](#configurazione-vlc) • [English Version](README_EN.md) • [Changelog](CHANGELOG_IT.md)

</div>

---

## 📱 Screenshot

*Coming soon...*

## ✨ Caratteristiche

### 🎯 Funzionalità Core
- ✅ **Controllo Completo**: Play, Pause, Stop, Avanti, Indietro
- ✅ **Gestione Volume**: Mappatura precisa 0-100% con sincronizzazione atomica
- ✅ **Seek Bar**: Navigazione temporale fluida con protezione dai salti
- ✅ **Fullscreen**: Toggle modalità schermo intero
- ✅ **Anteprima Playlist**: Visualizza i titoli della playlist generata prima di avviare la riproduzione (integrato con MyPlaylist)
- ✅ **Sincronizzazione Robusta**: Cancellazione echi del server per dati sempre accurati

### 🚀 Miglioramenti Rispetto all'Originale

#### 🎨 UI/UX Moderna
- **Material Design 3**: Design moderno e accattivante
- **Dark/Light Mode**: Supporto temi chiaro e scuro
- **Animazioni Fluide**: Transizioni e feedback visivi
- **Responsive**: Ottimizzato per phone, tablet e desktop

#### 💾 Gestione Connessioni
- **Connessioni Multiple**: Salva e gestisci più server VLC
- **Preferiti**: Marca le connessioni più usate
- **Auto-Reconnect**: Riconnessione automatica all'ultima connessione
- **Validazione Input**: Controlli di validità per IP e porta

#### 🔧 Architettura Migliorata
- **Provider Pattern**: State management con Provider
- **Servizi Separati**: Architettura modulare e manutenibile
- **Aggiornamenti Real-time**: Stato sincronizzato automaticamente
- **Error Handling**: Gestione errori robusta

### 🌍 Cross-Platform
- ✅ Android
- ✅ iOS
- ✅ Linux
- ✅ Windows
- ✅ macOS
- ✅ Web

---

## 📋 Requisiti

### Per l'App
- Flutter SDK >= 3.10.3
- Dart SDK >= 3.0.0

### Per VLC
- VLC Media Player installato sul computer
- Rete locale (stessa WiFi/LAN)

---

## 🚀 Installazione

### 1. Clona il Repository
```bash
git clone https://github.com/losciuto/vlcremote-flutter.git
cd vlcremote-flutter
```

### 2. Installa le Dipendenze
```bash
flutter pub get
```

### 3. Esegui l'App
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Linux
flutter run -d linux

# Windows
flutter run -d windows

# Web
flutter run -d chrome
```

---

## 🎮 Utilizzo

### 1. Configura VLC

Prima di utilizzare l'app, devi avviare VLC con l'interfaccia RC (Remote Control) abilitata:

#### Linux/macOS
```bash
vlc /path/to/playlist.m3u --intf rc --rc-host 0.0.0.0:8000
```

#### Windows
```cmd
"C:\Program Files\VideoLAN\VLC\vlc.exe" "C:\path\to\playlist.m3u" --intf rc --rc-host 0.0.0.0:8000
```

**Parametri:**
- `--intf rc`: Abilita l'interfaccia Remote Control
- `--rc-host 0.0.0.0:8000`: Ascolta su tutte le interfacce di rete sulla porta 8000

### 2. Trova l'Indirizzo IP del Computer

#### Linux
```bash
ip addr show | grep inet
```

#### macOS
```bash
ifconfig | grep inet
```

#### Windows
```cmd
ipconfig
```

Cerca l'indirizzo IP della tua rete locale (es. `192.168.1.15`)

### 3. Connetti l'App

1. Apri l'app VLC Remote
2. Tocca l'icona di connessione in alto a destra
3. Tocca "Nuova Connessione"
4. Inserisci:
   - **Nome**: Un nome descrittivo (es. "VLC Casa")
   - **IP**: L'indirizzo IP del computer (es. `192.168.1.15`)
   - **Porta**: La porta configurata (default: `8000`)
5. Tocca "Salva e Connetti"

### 4. Controlla VLC

Una volta connesso, puoi:
- ▶️ **Play/Pause/Stop**: Controlla la riproduzione
- ⏮️⏭️ **Prev/Next**: Naviga tra i brani
- 🔊 **Volume**: Aumenta/Diminuisci il volume
- 🖥️ **Fullscreen**: Attiva/Disattiva schermo intero
- 📊 **Seek**: Scorri la timeline del video
- 📝 **Playlist**: Visualizza e seleziona i brani (in sviluppo)

---

## 🔧 Configurazione VLC

### Configurazione Permanente

Per evitare di dover avviare VLC da terminale ogni volta, puoi creare uno script:

#### Linux/macOS
Crea un file `vlc-remote.sh`:
```bash
#!/bin/bash
vlc /path/to/your/playlist.m3u --intf rc --rc-host 0.0.0.0:8000
```

Rendilo eseguibile:
```bash
chmod +x vlc-remote.sh
```

#### Windows
Crea un file `vlc-remote.bat`:
```batch
@echo off
"C:\Program Files\VideoLAN\VLC\vlc.exe" "C:\path\to\playlist.m3u" --intf rc --rc-host 0.0.0.0:8000
```

### Porta Personalizzata

Se la porta 8000 è già in uso, puoi cambiarla:
```bash
vlc playlist.m3u --intf rc --rc-host 0.0.0.0:9000
```

Ricorda di usare la stessa porta nell'app!

---

## 🏗️ Architettura

```
lib/
├── main.dart                 # Entry point
├── models/                   # Modelli dati
│   ├── vlc_connection.dart
│   ├── vlc_status.dart
│   └── playlist_item.dart
├── services/                 # Servizi business logic
│   ├── vlc_service.dart
│   └── connection_service.dart
├── providers/                # State management
│   └── vlc_provider.dart
├── screens/                  # Schermate
│   └── home_screen.dart
└── widgets/                  # Widget riutilizzabili
    ├── connection_dialog.dart
    ├── control_panel.dart
    ├── now_playing_card.dart
    └── playlist_panel.dart
```

### Pattern Utilizzati
- **Provider**: State management reattivo
- **Service Layer**: Separazione logica di business
- **Repository Pattern**: Gestione dati persistenti

---

## 🛠️ Sviluppo

### Build Release

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle
```bash
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### Linux
```bash
flutter build linux --release
```

#### Windows
```bash
flutter build windows --release
```

### Testing
```bash
flutter test
```

### Analisi Codice
```bash
flutter analyze
```

---

## 📦 Dipendenze Principali

- **provider**: State management
- **shared_preferences**: Storage locale
- **http**: Comunicazione di rete (future)
- **network_info_plus**: Informazioni rete
- **intl**: Internazionalizzazione

---

## 🗺️ Roadmap

### Versione 1.1
- [ ] Implementazione completa gestione playlist
- [ ] Auto-discovery VLC sulla rete locale
- [ ] Supporto HTTP API di VLC
- [ ] Widget per controllo rapido

### Versione 1.2
- [ ] Supporto multi-lingua (IT, EN, ES, FR, DE)
- [ ] Temi personalizzabili
- [ ] Gesture controls (swipe per volume/seek)
- [ ] Notifiche per cambio brano

### Versione 2.0
- [ ] Streaming audio/video
- [ ] Equalizzatore
- [ ] Sottotitoli
- [ ] Chromecast support

---

## 🤝 Contribuire

I contributi sono benvenuti! Per favore:

1. Fai un Fork del progetto
2. Crea un branch per la tua feature (`git checkout -b feature/AmazingFeature`)
3. Commit le tue modifiche (`git commit -m 'Add some AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

---

## 📄 Licenza

Questo progetto è rilasciato sotto licenza MIT. Vedi il file `LICENSE` per i dettagli.

---

## 👨‍💻 Autore

**losciuto**

- Versione originale Android: [losciuto/vlcremote](https://github.com/losciuto/vlcremote)
- Versione Flutter: 1.3.0 (Dicembre 2025)

---

## 🙏 Ringraziamenti

- VLC Media Player team per l'eccellente media player
- Flutter team per il fantastico framework
- Comunità open source per il supporto

---

## 📞 Supporto

Se incontri problemi:

1. Controlla la [sezione Configurazione VLC](#configurazione-vlc)
2. Verifica che VLC sia in ascolto sulla porta corretta
3. Assicurati di essere sulla stessa rete
4. Apri una [Issue](https://github.com/losciuto/vlcremote-flutter/issues)

---

<div align="center">

**Fatto con ❤️ e Flutter**

⭐ Se ti piace questo progetto, lascia una stella!

</div>
