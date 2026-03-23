# R2U-NET Inspection Pro
ระบบตรวจจับชิ้นส่วนที่ขาดหายไปด้วย Deep Learning สำหรับสายการผลิต
พัฒนาด้วย Flutter (Desktop UI) + Python/Flask (AI Backend)

ภาพรวม
ส่วนประกอบเทคโนโลยีหน้าที่UIFlutter Desktopแสดงผล, ควบคุมการทำงานAI BackendPython + Flaskโหลดโมเดล, Inference, จัดการกล้องAI ModelTensorFlow / R2U-NetSemantic Segmentationกล้องOpenCV (Python)ดึง frame, live previewวิดีโอmedia_kitเล่นไฟล์วิดีโอบน Windows/macOS/Linux

ฟีเจอร์หลัก

Image Batch — อัปโหลดรูปภาพหลายรูปพร้อมกัน ดูผล Original vs AI Result คู่กัน
Live Video — เปิดกล้อง USB/Integrated หรือนำเข้าไฟล์วิดีโอ รัน AI inference อัตโนมัติ
Dashboard — สรุปผลการตรวจด้วย KPI cards และ Donut chart แบบ real-time
Export CSV — บันทึก inspection log ลงไฟล์ CSV พร้อม UTF-8 BOM (เปิดใน Excel ได้เลย)
Multi-model — รองรับ 2 โมเดลในคราวเดียว (Pipe Staple / Underbody Screw)
Custom parameters — ปรับ Confidence threshold และ Pixel threshold ได้จาก sidebar


โครงสร้างโปรเจกต์
r2unet_desktoplib/
│
├── lib/                          # Flutter source code
│   ├── main.dart                 # Entry point + Window setup
│   ├── providers/
│   │   └── app_state.dart        # Global state (Provider)
│   ├── screens/
│   │   ├── home_screen.dart      # Layout shell (sidebar + content)
│   │   ├── image_screen.dart     # Batch image upload
│   │   ├── video_screen.dart     # Camera / video inference
│   │   └── dashboard_screen.dart # KPI + chart + log table
│   ├── services/
│   │   ├── api_service.dart      # HTTP calls to Flask
│   │   └── log_service.dart      # Inspection log + CSV export
│   ├── theme/
│   │   └── app_theme.dart        # Design tokens (colors, radii)
│   └── widgets/
│       ├── sidebar.dart          # Navigation + settings panel
│       └── title_bar.dart        # Custom frameless title bar
│
├── model_back/                   # Python AI Backend
│   ├── app.py                    # Flask server (main)
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── defect_model.h5           # โมเดล Pipe Staple (128×128)
│   └── defect_model2.h5          # โมเดล Underbody Screw (256×256)
│
├── test/
│   └── widget_test.dart
├── pubspec.yaml
└── analysis_options.yaml

ความต้องการของระบบ
Flutter (UI)

Flutter SDK >=3.3.0
Dart SDK >=3.3.0
Windows 10/11 (64-bit) / macOS 12+ / Ubuntu 20.04+
Developer Mode เปิดอยู่ (Windows)

Python (Backend)

Python 3.9+
TensorFlow 2.12–2.15
OpenCV, Flask, Flask-CORS
