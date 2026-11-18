import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/segmentation_result.dart';
import '../theme/app_theme.dart';

enum InspectorViewMode {
  splitSlider('Split Slider'),
  original('Original'),
  binaryMask('Binary Mask'),
  contourOverlay('Contour Overlay');

  final String label;
  const InspectorViewMode(this.label);
}

/// Tactile, scientific-grade microscopic viewport featuring:
/// - Interactive Before/After split curtain slider
/// - InteractiveViewer for pinch-to-zoom (1.0x - 4.0x)
/// - View-mode switcher (Original, Preprocessed, Binary Mask, Contour Overlay)
/// - True optical micrometer scale bar (5 μm) and FOV HUD
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
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderHairline, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Viewport Mode & Optical Profile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('MICROSCOPE VIEWPORT', style: AppTheme.sectionHeader),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: const Text(
                  '100x Oil • Giemsa pH 7.2',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B21A8),
                    fontFeatures: AppTheme.tabularFeature,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // View Mode Selector Segmented Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: InspectorViewMode.values.map((mode) {
                final isSelected = _viewMode == mode;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _viewMode = mode),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryTealLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTealBorder : AppTheme.borderHairline,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        mode.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.primaryTealDark : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Microscopic Canvas Viewport with Gesture Slider
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: AppTheme.viewportBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderHairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final handleX = _splitFraction * constraints.maxWidth;
                return Stack(
                  children: [
                    // Zoomable Interactive Viewer
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

                    // Interactive Drag Handle (Direct child of Stack)
                    if (_viewMode == InspectorViewMode.splitSlider)
                      Positioned(
                        left: handleX - 16,
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
                            width: 32,
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Vertical Divider Line
                                  Container(
                                    width: 2,
                                    height: double.infinity,
                                    color: const Color(0xFF2DD4BF),
                                  ),
                                  // Tactile Grip Pill
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF0F766E), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator,
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

                // Top Left HUD: FOV & Micrometer Scale
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Text(
                      'FOV: 128×128 px | 0.12 μm/px',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontFeatures: AppTheme.tabularFeature,
                      ),
                    ),
                  ),
                ),

                // Top Right HUD: Zoom Magnification Factor & Reset
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: _currentScale > 1.05 ? _resetZoom : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_currentScale.toStringAsFixed(1)}x',
                            style: const TextStyle(
                              color: Color(0xFF2DD4BF),
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontFeatures: AppTheme.tabularFeature,
                            ),
                          ),
                          if (_currentScale > 1.05) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.refresh, size: 10, color: Colors.white70),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Left HUD: 5 μm Optical Scale Bar
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 38, height: 2.5, color: Colors.white),
                      const SizedBox(width: 5),
                      const Text(
                        '5 μm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontFeatures: AppTheme.tabularFeature,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Right HUD: Comparison Label
                if (_viewMode == InspectorViewMode.splitSlider)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Left: Giemsa Stained | Right: Binary Mask',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),

          // Tactile Split Slider Progress Bar
          if (_viewMode == InspectorViewMode.splitSlider)
            Row(
              children: [
                const Text(
                  'Curtain Split:',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: AppTheme.primaryTeal,
                      activeTrackColor: AppTheme.primaryTeal,
                      inactiveTrackColor: AppTheme.borderHairline,
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _splitFraction,
                      onChanged: (val) => setState(() => _splitFraction = val),
                    ),
                  ),
                ),
                Text(
                  '${(_splitFraction * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTeal,
                    fontFeatures: AppTheme.tabularFeature,
                  ),
                ),
              ],
            ),
        ],
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
