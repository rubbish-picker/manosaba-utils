import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'update_service.dart';

class TachibanaPage extends StatefulWidget {
  const TachibanaPage({super.key});

  @override
  State<TachibanaPage> createState() => _TachibanaPageState();
}

class _TachibanaPageState extends State<TachibanaPage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _maxFontSizeController =
      TextEditingController(text: "80");
  final TextEditingController _outlineWidthController =
      TextEditingController(text: "4");

  List<String> _backgroundImages = [
    'assets/TachibanaImages/001_舔舌头举手指.png',
    'assets/TachibanaImages/002_眯眼微笑挠头.png',
    'assets/TachibanaImages/003_握拳，加油打气.png',
    'assets/TachibanaImages/004_尴尬地拒绝.png',
    'assets/TachibanaImages/005_惊讶地摆手拒绝.png',
    'assets/TachibanaImages/006_投降.png',
    'assets/TachibanaImages/007_惊讶地表示赞同.png',
    'assets/TachibanaImages/008_惊讶地举起双手.png',
    'assets/TachibanaImages/009_挠头拒绝.png',
  ];
  String? _selectedBackground;

  final List<String> _fontFamilies = [
    'AppFont',
    'Microsoft YaHei',
    'Microsoft YaHei Bold',
    'Microsoft YaHei Light',
    'SimHei',
    'Source Han Serif SC',
  ];
  String _selectedFont = 'Microsoft YaHei Bold';

  Color _textColor = Colors.white;
  Color _outlineColor = Colors.black;
  bool _isBold = false;
  bool _isOutline = false;

  ui.Image? _generatedImage;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Initialize selection immediately
    if (_backgroundImages.isNotEmpty) {
      _selectedBackground = _backgroundImages.first;
    }
    // Try to load more from assets, but we already have defaults
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      // Generate initial preview immediately with default assets
      if (_selectedBackground != null) {
        _generateImage();
      }

      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final images = manifestMap.keys
          .where((String key) => key.contains('assets/TachibanaImages/'))
          .toList();

      if (images.isNotEmpty) {
        images.sort();
        if (mounted) {
          setState(() {
            _backgroundImages = images;
            // Only update selection if it was null (shouldn't happen now)
            _selectedBackground ??= _backgroundImages.first;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading assets: $e');
    }
  }

  Future<void> _generateImage() async {
    if (_selectedBackground == null) return;
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final String text = _textController.text;
      final String bgPath = _selectedBackground!;
      final String fontFamily = _selectedFont;
      final Color textColor = _textColor;
      final Color outlineColor = _outlineColor;
      final bool isBold = _isBold;
      final bool isOutline = _isOutline;
      final double maxFontSize =
          double.tryParse(_maxFontSizeController.text) ?? 80;
      final double outlineWidth =
          double.tryParse(_outlineWidthController.text) ?? 4;

      final ui.Image image = await _createImage(
        text,
        bgPath,
        fontFamily,
        textColor,
        outlineColor,
        isBold,
        isOutline,
        maxFontSize,
        outlineWidth,
      );

      setState(() {
        _generatedImage = image;
      });
    } catch (e) {
      debugPrint('Error generating image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<ui.Image> _createImage(
    String text,
    String bgPath,
    String fontFamily,
    Color textColor,
    Color outlineColor,
    bool isBold,
    bool isOutline,
    double maxFontSize,
    double outlineWidth,
  ) async {
    // 1. Load background image
    final ByteData data = await rootBundle.load(bgPath);
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(Uint8List.view(data.buffer), (ui.Image img) {
      completer.complete(img);
    });
    final ui.Image bgImage = await completer.future;

    // 2. Setup Canvas (900x900)
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 900, 900));

    // Draw background scaled to 900x900
    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(0, 0, 900, 900),
      image: bgImage,
      fit: BoxFit.fill,
    );

    // 3. Calculate Text Layout
    if (text.isNotEmpty) {
      _drawText(
        canvas,
        text,
        fontFamily,
        textColor,
        outlineColor,
        isBold,
        isOutline,
        maxFontSize,
        outlineWidth,
      );
    }

    // 4. Convert to Image
    final ui.Picture picture = recorder.endRecording();
    return picture.toImage(900, 900);
  }

  void _drawText(
    Canvas canvas,
    String text,
    String fontFamily,
    Color textColor,
    Color outlineColor,
    bool isBold,
    bool isOutline,
    double startFontSize,
    double outlineWidth,
  ) {
    const double maxWidth = 800;
    const double maxTotalHeight = 300;
    const double minFontSize = 20;

    double currentFontSize = startFontSize;
    TextPainter? finalPainter;
    double finalHeight = 0;

    // Iteratively find the best font size
    while (currentFontSize >= minFontSize) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: currentFontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      painter.layout(maxWidth: maxWidth);

      if (painter.height <= maxTotalHeight) {
        finalPainter = painter;
        finalHeight = painter.height;
        break;
      }

      currentFontSize -= 5;
    }

    // Fallback to min font size if needed
    if (finalPainter == null) {
      finalPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: minFontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      finalPainter.layout(maxWidth: maxWidth);
      finalHeight = finalPainter.height;
    }

    // Calculate Position
    // Bottom area is 600-900.
    // We want to place it at the bottom, with 30px padding.
    const double textAreaBottomY = 900;
    const double textAreaTopY = 600;

    double startY = textAreaBottomY - finalHeight - 30;
    if (startY < textAreaTopY) startY = textAreaTopY;

    // Draw Outline if enabled
    if (isOutline && outlineWidth > 0) {
      final TextPainter outlinePainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: finalPainter.text!.style!.fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth * 2
              ..color = outlineColor,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      outlinePainter.layout(maxWidth: maxWidth);

      // Center horizontally
      final double x = (900 - outlinePainter.width) / 2;
      outlinePainter.paint(canvas, Offset(x, startY));
    }

    // Draw Fill
    final double x = (900 - finalPainter.width) / 2;
    finalPainter.paint(canvas, Offset(x, startY));
  }

  Future<void> _shareImage() async {
    if (_generatedImage == null) return;

    try {
      final ByteData? byteData =
          await _generatedImage!.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Use share_plus to share/save
      final tempDir = await getTemporaryDirectory();
      final file = await File(
              '${tempDir.path}/sherry_meme_${DateTime.now().millisecondsSinceEpoch}.png')
          .create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)],
          text: '分享自 Tachibana\'s Gallery');
    } catch (e) {
      debugPrint('Error sharing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_generatedImage == null) return;

    try {
      final ByteData? byteData =
          await _generatedImage!.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to gallery
      await Gal.putImageBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tachibana\'s Gallery'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: () {
              UpdateService().checkForUpdates(context, isManual: true);
            },
            child: const Text('检查更新'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top: Preview Area (Fixed height or flexible)
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: _generatedImage != null
                    ? RawImage(
                        image: _generatedImage,
                        fit: BoxFit.contain,
                      )
                    : const Text('预览区域'),
              ),
            ),
          ),

          // Bottom: Controls (Scrollable if needed, but designed to fit)
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Row 1: Text Input
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: '输入文字',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      maxLines: 2,
                      onChanged: (_) => _generateImage(),
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Background & Font
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedBackground,
                            decoration: const InputDecoration(
                              labelText: '背景图片',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: _backgroundImages.map((String path) {
                              final String name =
                                  path.split('/').last.replaceAll('.png', '');
                              return DropdownMenuItem<String>(
                                value: path,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedBackground = newValue;
                              });
                              _generateImage();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedFont,
                            decoration: const InputDecoration(
                              labelText: '字体',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: _fontFamilies.map((String font) {
                              return DropdownMenuItem<String>(
                                value: font,
                                child: Text(
                                  font,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedFont = newValue;
                                });
                                _generateImage();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 3: Color Picker
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          const Center(
                              child: Text('颜色: ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          const SizedBox(width: 8),
                          ...[
                            Colors.white,
                            Colors.black,
                            Colors.red,
                            Colors.blue,
                            Colors.yellow,
                            Colors.green,
                            Colors.purple,
                            Colors.orange,
                          ].map((Color color) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _textColor = color;
                                });
                                _generateImage();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColor == color
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey,
                                    width: _textColor == color ? 2.0 : 1.0,
                                  ),
                                ),
                                child: _textColor == color
                                    ? Icon(Icons.check,
                                        size: 16,
                                        color: color.computeLuminance() > 0.5
                                            ? Colors.black
                                            : Colors.white)
                                    : null,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Row 4: Toggles & Settings
                    Row(
                      children: [
                        // Bold
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isBold = !_isBold;
                            });
                            _generateImage();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isBold,
                                onChanged: (v) {
                                  setState(() {
                                    _isBold = v ?? false;
                                  });
                                  _generateImage();
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                              const Text('加粗'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Outline
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isOutline = !_isOutline;
                            });
                            _generateImage();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isOutline,
                                onChanged: (v) {
                                  setState(() {
                                    _isOutline = v ?? false;
                                  });
                                  _generateImage();
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                              const Text('描边'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Outline Width
                        if (_isOutline)
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _outlineWidthController,
                                decoration: const InputDecoration(
                                  labelText: '宽度',
                                  border: OutlineInputBorder(),
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onSubmitted: (_) => _generateImage(),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Max Font Size
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _maxFontSizeController,
                              decoration: const InputDecoration(
                                labelText: '最大字号',
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 8),
                              ),
                              keyboardType: TextInputType.number,
                              onSubmitted: (_) => _generateImage(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Outline Color Picker
                    if (_isOutline) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            const Center(
                                child: Text('描边: ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            ...[
                              Colors.black,
                              Colors.white,
                              Colors.red,
                              Colors.blue,
                              Colors.yellow,
                              Colors.green,
                              Colors.purple,
                              Colors.orange,
                            ].map((Color color) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _outlineColor = color;
                                  });
                                  _generateImage();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _outlineColor == color
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey,
                                      width: _outlineColor == color ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: _outlineColor == color
                                      ? Icon(Icons.check,
                                          size: 16,
                                          color: color.computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white)
                                      : null,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Row 5: Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generateImage,
                            icon: const Icon(Icons.refresh),
                            label: const Text('生成'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _generatedImage != null ? _shareImage : null,
                            icon: const Icon(Icons.share),
                            label: const Text('分享'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _generatedImage != null ? _saveToGallery : null,
                            icon: const Icon(Icons.save_alt),
                            label: const Text('保存'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
