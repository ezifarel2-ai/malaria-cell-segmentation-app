"""
Server REST API Flask untuk Aplikasi Deteksi Citra Malaria
Mendukung inferensi pipeline PCD (Preprocessing, Segmentasi Otsu/Adaptive/K-Means, Ekstraksi Fitur, dan Klasifikasi)
"""

import time
import os
import sys

# Tambahkan direktori root dan backend ke sys.path
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, '..'))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from flask import Flask, request, jsonify

try:
    from backend.pipeline import MalariaImagePipeline
    from backend.model_manager import MalariaModelManager
except ImportError:
    from pipeline import MalariaImagePipeline
    from model_manager import MalariaModelManager

app = Flask(__name__)
pipeline = MalariaImagePipeline(target_size=(128, 128))
model_manager = MalariaModelManager()

# Tambahkan CORS manual sederhana agar kompatibel di semua platform
@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET,PUT,POST,DELETE,OPTIONS'
    return response

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        'service': 'Malaria Cell Image Processing API',
        'project': 'Proyek Kelompok 4 - Pengolahan Citra Digital',
        'status': 'running',
        'endpoints': {
            'health': '/api/health',
            'analyze': '/api/analyze (POST multipart/form-data)'
        }
    })

@app.route('/api/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'models_ready': model_manager.has_production_models,
        'supported_methods': [
            {'id': 'b0', 'name': 'Baseline (Seluruh Citra)'},
            {'id': 'b1', 'name': 'Otsu Thresholding (B1)'},
            {'id': 'b2', 'name': 'Adaptive Thresholding (B2)'},
            {'id': 'p1', 'name': 'K-Means Color Clustering (P1 Usulan)'}
        ],
        'supported_classifiers': ['svm', 'knn']
    })

@app.route('/api/analyze', methods=['POST'])
def analyze():
    start_time = time.time()

    if 'file' not in request.files:
        return jsonify({'error': 'Parameter file citra tidak ditemukan pada form-data.'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'Nama file kosong.'}), 400

    # Ambil opsi metode segmentasi dan classifier dari form
    method = request.form.get('method', 'p1').lower() # 'b0', 'b1', 'b2', 'p1'
    classifier = request.form.get('classifier', 'svm').lower() # 'svm', 'knn'

    try:
        img_bytes = file.read()
        if len(img_bytes) == 0:
            return jsonify({'error': 'File citra kosong.'}), 400

        # 1. Jalankan Pipeline PCD (Preprocessing, Segmentasi, Ekstraksi Fitur)
        prep_start = time.time()
        pcd_result = pipeline.process_full(img_bytes, method=method)
        prep_time_ms = round((time.time() - prep_start) * 1000, 1)

        # 2. Jalankan Inferensi Classifier
        infer_start = time.time()
        prediction_result = model_manager.predict(
            feature_vector=pcd_result['features']['vector'],
            features_dict=pcd_result['features'],
            classifier_type=classifier
        )
        infer_time_ms = round((time.time() - infer_start) * 1000, 1)
        total_time_ms = round((time.time() - start_time) * 1000, 1)

        # 3. Bentuk Respons JSON lengkap
        method_names = {
            'b0': 'Baseline (Seluruh Citra)',
            'b1': 'Otsu Thresholding (B1)',
            'b2': 'Adaptive Thresholding (B2)',
            'p1': 'K-Means Clustering (P1 Usulan)'
        }

        response_data = {
            'status': 'success',
            'method_id': method,
            'method_name': method_names.get(method, method.upper()),
            'classifier': prediction_result['model_name'],
            'prediction': prediction_result['prediction'],
            'confidence': prediction_result['confidence'],
            'mask_status': pcd_result['mask_status'],
            'mask_base64': pcd_result['mask_base64'],
            'features': {
                'shape': pcd_result['features']['shape'],
                'color': pcd_result['features']['color'],
                'texture': pcd_result['features']['texture'],
            },
            'timing': {
                'preprocessing_ms': prep_time_ms,
                'inference_ms': infer_time_ms,
                'total_ms': total_time_ms
            },
            'is_production_model': prediction_result['is_production_model'],
            'notes': 'Hasil klasifikasi untuk komputasi & riset (Bukan alat diagnosis klinis resmi).'
        }

        return jsonify(response_data), 200

    except Exception as e:
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"Server Flask berjalan di http://0.0.0.0:{port}")
    app.run(host='0.0.0.0', port=port, debug=False)

