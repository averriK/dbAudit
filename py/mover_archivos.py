#!/usr/bin/env python3
"""
Mover archivos desde carpetas que coinciden con un patrón a una carpeta destino.
Uso: python3 mover_archivos.py <patron> <carpeta_destino>
Ejemplo: python3 mover_archivos.py "*ley*laboratorio*" cert
"""
import sys
import shutil
import subprocess
from pathlib import Path

if len(sys.argv) != 3:
    print("Uso: python3 mover_archivos.py <patron> <carpeta_destino>")
    print("Ejemplo: python3 mover_archivos.py '*ley*laboratorio*' cert")
    sys.exit(1)

patron = sys.argv[1]
destino = Path(sys.argv[2])
destino.mkdir(exist_ok=True)

# Usar find para buscar carpetas (case-insensitive)
result = subprocess.run(
    ["find", "raw/", "-type", "d", "-iname", patron],
    capture_output=True,
    text=True
)

dirs = [line.strip() for line in result.stdout.split('\n') if line.strip()]
print(f"Encontradas {len(dirs)} carpetas con patrón '{patron}'")

if not dirs:
    print("No hay nada que mover.")
    sys.exit(0)

moved = 0
for i, dir_path in enumerate(dirs, 1):
    if i % 100 == 0:
        print(f"  {i}/{len(dirs)} procesadas, {moved} archivos movidos")

    p = Path(dir_path)
    if not p.exists():
        continue

    for file in p.iterdir():
        if file.is_file():
            dest = destino / file.name
            if dest.exists():
                base = file.stem
                ext = file.suffix
                counter = 1
                while dest.exists():
                    dest = destino / f"{base}_dup{counter:03d}{ext}"
                    counter += 1
            shutil.move(str(file), str(dest))
            moved += 1

print(f"Completado. {moved} archivos movidos a {destino}/")
