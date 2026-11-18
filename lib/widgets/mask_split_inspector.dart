import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/segmentation_result.dart';

enum InspectorViewMode {
  splitSlider('Split'),
  original('Asli'),
  binaryMask('Masker'),
  contourOverlay('Kontur');

  final String label;
  const InspectorViewMode(this.label);
}

/// Tactile, modern microscopic viewport inspired by high-precision tracking interfaces.
/// Displays an interactive Before/After split curtain slider, zoomable canvas,
/// and minimalist floating controls without visual clutter.
class MaskSplitInspector extends StatefulWidget {
  final SegmentationAnalysisResult analysis;
  final Uint8List? customImageBytes;
  final Uint8List? backendMaskBytes;

  const MaskSplitInspector({
    super.key,
    required this.analysis,
    this.customImageBytes,
    this.backendMaskBytes,
  });

  @override
  State<MaskSplitInspector> createState() => _MaskSplitInspectorState();
}

class _MaskSplitInspectorState extends State<MaskSplitInspector> {
  double _splitFraction = 0.50; // 0.0 to 1.0
  InspectorViewMode _viewMode = InspectorViewMode.splitSlider;
  final TransformationController _transformController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.05) {
      setState(() => _currentScale = scale);
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() => _currentScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final handleX = _splitFraction * constraints.maxWidth;
          return Stack(
            children: [
              // 1. Zoomable Interactive Viewer
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: MicroscopeViewportPainter(
                      splitFraction: _viewMode == InspectorViewMode.splitSlider
                          ? _splitFraction
                          : (_viewMode == InspectorViewMode.original
                              ? 1.0
                              : (_viewMode == InspectorViewMode.binaryMask ? 0.0 : 1.0)),
                      showOverlay: _viewMode == InspectorViewMode.contourOverlay,
                      isParasitized: widget.analysis.specimen.actualClass.isInfected,
                      method: widget.analysis.method,
                    ),
                  ),
                ),
              ),

              // 2. Interactive Drag Handle (Curtain Splitter)
              if (_viewMode == InspectorViewMode.splitSlider)
                Positioned(
                  left: handleX - 18,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitFraction += details.delta.dx / constraints.maxWidth;
                        _splitFraction = _splitFraction.clamp(0.05, 0.95);
                      });
                    },
                    child: SizedBox(
                      width: 36,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Neon-Teal Dividing Line
                            Container(
                              width: 2,
                              height: double.infinity,
                              color: const Color(0xFF14B8A6),
                            ),
                            // Modern Tactile Grip Pill
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F766E), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.code,
                                size: 13,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Top Floating Header Bar (Specimen Pill + Zoom Reset)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Specimen Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.analysis.specimen.actualClass.isInfected
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.analysis.specimen.name.split('(')[0].trim(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• ${widget.analysis.method.code.toUpperCase()}',
                            style: const TextStyle(
                              color: Color(0xFF2DD4BF),
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Zoom Pill
                    InkWell(
                      onTap: _currentScale > 1.05 ? _resetZoom : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_currentScale.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_currentScale > 1.05) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.refresh, size: 11, color: Colors.white70),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Floating Bar (Scale Bar & Mode Switcher)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Optical Scale Bar (5 μm)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.60),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 24, height: 2, color: Colors.white70),
                          const SizedBox(width: 5),
                          const Text(
                            '5 μm',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sleek Floating View Mode Switcher
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: InspectorViewMode.values.map((mode) {
                          final isSel = _viewMode == mode;
                          return InkWell(
                            onTap: () => setState(() => _viewMode = mode),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF0F766E) : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                mode.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                  color: isSel ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// CustomPainter accurately rendering Giemsa stained blood smear erythrocytes
/// and comparative binary segmentation masks (B0/B1/B2/P1) with curtain clipping.
class MicroscopeViewportPainter extends CustomPainter {
  final double splitFraction;
  final bool showOverlay;
  final bool isParasitized;
  final SegmentationMethod method;

  MicroscopeViewportPainter({
    required this.splitFraction,
    required this.showOverlay,
    required this.isParasitized,
    required this.method,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background Canvas
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF090D16));

    // Illumination field gradient (100x microscope condenser lens)
    final fieldGrad = RadialGradient(
      colors: const [Color(0xFF1E1B2E), Color(0xFF090D16)],
      stops: const [0.3, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 120));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..shader = fieldGrad);

    // Subtle microscope reticle grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 28) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 28) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Helper: Draw Left Side (Raw Giemsa Stained Cell)
    void drawRawCell() {
      // Main Erythrocyte (Normal Red Blood Cell Stroma)
      final cellGrad = RadialGradient(
        colors: const [Color(0xFFFDA4AF), Color(0xFFE11D48), Color(0xFF9F1239)],
        stops: const [0.2, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 62));

      canvas.drawCircle(Offset(cx, cy), 62, Paint()..shader = cellGrad);
      canvas.drawCircle(
        Offset(cx, cy),
        62,
        Paint()
          ..color = const Color(0xFF881337)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Central depression (biconcave disc pallor)
      canvas.drawCircle(
        Offset(cx, cy),
        32,
        Paint()
          ..color = const Color(0xFFFECDD3).withValues(alpha: 0.35)
          ..style = PaintingStyle.fill,
      );

      // If Parasitized: Draw Plasmodium falciparum ring stage morphology
      if (isParasitized) {
        final rx = cx - 15;
        final ry = cy - 12;

        // Indigo Cytoplasm Ring
        canvas.drawCircle(
          Offset(rx, ry),
          12,
          Paint()
            ..color = const Color(0xFF3730A3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.2,
        );

        // Dark Magenta/Red Chromatin Dot
        canvas.drawCircle(
          Offset(rx + 9, ry - 6),
          4.8,
          Paint()
            ..color = const Color(0xFF881337)
            ..style = PaintingStyle.fill,
        );
      }

      // Contour Overlay Mode: Draw isolated mathematical contours
      if (showOverlay) {
        // Green RBC membrane boundary
        canvas.drawCircle(
          Offset(cx, cy),
          63,
          Paint()
            ..color = const Color(0xFF10B981)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        // Red Parasite ring boundary
        if (isParasitized) {
          canvas.drawCircle(
            Offset(cx - 15, cy - 12),
            14,
            Paint()
              ..color = const Color(0xFFEF4444)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }
      }
    }

    // Helper: Draw Right Side (Binary Segmentation Mask)
    void drawMask() {
      // Pure black mask background
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF020408));

      if (method == SegmentationMethod.b0) {
        // Whole image baseline: Full rectangular active canvas
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: 140, height: 120),
          Paint()..color = Colors.white,
        );
        return;
      }

      // Outer RBC Contour (Gray border in mask)
      canvas.drawCircle(
        Offset(cx, cy),
        62,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      if (isParasitized) {
        final rx = cx - 15;
        final ry = cy - 12;

        if (method == SegmentationMethod.p1) {
          // Proposed K-Means: Multi-cluster segmentation (Cyan body + Rose core)
          canvas.drawCircle(
            Offset(rx, ry),
            12,
            Paint()..color = const Color(0xFF38BDF8),
          );
          canvas.drawCircle(
            Offset(rx + 9, ry - 6),
            5,
            Paint()..color = const Color(0xFFF43F5E),
          );
        } else if (method == SegmentationMethod.b2) {
          // Adaptive: Crisp edge contour
          canvas.drawCircle(
            Offset(rx, ry),
            12,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5,
          );
        } else {
          // Otsu B1: Solid white binary spot
          canvas.drawCircle(
            Offset(rx, ry),
            11,
            Paint()..color = Colors.white,
          );
        }
      }
    }

    if (splitFraction >= 0.999) {
      drawRawCell();
      return;
    }
    if (splitFraction <= 0.001) {
      drawMask();
      return;
    }

    // Split-Curtain Rendering with ClipRect
    drawRawCell();

    final splitX = splitFraction * size.width;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(splitX, 0, size.width - splitX, size.height));
    drawMask();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MicroscopeViewportPainter old) {
    return old.splitFraction != splitFraction ||
        old.showOverlay != showOverlay ||
        old.isParasitized != isParasitized ||
        old.method != method;
  }
}
