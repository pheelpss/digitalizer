"""Detecta mistura de arquivos de versões diferentes antes do Flutter."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "tools/source_manifest.json").read_text(encoding="utf-8"))
failures = []
for name, expected in manifest.items():
    path = root / name
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        failures.append(name)
if failures:
    raise SystemExit("Projeto incompleto ou com arquivos de versões diferentes. "
                     "Substitua o conteúdo completo do ZIP no GitHub. Arquivos: "
                     + ", ".join(failures))
print("Fontes Digitalizer 0.1.5+6 conferidos: catálogo, scanner e testes da mesma entrega.")
