"""Reproduz o modelo incluído. Não é executado pelo aplicativo/Codemagic."""
import os
os.environ.setdefault('OPENBLAS_NUM_THREADS', '2')
from pathlib import Path
import hashlib
import json
import struct
import urllib.request
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT.parent / 'digitalizer-training' / 'mnist.npz'
DATA.parent.mkdir(parents=True, exist_ok=True)
URL = 'https://storage.googleapis.com/tensorflow/tf-keras-datasets/mnist.npz'
EXPECTED = '731c5ac602752760c8e48fbffcf8c3b850d9dc2a2aedcf2cc48468fc17b673d1'
if not DATA.exists():
    urllib.request.urlretrieve(URL, DATA)
assert hashlib.sha256(DATA.read_bytes()).hexdigest() == EXPECTED
data = np.load(DATA, allow_pickle=False)
rng = np.random.default_rng(20261027)
x = data['x_train'].reshape(-1, 784).astype(np.float32) / 255
y = data['y_train']
xt = data['x_test'].reshape(-1, 784).astype(np.float32) / 255
yt = data['y_test']
hidden = 96
w1 = rng.normal(0, np.sqrt(2/784), (784, hidden)).astype(np.float32)
b1 = np.zeros(hidden, np.float32)
w2 = rng.normal(0, np.sqrt(2/hidden), (hidden, 10)).astype(np.float32)
b2 = np.zeros(10, np.float32)
params = [w1, b1, w2, b2]
momentum = [np.zeros_like(p) for p in params]
for epoch in range(20):
    order = rng.permutation(len(x))
    lr = .10 if epoch < 10 else .04
    for start in range(0, len(x), 128):
        idx = order[start:start+128]
        xb, yb = x[idx], y[idx]
        h = np.maximum(0, xb @ w1 + b1)
        logits = h @ w2 + b2
        probs = np.exp(logits - logits.max(axis=1, keepdims=True))
        probs /= probs.sum(axis=1, keepdims=True)
        probs[np.arange(len(idx)), yb] -= 1
        probs /= len(idx)
        dh = (probs @ w2.T) * (h > 0)
        grads = [xb.T @ dh, dh.sum(axis=0), h.T @ probs, probs.sum(axis=0)]
        for p, grad, velocity in zip(params, grads, momentum):
            velocity *= .9
            velocity += grad
            p -= lr * velocity
    pred = np.argmax(np.maximum(0, xt @ w1 + b1) @ w2 + b2, axis=1)
    print(f'Epoch {epoch+1}: MNIST test {np.mean(pred == yt):.4f}', flush=True)
asset = ROOT / 'assets'
asset.mkdir(parents=True, exist_ok=True)
payload = struct.pack('<4sIII', b'DGZ1', 784, hidden, 10)
for p in params:
    payload += p.astype('<f4').tobytes()
(asset / 'digits.bin').write_bytes(payload)
metrics = {
    'architecture': '784-96-ReLU-10-softmax',
    'seed': 20261027, 'epochs': 20,
    'dataset': URL, 'dataset_sha256': EXPECTED,
    'training_samples': len(x), 'test_samples': len(xt),
    'test_accuracy_0_to_9': float(np.mean(pred == yt)),
    'test_accuracy_0_to_5': float(np.mean(pred[yt <= 5] == yt[yt <= 5])),
    'model_sha256': hashlib.sha256(payload).hexdigest(),
    'limitation': 'MNIST limpo não mede acurácia em fotos de relatórios ou rasuras. A validação no aparelho continua necessária.'
}
(asset / 'model_metrics.json').write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(metrics, ensure_ascii=False), flush=True)
