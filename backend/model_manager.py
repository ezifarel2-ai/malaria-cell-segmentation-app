"""
Pengelola Model Klasifikasi (SVM & KNN) untuk Sel Malaria
Mendukung model terlatih (.pkl) dari Colab maupun fallback heuristic selama masa review dosen.
"""

import os
import joblib
import numpy as np

class MalariaModelManager:
    def __init__(self, models_dir=None):
        if models_dir is None:
            models_dir = os.path.join(os.path.dirname(__file__), 'models')
        self.models_dir = models_dir
        self.svm_path = os.path.join(self.models_dir, 'svm_model.pkl')
        self.knn_path = os.path.join(self.models_dir, 'knn_model.pkl')
        self.scaler_path = os.path.join(self.models_dir, 'scaler.pkl')

        self.svm_model = None
        self.knn_model = None
        self.scaler = None
        self.has_production_models = False

        self._load_models_if_available()

    def _load_models_if_available(self):
        """Memeriksa apakah model .pkl dari Colab sudah diexport dan disimpan."""
        try:
            if os.path.exists(self.scaler_path):
                self.scaler = joblib.load(self.scaler_path)
            if os.path.exists(self.svm_path):
                self.svm_model = joblib.load(self.svm_path)
            if os.path.exists(self.knn_path):
                self.knn_model = joblib.load(self.knn_path)

            if self.svm_model is not None and self.scaler is not None:
                self.has_production_models = True
                print("[ModelManager] Model produksi dari Colab berhasil dimuat!")
            else:
                print("[ModelManager] Belum ada model .pkl di backend/models/. Menggunakan mode Heuristic Review.")
        except Exception as e:
            print(f"[ModelManager] Gagal memuat file model .pkl: {e}. Menggunakan fallback.")

    def predict(self, feature_vector, features_dict, classifier_type='svm'):
        """
        Melakukan prediksi kelas ('Parasitized' atau 'Uninfected')
        dengan tingkat keyakinan (confidence %).
        """
        classifier_type = classifier_type.lower()
        selected_model = self.svm_model if classifier_type == 'svm' else self.knn_model

        # JIKA MODEL PKL TERSEDIA (Setelah review dosen selesai)
        if self.has_production_models and selected_model is not None and self.scaler is not None:
            try:
                scaled_vector = self.scaler.transform([feature_vector])
                prediction_idx = selected_model.predict(scaled_vector)[0]
                
                # Coba ambil probabilitas jika didukung
                if hasattr(selected_model, "predict_proba"):
                    proba = selected_model.predict_proba(scaled_vector)[0]
                    confidence = float(np.max(proba) * 100)
                else:
                    confidence = 90.0

                label = "Parasitized" if (prediction_idx == 1 or str(prediction_idx).lower() in ['1', 'parasitized']) else "Uninfected"
                return {
                    'prediction': label,
                    'confidence': round(confidence, 1),
                    'is_production_model': True,
                    'model_name': f"{classifier_type.upper()} (Trained Colab Model)"
                }
            except Exception as e:
                print(f"[ModelManager] Error saat inferensi model pkl: {e}. Mengalihkan ke heuristic...")

        # JIKA BELUM ADA MODEL PKL (Fallback Heuristic Berdasarkan Fitur Citra Giemsa)
        # Sel terinfeksi malaria memiliki:
        # 1. Kontras GLCM lebih tinggi karena adanya granula / cincin parasit
        # 2. Standar deviasi warna L dan b_ch yang lebih lebar
        # 3. Rasio area parasit terhadap sel
        glcm_contrast = features_dict['texture']['glcm_contrast']
        glcm_homogeneity = features_dict['texture']['glcm_homogeneity']
        std_l = features_dict['color']['std_l']
        circularity = features_dict['shape']['circularity']

        # Skor anomali tekstur & warna sitoplasma
        anomaly_score = (glcm_contrast * 0.05) + (std_l * 0.15) - (glcm_homogeneity * 10.0)
        
        # Penyesuaian ambang batas
        if anomaly_score > 3.5 or (std_l > 18.0 and glcm_contrast > 20.0):
            label = "Parasitized"
            raw_conf = 88.0 + min(11.0, (anomaly_score - 3.5) * 3.0)
        else:
            label = "Uninfected"
            raw_conf = 90.0 + min(9.0, (3.5 - anomaly_score) * 2.5)

        confidence = min(99.0, max(75.0, raw_conf))

        return {
            'prediction': label,
            'confidence': round(confidence, 1),
            'is_production_model': False,
            'model_name': f"{classifier_type.upper()} (Heuristic / Standby Review)"
        }

