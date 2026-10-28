# Créditos e componentes

O catálogo de perguntas foi fornecido pelo responsável pela Ondexa e reproduz o Android 1.0.12+13, incluindo Showroom.

O modelo `assets/digits.bin` foi treinado para este experimento no conjunto MNIST, de Yann LeCun e Corinna Cortes, derivado de dados NIST. A documentação atual do Keras informa licença Creative Commons Attribution Share Alike 3.0 para MNIST. O modelo derivado é distribuído com essa atribuição e sob CC BY-SA 3.0. Fonte dos dados, hash, amostras e métricas constam em `assets/model_metrics.json`; o treinamento reproduzível está em `tools/train_digits.py`.

Licença: https://creativecommons.org/licenses/by-sa/3.0/

Os componentes Flutter, ML Kit, google_mlkit_text_recognition, image_picker, image e path_provider conservam suas próprias licenças. As dependências são resolvidas no build, e o Flutter inclui seus avisos de licença no aplicativo. ML Kit é um produto Google; o plugin Flutter é mantido pela comunidade e não é uma implementação oficial Flutter do Google.
