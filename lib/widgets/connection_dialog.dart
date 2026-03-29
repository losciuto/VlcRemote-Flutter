import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vlc_connection.dart';
import '../providers/vlc_provider.dart';

class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController(text: '192.168.1.15');
  final _portController = TextEditingController(text: '8000');
  final _vlcPasswordController = TextEditingController();

  // MyPlaylist controllers
  final _mpIpController = TextEditingController();
  final _mpPortController = TextEditingController(text: '8080');
  final _mpSecretKeyController = TextEditingController(
    text: 'my_default_secret_key_32chars_long',
  );

  bool _showNewConnectionForm = false;
  VlcConnection? _editingConnection;
  bool _isPasswordVisible = false;
  List<VlcConnection> _savedConnections = [];
  // ...
  void _editConnection(VlcConnection connection) {
    setState(() {
      _editingConnection = connection;
      _showNewConnectionForm = true;
      _nameController.text = connection.name;
      _ipController.text = connection.ipAddress;
      _portController.text = connection.port.toString();
      _vlcPasswordController.text = connection.vlcPassword ?? '';
      _mpIpController.text = connection.myPlaylistIp ?? '';
      _mpPortController.text = (connection.myPlaylistPort ?? 8080).toString();
      _mpSecretKeyController.text = connection.myPlaylistSecretKey ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedConnections();
  }

  Future<void> _loadSavedConnections() async {
    final provider = context.read<VlcProvider>();
    final connections = await provider.getSavedConnections();
    setState(() {
      _savedConnections = connections;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _vlcPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_input_antenna,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gestione Server VLC',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (!_showNewConnectionForm) ...[
              // Lista connessioni salvate
              if (_savedConnections.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun server salvato',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _savedConnections.length,
                    itemBuilder: (context, index) {
                      final connection = _savedConnections[index];
                      return _buildConnectionTile(connection);
                    },
                  ),
                ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showNewConnectionForm = true;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuovo Server VLC'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              // Form nuova connessione
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nome Server',
                            hintText: 'es. VLC Casa',
                            prefixIcon: const Icon(Icons.label_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci un nome';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _ipController,
                          decoration: InputDecoration(
                            labelText: 'Indirizzo IP',
                            hintText: '192.168.1.15',
                            prefixIcon: const Icon(Icons.computer),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci un indirizzo IP';
                            }
                            // Validazione IP semplice
                            final parts = value.split('.');
                            if (parts.length != 4) {
                              return 'Indirizzo IP non valido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _portController,
                          decoration: InputDecoration(
                            labelText: 'Porta VLC',
                            hintText: '8000',
                            prefixIcon: const Icon(Icons.settings_ethernet),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci una porta';
                            }
                            final port = int.tryParse(value);
                            if (port == null || port < 1 || port > 65535) {
                              return 'Porta non valida (1-65535)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _vlcPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Password VLC (per HTTP API)',
                            hintText: 'Richiesta per widget e playlist stabili',
                            prefixIcon: const Icon(Icons.password),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),

                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'Configurazione MyPlaylist (Opzionale)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _mpIpController,
                          decoration: InputDecoration(
                            labelText: 'Indirizzo IP MyPlaylist',
                            hintText: '192.168.1.15',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _mpPortController,
                                decoration: InputDecoration(
                                  labelText: 'Porta MP',
                                  hintText: '8080',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 7,
                              child: TextFormField(
                                controller: _mpSecretKeyController,
                                decoration: InputDecoration(
                                  labelText: 'Secret Key (32 char)',
                                  prefixIcon: const Icon(Icons.key),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(
                                      () => _isPasswordVisible =
                                          !_isPasswordVisible,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: !_isPasswordVisible,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _showNewConnectionForm = false;
                                    _editingConnection = null;
                                    _nameController.clear();
                                    _ipController.text = '192.168.1.15';
                                    _portController.text = '8000';
                                    _vlcPasswordController.clear();
                                    _mpIpController.clear();
                                    _mpPortController.text = '8080';
                                    _mpSecretKeyController.text =
                                        'my_default_secret_key_32chars_long';
                                  });
                                },
                                child: const Text('Annulla'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveAndConnect,
                                child: Text(
                                  _editingConnection != null
                                      ? 'Salva Modifiche'
                                      : 'Salva e Connetti',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTile(VlcConnection connection) {
    final bool isSelected =
        context.watch<VlcProvider>().currentConnection?.id == connection.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _connectTo(connection),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.computer,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connection.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'VLC: ${connection.ipAddress}:${connection.port}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (connection.myPlaylistIp != null)
                          Text(
                            'MP: ${connection.myPlaylistIp}:${connection.myPlaylistPort ?? 8080}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildSmallActionBtn(
                    icon: connection.isFavorite
                        ? Icons.star
                        : Icons.star_border,
                    color: connection.isFavorite ? Colors.amber : Colors.grey,
                    onPressed: () async {
                      final provider = context.read<VlcProvider>();
                      await provider.toggleFavorite(connection.id);
                      await _loadSavedConnections();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildSmallActionBtn(
                    icon: Icons.edit_outlined,
                    color: Colors.blue,
                    onPressed: () => _editConnection(connection),
                  ),
                  const SizedBox(width: 8),
                  _buildSmallActionBtn(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onPressed: () => _deleteConnection(connection),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallActionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Future<void> _saveAndConnect() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validazione IP
    final ip = _ipController.text.trim();
    if (!_validateIpAddress(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indirizzo IP non valido. Formato: 192.168.1.1'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validazione Porta
    final portStr = _portController.text.trim();
    if (!_validatePort(portStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Porta non valida. Deve essere tra 1 e 65535'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final connection = VlcConnection(
      id:
          _editingConnection?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      ipAddress: ip,
      port: int.parse(portStr),
      lastUsed: DateTime.now(),
      isFavorite: _editingConnection?.isFavorite ?? false,
      vlcPassword: _vlcPasswordController.text.trim().isNotEmpty
          ? _vlcPasswordController.text.trim()
          : null,
      myPlaylistIp: _mpIpController.text.trim().isNotEmpty
          ? _mpIpController.text.trim()
          : null,
      myPlaylistPort: int.tryParse(_mpPortController.text.trim()),
      myPlaylistSecretKey: _mpSecretKeyController.text.trim().isNotEmpty
          ? _mpSecretKeyController.text.trim()
          : null,
    );

    final provider = context.read<VlcProvider>();
    await provider.saveConnection(connection);

    if (mounted) {
      await _connectTo(connection);
    }
  }

  Future<void> _connectTo(VlcConnection connection) async {
    final provider = context.read<VlcProvider>();

    // Mostra un indicatore di caricamento e chiudi il dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    final success = await provider.connect(connection);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connesso con successo a ${connection.name}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossibile connettersi a ${connection.name} (${connection.ipAddress})',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Riprova',
              textColor: Colors.white,
              onPressed: () => _connectTo(connection),
            ),
          ),
        );
      }
    }
  }

  bool _validateIpAddress(String ip) {
    // IpPattern gestisce il formato base (X.X.X.X)
    final ipPattern = RegExp(r'^([0-9]{1,3}\.){3}[0-9]{1,3}$');
    if (!ipPattern.hasMatch(ip)) {
      return false;
    }

    // Controllo manuale di ogni octetto per valori 0-255 e assenza di leading zero non validi (es. 01)
    final octets = ip.split('.');
    for (final octet in octets) {
      if (octet.isEmpty) return false;
      if (octet.length > 1 && octet.startsWith('0')) {
        return false; // "01" non è valido
      }

      final value = int.tryParse(octet);
      if (value == null || value < 0 || value > 255) {
        return false;
      }
    }
    return true;
  }

  bool _validatePort(String port) {
    if (port.isEmpty) return false;
    final portValue = int.tryParse(port);
    return portValue != null && portValue > 0 && portValue <= 65535;
  }

  Future<void> _deleteConnection(VlcConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Server VLC'),
        content: Text('Vuoi eliminare "${connection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<VlcProvider>();
      await provider.deleteConnection(connection.id);
      if (mounted) {
        await _loadSavedConnections();
      }
    }
  }
}
