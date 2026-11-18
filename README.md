# MalariaVision Lab - Mobile App for Malaria Cell Segmentation & Classification

> **Proyek Kelompok 4 • Mata Kuliah Pengolahan Citra Digital**  
> **Judul Riset:** *Evaluasi Metode Segmentasi Sel pada Klasifikasi Citra Mikroskopis Malaria Berbasis Fitur Handcrafted*  
> **Target Jurnal:** Progresif: Jurnal Ilmiah Komputer (SINTA 4)  
> **Dosen Pengampu:** Rangga Pebrianto, M.Kom.

---

## 📌 Ringkasan Proyek

Repositori ini berisi implementasi **Aplikasi Mobile (Flutter)** dan **Server Backend Pengolahan Citra (Python Flask)** untuk deteksi dan klasifikasi sel darah malaria (*Plasmodium falciparum*) pada apusan darah tipis (*thin blood smear*) berbasis fitur *handcrafted*.

Fokus riset ini adalah **menunjukkan pengaruh pemilihan metode segmentasi terhadap diskriminasi fitur dan akurasi klasifikasi**, bukan sekadar melatih classifier black-box (CNN bukan metode utama).

---

## 🔬 4 Konfigurasi Segmentasi yang Dievaluasi

| Konfigurasi | Nama Metode | Karakteristik Komputasi |
| :--- | :--- | :--- |
| **B0** | **Baseline (Whole Image)** | Ekstraksi fitur dari seluruh kanvas citra tanpa segmentasi khusus. |
| **B1** | **Otsu Thresholding** | Ambang batas global bimodal + pembersihan morfologi *opening/closing*. |
| **B2** | **Adaptive Gaussian** | Thresholding lokal adaptif terhadap gradien pencahayaan dan variasi warna. |
| **P1** | **K-Means Clustering (Usulan)** | Klasterisasi 3 klaster pada ruang warna **CIE L\*a\*b\*** + seleksi klaster parasit/sel + eliminasi objek kecil. |

---

## 🧬 Vektor Fitur Handcrafted (15 Dimensi)

1. **Morfologi & Bentuk:**
   - Luas Objek (*Area* dalam $\text{px}^2$)
   - Keliling (*Perimeter* dalam $\text{px}$)
   - Sirkularitas ($\frac{4\pi \times \text{Area}}{\text{Perimeter}^2}$, $0.00 - 1.00$)
   - Rasio Luas Objek terhadap Citra (*Area Ratio*)
2. **Warna CIE L\*a\*b\*:**
   - Rata-rata & Simpangan Baku Kecerahan ($L^*$)
   - Kroma Kromatin Giemsa ($a^*$ magenta-cyan)
   - Kroma Kuning-Biru ($b^*$)
3. **Tekstur (GLCM & LBP):**
   - Gray-Level Co-occurrence Matrix (GLCM): *Contrast*, *Homogeneity*, *Energy*, *Correlation*
   - Local Binary Pattern (LBP): *Uniform Pattern Energy*

---

## 📱 Arsitektur Aplikasi Mobile

- **Theme & Design System:** Modern Scientific / Precision Medical Workstation (terinspirasi dari standar Leica Biosystems & Apple Health) dengan kartu putih bersih, border hairline 1px (`#E2E8F0`), dan angka tabular (`FontFeature.tabularFigures()`).
- **Interactive Split-Curtain Microscope Viewport:** Geser slider pembatas untuk membandingkan preparat apusan darah Giemsa dengan mask segmentasi biner secara *real-time*.
- **Pinch-to-Zoom ($1.0\times - 4.0\times$):** Inspeksi morfologi sel mikroskopis dengan skala mikrometer optik ($5\,\mu\text{m}$) dan resolusi FOV ($128\times 128\,\text{px}$).
- **Explainable AI (XAI) Insight:** Penjelasan transparan berbasis deviasi fitur kuantitatif.

---

## 🚀 Cara Menjalankan Sistem

### 1. Menjalankan Backend Python (Pemroses Citra & ML)
Pastikan Python 3.10+ sudah terinstal beserta dependensi:
```bash
pip install flask opencv-python scikit-image scikit-learn numpy pillow joblib
```
Jalankan server:
```bash
python backend/app.py
```
*Server aktif di `http://localhost:5000` (atau port yang ditentukan).*

### 2. Menjalankan Aplikasi Mobile Flutter
Pastikan Flutter SDK sudah terpasang, lalu jalankan:
```bash
# Mengambil dependensi
flutter pub get

# Menjalankan di Chrome (Web)
flutter run -d chrome

# Atau menjalankan di Android Emulator / HP Fisik
flutter run
```

---

## 📥 Integrasi Model dari Google Colab

Setelah proses pelatihan dan *cross-validation* di notebook Google Colab selesai, simpan model ke format `.pkl`:
```python
import joblib
from google.colab import files

joblib.dump(scaler, 'scaler.pkl')
joblib.dump(svm_model, 'svm_model.pkl')
joblib.dump(knn_model, 'knn_model.pkl')

files.download('scaler.pkl')
files.download('svm_model.pkl')
files.download('knn_model.pkl')
```
Letakkan file yang telah diunduh ke dalam folder:
```text
backend/models/
├── scaler.pkl
├── svm_model.pkl
└── knn_model.pkl
```
*Backend akan otomatis beralih menggunakan bobot model resmi dari eksperimen Anda.*

---

## ⚖️ Batasan Etika & Klaim Riset
Aplikasi ini dikembangkan murni untuk pengujian komputasi pengolahan citra digital tugas akademik. Sesuai etika penelitian, hasil luaran klasifikasi komputasi **dilarang digunakan sebagai alat diagnosis klinis resmi maupun pengganti tenaga medis patologi anatomi**.
