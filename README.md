# Analisis Deteksi Penipuan untuk Paper.id  

## **Gambaran Umum Proyek**  
Proyek ini bertujuan untuk menganalisis dan mendeteksi transaksi penipuan (*fraud*) dalam platform pembayaran digital **Paper.id**, sebuah penyedia layanan faktur dan pembayaran digital terkemuka di Indonesia dengan lebih dari **600.000 pengguna** dan **8 juta faktur** yang diproses.  

Analisis ini menggunakan berbagai teknik *data science*, termasuk:  
- **Pemrograman Python** (*Data Cleaning, Feature Engineering, EDA*)  
- **Query SQL Lanjutan** (*Advanced Queries, Stored Procedures, Views*)  
- **Analisis Jaringan Sosial** (*Social Network Analysis*)  
- **Visualisasi Data** (*Tableau Dashboard*)  

Tujuan utamanya adalah mengidentifikasi **pola transaksi mencurigakan**, **hubungan tidak wajar antara pembeli-penjual**, dan **penyalahgunaan promo** untuk memberikan rekomendasi pencegahan *fraud*.  

---  

## **Struktur Proyek**  
Proyek ini dibagi menjadi beberapa tahap utama:  

### **1. Analisis Bisnis**  
- Memahami konteks bisnis Paper.id dan tantangan terkait *fraud*.  
- Identifikasi dampak *fraud* terhadap pendapatan dan kepercayaan pelanggan.  

### **2. Analisis Data dengan Python**  
- **Pembersihan Data** (*Data Cleaning*): Menangani *missing values*, duplikat, dan anomali data.  
- **Feature Engineering**: Membuat fitur baru untuk analisis, seperti:  
  - Frekuensi transaksi pembeli-penjual  
  - Nilai transaksi di luar rentang normal  
  - Penggunaan promo yang tidak wajar  
- **Scaling & Normalisasi**: Persiapan data untuk pemodelan.  

### **3. Exploratory Data Analysis (EDA)**  
- Analisis distribusi `transaction_amount`.  
- Identifikasi pasangan **buyer-seller** dengan frekuensi transaksi tinggi.  
- Analisis pola penggunaan promo dan *self-transaction*.  
- Visualisasi:  
  - Tren transaksi harian  
  - Graf jaringan hubungan pembeli-penjual  
  - Eksploitasi promo  

### **4. Analisis SQL Lanjutan**  
- **Query untuk Deteksi Fraud**:  
  - Transaksi dengan nilai jauh di atas normal  
  - Hubungan pembeli-penjual mencurigakan  
  - Deteksi penyalahgunaan promo  
  - Waktu transaksi tidak wajar (*odd-hour transactions*)  
- **SQL Joins**: Menggabungkan data transaksi dengan informasi pengguna (*user fraud flag, KYC status*).  
- **Stored Procedures & Views**:  
  - `Laporan Fraud Bulanan`  
  - `View Pasangan Buyer-Seller Paling Mencurigakan`  

### **5. Analisis Jaringan Sosial (Python)**  
- Visualisasi hubungan pembeli-penjual menggunakan **NetworkX** dan **Gephi**.  
- Identifikasi *cluster* mencurigakan (*fraud rings*).  
- **Cohort Analysis**:  
  - Pelacakan aktivitas pengguna dari waktu ke waktu  
  - Deteksi perilaku penipuan setelah periode tidak aktif  

### **6. Visualisasi dengan Tableau**  
- **Dashboard Interaktif**:  
  - Tren transaksi penipuan  
  - Visualisasi jaringan pembeli-penjual  
  - Analisis penyalahgunaan promo  
- **Filter Dinamis**: Memungkinkan drill-down berdasarkan waktu, metode pembayaran, atau *user fraud flag*.  

---  

## **Sumber Data**  
Data yang digunakan meliputi:  
1. **Digital Payment Transaction**:  
   - `buyer_id`, `seller_id`, `transaction_amount`, `payment_method`, `transaction_datetime`, `promo_used`.  
2. **Digital Payment Request**:  
   - `total_fee_amount`, `document_type`.  
3. **Promotion Data**:  
   - `promo_code`, `cashback_amount`.  
4. **Company/User Data**:  
   - `KYC status`, `fraud_flag`, `blacklist_status`, `registered_date`.  

---  

## **Tools yang Digunakan**  
- **Python** (Pandas, NumPy, Matplotlib, Seaborn, NetworkX)  
- **SQL** (Query Lanjutan, Stored Procedures)  
- **Tableau** (Visualisasi & Dashboard)   

---  

## **Kesimpulan & Rekomendasi**  
- **Pola Fraud Teridentifikasi**:  
  - Transaksi bernilai tinggi di luar jam normal.  
  - Pasangan buyer-seller dengan transaksi berulang dalam waktu singkat.  
  - Penyalahgunaan promo (*cashback exploitation*).  
- **Rekomendasi**:  
  - Penerapan **real-time fraud detection** berbasis aturan (*rule-based*).  
  - Peningkatan verifikasi **KYC/KYB** untuk akun mencurigakan.  
  - Pemantauan ketat transaksi menggunakan promo besar.  

---  
