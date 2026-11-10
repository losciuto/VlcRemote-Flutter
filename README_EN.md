# VLC Remote Flutter 🎵

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**Modern Remote Control for VLC Media Player**

A cross-platform Flutter application to control VLC Media Player remotely over your local network.

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [VLC Configuration](#vlc-configuration)

</div>

---

## 📱 Screenshots

*Coming soon...*

## ✨ Features

### 🎯 Core Functionality
- ✅ **Full Control**: Play, Pause, Stop, Forward, Backward
- ✅ **Volume Management**: Precise 0-100% mapping with atomic synchronization
- ✅ **Seek Bar**: Smooth temporal navigation with jump protection
- ✅ **Fullscreen**: Toggle fullscreen mode
- ✅ **Kill VLC**: Force-stop all VLC instances (local and remote)
- ✅ **Playlist Preview**: View generated playlist titles before starting playback (integrated with MyPlaylist)
- ✅ **Robust Sync**: Server echo cancellation for consistently accurate data
- ✅ **Offline Voice Commands**: Control VLC and playlists by voice, with on-device recognition (Vosk): the audio never leaves the device

### 🚀 Improvements Over Original
#### 🎨 Modern UI/UX
- **Material Design 3**: Modern and attractive design
- **Dark/Light Mode**: Support for light and dark themes
- **Smooth Animations**: Visual feedback and transitions
- **Responsive**: Optimized for phone, tablet, and desktop

#### 💾 Connection Management
- **Multiple Connections**: Save and manage multiple VLC servers
- **Favorites**: Mark frequently used connections
- **Auto-Reconnect**: Automatically reconnects to the last used connection
- **Input Validation**: Validity checks for IP and port

#### 🔧 Improved Architecture
- **Provider Pattern**: Reactive state management with Provider
- **Service Layer**: Modular and maintainable architecture
- **Real-time Updates**: Automatically synchronized status
- **Error Handling**: Robust error management

### 🌍 Cross-Platform
- ✅ Android
- ✅ iOS
- ✅ Linux
- ✅ Windows
- ✅ macOS

The **web build is not supported** and never has been: the app talks to VLC and
to MyPlaylist over raw TCP sockets, which the browser does not have. Making it
work would mean rewriting the MyPlaylist server side over WebSocket, changing
the protocol and invalidating the clients already installed: not something
that can be done from this app. The `web/` folder stays in the repository
because `flutter create` generates it and it does no harm, but
`flutter build web` produces nothing usable.

---

## 📋 Requirements

### For the App
- Flutter SDK >= 3.10.3
- Dart SDK >= 3.0.0

### For VLC
- VLC Media Player installed on the computer
- Local network (same WiFi/LAN)

### For voice commands (optional)
- A **microphone** accessible to the system (on Linux the user needs access to
  PipeWire/PulseAudio)
- About **40-50 MiB** of space for the Vosk model, downloaded on first use
- On Android the app asks for the audio recording permission: it is optional,
  so the app stays installable on devices without a microphone

---

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/losciuto/vlcremote-flutter.git
cd vlcremote-flutter
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
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

## 🎮 Usage

### 1. Configure VLC
Launch VLC with the RC (Remote Control) interface enabled:

#### Linux/macOS
```bash
vlc /path/to/playlist.m3u --intf rc --rc-host 0.0.0.0:8000
```

#### Windows
```cmd
"C:\Program Files\VideoLAN\VLC\vlc.exe" "C:\path\to\playlist.m3u" --intf rc --rc-host 0.0.0.0:8000
```

**Parameters:**
- `--intf rc`: Enables the Remote Control interface
- `--rc-host 0.0.0.0:8000`: Listens on all network interfaces on port 8000

### 2. Find Your Computer's IP Address
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
Look for your local network IP (e.g., `192.168.1.15`)

### 3. Connect the App
1. Open the VLC Remote app
2. Tap the connection icon in the top right
3. Tap "New Connection"
4. Enter:
   - **Name**: A descriptive name (e.g., "Home VLC")
   - **IP**: Computer's IP address (e.g., `192.168.1.15`)
   - **Port**: Configured port (default: `8000`)
5. Tap "Save and Connect"

### 4. Control VLC
Once connected, you can:
- ▶️ **Play/Pause/Stop**: Control playback
- ⏮️⏭️ **Prev/Next**: Navigate tracks
- 🔊 **Volume**: Increase/Decrease volume
- 🖥️ **Fullscreen**: Toggle fullscreen
- 📊 **Seek**: Scroll through the video timeline
- 📝 **Playlist**: View and select tracks (in development)

### 5. Voice commands

The microphone icon in the top bar opens the voice commands panel.

1. On first use the panel **downloads the Vosk model** for the selected
   language (Italian or English, about 40-50 MiB). The model stays on the
   device and is not downloaded again.
2. Press the microphone button to start listening: the panel shows the input
   audio level, so it is immediately visible whether the microphone is
   capturing anything.
3. Speak, and the command is executed; the outcome is listed in the history at
   the bottom of the panel.

The recognized commands are play, pause, stop, next and previous track,
volume (up, down, numeric value), seeking forward and backward by N seconds,
and the three playlist actions of MyPlaylist (random list, recent list, play
the current list).

Recognition is **keyword based**, not natural language: "raise the volume" is
recognized, "could you raise the volume a bit" is not. The full catalogue is
listed inside the panel and in
[`docs/VOICE_COMMANDS.md`](docs/VOICE_COMMANDS.md).

| Platform | Voice commands |
|---|---|
| Linux, Android, Windows | supported |
| macOS | not supported: the Vosk plugin does not expose the native interface |

Audio is recognized **on-device**: nothing is sent to an external service. The
only network access is the model download, on first use.

---

## 🔧 VLC Configuration

### Permanent Configuration
To avoid starting VLC from the terminal every time, you can create a script:

#### Linux/macOS
Create a `vlc-remote.sh` file:
```bash
#!/bin/bash
vlc /path/to/your/playlist.m3u --intf rc --rc-host 0.0.0.0:8000
```
Make it executable:
```bash
chmod +x vlc-remote.sh
```

#### Windows
Create a `vlc-remote.bat` file:
```batch
@echo off
"C:\Program Files\VideoLAN\VLC\vlc.exe" "C:\path\to\playlist.m3u" --intf rc --rc-host 0.0.0.0:8000
```

---

## 🏗️ Architecture
```
lib/
├── main.dart                 # Entry point
├── models/                   # Data models
│   ├── vlc_connection.dart
│   ├── vlc_status.dart
│   └── playlist_item.dart
├── services/                 # Business logic services
│   ├── vlc_service.dart
│   ├── connection_service.dart
│   └── voice/                # Offline voice commands (Vosk)
│       ├── voice_language.dart
│       ├── voice_command.dart
│       ├── voice_command_parser.dart
│       ├── voice_command_service.dart
│       └── voice_command_executor.dart
├── providers/                # State management
│   └── vlc_provider.dart
├── screens/                  # Screens
│   └── home_screen.dart
└── widgets/                  # Reusable widgets
    ├── connection_dialog.dart
    ├── control_panel.dart
    ├── now_playing_card.dart
    ├── playlist_panel.dart
    └── voice_panel.dart
```

---

## 🛠️ Development

### Build Release
#### Android APK
```bash
flutter build apk --release
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

The voice commands integration test needs a device (or a graphical session) and
runs separately:
```bash
flutter test integration_test/voice_panel_test.dart -d linux
```

---

## 📄 License
This project is released under the MIT License. See `LICENSE` for details.

---

## 👨‍💻 Author
**losciuto**
- Version: 2.9.0 (10/11/2026)

---

<div align="center">

**Made with ❤️ and Flutter**

⭐ If you like this project, leave a star!

</div>
