import 'package:flutter/material.dart';
import '../models/segmentation_result.dart';
import '../theme/app_theme.dart';

/// Clean, expandable cards displaying the quantitative handcrafted feature vector
/// and computation latency breakdown for the selected segmentation pipeline.
class FeatureBreakdownCard extends StatefulWidget {
  final SegmentationAnalysisResult analysis;

  const FeatureBreakdownCard({super.key, required this.analysis});

  @override
  State<FeatureBreakdownCard> createState() => _FeatureBreakdownCardState();
}

class _FeatureBreakdownCardState extends State<FeatureBreakdownCard> {
  bool _isGeometryExpanded = true;
  bool _isTextureExpanded = true;
  bool _isLatencyExpanded = true;

  @override
  Widget build(BuildContext context) {
    final shape = widget.analysis.shape;
    final texture = widget.analysis.colorTexture;
    final latency = widget.analysis.latency;
    final isParasitized = widget.analysis.specimen.actualClass.isInfected;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderHairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Master Header
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
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
                    const Text('HANDCRAFTED FEATURE VECTOR', style: AppTheme.sectionHeader),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCanvas,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderHairline),
                  ),
                  child: const Text(
                    '15 Parameters',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: AppTheme.textMuted,
                      fontFeatures: AppTheme.tabularFeature,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Section 1: Geometry & Morphology
          _buildCollapsibleSection(
            title: '1. Geometry & Morphology',
            subtitle: 'Contour bounds, perimeter, and biconcave circularity',
            isExpanded: _isGeometryExpanded,
            onToggle: () => setState(() => _isGeometryExpanded = !_isGeometryExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: Column(
                children: [
                  _buildMetricRow(
                    label: 'Object Area',
                    value: '${shape.area.toStringAsFixed(1)} px²',
                    subvalue: 'Area Ratio: ${(shape.areaRatio * 100).toStringAsFixed(1)}%',
                    barFraction: shape.areaRatio.clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'Perimeter',
                    value: '${shape.perimeter.toStringAsFixed(1)} px',
                    subvalue: 'Arc Length',
                    barFraction: (shape.perimeter / 300.0).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'Circularity (4π·Area / P²)',
                    value: shape.circularity.toStringAsFixed(3),
                    subvalue: shape.circularity > 0.90 ? 'Regular Disc' : 'Irregular Fringe',
                    barFraction: shape.circularity.clamp(0.0, 1.0),
                    highlightColor: shape.circularity > 0.90 ? AppTheme.statusUninfected : null,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Section 2: Color Space & Texture (GLCM / LBP)
          _buildCollapsibleSection(
            title: '2. Color & Texture (GLCM & LBP)',
            subtitle: 'CIE Lab dispersion, spatial co-occurrence, and micro-patterns',
            isExpanded: _isTextureExpanded,
            onToggle: () => setState(() => _isTextureExpanded = !_isTextureExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: Column(
                children: [
                  _buildMetricRow(
                    label: 'GLCM Contrast',
                    value: '${texture.glcmContrast.toStringAsFixed(2)} px',
                    subvalue: isParasitized ? '+210% (Ring Elevation)' : 'Homogeneous Stroma',
                    barFraction: (texture.glcmContrast / 30.0).clamp(0.0, 1.0),
                    highlightColor: isParasitized ? AppTheme.statusParasitized : null,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'GLCM Homogeneity',
                    value: texture.glcmHomogeneity.toStringAsFixed(3),
                    subvalue: 'Inverse Difference Moment',
                    barFraction: texture.glcmHomogeneity.clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'CIE L* Lightness Dispersion',
                    value: 'Mean: ${texture.meanL.toStringAsFixed(1)} (σ: ${texture.stdL.toStringAsFixed(1)})',
                    subvalue: isParasitized ? 'Heterogeneous Cytoplasm' : 'Uniform RBC Stroma',
                    barFraction: (texture.stdL / 25.0).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'CIE a* Giemsa Chromatin',
                    value: '+${texture.meanA.toStringAsFixed(2)}',
                    subvalue: 'Magenta-Cyan Chroma Vector',
                    barFraction: (texture.meanA / 30.0).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'LBP Micro-texture Energy',
                    value: texture.lbpEnergy.toStringAsFixed(4),
                    subvalue: 'P=8, R=1 Uniform Pattern',
                    barFraction: (texture.lbpEnergy / 0.8).clamp(0.0, 1.0),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Section 3: Latency & Execution Breakdown
          _buildCollapsibleSection(
            title: '3. Execution Latency Breakdown',
            subtitle: 'Computational time per pipeline stage (Academic Paper Metric)',
            isExpanded: _isLatencyExpanded,
            onToggle: () => setState(() => _isLatencyExpanded = !_isLatencyExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pipeline Latency', style: AppTheme.bodyMedium),
                      Text(
                        '${latency.totalMs} ms',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryTealDark,
                          fontFeatures: AppTheme.tabularFeature,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Stacked Horizontal Latency Breakdown Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          Expanded(
                            flex: latency.prepAndSegMs.clamp(1, 1000),
                            child: Container(color: const Color(0xFF0F766E)), // Prep
                          ),
                          Expanded(
                            flex: latency.featureExtractionMs.clamp(1, 1000),
                            child: Container(color: const Color(0xFF14B8A6)), // Feat
                          ),
                          Expanded(
                            flex: latency.classificationMs.clamp(1, 1000),
                            child: Container(color: const Color(0xFF2DD4BF)), // Infer
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Latency Stage Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLatencyLegend('Prep & Seg', '${latency.prepAndSegMs} ms', const Color(0xFF0F766E)),
                      _buildLatencyLegend('Features', '${latency.featureExtractionMs} ms', const Color(0xFF14B8A6)),
                      _buildLatencyLegend('Model Infer', '${latency.classificationMs} ms', const Color(0xFF2DD4BF)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Section 4: Explainable AI (XAI) Natural Language Summary
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.primaryTealLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology_outlined, size: 16, color: AppTheme.primaryTealDark),
                      SizedBox(width: 6),
                      Text(
                        'Explainable AI (XAI) Insight:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTealDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.analysis.xaiExplanation,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF115E59),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.titleMedium),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: AppTheme.bodyRegular,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) child,
      ],
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required String subvalue,
    required double barFraction,
    Color? highlightColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTheme.metricLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: highlightColor ?? AppTheme.textPrimary,
                    fontFeatures: AppTheme.tabularFeature,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '($subvalue)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: highlightColor ?? AppTheme.textMuted,
                    fontWeight: highlightColor != null ? FontWeight.w600 : FontWeight.normal,
                    fontFeatures: AppTheme.tabularFeature,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: barFraction,
            minHeight: 4,
            backgroundColor: AppTheme.borderHairline,
            valueColor: AlwaysStoppedAnimation<Color>(highlightColor ?? AppTheme.primaryTeal),
          ),
        ),
      ],
    );
  }

  Widget _buildLatencyLegend(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            fontFeatures: AppTheme.tabularFeature,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
