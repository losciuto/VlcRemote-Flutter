---
description: Rivedi e aggiorna il piano di refactoring
---

Leggi `docs/REFACTORING_TODO.md` e riferisci lo stato del lavoro.

Poi fai esattamente queste cose, in ordine:

1. **Riassumi**: conta gli item per stato (fatto / da fare / parziale /
   decisione / bloccato) e per fase.
2. **Segnala le decisioni aperte**: elenca le voci `D<n>` ancora senza
   risposta nella colonna "Risposta". Per ognuna ricorda l'opzione consigliata in
   una riga, senza applicarla.
3. **Propogli il prossimo passo**: il primo item `da fare` con severità più
   alta e `Impatto server = ok`, e ricorda che gli item `⚠️` non si toccano
   senza decisione.
4. **Verifica** che `dart format --output=none --set-exit-if-changed .`,
   `flutter analyze` e `flutter test` siano verdi prima di riportare lo stato.
5. Aggiorna la tabella solo se qualcosa è cambiato davvero: non inventare
   avanzamenti. Se un item è stato fatto, cambia lo stato in `fatto` e annota
   cosa hai cambiato.
