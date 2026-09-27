import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/utils/validators.dart';

void main() {
  group('IPv4', () {
    test('accetta gli indirizzi normali', () {
      for (final indirizzo in [
        '192.168.1.15',
        '10.0.0.1',
        '0.0.0.0',
        '255.255.255.255',
        '8.8.8.8',
      ]) {
        expect(
          Validators.isValidIpv4(indirizzo),
          isTrue,
          reason: '$indirizzo doveva essere valido',
        );
      }
    });

    test('rifiuta un numero di parti diverso da quattro', () {
      for (final indirizzo in [
        '192.168.1',
        '192.168.1.15.7',
        'localhost',
        '',
      ]) {
        expect(
          Validators.isValidIpv4(indirizzo),
          isFalse,
          reason: '$indirizzo non e\' un indirizzo',
        );
      }
    });

    test('rifiuta un ottetto sopra 255', () {
      // Il controllo precedente contava solo le parti: questi passavano e
      // fallivano poi all'avvio della connessione, con un errore che parlava
      // di rete e non di quello che era successo.
      for (final indirizzo in [
        '256.1.1.1',
        '999.999.999.999',
        '192.168.1.300',
      ]) {
        expect(
          Validators.isValidIpv4(indirizzo),
          isFalse,
          reason: '$indirizzo ha un ottetto fuori scala',
        );
      }
    });

    test('rifiuta cio\' che sembra un numero ma non lo e\'', () {
      for (final indirizzo in [
        'a.b.c.d',
        '192.168.1.x',
        '-1.1.1.1',
        '+7.1.1.1',
        '1.1.1.',
        '.1.1.1',
        '1..1.1',
      ]) {
        expect(
          Validators.isValidIpv4(indirizzo),
          isFalse,
          reason: '$indirizzo non e\' un indirizzo',
        );
      }
    });

    test('rifiuta gli zeri iniziali', () {
      // `int.tryParse('010')` vale 10, quindi una conversione ingenua
      // accetterebbe '010.1.1.1' come se fosse 10.1.1.1: due indirizzi
      // diversi per la stessa casella.
      expect(Validators.isValidIpv4('010.1.1.1'), isFalse);
      expect(Validators.isValidIpv4('01.01.01.01'), isFalse);
    });

    test('tolera spazi attorno', () {
      // Digitare con il dito lascia spazi, e non vale la pena far fallire la
      // form per quello.
      expect(Validators.isValidIpv4('  192.168.1.15  '), isTrue);
    });
  });

  group('porta', () {
    test('accetta l\'intervallo utile', () {
      for (final porta in ['1', '80', '8080', '65535']) {
        expect(Validators.isValidPort(porta), isTrue, reason: porta);
      }
    });

    test('rifiuta la porta 0 e quelle fuori scala', () {
      // La 0 e' riservata: chiederla a una socket fallisce in modo poco
      // leggibile, quindi e' meglio rifiutarla qui.
      for (final porta in ['0', '65536', '99999']) {
        expect(Validators.isValidPort(porta), isFalse, reason: porta);
      }
    });

    test('rifiuta cio\' che non e\' un numero', () {
      for (final porta in ['', 'abc', '80a', '-1', '8.0']) {
        expect(Validators.isValidPort(porta), isFalse, reason: porta);
      }
    });
  });
}
