import 'package:flutter/material.dart';
import 'package:vlc_remote_flutter/constants/app_constants.dart';
import 'package:vlc_remote_flutter/utils/validators.dart';

/// Modulo per inserire o modificare un server.
///
/// I sette controller restano del dialogo che apre questo modulo: il modulo
/// li usa, non li possiede. Il dialogo conserva la lista dei server che si
/// sta modificando, quindi i controller devono sopravvivere al passaggio fra
/// elenco e modulo e venir distrutti una volta sola, quando il dialogo chiude.
class ConnectionForm extends StatefulWidget {
  const ConnectionForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.ipController,
    required this.portController,
    required this.vlcPasswordController,
    required this.myPlaylistIpController,
    required this.myPlaylistPortController,
    required this.myPlaylistSecretKeyController,
    required this.isEditing,
    required this.onCancel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController nameController;
  final TextEditingController ipController;
  final TextEditingController portController;
  final TextEditingController vlcPasswordController;
  final TextEditingController myPlaylistIpController;
  final TextEditingController myPlaylistPortController;
  final TextEditingController myPlaylistSecretKeyController;

  /// Vero quando si sta modificando un server gia' salvato: cambia la scritta
  /// del pulsante, cosi' si sa quale delle due operazioni si sta facendo.
  final bool isEditing;

  /// Chiamato solo quando il modulo e' valido: chi apre non deve ricontrollare
  /// nulla, e soprattutto non deve potersi dimenticare di farlo.
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  @override
  State<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<ConnectionForm> {
  /// Solo la chiave di MyPlaylist si puo' mostrare in chiaro. La password di
  /// VLC resta sempre nascosta: e' un segreto che l'utente non deve rivedere
  /// per sbaglio, mentre la chiave va confrontata carattere per carattere con
  /// quella del server, quindi va potuto leggere.
  bool _isSecretKeyVisible = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo(
              controller: widget.nameController,
              label: 'Nome Server',
              hint: 'es. VLC Casa',
              prefixIcon: const Icon(Icons.label_outline),
              messaggioVuoto: 'Inserisci un nome',
            ),
            _campo(
              controller: widget.ipController,
              label: 'Indirizzo IP',
              hint: '192.168.1.15',
              prefixIcon: const Icon(Icons.computer),
              keyboardType: TextInputType.number,
              messaggioVuoto: 'Inserisci un indirizzo IP',
              validator: _validaIp,
            ),
            _campo(
              controller: widget.portController,
              label: 'Porta VLC',
              hint: '${AppConstants.defaultVlcHttpPort}',
              prefixIcon: const Icon(Icons.settings_ethernet),
              keyboardType: TextInputType.number,
              messaggioVuoto: 'Inserisci una porta',
              validator: _validaPorta,
            ),
            _campo(
              controller: widget.vlcPasswordController,
              label: 'Password VLC (per HTTP API)',
              hint: 'Richiesta per widget e playlist stabili',
              prefixIcon: const Icon(Icons.password),
              obscure: true,
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Configurazione MyPlaylist (Opzionale)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _campo(
              controller: widget.myPlaylistIpController,
              label: 'Indirizzo IP MyPlaylist',
              hint: '192.168.1.15',
              prefixIcon: const Icon(Icons.link),
              keyboardType: TextInputType.number,
              validator: _validaIpFacoltativa,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: widget.myPlaylistPortController,
                    decoration: _decorazione(
                      label: 'Porta MP',
                      hint: '${AppConstants.defaultMyPlaylistPort}',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _validaPortaFacoltativa,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: TextFormField(
                    controller: widget.myPlaylistSecretKeyController,
                    decoration: _decorazione(
                      label: 'Secret Key (max 32 char)',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isSecretKeyVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _isSecretKeyVisible = !_isSecretKeyVisible,
                        ),
                        tooltip: _isSecretKeyVisible
                            ? 'Nascondi la chiave'
                            : 'Mostra la chiave',
                      ),
                    ),
                    obscureText: !_isSecretKeyVisible,
                    // La chiave viene completata con zeri fino a 32 byte, e
                    // MyPlaylist fa esattamente la stessa cosa: una chiave piu'
                    // corta di 32 caratteri funziona, e su questo campo non
                    // c'e' nemmeno un vincolo di lunghezza. Si blocca solo
                    // oltre i 32 caratteri, perche' li si perderebbero in
                    // silenzio: un refuso sul bordo destro produrrebbe una
                    // chiave diversa da quella pensata, con un errore di
                    // decifratura che non spiega niente.
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (value.length > 32) {
                        return 'La chiave non puo\' superare 32 caratteri';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _salva,
                    child: Text(
                      widget.isEditing ? 'Salva Modifiche' : 'Salva e Connetti',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Valida e poi avvisa. La validazione sta qui e non nel dialogo perche' i
  /// validatori sono di questo modulo: lasciarla al chiamante significa che
  /// il pulsante puo' salvare senza che nessuno abbia controllato nulla, e il
  /// difetto si vederebbe solo su un salvataggio sbagliato.
  Future<void> _salva() async {
    if (!(widget.formKey.currentState?.validate() ?? false)) return;
    await widget.onSave();
  }

  /// Campo con bordo arrotondato e distanza sotto costante: i sette campi
  /// scritti per esteso erano 150 righe di `SizedBox(height: 16)` e di bordi
  /// identici, e il distacco finale era un'altra `SizedBox` per ogni sezione.
  ///
  /// [messaggioVuoto] vale solo per i campi obbligatori, e serve perche' un
  /// campo vuoto ha un messaggio suo: dire 'Indirizzo IP non valido' a chi
  /// non ha ancora scritto niente descrive un problema che non si e' ancora
  /// verificato, e non dice cosa manca.
  Widget _campo({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    String? hint,
    Widget? prefixIcon,
    TextInputType? keyboardType,
    String? messaggioVuoto,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: _decorazione(
          label: label,
          hint: hint,
          prefixIcon: prefixIcon,
        ),
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: messaggioVuoto == null
            ? validator
            : (value) {
                if (value == null || value.isEmpty) return messaggioVuoto;
                return validator?.call(value);
              },
      ),
    );
  }

  InputDecoration _decorazione({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String? _validaIp(String? value) {
    if (value == null || value.isEmpty) return 'Inserisci un indirizzo IP';
    return Validators.isValidIpv4(value) ? null : 'Indirizzo IP non valido';
  }

  String? _validaPorta(String? value) {
    if (value == null || value.isEmpty) return 'Inserisci una porta';
    return Validators.isValidPort(value) ? null : 'Porta non valida (1-65535)';
  }

  /// I tre campi di MyPlaylist sono facoltativi per costruzione: vuoto vuol
  /// dire che MyPlaylist non e' su questa macchina, e va accettato. Se pero'
  /// c'e' qualcosa, deve essere un indirizzo o una porta come quelli sopra.
  String? _validaIpFacoltativa(String? value) {
    if (value == null || value.isEmpty) return null;
    return Validators.isValidIpv4(value)
        ? null
        : 'Indirizzo IP MyPlaylist non valido';
  }

  String? _validaPortaFacoltativa(String? value) {
    if (value == null || value.isEmpty) return null;
    return Validators.isValidPort(value) ? null : 'Porta non valida (1-65535)';
  }
}
