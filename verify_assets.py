from pathlib import Path
import hashlib
import json
import struct

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'assets/catalog.json').read_text(encoding='utf-8'))
assert len(catalog) == 32
assert sum(len(area['items']) for area in catalog.values()) == 749
assert len(catalog['Showroom']['items']) == 14
for area in catalog.values():
    items = area['items']
    assert len({q['number'] for q in items}) == len(items)
    for sense in range(1, 6):
        codes = [q['number'] for q in items if q['categoryCode'] == f'{sense}S']
        assert codes == [f'{sense}.{i + 1}' for i in range(len(codes))]
binary = (root / 'assets/digits.bin').read_bytes()
magic, inputs, hidden, outputs = struct.unpack('<4sIII', binary[:16])
assert (magic, inputs, hidden, outputs) == (b'DGZ1', 784, 96, 10)
assert len(binary) == 16 + (inputs * hidden + hidden + hidden * outputs + outputs) * 4
metrics = json.loads((root / 'assets/model_metrics.json').read_text(encoding='utf-8'))
assert hashlib.sha256(binary).hexdigest() == metrics['model_sha256']
print('32 áreas, 749 perguntas e modelo offline íntegro.')
