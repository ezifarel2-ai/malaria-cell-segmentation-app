import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/segmentation_result.dart';
import '../theme/app_theme.dart';
import '../widgets/feature_breakdown_card.dart';
import '../widgets/mask_split_inspector.dart';

/// Clean, modern, tactile Laboratory Workspace Screen.
/// Follows modern tracking/analytical app design principles:
/// 1. Prominent Hero Microscope Viewport with interactive split slider.
/// 2. Clean, high-contrast Diagnostic Status Card.
/// 3. Minimalist Method & Classifier Selector.
/// 4. Streamlined Specimen Slides and Image Capture Actions.
/// 5. On-demand Technical PCD Feature Vector Breakdown.
class LabWorkspaceScreen extends StatefulWidget {
  const LabWorkspaceScreen({super.key});

  @override
  State<LabWorkspaceScreen> createState() => _LabWorkspaceScreenState();
}

class _LabWorkspaceScreenState extends State<LabWorkspaceScreen> {
  final ImagePicker _picker = ImagePicker();

  final String _backendBaseUrl = kIsWeb
      ? 'http://localhost:5000'
      : (Platform.isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000');
  bool _isBackendOnline = false;

  SpecimenSample _selectedSample = MockAnalysisRepository.presetSamples[0];
  SegmentationMethod _selectedMethod = SegmentationMethod.p1;
  ClassifierType _selectedClassifier = ClassifierType.svm;

  late SegmentationAnalysisResult _analysis;
  bool _isProcessing = false;
  bool _showFeatureDetails = false;

  Uint8List? _customImageBytes;
  Uint8List? _backendMaskBytes;

  @override
  void initState() {
    super.initState();
    _recomputeAnalysis();
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    try {
      final res = await http.get(Uri.parse('$_backendBaseUrl/api/health')).timeout(
        const Duration(seconds: 3),
      );
      if (mounted) {
        setState(() => _isBackendOnline = res.statusCode == 200);
      }
    } catch (_) {
      if (mounted) setState(() => _isBackendOnline = false);
    }
  }

  void _recomputeAnalysis() {
    setState(() {
      _analysis = MockAnalysisRepository.evaluate(
        specimen: _selectedSample,
        method: _selectedMethod,
        classifier: _selectedClassifier,
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _customImageBytes = bytes;
          _backendMaskBytes = null;
        });
        _runInferenceWithBackendOrFallback();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat citra: $e')),
      );
    }
  }

