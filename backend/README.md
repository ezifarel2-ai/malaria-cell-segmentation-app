# Backend API Pengolahan Citra Digital (PCD) Malaria

Backend ini mengimplementasikan **Pipeline Pengolahan Citra dan Klasifikasi Sel Malaria** sesuai ketentuan Proyek Kelompok 4:
- **Tahap 3 Preprocessing**: Resize (128x128), normalisasi, konversi RGB ke CIE L\*a\*b\* dan Grayscale, CLAHE perbaikan kontras terbatas.
- **Tahap 4 Segmentasi & Morfologi**:
  - `B0`: Baseline seluruh citra
  - `B1`: Otsu Thresholding + Opening/Closing
  - `B2`: Adaptive Thresholding + Morfologi
  - `P1`: K-Means Color Clustering pada ruang warna CIE Lab (Usulan)
- **Tahap 5 Ekstraksi Fitur**:
  - Fitur Bentuk: Luas, Keliling, Circularity, Rasio Area
  - Fitur Warna: Mean dan Std Dev pada kanal L\*, a\*, b\*, R, G, B
  - Fitur Tekstur: GLCM (Kontras, Disimilaritas, Homogenitas, Energi, Korelasi) & LBP
- **Tahap 6 Klasifikasi**:
  - SVM (RBF / Linear) & KNN (k=3, 5, 7, 9)

---

## 1. Cara Menjalankan Backend

Buka terminal di root proyek, lalu jalankan:
```bash
python backend/app.py
```
Server akan berjalan di `http://localhost:5000` (atau port yang ditentukan).

---

## 2. Cara Menyimpan Model dari Google Colab (Setelah Selesai Review Dosen)

Di bagian akhir notebook Google Colab kelompok Anda (setelah proses training & cross-validation selesai):

```python
import joblib

# 1. Simpan StandardScaler yang telah di-fit pada data training
joblib.dump(scaler, 'scaler.pkl')

# 2. Simpan Model SVM terbaik
joblib.dump(svm_model, 'svm_model.pkl')

# 3. Simpan Model KNN pembanding
joblib.dump(knn_model, 'knn_model.pkl')

# Download ketiga file tersebut:
from google.colab import files
files.download('scaler.pkl')
files.download('svm_model.pkl')
files.download('knn_model.pkl')
```

Setelah diunduh, letakkan ketiga file tersebut ke dalam folder:
`backend/models/`
- `backend/models/scaler.pkl`
- `backend/models/svm_model.pkl`
- `backend/models/knn_model.pkl`

Backend akan **otomatis mendeteksi dan menggunakan model asli Colab Anda**. Jika file tersebut belum diletakkan, backend tetap berjalan normal menggunakan mode *heuristic standby* sehingga aplikasi mobile tetap bisa diuji coba secara fungsional.

---

## 3. Menghubungkan Flutter ke Backend

1. **Android Emulator**: Gunakan `http://10.0.2.2:5000` (sudah diset sebagai default).
2. **Windows Desktop / Chrome Web**: Gunakan `http://localhost:5000`.
3. **HP Android Fisik (WiFi)**:
   - Pastikan laptop dan HP terhubung ke WiFi yang sama.
   - Cek IP laptop via `ipconfig` (misalnya `192.168.1.15`).
   - Buka ikon **Pengaturan (Gear)** di pojok kanan atas aplikasi Flutter, lalu masukkan `http://192.168.1.15:5000`.

