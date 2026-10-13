# Brightly

Aplikasi Flutter untuk mencari beasiswa global: katalog beasiswa, pencarian,
penyimpanan, notifikasi tenggat, kuis rekomendasi, dan asisten AI.

## Stack

- Flutter + Material 3
- Firebase (Auth, Cloud Firestore, Google Sign-In)
- Provider (state management)
- Google Fonts (Plus Jakarta Sans)
- fl_chart, shimmer, shared_preferences, google_generative_ai

## Menjalankan

```bash
flutter pub get
flutter run
```

## Setup Firebase (wajib)

### 0. Login Google di web

Web **tidak butuh OAuth client id**. Alur web memakai
`signInWithPopup(GoogleAuthProvider())`, jadi Firebase JS SDK mengarahkan lewat
`authDomain` (`scholarpath-e5d39.firebaseapp.com/__/auth/handler`) yang sudah
terdaftar sebagai `redirect_uri`.

Android/iOS memakai `google_sign_in` dengan `serverClientId` dari
`firebase_options.dart`.

Satu-satunya sisi yang masih perlu disiapkan: **Authorized domains** di Firebase
Console → Authentication → Settings. Pastikan `localhost` dan `127.0.0.1` ada di
 sana, dan tambahkan domain produksi sebelum deploy. Kalau tidak, Firebase
menolak dengan `unauthorized-domain` sebelum OAuth sempat jalan.

#### Kalau muncul `Error 400: redirect_uri_mismatch` / `origin_mismatch`

Ini **bukan** masalah origin, dan mendaftarkan `http://localhost` sebagai
authorized origin **tidak akan menyelesaikannya**. Google memvalidasi *origin* dan
*redirect_uri* secara terpisah, dan yang gagal di sini adalah `redirect_uri`:
alur `google_sign_in` di web mengirim `http://localhost:<port>`, yang tidak pernah
terdaftar pada OAuth client project ini.

Verifikasi cepat:

```bash
# gagal: redirect_uri localhost
curl -s "https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$WEB_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"providerId":"google.com","continueUri":"http://localhost:59477"}'

# lolos: redirect_uri authDomain
curl -s "https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$WEB_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"providerId":"google.com","continueUri":"https://scholarpath-e5d39.firebaseapp.com/__/auth/handler"}'
```

Kalau popup diblokir browser, alur web otomatis beralih ke
`signInWithRedirect`, dan `AuthService.completeRedirectSignIn()` menuntaskannya
saat app start lagi.

### 1. Firestore Security Rules

Deploy `firestore.rules`:

```bash
firebase deploy --only firestore:rules
```

> Penting: versi rules sebelumnya hanya mengenali `role == 'admin'` (huruf kecil)
> sementara dashboard admin menuliskan `'Admin'`. Akibatnya **semua operasi tulis
> admin ditolak**. Rules sekarang sudah case-insensitive
> (`currentUserDoc().data.role.lower()`).

### 2. Menosecondsikan admin pertama

Role disimpan di dokumen `users/{uid}`. Setelah user pertama register, jalankan di
Firebase Console:

```
users/{uid}
  nama: <nama>
  email: <email>
  role: admin        # WAJIB huruf kecil 'admin'
  blocked: false
  bookmarks: []
```

Atau lewat script:

```js
// Firebase Console → Firestore → Rule Playground
db.collection("users").doc("<uid>").update({ role: "admin" });
```

### 3. Gemini API key (fitur AI Chat)

> API key yang tadinya **tertanam di source code** sudah dihapus. Sekarang dibaca
> dari konfigurasi, dengan urutan prioritas:

| # | Sumber | Kapan dipakai |
| --- | --- | --- |
| 1 | `--dart-define` | Developing di laptop |
| 2 | Firestore `config/api_keys` | **Untuk semua device** (rekomendasi) |
| 3 | `assets/ai_config.json` | Fallback lokal |

#### Cara A — permanen (Firestore, paling praktis)

Buat dokumen di Firebase Console:

```
config/api_keys
  gemini_api_key: "AIza..."      ← dari https://aistudio.google.com/apikey
```

Sekali buat, semua device langsung jalan tanpa rebuild.

#### Cara B — hanya di laptop

```bash
flutter run --dart-define=GEMINI_API_KEY=AIza...
```

#### Cara C — fallback file lokal

Isi `assets/ai_config.json`:

```json
{ "gemini_api_key": "AIza..." }
```

> File ini sudah masuk `.gitignore`, jadi key asli tidak ikut ter-commit.

#### Kalau muncul "Fitur AI belum dikonfigurasi"

