import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/filter_settings.dart';
import '../providers/vlc_provider.dart';

/// Dialogo dei filtri della smart playlist.
///
/// Vive in un widget a se' invece che dentro `_showFilterDialog` perche' i
/// campi di testo hanno una vita precisa: nascono quando il dialogo si apre e
/// vanno distrutti quando si chiude. Nella versione precedente erano nove
/// `TextEditingController` creati nel metodo che apre il dialogo e mai
/// liberati: ogni apertura ne lasciava nove in giro, con i loro listener.
///
/// Vivere in uno `State` rende la cosa automatica, e toglie di mezzo il
/// `StatefulBuilder` che serviva solo per poter chiamare `setState`.
class SmartFilterDialog extends StatefulWidget {
  const SmartFilterDialog({
    super.key,
    required this.last,
    required this.previewMode,
  });

  /// Ultimi filtri applicati, per ripartire da dove si era rimasti.
  final FilterSettings? last;

  /// Se il comando va eseguito in anteprima invece che subito.
  final bool previewMode;

  @override
  State<SmartFilterDialog> createState() => _SmartFilterDialogState();
}

class _SmartFilterDialogState extends State<SmartFilterDialog> {
  late final TextEditingController _generi;
  late final TextEditingController _esclusiGeneri;
  late final TextEditingController _anno;
  late final TextEditingController _esclusiAnni;
  late final TextEditingController _attori;
  late final TextEditingController _esclusiAttori;
  late final TextEditingController _registi;
  late final TextEditingController _esclusiRegisti;
  late final TextEditingController _limite;

  double _minRating = 0;

  @override
  void initState() {
    super.initState();
    final last = widget.last;
    _generi = TextEditingController(text: last?.genres.join(', ') ?? '');
    _esclusiGeneri = TextEditingController(
      text: last?.excludedGenres.join(', ') ?? '',
    );
    _anno = TextEditingController(text: last?.years.join(', ') ?? '');
    _esclusiAnni = TextEditingController(
      text: last?.excludedYears.join(', ') ?? '',
    );
    _attori = TextEditingController(text: last?.actors.join(', ') ?? '');
    _esclusiAttori = TextEditingController(
      text: last?.excludedActors.join(', ') ?? '',
    );
    _registi = TextEditingController(text: last?.directors.join(', ') ?? '');
    _esclusiRegisti = TextEditingController(
      text: last?.excludedDirectors.join(', ') ?? '',
    );
    _limite = TextEditingController(text: (last?.limit ?? 10).toString());
    _minRating = last?.ratingMin ?? 0.0;
  }

  @override
  void dispose() {
    _generi.dispose();
    _esclusiGeneri.dispose();
    _anno.dispose();
    _esclusiAnni.dispose();
    _attori.dispose();
    _esclusiAttori.dispose();
    _registi.dispose();
    _esclusiRegisti.dispose();
    _limite.dispose();
    super.dispose();
  }

  /// Divide il testo di un campo in valori, come ci si aspetta da un campo
  /// con piu' voci separate da virgola.
  static List<String> _split(String testo) =>
      testo.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void _azzera() {
    setState(() {
      _generi.clear();
      _esclusiGeneri.clear();
      _anno.clear();
      _esclusiAnni.clear();
      _attori.clear();
      _esclusiAttori.clear();
      _registi.clear();
      _esclusiRegisti.clear();
      _limite.text = '10';
      _minRating = 0.0;
    });
    context.read<VlcProvider>().setLastFilterSettings(null);
  }

  void _genera() {
    final genres = _split(_generi.text);
    final excludedGenres = _split(_esclusiGeneri.text);
    final years = _split(_anno.text);
    final excludedYears = _split(_esclusiAnni.text);
    final actors = _split(_attori.text);
    final excludedActors = _split(_esclusiAttori.text);
    final directors = _split(_registi.text);
    final excludedDirectors = _split(_esclusiRegisti.text);
    final limit = int.tryParse(_limite.text) ?? 10;
    final minRating = _minRating;

    final settings = FilterSettings(
      genres: genres,
      years: years,
      ratingMin: minRating,
      actors: actors,
      directors: directors,
      excludedGenres: excludedGenres,
      excludedYears: excludedYears,
      excludedActors: excludedActors,
      excludedDirectors: excludedDirectors,
      limit: limit,
    );

    final provider = context.read<VlcProvider>();
    provider.setLastFilterSettings(settings);
    provider.mpGenerateFiltered(
      genres: genres.isEmpty ? null : genres,
      excludedGenres: excludedGenres.isEmpty ? null : excludedGenres,
      years: years.isEmpty ? null : years,
      excludedYears: excludedYears.isEmpty ? null : excludedYears,
      actors: actors.isEmpty ? null : actors,
      excludedActors: excludedActors.isEmpty ? null : excludedActors,
      directors: directors.isEmpty ? null : directors,
      excludedDirectors: excludedDirectors.isEmpty ? null : excludedDirectors,
      minRating: minRating > 0 ? minRating : null,
      limit: limit,
      preview: widget.previewMode,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.filter_alt, color: Colors.blue),
          SizedBox(width: 12),
          Text('Filtro smart playlist'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'METADATI DA INCLUDERE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _generi,
              decoration: const InputDecoration(
                labelText: 'Generi',
                hintText: 'Azione, Commedia',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _anno,
              decoration: const InputDecoration(
                labelText: 'Anni',
                hintText: '2023, 2024',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _attori,
                    decoration: const InputDecoration(
                      labelText: 'Attori',
                      hintText: 'Tom Cruise',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _registi,
                    decoration: const InputDecoration(
                      labelText: 'Registi',
                      hintText: 'Christopher Nolan',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'METADATI DA ESCLUDERE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _esclusiGeneri,
              decoration: const InputDecoration(
                labelText: 'Escludi Generi',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _esclusiAnni,
              decoration: const InputDecoration(
                labelText: 'Escludi Anni',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _esclusiAttori,
                    decoration: const InputDecoration(
                      labelText: 'Escludi Attori',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _esclusiRegisti,
                    decoration: const InputDecoration(
                      labelText: 'Escludi Registi',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'ALTRI PARAMETRI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Valutazione Minima:'),
            Slider(
              value: _minRating,
              min: 0,
              max: 10,
              divisions: 20,
              label: _minRating.toStringAsFixed(1),
              onChanged: (value) => setState(() => _minRating = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _limite,
              decoration: const InputDecoration(
                labelText: 'Limite Risultati',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _azzera,
          child: const Text('Azzera', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(onPressed: _genera, child: const Text('Genera')),
      ],
    );
  }
}
