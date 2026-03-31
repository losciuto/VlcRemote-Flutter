import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final GitHubRelease release;

  const UpdateDialog({super.key, required this.release});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  String? _errorMessage;
  double? _downloadProgress;

  Future<void> _startUpdate() async {
    final apkUrl = widget.release.apkUrl;

    if (apkUrl == null || !Platform.isAndroid) {
      // Fallback per iOS o se non c'è l'APK diretto
      final url = Uri.parse(widget.release.htmlUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        setState(() {
          _errorMessage = 'Impossibile aprire la pagina del rilascio.';
        });
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/VlcRemote_update.apk';
      final file = File(apkPath);

      // Download con progresso
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Errore download: ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final List<int> bytes = [];
      int downloaded = 0;

      await for (final List<int> chunk in response.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        if (contentLength != null) {
          setState(() {
            _downloadProgress = downloaded / contentLength;
          });
        }
      }

      await file.writeAsBytes(bytes);

      // Apri l'APK per l'installazione
      final result = await OpenFilex.open(apkPath);

      if (result.type != ResultType.done) {
        throw Exception(
          'Impossibile avviare l\'installazione: ${result.message}',
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Errore durante l\'aggiornamento: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/icon/icon.png', width: 36, height: 36),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Nuovo Aggiornamento')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versione ${widget.release.tagName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (!_isDownloading && widget.release.body.isNotEmpty) ...[
              const Text(
                'Novità:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.release.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              const Text(
                'Scaricamento in corso...',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _downloadProgress),
              if (_downloadProgress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${(_downloadProgress! * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 20),
              const Text(
                'È disponibile una nuova versione di VlcRemote. Vuoi installarla ora?',
                style: TextStyle(fontSize: 14),
              ),
            ],
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ANNULLA'),
          ),
        if (!_isDownloading)
          ElevatedButton(
            onPressed: _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('AGGIORNA ORA'),
          ),
      ],
    );
  }
}
