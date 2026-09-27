import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vlc_remote_flutter/constants/app_constants.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/widgets/connections/connection_form.dart';
import 'package:vlc_remote_flutter/widgets/connections/connection_list.dart';

/// Gestione dei server VLC: elenco dei server salvati, oppure modulo per
/// aggiungerne o modificarne uno.
///
/// Il dialogo tiene i sette controller perche' sopravvivono al passaggio fra
/// elenco e modulo: e' lui che decide quando sono finiti e chi li distrugge.
/// I due schermi sono in file separati, e' [_ConnectionList] e
/// [ConnectionForm].
class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  static const _indirizzoDiDefault = '192.168.1.15';
  static const _chiaveDiDefault = 'my_default_secret_key_32chars_long';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController(text: _indirizzoDiDefault);
  final _portController = TextEditingController(
    text: '${AppConstants.defaultVlcHttpPort}',
  );
  final _vlcPasswordController = TextEditingController();

  // MyPlaylist controllers
  final _mpIpController = TextEditingController();
  final _mpPortController = TextEditingController(
    text: '${AppConstants.defaultMyPlaylistPort}',
  );
  final _mpSecretKeyController = TextEditingController(text: _chiaveDiDefault);

  bool _showNewConnectionForm = false;
  VlcConnection? _editingConnection;
  List<VlcConnection> _savedConnections = [];

  @override
  void initState() {
    super.initState();
    _loadSavedConnections();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _vlcPasswordController.dispose();

    // Anche i tre campi di MyPlaylist vanno distrutti: trattenerli lasciava
    // vivo un listener per ogni controller a ogni apertura del dialogo. Il
    // segreto di MyPlaylist e' il piu' sensibile dei tre, ma il problema non
    // e' la privacy: e' che le tre righe mancanti rendevano il dispose
    // incompleto e nessuno se ne accorgeva.

    _mpIpController.dispose();
    _mpPortController.dispose();
    _mpSecretKeyController.dispose();

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
            _intestazione(context),
            const SizedBox(height: 24),
            Expanded(child: _showNewConnectionForm ? _modulo() : _elenco()),
          ],
        ),
      ),
    );
  }

  Widget _intestazione(BuildContext context) {
    return Row(
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
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Chiudi',
        ),
      ],
    );
  }

  Widget _elenco() {
    return ConnectionList(
      connections: _savedConnections,
      selectedConnectionId: context.watch<VlcProvider>().currentConnection?.id,
      onConnect: _connectTo,
      onToggleFavorite: _toggleFavorite,
      onEdit: _editConnection,
      onDelete: _deleteConnection,
      onAddNew: () => setState(() => _showNewConnectionForm = true),
    );
  }

  Widget _modulo() {
    return ConnectionForm(
      formKey: _formKey,
      nameController: _nameController,
      ipController: _ipController,
      portController: _portController,
      vlcPasswordController: _vlcPasswordController,
      myPlaylistIpController: _mpIpController,
      myPlaylistPortController: _mpPortController,
      myPlaylistSecretKeyController: _mpSecretKeyController,
      isEditing: _editingConnection != null,
      onCancel: _resetToList,
      onSave: _saveAndConnect,
    );
  }

  void _editConnection(VlcConnection connection) {
    setState(() {
      _editingConnection = connection;
      _showNewConnectionForm = true;
      _nameController.text = connection.name;
      _ipController.text = connection.ipAddress;
      _portController.text = connection.port.toString();
      _vlcPasswordController.text = connection.vlcPassword ?? '';
      _mpIpController.text = connection.myPlaylistIp ?? '';
      _mpPortController.text =
          (connection.myPlaylistPort ?? AppConstants.defaultMyPlaylistPort)
              .toString();
      _mpSecretKeyController.text = connection.myPlaylistSecretKey ?? '';
    });
  }

  /// Torna all'elenco e rimette i campi ai valori di partenza.
  ///
  /// Azzerare i campi serve a qualcosa di preciso: senza, modificando un
  /// server e poi premendo "Annulla", riaprendo quel server i campi mostrano
  /// quello dell'ultimo tentativo invece dei suoi.
  void _resetToList() {
    setState(() {
      _showNewConnectionForm = false;
      _editingConnection = null;
      _nameController.clear();
      _ipController.text = _indirizzoDiDefault;
      _portController.text = '${AppConstants.defaultVlcHttpPort}';
      _vlcPasswordController.clear();
      _mpIpController.clear();
      _mpPortController.text = '${AppConstants.defaultMyPlaylistPort}';
      _mpSecretKeyController.text = _chiaveDiDefault;
    });
  }

  Future<void> _loadSavedConnections() async {
    final provider = context.read<VlcProvider>();
    final connections = await provider.getSavedConnections();
    if (!mounted) return;
    setState(() {
      _savedConnections = connections;
    });
  }

  Future<void> _toggleFavorite(VlcConnection connection) async {
    final provider = context.read<VlcProvider>();
    await provider.toggleFavorite(connection.id);
    await _loadSavedConnections();
  }

  /// Non ricontrolla nulla: [ConnectionForm] ha gia' validato i campi prima di
  /// arrivare qui, e il dialogo non ne ha uno da cui controllare. Per questo
  /// `port` e' un `int.parse` e non un `int.tryParse` con un fallback: un
  /// valore non numerico qui non puo' arrivarci, perche' il campo lo ha gia'
  /// respinto con un messaggio accanto al campo stesso.
  Future<void> _saveAndConnect() async {
    final connection = VlcConnection(
      id:
          _editingConnection?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      ipAddress: _ipController.text.trim(),
      port: int.parse(_portController.text.trim()),
      lastUsed: DateTime.now(),
      isFavorite: _editingConnection?.isFavorite ?? false,
      vlcPassword: _testoOppureNull(_vlcPasswordController),
      myPlaylistIp: _testoOppureNull(_mpIpController),
      myPlaylistPort: int.tryParse(_mpPortController.text.trim()),
      myPlaylistSecretKey: _testoOppureNull(_mpSecretKeyController),
    );

    final provider = context.read<VlcProvider>();
    await provider.saveConnection(connection);

    if (mounted) {
      await _connectTo(connection);
    }
  }

  /// Il campo vuoto in [VlcConnection] vuol dire "non configurato", ed e'
  /// diverso dal campo vuoto in un controller, che vuol dire "non scritto".
  String? _testoOppureNull(TextEditingController controller) {
    final testo = controller.text.trim();
    return testo.isNotEmpty ? testo : null;
  }

  Future<void> _connectTo(VlcConnection connection) async {
    final provider = context.read<VlcProvider>();

    // Chiude il dialogo subito: la connessione puo' mettere qualche secondo,
    // e tenere aperto il dialogo intanto mostrerebbe una lista che non
    /// reagisce a nulla.
    if (mounted) {
      Navigator.of(context).pop();
    }

    final success = await provider.connect(connection);

    if (!mounted) return;
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
