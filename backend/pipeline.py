"""
Pipeline Pengolahan Citra Digital (PCD) untuk Klasifikasi Sel Darah Malaria
Berdasarkan Dokumen Ketentuan Proyek Kelompok 4
"""

import cv2
import numpy as np
import base64
from io import BytesIO
from PIL import Image
from skimage.feature import graycomatrix, graycoprops, local_binary_pattern
from skimage import morphology

class MalariaImagePipeline:
    def __init__(self, target_size=(128, 128)):
        self.target_size = target_size

    def preprocess(self, img_bgr):
        """
        Tahap 3 Preprocessing:
        - Resize seragam
        - Normalisasi dan konversi ruang warna (CIE Lab, Grayscale)
        - Perbaikan kontras terbatas (CLAHE)
        """
        # 1. Resize seragam
        resized = cv2.resize(img_bgr, self.target_size, interpolation=cv2.INTER_AREA)

        # 2. Konversi ruang warna
        gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
        lab = cv2.cvtColor(resized, cv2.COLOR_BGR2LAB)
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)

        # 3. CLAHE pada kanal L (Contrast-Limited Adaptive Histogram Equalization)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        lab_planes = list(cv2.split(lab))
        lab_planes[0] = clahe.apply(lab_planes[0])
        enhanced_lab = cv2.merge(lab_planes)
        enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)

        return {
            'original_bgr': resized,
            'rgb': rgb,
            'gray': gray,
            'lab': enhanced_lab,
            'enhanced_bgr': enhanced_bgr
        }

    def segment(self, preprocessed_data, method='p1'):
        """
        Tahap 4 Segmentasi dan Morfologi:
        - B0 Baseline: resize dan ekstraksi fitur dari seluruh citra (tanpa segmentasi khusus)
        - B1: Otsu thresholding dan morfologi
        - B2: Adaptive thresholding dan morfologi
        - P1 Usulan: K-means segmentation, pemilihan cluster sel, dan morfologi
        """
        method = method.lower()
        gray = preprocessed_data['gray']
        lab = preprocessed_data['lab']
        h, w = gray.shape

        if method == 'b0':
            # B0: Seluruh citra sebagai mask
            mask = np.ones((h, w), dtype=np.uint8) * 255
            mask_status = "Stabil (Baseline Seluruh Citra)"

        elif method == 'b1':
            # B1: Otsu Thresholding pada kanal gray / kanal a/b
            # Sel darah apusan Giemsa biasanya memiliki kontras tinggi pada grayscale atau kanal a/b
            blur = cv2.GaussianBlur(gray, (5, 5), 0)
            _, mask_raw = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
            
            # Morfologi: Opening & Closing
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
            opened = cv2.morphologyEx(mask_raw, cv2.MORPH_OPEN, kernel, iterations=1)
            mask = cv2.morphologyEx(opened, cv2.MORPH_CLOSE, kernel, iterations=2)
            
            # Hapus objek sangat kecil
            mask = self._remove_small_components(mask, min_size=60)
            mask_status = self._evaluate_mask_quality(mask, h * w)

        elif method == 'b2':
            # B2: Adaptive Thresholding
            blur = cv2.GaussianBlur(gray, (5, 5), 0)
            mask_raw = cv2.adaptiveThreshold(
                blur, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                cv2.THRESH_BINARY_INV, 15, 3
            )
            # Morfologi pembersihan
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
            opened = cv2.morphologyEx(mask_raw, cv2.MORPH_OPEN, kernel, iterations=1)
            mask = cv2.morphologyEx(opened, cv2.MORPH_CLOSE, kernel, iterations=1)
            mask = self._remove_small_components(mask, min_size=80)
            mask_status = self._evaluate_mask_quality(mask, h * w)

        else:
            # P1 (Usulan): K-Means clustering pada ruang warna Lab
            # Pixel clustering dengan K=3 (Background, Sel Darah, Parasit/Kromatin)
            pixels = lab.reshape((-1, 3)).astype(np.float32)
            criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 0.2)
            k = 3
            _, labels, centers = cv2.kmeans(pixels, k, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS)
            
            # Cari cluster foreground (sel darah merah / parasit yang bukan background terang)
            # Kanal L di Lab menunjukkan kecerahan: background biasanya paling terang (L tinggi)
            # atau sudut terjauh
            l_values = centers[:, 0]
            bg_cluster = np.argmax(l_values) # background biasanya cluster paling terang
            
            # Mask foreground adalah cluster selain background
            fg_mask = (labels.flatten() != bg_cluster).astype(np.uint8) * 255
            mask_raw = fg_mask.reshape((h, w))

            # Morfologi penyempurnaan
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
            opened = cv2.morphologyEx(mask_raw, cv2.MORPH_OPEN, kernel, iterations=1)
            mask = cv2.morphologyEx(opened, cv2.MORPH_CLOSE, kernel, iterations=2)
            mask = self._remove_small_components(mask, min_size=100)
            mask_status = self._evaluate_mask_quality(mask, h * w)

        return mask, mask_status

    def _remove_small_components(self, binary_mask, min_size=80):
        """Menghapus noise berupa komponen kecil."""
        bool_mask = binary_mask > 0
        try:
            cleaned = morphology.remove_small_objects(bool_mask, max_size=min_size)
        except (TypeError, ValueError):
            cleaned = morphology.remove_small_objects(bool_mask, min_size=min_size)
        return (cleaned.astype(np.uint8)) * 255

    def _evaluate_mask_quality(self, mask, total_pixels):
        """Mengevaluasi stabilitas dan kualitas mask sesuai ketentuan proyek."""
        fg_pixels = np.count_nonzero(mask)
        ratio = fg_pixels / total_pixels
        if ratio < 0.05:
            return "Mask Terlalu Kecil / Berpotensi Gagal"
        elif ratio > 0.90:
            return "Mask Kurang Diskriminatif (Hampir Penuh)"
        else:
            return "Stabil / Objek Terdeteksi"

    def extract_features(self, preprocessed_data, mask):
        """
        Tahap 5 Ekstraksi Fitur Handcrafted:
        - Luas, perimeter, circularity, rasio area
        - Statistik warna (mean, std dev pada RGB & Lab)
        - GLCM (kontras, dissimilarity, homogenitas, energi, korelasi)
        - LBP (Local Binary Pattern)
        """
        h, w = preprocessed_data['gray'].shape
        total_pixels = h * w
        
        # 1. Fitur Morfologi / Bentuk
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            main_contour = max(contours, key=cv2.contourArea)
            area = float(cv2.contourArea(main_contour))
            perimeter = float(cv2.arcLength(main_contour, True))
            circularity = (4.0 * np.pi * area) / ((perimeter ** 2) + 1e-6)
            circularity = min(1.0, max(0.0, float(circularity)))
        else:
            area = 0.0
            perimeter = 0.0
            circularity = 0.0

        area_ratio = float(area / total_pixels)

        shape_features = {
            'area': round(area, 2),
            'perimeter': round(perimeter, 2),
            'circularity': round(circularity, 4),
            'area_ratio': round(area_ratio, 4)
        }

        # 2. Fitur Statistik Warna (pada area foreground mask)
        mask_bool = mask > 0
        if np.any(mask_bool):
            rgb = preprocessed_data['rgb']
            lab = preprocessed_data['lab']
            
            r_vals = rgb[:, :, 0][mask_bool]
            g_vals = rgb[:, :, 1][mask_bool]
            b_vals = rgb[:, :, 2][mask_bool]
            l_vals = lab[:, :, 0][mask_bool]
            a_vals = lab[:, :, 1][mask_bool]
            b_ch_vals = lab[:, :, 2][mask_bool]

            color_features = {
                'mean_r': round(float(np.mean(r_vals)), 2),
                'std_r': round(float(np.std(r_vals)), 2),
                'mean_g': round(float(np.mean(g_vals)), 2),
                'std_g': round(float(np.std(g_vals)), 2),
                'mean_b': round(float(np.mean(b_vals)), 2),
                'std_b': round(float(np.std(b_vals)), 2),
                'mean_l': round(float(np.mean(l_vals)), 2),
                'std_l': round(float(np.std(l_vals)), 2),
                'mean_a': round(float(np.mean(a_vals)), 2),
                'mean_b_ch': round(float(np.mean(b_ch_vals)), 2),
            }
        else:
            color_features = {
                'mean_r': 0.0, 'std_r': 0.0, 'mean_g': 0.0, 'std_g': 0.0,
                'mean_b': 0.0, 'std_b': 0.0, 'mean_l': 0.0, 'std_l': 0.0,
                'mean_a': 0.0, 'mean_b_ch': 0.0
            }

        # 3. Fitur Tekstur GLCM
        gray = preprocessed_data['gray']
        # Masking grayscale untuk fokus pada area sel
        masked_gray = np.where(mask > 0, gray, 0)
        # GLCM dengan jarak 1 dan sudut [0, 45, 90, 135 derajat]
        glcm = graycomatrix(masked_gray, distances=[1], angles=[0, np.pi/4, np.pi/2, 3*np.pi/4], levels=256, symmetric=True, normed=True)
        
        glcm_contrast = float(np.mean(graycoprops(glcm, 'contrast')))
        glcm_dissimilarity = float(np.mean(graycoprops(glcm, 'dissimilarity')))
        glcm_homogeneity = float(np.mean(graycoprops(glcm, 'homogeneity')))
        glcm_energy = float(np.mean(graycoprops(glcm, 'energy')))
        glcm_correlation = float(np.mean(graycoprops(glcm, 'correlation')))

        # 4. Fitur Tekstur LBP
        # Titik tetangga 8, radius 1
        lbp = local_binary_pattern(gray, P=8, R=1, method='uniform')
        lbp_hist, _ = np.histogram(lbp[mask > 0] if np.any(mask > 0) else lbp, bins=10, range=(0, 10), density=True)
        lbp_energy = float(np.sum(lbp_hist ** 2))

        texture_features = {
            'glcm_contrast': round(glcm_contrast, 3),
            'glcm_dissimilarity': round(glcm_dissimilarity, 3),
            'glcm_homogeneity': round(glcm_homogeneity, 4),
            'glcm_energy': round(glcm_energy, 4),
            'glcm_correlation': round(glcm_correlation, 4),
            'lbp_energy': round(lbp_energy, 4)
        }

        # Gabungkan vektor fitur numerik 1D untuk classifier
        feature_vector = np.array([
            shape_features['area'],
            shape_features['perimeter'],
            shape_features['circularity'],
            shape_features['area_ratio'],
            color_features['mean_r'],
            color_features['mean_g'],
            color_features['mean_b'],
            color_features['mean_l'],
            color_features['mean_a'],
            color_features['mean_b_ch'],
            texture_features['glcm_contrast'],
            texture_features['glcm_homogeneity'],
            texture_features['glcm_energy'],
            texture_features['glcm_correlation'],
            texture_features['lbp_energy']
        ], dtype=np.float32)

        return {
            'shape': shape_features,
            'color': color_features,
            'texture': texture_features,
            'vector': feature_vector
        }

    def mask_to_base64(self, mask):
        """Konversi mask biner ke Base64 PNG untuk ditampilkan di Flutter UI."""
        _, buffer = cv2.imencode('.png', mask)
        return base64.b64encode(buffer).decode('utf-8')

    def process_full(self, img_bytes, method='p1'):
        """Menjalankan seluruh alur PCD."""
        # Decode citra dari bytes
        nparr = np.frombuffer(img_bytes, np.uint8)
        img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img_bgr is None:
            raise ValueError("Gagal membaca file citra. Pastikan format citra valid (JPG/PNG).")

        # 1. Preprocessing
        prep = self.preprocess(img_bgr)

        # 2. Segmentasi & Morfologi
        mask, mask_status = self.segment(prep, method=method)

        # 3. Ekstraksi Fitur
        features = self.extract_features(prep, mask)

        # 4. Mask biner format Base64
        mask_base64 = self.mask_to_base64(mask)

        return {
            'mask_base64': mask_base64,
            'mask_status': mask_status,
            'features': features,
            'prep_data': prep
        }
