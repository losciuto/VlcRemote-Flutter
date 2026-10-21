import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_settings.dart';
import '../utils/app_logger.dart';

/// Servizio per gestire le impostazioni generali di VlcRemote
class SettingsService {
  /// Tag usato nei log di questo servizio.
  static const String _tag = 'SettingsService';
  static const String _lastFilterSettingsKey = 'last_filter_settings';
  static const String _voiceLanguageKey = 'voice_language';
  static const String _voiceInputDeviceKey = 'voice_input_device';

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
      AppLogger.w(_tag, 'Errore durante il salvataggio dei filtri', e);
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
      AppLogger.w(_tag, 'Errore durante il caricamento dei filtri', e);
      return null;
    }
  }

  /// Lingua del riconoscimento vocale: null significa la lingua predefinita.
  String? get voiceLanguage => _prefs?.getString(_voiceLanguageKey);

  /// Salva la lingua del riconoscimento vocale.
  Future<bool> setVoiceLanguage(String? code) async {
    if (_prefs == null) return false;
    if (code == null) return await _prefs!.remove(_voiceLanguageKey);
    return await _prefs!.setString(_voiceLanguageKey, code);
  }

  /// Id del microfono scelto per i comandi vocali.
  String? get voiceInputDevice => _prefs?.getString(_voiceInputDeviceKey);

  /// Salva il microfono scelto per i comandi vocali.
  Future<bool> setVoiceInputDevice(String? deviceId) async {
    if (_prefs == null) return false;
    if (deviceId == null) return await _prefs!.remove(_voiceInputDeviceKey);
    return await _prefs!.setString(_voiceInputDeviceKey, deviceId);
  }
}
