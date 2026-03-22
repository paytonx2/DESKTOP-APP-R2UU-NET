# R2U-NET Inspection Pro — Flutter Desktop App

## 📦 Project Structure
```
r2unet_desktop/
├── lib/
│   ├── main.dart                    ← Entry point + window setup
│   ├── theme/
│   │   └── app_theme.dart           ← Colors, fonts, theme
│   ├── providers/
│   │   └── app_state.dart           ← Global state (Provider)
│   ├── services/
│   │   ├── api_service.dart         ← HTTP calls to Flask API
│   │   └── log_service.dart         ← Inspection logs + CSV export
│   ├── screens/
│   │   ├── home_screen.dart         ← Layout (sidebar + content)
│   │   ├── image_screen.dart        ← Batch image upload & results
│   │   ├── video_screen.dart        ← Camera / video live analysis
│   │   └── dashboard_screen.dart    ← KPI + Donut chart + log table
│   └── widgets/
│       ├── title_bar.dart           ← Custom frameless title bar
│       └── sidebar.dart             ← Navigation + settings panel
├── assets/fonts/                    ← SpaceMono font files (see below)
└── pubspec.yaml
```

---

## ⚙️ STEP 1 — Install Flutter

### Windows
1. Download Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to PATH
4. Run: `flutter doctor`

### macOS
```bash
brew install --cask flutter
flutter doctor
```

### Linux (Ubuntu/Debian)
```bash
sudo snap install flutter --classic
flutter doctor
```

---

## ⚙️ STEP 2 — Install VSCode Extensions

Install these extensions in VSCode:
- **Flutter** (by Dart Code) — dart extension included automatically
- **Dart** (by Dart Code)

---

## ⚙️ STEP 3 — Enable Desktop Support

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

---

## ⚙️ STEP 4 — Add Font Files

Download SpaceMono font from Google Fonts:
https://fonts.google.com/specimen/Space+Mono

Create folder and place files:
```
assets/fonts/SpaceMono-Regular.ttf
assets/fonts/SpaceMono-Bold.ttf
```

OR replace with any monospace font you prefer, and update `pubspec.yaml`.

---

## ⚙️ STEP 5 — Setup the Project

```bash
# Navigate to project folder
cd r2unet_desktop

# Initialize Flutter desktop platform files
flutter create . --platforms=windows,macos,linux

# Install dependencies
flutter pub get
```

---

## ⚙️ STEP 6 — Run the App

```bash
# Run on Windows
flutter run -d windows

# Run on macOS
flutter run -d macos

# Run on Linux
flutter run -d linux
```

---

## ⚙️ STEP 7 — Start Flask Backend

Start your Flask API server on the same machine:

```bash
# Option A: Direct Python
python app.py

# Option B: Docker
docker build -t r2unet-api .
docker run -p 7860:7860 r2unet-api
```

The app connects to `http://127.0.0.1:7860` by default.
You can change the URL in the sidebar → Server section.

---

## 🏗️ STEP 8 — Build Release

```bash
# Windows .exe
flutter build windows --release

# macOS .app
flutter build macos --release

# Linux binary
flutter build linux --release
```

Output: `build/windows/x64/runner/Release/`

---

## 🎯 Features

| Feature | Description |
|---------|-------------|
| 📷 Image Batch | Drag & drop multiple images, see original vs AI result side by side |
| 🎥 Live Video | Connect camera or load video file, run AI inference every ~800ms |
| 📊 Dashboard | KPI cards, pass/fail donut chart, full inspection log table |
| 📤 Export CSV | Save inspection log as CSV to Downloads folder |
| ⚙️ Settings | Model selector, confidence slider, pixel threshold, server URL |
| 🖥️ Custom UI | Frameless window, draggable title bar, minimize/maximize/close |

---

## 🔧 Troubleshooting

**`flutter doctor` shows issues**
→ Follow the suggested fixes for your OS

**Camera not working on Windows**
→ Add camera permission in `windows/runner/Runner.rc`

**`path_provider` error on Linux**
→ Run: `sudo apt-get install libsecret-1-dev libjsoncpp-dev`

**HTTP connection refused**
→ Make sure Flask server is running on port 7860
→ Check the URL in sidebar matches your server

**Font not found error**
→ Make sure `assets/fonts/` folder exists with TTF files
→ Run `flutter pub get` again
