#!/bin/bash
# Eliminar folders vacíos recursivamente en raw/

echo "Buscando folders vacíos..."
count=$(find raw/ -type d -empty | wc -l | tr -d ' ')
echo "Encontrados: $count folders vacíos"

if [ "$count" -eq 0 ]; then
  echo "No hay folders vacíos."
  exit 0
fi

find raw/ -type d -empty -delete
echo "Eliminados: $count folders vacíos"
