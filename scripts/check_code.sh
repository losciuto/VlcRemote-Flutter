#!/bin/bash

# Script per verificare la qualità del codice prima del push
# Esegue formattazione, analisi statica e test

STATUS=0

echo "1. Formattazione del codice..."
dart format . || STATUS=1

echo "2. Analisi statica (flutter analyze)..."
flutter analyze || STATUS=1

echo "3. Test (flutter test)..."
flutter test || STATUS=1

echo "------------------------------------------------"
if [ $STATUS -eq 0 ]; then
  echo "✅ Tutto ok! Puoi procedere con il push."
else
  echo "❌ Sono stati trovati problemi. Correggili prima del push."
  exit 1
fi
