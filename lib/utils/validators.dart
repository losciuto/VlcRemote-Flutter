/// Controlli sui valori che l'utente scrive nei campi.
///
/// Sono funzioni pure e hanno un test dedicato: la validazione dentro il
/// widget si vede solo quando qualcosa va storto, mentre qui si puo' provare
/// ogni caso, compreso quello che nessuno scriverebbe mai a mano.
class Validators {
  Validators._();

  /// Vero se [indirizzo] e' un indirizzo IPv4 valido.
  ///
  /// Vanno controllate tutte e quattro le parti, e non solo che ci siano:
  /// `999.1.1.1` ha quattro parti ed e' comunque un indirizzo che non
  /// esiste, e senza questo controllo l'app lo accetterebbe e poi fallirebbe
  /// solo al momento di connettersi, con un errore che parla di rete.
  ///
  /// Non ammette spazi, numeri con zeri iniziali (`010.1.1.1`) ne tanto nomi
  /// di host: qui si accetta solo la forma stretta dell'IPv4, perche' e' il
  /// campo in cui si scrive l'indirizzo di un server di casa.
  static bool isValidIpv4(String indirizzo) {
    final parti = indirizzo.trim().split('.');
    if (parti.length != 4) return false;

    for (final parte in parti) {
      if (parte.isEmpty || parte.length > 3) return false;
      // `int.tryParse` accetterebbe anche '+7' e ' 7': questi non sono ottetti.
      if (!RegExp(r'^\d{1,3}$').hasMatch(parte)) return false;
      // Uno zero iniziale non e' un errore di battitura da perdonare:
      // `010` vale 10, quindi '010.1.1.1' e '10.1.1.1' sarebbero due
      // caselle diverse per lo stesso indirizzo scritto in due modi.
      if (parte.length > 1 && parte.startsWith('0')) return false;
      final valore = int.parse(parte);
      if (valore > 255) return false;
    }
    return true;
  }

  /// Vero se [porta] e' una porta valida, da 1 a 65535.
  ///
  /// La porta 0 non vuol dire "nessuna": e' riservata, e chiederla a una
  /// socket fallisce in un modo poco leggibile.
  static bool isValidPort(String porta) {
    final valore = int.tryParse(porta.trim());
    return valore != null && valore >= 1 && valore <= 65535;
  }
}
