import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_settings.dart';

/// Servizio per gestire le impostazioni generali di VlcRemote
class SettingsService {
  static const String _lastFilterSettingsKey = 'last_filter_settings';

  SharedPreferences? _prefs;

  /// Inizializza il servizio
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Salva le impostazioni dei filtri
  Future<bool> saveFilterSettings(FilterSettings? settings) async {
    if (_prefs == null) return false;

    if (settings == null) {
      return await _prefs!.remove(_lastFilterSettingsKey);
    }

    try {
      final jsonString = jsonEncode(settings.toJson());
      return await _prefs!.setString(_lastFilterSettingsKey, jsonString);
    } catch (e) {
      print('Errore durante il salvataggio dei filtri: $e');
      return false;
    }
  }

  /// Ottiene le ultime impostazioni dei filtri
  FilterSettings? getFilterSettings() {
    if (_prefs == null) return null;

    try {
      final jsonString = _prefs!.getString(_lastFilterSettingsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return FilterSettings.fromJson(jsonMap);
    } catch (e) {
      print('Errore durante il caricamento dei filtri: $e');
      return null;
    }
  }
}
