# 🔧 FIXES PER BUG CRITICI

## Fix 1: Memory Leak Timer

**File:** `lib/providers/vlc_provider.dart`  
**Linea:** 89

**Codice attuale (BUGGY):**
```dart
void _startStatusUpdates() {
  _stopStatusUpdates();
  _statusUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
    if (_vlcService.isConnected) {
      await _updateStatus();
    } else {
      _stopStatusUpdates();
    }
  });
}
```

**Problema:** Se `_vlcService.isConnected` diventa false tra iterazioni, il timer continua a girarsi inutilmente.

**Fix proposto:**
```dart
void _startStatusUpdates() {
  _stopStatusUpdates();
  _statusUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
    if (!_vlcService.isConnected) {
      timer.cancel();
      _statusUpdateTimer = null;
      return;
    }
    try {
      await _updateStatus();
    } catch (e) {
      print('Errore aggiornamento stato: $e');
      timer.cancel();
      _statusUpdateTimer = null;
    }
  });
}
```

---

## Fix 2: StreamSubscription Leak

**File:** `lib/services/vlc_service.dart`  
**Linea:** 82

**Codice attuale (BUGGY):**
```dart
Future<void> disconnect() async {
  try {
    await _socketSubscription?.cancel();  // Potrebbe fallire
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _isConnected = false;
    _currentHost = null;
    _currentPort = null;
  } catch (e) {
    print('Errore durante la disconnessione: $e');
  }
}
```

**Problema:** Se `_socket` è già chiuso, `await _socket?.close()` può lanciare eccezione.

**Fix proposto:**
```dart
Future<void> disconnect() async {
  try {
    _isConnected = false;
    
    // Cancella subscription
    try {
      await _socketSubscription?.cancel();
    } catch (e) {
      print('Errore cancellazione subscription: $e');
    }
    _socketSubscription = null;
    
    // Chiudi socket
    try {
      _socket?.destroySink();
      await _socket?.close();
    } catch (e) {
      print('Errore chiusura socket: $e');
    }
    _socket = null;
    
    _currentHost = null;
    _currentPort = null;
  } catch (e) {
    print('Errore durante la disconnessione: $e');
  }
}
```

---

## Fix 3: Validazione IP Address

**File:** `lib/widgets/connection_dialog.dart`  
**Linea:** 200+ (metodo `_connectAndSave()`)

**Codice proposto:**
```dart
bool _validateIpAddress(String ip) {
  final ipPattern = RegExp(
    r'^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  );
  
  if (!ipPattern.hasMatch(ip)) {
    return false;
  }
  
  // Verifica che ogni octetto sia 0-255
  final octets = ip.split('.');
  for (final octet in octets) {
    final value = int.tryParse(octet);
    if (value == null || value > 255) {
      return false;
    }
  }
  
  return true;
}

bool _validatePort(String port) {
  final portValue = int.tryParse(port);
  return portValue != null && portValue > 0 && portValue < 65536;
}

Future<void> _connectAndSave() async {
  final ip = _ipController.text;
  final port = _portController.text;
  
  if (!_validateIpAddress(ip)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Indirizzo IP non valido'))
    );
    return;
  }
  
  if (!_validatePort(port)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Porta non valida (1-65535)'))
    );
    return;
  }
  
  // Continua con la connessione
}
```

---

## Fix 4: Playlist Loading Improvement

**File:** `lib/services/vlc_service.dart`  
**Linea:** 245

**Miglioramento proposto:**
```dart
Future<List<PlaylistItem>> getPlaylist() async {
  try {
    final playlistItems = <PlaylistItem>[];
    if (!_isConnected || _socket == null) return [];

    _socket!.write('playlist\n');
    await _socket!.flush();

    final buffer = StringBuffer();
    final startTime = DateTime.now();
    final completer = Completer<String>();
    StreamSubscription<List<int>>? sub;

    sub = _socket!.listen(
      (data) {
        buffer.write(utf8.decode(data));
        
        final content = buffer.toString();
        if (content.contains('>') || 
            content.endsWith('\n>') ||
            DateTime.now().difference(startTime).inMilliseconds > 800) {
          sub?.cancel();
          if (!completer.isCompleted) {
            completer.complete(content);
          }
        }
      },
      onError: (_) {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
      onDone: () {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
    );

    final response = await completer.future
        .timeout(const Duration(milliseconds: 1000))
        .catchError((_) => buffer.toString());

    // Pattern migliorato per catturare elementi
    int itemIndex = 0;
    final lines = response.split('\n');
    
    for (final line in lines) {
      // Formato VLC: "| |-- numero. titolo" o varianti
      if (line.contains('--') && !line.contains('index') && !line.contains('Playlist')) {
        final parts = line.split('--');
        if (parts.length > 1) {
          var titlePart = parts.last.trim();
          
          // Rimuovi numero iniziale
          titlePart = titlePart.replaceFirst(RegExp(r'^\d+\.\s*'), '');
          
          // Rimuovi info tra parentesi
          titlePart = titlePart.replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '').trim();
          
          if (titlePart.isNotEmpty && 
              !titlePart.contains('index') && 
              !titlePart.contains('Playlist') &&
              !playlistItems.any((item) => item.title == titlePart)) {
            
            playlistItems.add(
              PlaylistItem(
                index: itemIndex,
                title: titlePart,
                duration: null,
              ),
            );
            itemIndex++;
          }
        }
      }
    }

    print('[VlcService] Playlist caricata: ${playlistItems.length} elementi');
    return playlistItems;
  } catch (e) {
    print('[VlcService] Errore durante getPlaylist: $e');
    return [];
  }
}
```

---

## 🚀 IMPLEMENTAZIONE

Per implementare questi fix:

1. **Copiate il codice dai fix sopra**
2. **Sostituite il codice vecchio** nei file indicati
3. **Testate completamente** con VLC
4. **Committate con messaggio:**
   ```
   fix: risolvi memory leaks e validazione input
   
   - Fisso memory leak in Timer (issue #1)
   - Fisso StreamSubscription leak (issue #2)
   - Aggiungi validazione IP (issue #3)
   - Migliora parsing playlist (issue #4)
   ```

