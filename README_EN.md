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
- ✅ **Playlist Preview**: View generated playlist titles before starting playback (integrated with MyPlaylist)
- ✅ **Robust Sync**: Server echo cancellation for consistently accurate data

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
- ✅ Web

---

## 📋 Requirements

### For the App
- Flutter SDK >= 3.10.3
- Dart SDK >= 3.0.0

### For VLC
- VLC Media Player installed on the computer
- Local network (same WiFi/LAN)

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
│   └── connection_service.dart
├── providers/                # State management
│   └── vlc_provider.dart
├── screens/                  # Screens
│   └── home_screen.dart
└── widgets/                  # Reusable widgets
    ├── connection_dialog.dart
    ├── control_panel.dart
    ├── now_playing_card.dart
    └── playlist_panel.dart
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

---

## 📄 License
This project is released under the MIT License. See `LICENSE` for details.

---

## 👨‍💻 Author
**losciuto**
- Version: 2.2.0 (January 2026)

---

<div align="center">

**Made with ❤️ and Flutter**

⭐ If you like this project, leave a star!

</div>
