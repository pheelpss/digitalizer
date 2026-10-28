import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'domain.dart';
import 'scanner.dart';
import 'vision.dart';

void main() => runApp(const Digitalizer());

class Digitalizer extends StatelessWidget {
  const Digitalizer({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Digitalizer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xff164d8d),
      scaffoldBackgroundColor: const Color(0xfff4f6fa),
    ),
    home: const CapturePage(),
  );
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});
  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final _picker = ImagePicker();
  final _scanner = Scanner();
  Catalog? _catalog;
  Uint8List? _model, _photo, _rectified;
  String? _area, _message;
  final List<Offset> _corners = [];
  bool _busy = false;
  List<Map<String, dynamic>>? _readings;
  final Map<String, int?> _corrections = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = Catalog.parse(
        await rootBundle.loadString('assets/catalog.json'),
      );
      final model = await rootBundle.load('assets/digits.bin');
      final cache = await getTemporaryDirectory();
      final previous = File('${cache.path}/digitalizer-session/page.png');
      if (await previous.exists()) await previous.delete();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _model = model.buffer.asUint8List(
          model.offsetInBytes,
          model.lengthInBytes,
        );
      });
      final lost = await _picker.retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      if (lost.files?.isNotEmpty ?? false) {
        final bytes = await lost.files!.first.readAsBytes();
        if (mounted) {
          setState(() {
            _photo = bytes;
            _message = 'Foto recuperada. Marque os quatro cantos da folha.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = 'Não foi possível preparar o Digitalizer: $error';
        });
      }
    }
  }

  Future<void> _capture(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 3000,
        maxHeight: 4000,
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      // O arquivo da galeria nunca é excluído. Captura do app é temporária.
      if (source == ImageSource.camera) {
        final cache = await getTemporaryDirectory();
        if (image.path.startsWith('${cache.path}/')) {
          final file = File(image.path);
          if (await file.exists()) await file.delete();
        }
      }
      if (mounted) {
        setState(() {
          _photo = bytes;
          _rectified = null;
          _readings = null;
          _corners.clear();
          _corrections.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = 'Não foi possível obter a foto: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<String?> _confirmArea(List<String> detected) async {
    final recognized = detected.length == 1 ? detected.single : null;
    if (recognized != null && (_area == null || _area == recognized)) {
      return recognized;
    }
    String? choice = recognized ?? _area;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            recognized == null
                ? 'Confirme a área da folha'
                : 'A área da foto é diferente',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recognized == null
                    ? 'Não identificamos uma única área com segurança. Selecione a área impressa. A numeração ainda será conferida.'
                    : 'Selecionada: $_area. Identificada na folha: $recognized. Confirme para continuar.',
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: choice,
                hint: const Text('Escolha a área'),
                items: _catalog!.names
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (value) => update(() {
                  choice = value;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: choice == null
                  ? null
                  : () => Navigator.pop(dialogContext, choice),
              child: const Text('Confirmar área'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze() async {
    if (_photo == null || _corners.length != 4 || _busy) return;
    final cross = List<double>.generate(4, (i) {
      final a = _corners[i],
          b = _corners[(i + 1) % 4],
          c = _corners[(i + 2) % 4];
      return (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    });
    if (!cross.every((c) => c > .002)) {
      setState(() {
        _message = 'Marque os cantos na ordem indicada, sem cruzar as linhas.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = 'Endireitando a folha e identificando as perguntas…';
    });
    try {
      final corrected = await compute(rectifyPhoto, {
        'bytes': _photo!,
        'points': _corners.map((p) => [p.dx, p.dy]).toList(),
      });
      if (!mounted) return;
      setState(() {
        _rectified = corrected;
      });
      final layout = await _scanner.inspect(corrected, _catalog!);
      if (!mounted) return;
      final area = await _confirmArea(layout.detectedAreas);
      if (area == null || !mounted) return;
      if (!_catalog!.matches(
        area,
        layout.anchors.map((a) => a['number'] as String),
      )) {
        setState(() {
          _message =
              'Aplicação bloqueada: a numeração ou a quantidade de perguntas não coincide com $area. Pode ser modelo antigo ou leitura incompleta. Refaça a foto usando o questionário atual.';
        });
        return;
      }
      setState(() {
        _area = area;
        _message = 'Lendo apenas a coluna de notas atuais…';
      });
      final result = await _scanner.recognize(corrected, _model!, layout);
      if (!mounted) return;
      if (result['error'] != null) {
        setState(() {
          _message = result['error'] as String;
        });
        return;
      }
      setState(() {
        _readings = result['readings'] as List<Map<String, dynamic>>;
        _corrections.clear();
        _message = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = 'A leitura não foi concluída: $error. Refaça a captura.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _discard() => setState(() {
    _photo = null;
    _rectified = null;
    _readings = null;
    _corners.clear();
    _corrections.clear();
    _message = null;
  });

  Future<void> _showPhoto() async {
    if (_rectified == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Conferir folha'),
            leading: CloseButton(onPressed: () => Navigator.pop(context)),
          ),
          body: InteractiveViewer(
            minScale: .5,
            maxScale: 8,
            child: Center(child: Image.memory(_rectified!)),
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final lines = _readings!;
    final untouched = lines
        .where((r) => !_corrections.containsKey(r['number']))
        .length;
    final changed = lines
        .where(
          (r) =>
              _corrections.containsKey(r['number']) &&
              _corrections[r['number']] != r['score'],
        )
        .length;
    final remaining = lines
        .where(
          (r) =>
              (_corrections.containsKey(r['number'])
                  ? _corrections[r['number']]
                  : r['score']) ==
              null,
        )
        .length;
    final summary =
        'Área: $_area\nPerguntas: ${lines.length}\n'
        'Correções manuais: $changed\nSem nota ao concluir: $remaining\n'
        'Sem alteração manual: $untouched\n\n'
        'Este resultado é somente do teste. Nada foi enviado à Ondexa.';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferência do teste'),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: summary)),
            child: const Text('Copiar resumo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    if (mounted) _discard();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _catalog != null && _model != null;
    return PopScope(
      canPop: _photo == null && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) _discard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Digitalizer'),
          actions: [
            if (_photo != null)
              IconButton(
                onPressed: _busy ? null : _discard,
                tooltip: 'Descartar digitalização',
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        body: SafeArea(
          child: _readings == null ? _captureView(ready) : _reviewView(),
        ),
      ),
    );
  }

  Widget _captureView(bool ready) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Do papel para as notas',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Teste offline dos relatórios atuais da Ondexa. Leia uma folha por vez. '
        'Não há conexão com suas auditorias nem salvamento da foto.',
      ),
      const SizedBox(height: 18),
      if (ready)
        DropdownButtonFormField<String>(
          initialValue: _area,
          decoration: const InputDecoration(
            labelText: 'Área esperada (opcional)',
            border: OutlineInputBorder(),
          ),
          items: _catalog!.names
              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _area = value;
                }),
        ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: ready && !_busy ? () => _capture(ImageSource.camera) : null,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Fotografar relatório'),
      ),
      TextButton.icon(
        onPressed: ready && !_busy ? () => _capture(ImageSource.gallery) : null,
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Testar foto da galeria'),
      ),
      if (_photo != null) ...[
        const SizedBox(height: 10),
        Text(
          _corners.length < 4
              ? 'Toque no canto ${_corners.length + 1}: ${['superior esquerdo', 'superior direito', 'inferior direito', 'inferior esquerdo'][_corners.length]} da folha.'
              : 'Quatro cantos marcados. Confira o contorno antes de ler.',
        ),
        const SizedBox(height: 10),
        // A área de toque e a foto usam o mesmo retângulo, sem letterboxing.
        FutureBuilder<Size>(
          future: _imageSize(_photo!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final size = snapshot.data!;
            return AspectRatio(
              aspectRatio: size.width / size.height,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onTapDown: _busy || _corners.length == 4
                      ? null
                      : (details) => setState(() {
                          _corners.add(
                            Offset(
                              details.localPosition.dx / constraints.maxWidth,
                              details.localPosition.dy / constraints.maxHeight,
                            ),
                          );
                        }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_photo!, fit: BoxFit.fill),
                      CustomPaint(painter: CornerPainter(List.of(_corners))),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _corners.clear();
                }),
          child: const Text('Marcar os cantos novamente'),
        ),
        FilledButton(
          onPressed: _corners.length == 4 && !_busy ? _analyze : null,
          child: const Text('Ler área e notas'),
        ),
      ],
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _message!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        'Boa captura: folha inteira, apoiada e iluminada; evite sombras e reflexos. '
        'A foto antiga enviada como exemplo pode ser bloqueada por ter outro questionário.',
      ),
    ],
  );

  Widget _reviewView() {
    final questions = _catalog!.areas[_area]!;
    final byNumber = {
      for (final reading in _readings!) reading['number'] as String: reading,
    };
    final recognized = _readings!.where((r) => r['score'] != null).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conferir $_area',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$recognized sugestões · ${questions.length - recognized} sem leitura. '
                'Confira também as notas sugeridas: o modelo pode errar.',
              ),
              TextButton.icon(
                onPressed: _showPhoto,
                icon: const Icon(Icons.zoom_in),
                label: const Text('Ampliar folha temporária'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index], reading = byNumber[q.number]!;
              final original = reading['score'] as int?;
              final value = _corrections.containsKey(q.number)
                  ? _corrections[q.number]
                  : original;
              final manual = _corrections.containsKey(q.number);
              return Card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${q.number}  ${q.text}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        manual
                            ? 'Conferência manual · leitura original: ${original ?? "sem leitura"}'
                            : '${reading['reason']}',
                        style: TextStyle(
                          color: original == null
                              ? Colors.brown
                              : Colors.blueGrey,
                        ),
                      ),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: value ?? -1,
                        items: [
                          const DropdownMenuItem(
                            value: -1,
                            child: Text('Sem nota'),
                          ),
                          for (var n = 0; n <= 5; n++)
                            DropdownMenuItem(value: n, child: Text('Nota $n')),
                        ],
                        onChanged: (n) => setState(() {
                          _corrections[q.number] = n == -1 ? null : n;
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _discard,
                  child: const Text('Descartar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _finish,
                  child: const Text('Concluir teste'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Size> _imageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } finally {
      codec.dispose();
    }
  }
}

class CornerPainter extends CustomPainter {
  CornerPainter(this.points);
  final List<Offset> points;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 3;
    final scaled = points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    for (var i = 0; i < scaled.length; i++) {
      canvas.drawCircle(scaled[i], 7, paint);
      if (i > 0) canvas.drawLine(scaled[i - 1], scaled[i], paint);
    }
    if (scaled.length == 4) canvas.drawLine(scaled.last, scaled.first, paint);
  }

  @override
  bool shouldRepaint(CornerPainter old) => !listEquals(old.points, points);
}
