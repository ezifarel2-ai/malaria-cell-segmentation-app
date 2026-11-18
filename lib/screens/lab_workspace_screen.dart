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

/// Main Laboratory Workspace Screen integrating:
/// - Persistent non-clinical ethical disclaimer banners
/// - Optical calibration & backend API health status
/// - Interactive pipeline configurator (B0, B1, B2, P1 + SVM/KNN)
/// - Microscope split-curtain inspector & feature breakdown cards
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

  void _showProjectAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.biotech, color: AppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Proyek Kelompok 4', style: AppTheme.titleMedium),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mata Kuliah: Pengolahan Citra Digital\n'
                'Judul: Evaluasi Metode Segmentasi Sel pada Klasifikasi Citra Mikroskopis Malaria Berbasis Fitur Handcrafted\n\n'
                'Metode Segmentasi yang Dievaluasi:\n'
                '• B0: Baseline Tanpa Segmentasi (Seluruh Citra)\n'
                '• B1: Otsu Thresholding & Morfologi\n'
                '• B2: Adaptive Gaussian Thresholding\n'
                '• P1: K-Means Lab Color Space Clustering (Usulan)\n\n'
                'Target Jurnal:\n'
                'Progresif: Jurnal Ilmiah Komputer (SINTA 4)\n\n'
                'Aturan Validasi:\n'
                'Random seed 42, StandardScaler dipelajari hanya dari data training, '
                'evaluasi ketahanan (robustness) terhadap variasi pencahayaan dan pewarnaan.',
                style: AppTheme.bodyRegular,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: AppTheme.primaryTeal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isParasitized = _analysis.predictedClass == CellClass.parasitized;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTealLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryTealBorder, width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      'μS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('MalariaVision Lab', style: AppTheme.titleLarge),
              ],
            ),
            const Text(
              'Digital Pathology & Feature Engineering Workstation',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          // Live Backend Health Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _isBackendOnline ? AppTheme.statusUninfectedBg : AppTheme.warningAmberBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isBackendOnline ? AppTheme.statusUninfectedBorder : AppTheme.warningAmberBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isBackendOnline ? AppTheme.statusUninfected : AppTheme.warningAmber,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isBackendOnline ? 'API :5000' : 'Standby',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: _isBackendOnline ? AppTheme.statusUninfected : AppTheme.warningAmber,
                    fontFeatures: AppTheme.tabularFeature,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Panduan & Ketentuan Proyek',
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: _showProjectAboutDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.borderHairline, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Persistent Top Ethical Disclaimer Banner
          _buildTopEthicalBanner(),

          // Progress indicator during inference
          if (_isProcessing)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: AppTheme.borderHairline,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
            ),

          // Scrollable Lab Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Image Source & Specimen Selector Card
                  _buildSpecimenSelectorCard(),
                  const SizedBox(height: 12),

                  // Section 2: Pipeline Configurator (Methods B0/B1/B2/P1 & Classifier)
                  _buildPipelineConfiguratorCard(),
                  const SizedBox(height: 12),

                  // Section 3: Classification Diagnostic Outcome Banner
                  _buildDiagnosticSummaryBanner(isParasitized),
                  const SizedBox(height: 12),

                  // Section 4: Interactive Microscope Split-Screen Inspector
                  MaskSplitInspector(
                    analysis: _analysis,
                    customImageBytes: _customImageBytes,
                    backendMaskBytes: _backendMaskBytes,
                  ),
                  const SizedBox(height: 12),

                  // Section 5: Handcrafted Feature Breakdown (Geometry, Color, Texture, Latency)
                  FeatureBreakdownCard(analysis: _analysis),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Persistent Bottom Non-Clinical Legal Disclaimer
          _buildBottomEthicalFooter(),
        ],
      ),
    );
  }

  Widget _buildTopEthicalBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: AppTheme.warningAmberBg,
        border: Border(bottom: BorderSide(color: AppTheme.warningAmberBorder, width: 1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 14, color: AppTheme.warningAmber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Research Prototype Only: Computational image classification tool, not for clinical medical diagnosis.',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomEthicalFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        border: Border(top: BorderSide(color: AppTheme.borderHairline, width: 1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pengolahan Citra Digital • Kelompok 4',
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
          Text(
            'Target SINTA 4 (Jurnal Progresif)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTealDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecimenSelectorCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderHairline, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SELECT SPECIMEN SLIDE', style: AppTheme.sectionHeader),
              Text(
                _selectedSample.id,
                style: AppTheme.tabularMono.copyWith(color: AppTheme.primaryTealDark),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preset Biological Samples Chips
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
                        color: isSelected ? AppTheme.primaryTealLight : AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryTealBorder : AppTheme.borderHairline,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sample.actualClass.isInfected
                                  ? AppTheme.statusParasitized
                                  : AppTheme.statusUninfected,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sample.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

          // Action Buttons: Camera Microscope & Gallery Upload
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryTeal,
                    side: const BorderSide(color: AppTheme.primaryTealBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Camera Microscope', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.borderHairline),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Upload Cell Image', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineConfiguratorCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderHairline, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PIPELINE CONFIGURATOR', style: AppTheme.sectionHeader),
              // Classifier Selector Toggle
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCanvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderHairline),
                ),
                child: Row(
                  children: ClassifierType.values.map((c) {
                    final isSel = _selectedClassifier == c;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedClassifier = c);
                        _recomputeAnalysis();
                      },
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          c.label.split(' ')[0], // SVM or KNN
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4-Method Segmented Cards: B0, B1, B2, P1
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryTealLight : AppTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel ? AppTheme.primaryTealBorder : AppTheme.borderHairline,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            method.shortLabel.split(' ')[0], // B0, B1, B2, P1
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: isSel ? AppTheme.primaryTealDark : AppTheme.textPrimary,
                              fontFeatures: AppTheme.tabularFeature,
                            ),
                          ),
                          Text(
                            method.isProposed ? 'Usulan' : 'Baseline',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildDiagnosticSummaryBanner(bool isParasitized) {
    return Container(
      decoration: BoxDecoration(
        color: isParasitized ? AppTheme.statusParasitizedBg : AppTheme.statusUninfectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isParasitized ? AppTheme.statusParasitizedBorder : AppTheme.statusUninfectedBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isParasitized ? AppTheme.statusParasitized : AppTheme.statusUninfected,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isParasitized ? 'DETECTION: POSITIVE (+1)' : 'DETECTION: NEGATIVE (0)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      fontFamily: 'monospace',
                      color: isParasitized ? AppTheme.statusParasitized : AppTheme.statusUninfected,
                    ),
                  ),
                ],
              ),
              Text(
                'Confidence: ${_analysis.confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontFeatures: AppTheme.tabularFeature,
                  color: isParasitized ? AppTheme.statusParasitized : AppTheme.statusUninfected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _analysis.predictedClass.label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isParasitized ? AppTheme.statusParasitized : AppTheme.statusUninfected,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isParasitized ? AppTheme.statusParasitizedBorder : AppTheme.statusUninfectedBorder,
                  ),
                ),
                child: Text(
                  _analysis.maskStatus,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isParasitized ? AppTheme.statusParasitized : AppTheme.statusUninfected,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