Itu **bukan crash** — app sengaja menampilkan panduan. Penyebab biasanya:

- dokumen `config/api_keys` belum dibuat / field-nya kosong
- user belum login (Firestore menolak pembacaan)
- `security rules` versi lama masih ter-deploy:
  ```bash
  firebase deploy --only firestore:rules
  ```

Detail teknisnya (`AiConfig.source`, `AiConfig.failure`) tercetak di log debug
dengan prefix `AiConfig:`.

> Untuk produksi, pindahkan pemanggilan Gemini ke **Cloud Functions** agar key
> tidak pernah sampai ke client sama sekali.

## Design system

Semua token & komponen bersama ada di `lib/services/app_style.dart`.

### Arah visual

Referensi: `Downloads/jpg(2)` — kartu putih di atas kanvas abu-abu dingin, pemisahan
memakai **border 1px** (bukan shadow tebal), satu biru percaya diri, aksen lime
hanya di momen penting, dan angka besar sebagai pusat perhatian.

Prinsipnya: **warna dan bentuk yang membawa karakter, bukan hiasan.**

| Token | Nilai | Peran |
| --- | --- | --- |
| `ink` | `#17161B` | Teks utama, navbar AI, surface hero gelap. Hampir hitam, bukan navy, supaya tidak terasa bernuansa. |
| `spark` | `#3760F9` | Satu-satunya warna interaktif. "Ini bisa diklik" tidak pernah ambigu. |
| `lime` | `#D2FC59` | Aksen hemat. Hanya di logo AI dan banner ajakan. |
| `lavender` | `#DAD9FB` | Latar avatar & surface lembut. |
| `cream` | `#F4F5F9` | Kanvas abu-abu dingin, bukan krem hangat. |
| `success` / `warning` / `danger` | — | Hanya untuk status: tenggat, validasi, blokir. |

Aturan yang menjaga tampilan tetap profesional:

- **Tidak ada blob dekoratif.** `AppStyle.background()` sekarang hanya menempel
  warna kanvas. Dua lingkaran samar di belakang setiap layar-lah yang bikin app
  terasa seperti mainan.
- **Tidak ada gradient per kartu.** Gradient hanya di hero besar (login, splash,
  banner AI). Kartu dan tile memakai fill rata + border 1px.
- **Tidak ada warna-warna ungu/merah di tiap tab.** Navbar, kartu statistik,
  dan item menu semuanya `spark`. Empat warna jenjang berbeda bikin navbar
  terlihat seperti mainan.
- **Dekorasi hanya di hero.** Sparkle hanya di splash, hero login, dan kartu
  carousel. Daftar dan row tetap bersih supaya data mudah dipindai.
- **Label navbar selalu tampil.** Dulu hanya tab aktif yang berlabel, sehingga
  navbar berubah lebar tiap pindah tab dan terasa tidak stabil.

### Palet

| Token | Nilai | Dipakai untuk |
| --- | --- | --- |
| `ink` | `#16323F` | Warna utama, nav bar gelap, tombol |
| `spark` | `#3E8FD0` | Aksen biru (sejajar logo) |
| `coral` | `#FF7A66` | Aksen hangat, badge, bookmark |
| `sunny` | `#FFC24B` | Highlight, "featured", avatar |
| `periwinkle` | `#8E9BF5` | AI, violet accent |
| `mint` | `#4FBFA0` | Sukses / beasiswa full funded |
| `cream` | `#FCF7F0` | Canvas terang |
| `paper` | `#FFFFFF` | Kartu terang |
| `inkDark` / `paperDark` | `#0F1A21` / `#1B2A33` | Mode gelap |

Logo aplikasi berwarna biru, jadi `ink` + `spark` menahan identitas brand,
sedangkan aksen hangat membuat nuansanya ramah dan tidak kaku.

### Bentuk & spasial

- Radius bertingkat: `rXs 10` → `rSm 14` → `rMd 20` → `rLg 28` → `rXl 36` → `rPill 999`
- Margin layar konsisten `gutter 20`, jarak antar kartu `12`
- Tombol utama full-width, tinggi `54`, bentuk pil
- **Header tidak pernah menempel ke status bar.** `AppStyle.topInset(context)`
  menjumlahkan inset notch + gap 14, daninset yang terlalu tinggi (landscape /
  tablet) di-clamp agar konten tidak terdorong terlalu jauh.
- **Nav bar & isi daftar menghormati home indicator** lewat
  `AppStyle.bottomInset(context)`.

### Komponen

