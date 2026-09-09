import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/photo_crop_model.dart';

class CropPhotoScreen extends StatefulWidget {
  final File imageFile;
  final PhotoCropData? initialCropData;

  const CropPhotoScreen({
    super.key,
    required this.imageFile,
    this.initialCropData,
  });

  @override
  State<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends State<CropPhotoScreen> {
  late PhotoCropData _cropData;
  final double _circleSize = 250.0;
  late Image _image;
  Size? _imageSize;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cropData = widget.initialCropData ?? PhotoCropData();

    // Load image to get dimensions
    _image = Image.file(widget.imageFile);
    _image.image.resolve(ImageConfiguration.empty).addListener(
      ImageStreamListener((image, synchronousCall) {
        setState(() {
          _imageSize = Size(
            image.image.width.toDouble(),
            image.image.height.toDouble(),
          );
        });
      }),
    );
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _cropData = _cropData.copyWith(
        offsetX: _cropData.offsetX + details.focalPointDelta.dx,
        offsetY: _cropData.offsetY + details.focalPointDelta.dy,
        scale: (_cropData.scale * details.scale).clamp(1.0, 3.0),
      );
    });
  }

  void _resetCrop() {
    setState(() {
      _cropData = PhotoCropData();
    });
  }

  Future<void> _saveCrop() async {
    setState(() => _isProcessing = true);

    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/profile_image_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Just copy the original file, don't crop it
      await widget.imageFile.copy(tempFile.path);

      if (mounted) {
        Navigator.pop(context, {
          'cropData': _cropData,
          'croppedFile': tempFile,
        });
      }
    } catch (e) {
      print('Error saving image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Profile Photo'),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
      body: Column(
        children: [
          // Crop Canvas Area
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: GestureDetector(
                  onScaleUpdate: _handleScaleUpdate,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Image with transforms
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.translationValues(_cropData.offsetX, _cropData.offsetY, 0)
                          ..multiply(Matrix4.diagonal3Values(_cropData.scale, _cropData.scale, 1.0)),
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                          width: _imageSize?.width ?? 300,
                          height: _imageSize?.height ?? 300,
                        ),
                      ),

                      // Circular guide overlay
                      Container(
                        width: _circleSize,
                        height: _circleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white70,
                            width: 2,
                          ),
                        ),
                      ),

                      // Darkened areas outside circle
                      CustomPaint(
                        painter: CircleVignettePainter(
                          radius: _circleSize / 2,
                        ),
                        size: Size.infinite,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Preview + Controls
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imageSize != null
                        ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.translationValues(
                        (_cropData.offsetX / _circleSize) * 120,
                        (_cropData.offsetY / _circleSize) * 120,
                        0,
                        )
                        ..multiply(Matrix4.diagonal3Values(_cropData.scale, _cropData.scale, 1.0)),
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const CircularProgressIndicator(),
                  ),
                ),
                const SizedBox(height: 20),

                // Zoom slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zoom: ${_cropData.scale.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Slider(
                      value: _cropData.scale,
                      min: 1.0,
                      max: 3.0,
                      activeColor: const Color(0xFFEA2327),
                      inactiveColor: Colors.grey[700],
                      onChanged: (value) {
                        setState(() {
                          _cropData = _cropData.copyWith(scale: value);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _resetCrop,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _saveCrop,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA2327),
                          foregroundColor: Colors.white,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that darkens areas outside the circular crop region
class CircleVignettePainter extends CustomPainter {
  final double radius;

  CircleVignettePainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw semi-transparent overlay outside circle
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw rectangle covering entire canvas
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Clear the circular area with a circle path
    final circlePath = Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.clipPath(circlePath, doAntiAlias: true);
    canvas.drawColor(Colors.transparent, BlendMode.clear);
  }

  @override
  bool shouldRepaint(CircleVignettePainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}