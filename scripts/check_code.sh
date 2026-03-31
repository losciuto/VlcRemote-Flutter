#!/bin/bash

# Script per verificare la qualità del codice prima del push
# Esegue formattazione e analisi statica

echo "1. Formattazione del codice..."
dart format .

echo "2. Analisi statica (flutter analyze)..."
flutter analyze

echo "------------------------------------------------"
if [ $? -eq 0 ]; then
  echo "✅ Tutto ok! Puoi procedere con il push."
else
  echo "❌ Sono stati trovati problemi. Correggili prima del push."
  exit 1
fi