`AppStyle.darkNavBar` · `sparkles` · `dashedArc` · `circleButton` ·
`bellButton` · `avatar` · `searchField` · `segmentedPills` · `sectionTitle` ·
`chip` · `statBubble` · `emptyState` · `primaryButton` ·
`AppHeaders.greeting` · `AppHeaders.pageHeader`

### Aturan agar tidak norak

1. Dekorasi (sparkle, blob, ring) hanya di **hero** — kartu list tetap bersih.
2. Satu warna aksen per section, tidak mencampur.
3. Teks panjang selalu `maxLines` + `ellipsis`; chip selalu `Flexible`.
4. `test/ui_smoke_test.dart` menangkap `RenderFlex overflow` otomatis.

## Struktur

```
lib/
  main.dart                      # Bootstrap + tema global (light/dark)
  firebase_options.dart
  models/scholarship_data.dart   # Katalog bawaan (~100 beasiswa)
  providers/
    scholarship_provider.dart    # Single source of truth: beasiswa + bookmark
  screens/
    splash_screen.dart           # Gate: maintenance / blocked / role routing
    login_screen.dart
    register_screen.dart
    home_screen.dart             # Dashboard + IndexedStack shell
    explore_screen.dart          # Kategori, pencarian, kuis
    saved_screen.dart
    profile_screen.dart
    detail_screen.dart
    quiz_screen.dart             # Kuis rekomendasi
    ai_chat_screen.dart
    notifications_screen.dart
    settings_screen.dart
    edit_profile_screen.dart
    help_support_screen.dart
    admin_dashboard.dart         # Dashboard admin (berjaga akses)
    add_scholarship_screen.dart
    manage_scholarships_screen.dart
  services/
    app_style.dart               # Token warna + header bersama
    app_state.dart               # Preferensi persisten (theme/locale)
    app_translations.dart        # EN / ID
    auth_service.dart
    google_auth_config.dart      # Client ID native + klasifikasi error
    ai_config.dart               # Resolusi Gemini API key (3 sumber)
    data_migration.dart          # Seeding katalog (fire-and-forget)
    validators.dart
  widgets/
    scholarship_card.dart        # Kartu list + accessor null-safe
    google_auth_setup_dialog.dart# Panduan konfigurasi OAuth
    shimmer_loading.dart
    admin/…
```

## Catatan arsitektur penting

| Topik | Kenapa |
| --- | --- |
| **Satu sumber kebenaran** | Bookmark & data beasiswa hanya disimpan di `ScholarshipProvider`. Sebelumnya `HomeScreen` punya salinan sendiri sehingga tidak sinkron. |
| **Hero tag unik** | Tiap daftar memakai prefix berbeda (`latest::`, `explore::`, `saved::`, `quiz::`, `featured::`). Tag yang sama di satu `Navigator` route akan **crash**, terutama karena keempat tab hidup bersamaan di dalam `IndexedStack`. |
| **Tidak ada `orderBy` pada field yang bisa hilang** | `orderBy('createdAt')` diam-diam membuang dokumen yang tidak punya field tersebut. Sorting dilakukan di memori. |
| **`set(..., merge: true)` bukan `update()`** | `update()` melempar `NOT_FOUND` kalau dokumen user belum dibuat. |
| **Perorovsiensi preferensi** | Tema & bahasa disimpan lewat `shared_preferences` dan dimuat sebelum frame pertama. |
| **Akses admin diverifikasi ulang** | `AdminDashboard` mengecek role saat `initState` dan 즉시 keluar bila bukan admin. |
| **Tidak ada data analytics palsu** | Grafik admin menghitung katalog sebenarnya; sebelumnya menampilkan angka hard-code + badge "+12.5%". |
| **Login Google dipisah per platform** | Web memakai popup Firebase (`redirect_uri` = `authDomain`, selalu valid); Android/iOS memakai `google_sign_in`. Sebelumnya web memakai client Android yang membuat `redirect_uri_mismatch` terus-menerus. |
| **Redirect sign-in diselesaikan** | Popup diblokir → jatuh ke `signInWithRedirect`, lalu `completeRedirectSignIn()` hurdles di splash. Tanpa ini user kembali ke layar login padahal sudah masuk. |

## Kualitas kode

```bash
flutter analyze   # harus: No issues found!
flutter test      # harus: All tests passed! (48 test)
```

`analysis_options.yaml` sudah menaikkan `dead_code`, `unused_import`, dan
`unused_local_variable` menjadi **error** supaya regresi cepat ketahuan.

## Lisensi

Hak cipta © Brightly.