  Future<void> _runInferenceWithBackendOrFallback() async {
    setState(() => _isProcessing = true);

    if (_customImageBytes != null && _isBackendOnline) {
      try {
        final uri = Uri.parse('$_backendBaseUrl/api/analyze');
        final req = http.MultipartRequest('POST', uri);
        req.fields['method'] = _selectedMethod.code;
        req.fields['classifier'] = _selectedClassifier.code;
        req.files.add(
          http.MultipartFile.fromBytes('file', _customImageBytes!, filename: 'sample.png'),
        );

        final streamed = await req.send().timeout(const Duration(seconds: 10));
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          if (mounted) {
            final b64 = data['mask_base64'];
            if (b64 != null) {
              _backendMaskBytes = base64Decode(b64);
            }
          }
        }
      } catch (_) {
        // Fallback to local evaluation
      }
    }

    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      _recomputeAnalysis();
      setState(() => _isProcessing = false);
    }
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Informasi Proyek Riset', style: AppTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evaluasi Metode Segmentasi Citra Sel Malaria Berbasis Fitur Handcrafted',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.3),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Mata Kuliah: Pengolahan Citra Digital (PCD)\n'
                        'Kelompok 4 • Dosen: Rangga Pebrianto, M.Kom.\n'
                        'Target Publikasi: SINTA 4 (Jurnal Progresif)',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmberBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warningAmberBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.gavel_outlined, size: 18, color: Color(0xFFB45309)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Catatan Etika: Aplikasi ini adalah purwarupa komputasi citra digital untuk evaluasi akademis, bukan alat diagnosis klinis resmi.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isParasitized = _analysis.predictedClass == CellClass.parasitized;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 18,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('MalariaVision', style: AppTheme.titleMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTealLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Kelompok 4',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Evaluasi Segmentasi Sel & Ekstraksi Fitur PCD',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          // Minimalist Online Status Pill
          InkWell(
            onTap: _checkBackendHealth,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _isBackendOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isBackendOnline ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isBackendOnline ? const Color(0xFF10B981) : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isBackendOnline ? 'Online' : 'Standby',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _isBackendOnline ? const Color(0xFF047857) : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20, color: AppTheme.textSecondary),
            onPressed: _showInfoSheet,
            tooltip: 'Tentang Riset',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: Column(
        children: [
          if (_isProcessing)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================
                  // 1. HERO: MICROSCOPE VIEWPORT WITH SPLIT SLIDER
                  // ==========================================
                  MaskSplitInspector(
                    analysis: _analysis,
                    customImageBytes: _customImageBytes,
                    backendMaskBytes: _backendMaskBytes,
                  ),
                  const SizedBox(height: 14),

                  // ==========================================
                  // 2. DIAGNOSTIC RESULT CARD (Tracking App Style)
                  // ==========================================
                  _buildDiagnosticCard(isParasitized),
                  const SizedBox(height: 14),

                  // ==========================================
                  // 3. SEGMENTATION METHOD & CLASSIFIER SWITCHER
                  // ==========================================
                  _buildMethodSelector(),
                  const SizedBox(height: 14),

                  // ==========================================
                  // 4. SPECIMEN SELECTION & CAPTURE ACTIONS
                  // ==========================================
                  _buildSpecimenAndActions(),
                  const SizedBox(height: 14),

                  // ==========================================
                  // 5. ON-DEMAND FEATURE VECTOR (XAI COLLAPSIBLE)
                  // ==========================================
                  _buildCollapsibleFeatureSection(),
                  const SizedBox(height: 20),

                  // Subtle Non-intrusive Academic Footer
                  Center(
                    child: Text(
                      'Purwarupa Riset PCD Kelompok 4 • Non-Klinis • Target SINTA 4',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// High-contrast, tactile status card inspired by modern shipment tracking interfaces
  Widget _buildDiagnosticCard(bool isParasitized) {
    final badgeBg = isParasitized ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final badgeBorder = isParasitized ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0);
    final primaryColor = isParasitized ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status & Confidence Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isParasitized ? 'TERDETEKSI PARASIT' : 'SEL DARAH NORMAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isParasitized ? 'Parasitized (+1)' : 'Uninfected (0)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              // Confidence Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      '${_analysis.confidence.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        fontFeatures: AppTheme.tabularFeature,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Keyakinan',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Confidence Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_analysis.confidence / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 12),

          // Micro Stats Row (Method, Model, Latency)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Metode', _selectedMethod.code.toUpperCase()),
                _buildStatItem('Klasifikasi', _selectedClassifier.label.split(' ')[0]),
                _buildStatItem('Latensi', '${_analysis.latency.totalMs} ms'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Modern segmented selector for PCD methods & SVM/KNN toggle
  Widget _buildMethodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'METODE SEGMENTASI',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textMuted,
                ),
              ),
              // Inline Classifier Toggle
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedClassifier = _selectedClassifier == ClassifierType.svm
                        ? ClassifierType.knn
                        : ClassifierType.svm;
                  });
                  _recomputeAnalysis();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune, size: 12, color: AppTheme.primaryTealDark),
                      const SizedBox(width: 4),
                      Text(
                        'Model: ${_selectedClassifier.label.split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTealDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Clean Method Pills
          Row(
            children: SegmentationMethod.values.map((method) {
              final isSel = _selectedMethod == method;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedMethod = method);
                      _recomputeAnalysis();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryTealLight : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppTheme.primaryTealBorder : const Color(0xFFE2E8F0),
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            method.code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: isSel ? AppTheme.primaryTealDark : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            method.isProposed ? 'Usulan' : 'Baseline',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? AppTheme.primaryTeal : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Compact specimen slides and modern capture buttons
  Widget _buildSpecimenAndActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SAMPEL PREPARAT DARAH',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                _selectedSample.id,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal specimen chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MockAnalysisRepository.presetSamples.map((sample) {
                final isSelected = _selectedSample.id == sample.id && _customImageBytes == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSample = sample;
                        _customImageBytes = null;
                        _backendMaskBytes = null;
                      });
                      _recomputeAnalysis();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryTealLight : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTealBorder : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sample.actualClass.isInfected
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sample.name.split('(')[0].trim(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppTheme.primaryTealDark : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Modern Action Buttons (Camera & Gallery)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text(
                    'Ambil Foto',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text(
                    'Pilih Galeri',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Collapsible feature breakdown (keeps default view ultra clean)
  Widget _buildCollapsibleFeatureSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _showFeatureDetails = !_showFeatureDetails),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 17, color: AppTheme.primaryTeal),
                      const SizedBox(width: 8),
                      Text(
                        _showFeatureDetails
                            ? 'Sembunyikan Rincian Fitur PCD'
                            : 'Lihat Rincian Fitur Handcrafted (XAI)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTealDark,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showFeatureDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_showFeatureDetails) ...[
            const Divider(height: 1),
            FeatureBreakdownCard(analysis: _analysis),
          ],
        ],
      ),
    );
  }
}
