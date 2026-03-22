"""
R2U-NET Inspection Pro — Flask Backend
Compatible with Flutter Desktop App (r2unet_v2)

Fixes vs original:
  • Handles legacy Keras 'batch_shape' / 'InputLayer' deserialisation error
  • Per-model input size  (defect=128×128, tank_screw=256×256)
  • Correct tank_screw filename  (defect_model2.h5)
  • Filename is now configurable via env-var MODEL_SCREW_PATH

Run:
    python app.py
    or
    docker build -t r2unet-api . && docker run -p 7860:7860 r2unet-api
"""

import os
import base64
import logging
import numpy as np
import cv2
import tensorflow as tf
from flask import Flask, request, jsonify
from flask_cors import CORS
from tensorflow.keras import backend as K

# ─────────────────────────────────────────────────────────────────────────────
#  Logging
# ─────────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s — %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
#  Flask app
# ─────────────────────────────────────────────────────────────────────────────
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# ─────────────────────────────────────────────────────────────────────────────
#  Patch: fix legacy Keras "batch_shape" / InputLayer deserialisation error
#
#  Keras ≥ 2.13 renamed the 'batch_shape' kwarg to 'batch_input_shape'.
#  Models saved with older Keras will crash on load with:
#      TypeError: Unrecognized keyword arguments: ['batch_shape']
#  This monkey-patch converts the old key to the new one transparently.
# ─────────────────────────────────────────────────────────────────────────────
_original_from_config = tf.keras.layers.InputLayer.from_config.__func__

@classmethod  # type: ignore[misc]
def _patched_from_config(cls, config):
    if "batch_shape" in config and "batch_input_shape" not in config:
        config["batch_input_shape"] = config.pop("batch_shape")
    return _original_from_config(cls, config)

tf.keras.layers.InputLayer.from_config = _patched_from_config
log.info("InputLayer.from_config patched for legacy 'batch_shape' compatibility.")

# ─────────────────────────────────────────────────────────────────────────────
#  Custom loss / metrics  (required when loading .h5 models)
# ─────────────────────────────────────────────────────────────────────────────
def dice_coeff(y_true, y_pred, smooth: float = 1e-6):
    y_true_f = K.flatten(y_true)
    y_pred_f = K.flatten(y_pred)
    intersection = K.sum(y_true_f * y_pred_f)
    return (2.0 * intersection + smooth) / (K.sum(y_true_f) + K.sum(y_pred_f) + smooth)


def dice_loss(y_true, y_pred):
    return 1.0 - dice_coeff(y_true, y_pred)


def combined_loss(y_true, y_pred):
    bce = tf.keras.losses.binary_crossentropy(y_true, y_pred)
    return 0.5 * bce + 0.5 * dice_loss(y_true, y_pred)


CUSTOM_OBJECTS = {
    "dice_coeff":    dice_coeff,
    "dice_loss":     dice_loss,
    "combined_loss": combined_loss,
}

# ─────────────────────────────────────────────────────────────────────────────
#  Model registry
#  Each entry: { "path": str, "input_size": (W, H) }
#
#  Override filenames with env-vars if needed:
#    set MODEL_DEFECT_PATH=my_defect.h5
#    set MODEL_SCREW_PATH=my_screw.h5
# ─────────────────────────────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def _p(env_key: str, default_name: str) -> str:
    return os.environ.get(env_key, os.path.join(BASE_DIR, default_name))

MODEL_REGISTRY: dict[str, dict] = {
    "defect": {
        "path":       _p("MODEL_DEFECT_PATH", "defect_model.h5"),
        "input_size": (128, 128),   # W × H — must match training
    },
    "tank_screw": {
        "path":       _p("MODEL_SCREW_PATH",  "defect_model2.h5"),
        "input_size": (256, 256),   # tank_screw was trained at 256×256
    },
}

_models: dict = {}   # name → loaded Keras model


def load_models() -> None:
    """Load all models at startup; skip gracefully if file missing."""
    for name, cfg in MODEL_REGISTRY.items():
        path = cfg["path"]
        if not os.path.exists(path):
            log.warning("Model file not found, skipping — %s", path)
            continue
        log.info("Loading model '%s'  input=%s  path=%s …", name, cfg["input_size"], path)
        try:
            _models[name] = tf.keras.models.load_model(
                path,
                custom_objects=CUSTOM_OBJECTS,
                compile=False,
            )
            log.info("Model '%s' loaded OK.", name)
        except Exception as exc:
            log.error("Failed to load model '%s': %s", name, exc)

    if not _models:
        log.error("No models loaded! Place .h5 files next to app.py and restart.")


def get_model(model_type: str):
    """Return the requested model, or fall back to the first available."""
    if model_type in _models:
        return _models[model_type]
    if _models:
        fallback = next(iter(_models))
        log.warning("Model '%s' not loaded — falling back to '%s'.", model_type, fallback)
        return _models[fallback]
    return None


def get_input_size(model_type: str) -> tuple[int, int]:
    """Return (W, H) for the given model type."""
    cfg = MODEL_REGISTRY.get(model_type)
    if cfg:
        return cfg["input_size"]
    # Fallback: read from the loaded model's input shape
    model = _models.get(model_type) or (next(iter(_models.values())) if _models else None)
    if model is not None:
        shape = model.input_shape  # (None, H, W, C)
        return (shape[2], shape[1])
    return (128, 128)


# ─────────────────────────────────────────────────────────────────────────────
#  Image helpers
# ─────────────────────────────────────────────────────────────────────────────
def preprocess(img_bgr: np.ndarray, input_size: tuple[int, int]) -> np.ndarray:
    """BGR → RGB → resize → normalise → add batch dim."""
    img_rgb   = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    img_small = cv2.resize(img_rgb, input_size)          # (W, H)
    img_norm  = img_small.astype("float32") / 255.0
    return np.expand_dims(img_norm, axis=0)


def build_result_image(
    img_rgb:      np.ndarray,
    mask_full:    np.ndarray,
    px_threshold: int,
) -> np.ndarray:
    """
    Overlay red mask on the original image and draw bounding boxes
    around contours that exceed px_threshold.
    Returns a BGR image ready for JPEG encoding.
    """
    overlay = img_rgb.copy()
    overlay[mask_full == 1] = [255, 0, 0]                          # red highlight
    result  = cv2.addWeighted(overlay, 0.5, img_rgb, 0.5, 0)       # blend

    contours, _ = cv2.findContours(
        mask_full.astype(np.uint8),
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE,
    )

    for cnt in contours:
        if cv2.contourArea(cnt) > px_threshold:
            x, y, w, h = cv2.boundingRect(cnt)
            cv2.rectangle(result, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.putText(
                result, "MISSING",
                (x, max(y - 10, 10)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6, (0, 255, 0), 2,
            )

    return cv2.cvtColor(result, cv2.COLOR_RGB2BGR)


# ─────────────────────────────────────────────────────────────────────────────
#  Routes
# ─────────────────────────────────────────────────────────────────────────────
@app.route("/predict", methods=["POST"])
def predict():
    """
    Accepts multipart/form-data:
        image          — image file (JPG / PNG)
        model_type     — 'defect' | 'tank_screw'  (default: 'defect')
        conf_threshold — float 0.10–0.95           (default: 0.35)
        px_threshold   — int pixels                (default: 500)

    Returns JSON:
        { success, status, pixel_count, image }
        or
        { success: false, error }
    """
    try:
        # ── Parse inputs ──────────────────────────────────────────────────────
        if "image" not in request.files:
            return jsonify(success=False, error="No image field in request"), 400

        file           = request.files["image"]
        model_type     = request.form.get("model_type",     "defect")
        conf_threshold = float(request.form.get("conf_threshold", 0.35))
        px_threshold   = int(request.form.get("px_threshold",     500))

        # ── Decode image ──────────────────────────────────────────────────────
        img_bytes = np.frombuffer(file.read(), np.uint8)
        img_bgr   = cv2.imdecode(img_bytes, cv2.IMREAD_COLOR)

        if img_bgr is None:
            return jsonify(success=False, error="Cannot decode image"), 400

        h_orig, w_orig = img_bgr.shape[:2]

        # ── Select model ──────────────────────────────────────────────────────
        model = get_model(model_type)
        if model is None:
            return jsonify(success=False, error="No model available — check server logs"), 503

        # ── Inference ─────────────────────────────────────────────────────────
        input_size = get_input_size(model_type)
        img_input  = preprocess(img_bgr, input_size)
        pred_mask  = model.predict(img_input, verbose=0)[0]

        # Squeeze channel dim if present
        if pred_mask.ndim == 3:
            pred_mask = pred_mask[:, :, 0]

        mask_binary = (pred_mask > conf_threshold).astype(np.uint8)

        # Resize mask back to original resolution
        mask_full   = cv2.resize(
            mask_binary, (w_orig, h_orig),
            interpolation=cv2.INTER_NEAREST,
        )
        pixel_count = int(np.sum(mask_full))

        # ── Build result image ────────────────────────────────────────────────
        img_rgb    = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        result_bgr = build_result_image(img_rgb, mask_full, px_threshold)

        # ── JPEG encode → base64 ──────────────────────────────────────────────
        ok, buffer = cv2.imencode(
            ".jpg", result_bgr,
            [cv2.IMWRITE_JPEG_QUALITY, 88],
        )
        if not ok:
            return jsonify(success=False, error="Image encoding failed"), 500

        encoded = base64.b64encode(buffer).decode("utf-8")

        # ── Determine status ──────────────────────────────────────────────────
        status = "MISSING" if pixel_count >= px_threshold else "GOOD"

        log.info(
            "Predict | model=%-10s conf=%.2f px_thr=%d → %s (%d px)",
            model_type, conf_threshold, px_threshold, status, pixel_count,
        )

        return jsonify(
            success=True,
            status=status,
            pixel_count=pixel_count,
            image=encoded,
        )

    except Exception as exc:
        log.exception("Unhandled error in /predict")
        return jsonify(success=False, error=str(exc)), 500


# ─────────────────────────────────────────────────────────────────────────────
#  Camera management  (Python/OpenCV จัดการกล้องแทน Flutter)
# ─────────────────────────────────────────────────────────────────────────────
import threading

class CameraManager:
    """Thread-safe OpenCV camera wrapper."""

    def __init__(self):
        self._cap:    cv2.VideoCapture | None = None
        self._index:  int  = 0
        self._lock:   threading.Lock = threading.Lock()
        self._active: bool = False

    # ── List available cameras ────────────────────────────────────────────────
    def list_cameras(self, max_check: int = 5) -> list[dict]:
        found = []
        for i in range(max_check):
            cap = cv2.VideoCapture(i, cv2.CAP_DSHOW)   # CAP_DSHOW เร็วกว่าบน Windows
            if cap.isOpened():
                found.append({
                    "index": i,
                    "name":  f"Camera {i}",
                    "width":  int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
                    "height": int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
                })
                cap.release()
        return found

    # ── Open camera ───────────────────────────────────────────────────────────
    def open(self, index: int = 0) -> dict:
        with self._lock:
            if self._cap is not None:
                self._cap.release()

            cap = cv2.VideoCapture(index, cv2.CAP_DSHOW)
            if not cap.isOpened():
                return {"success": False, "error": f"Cannot open camera {index}"}

            cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1280)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT,  720)
            cap.set(cv2.CAP_PROP_FPS,           30)

            self._cap    = cap
            self._index  = index
            self._active = True
            log.info("Camera %d opened (%dx%d)", index,
                     int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
                     int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)))
            return {"success": True, "index": index}

    # ── Close camera ──────────────────────────────────────────────────────────
    def close(self) -> None:
        with self._lock:
            if self._cap is not None:
                self._cap.release()
                self._cap    = None
                self._active = False
            log.info("Camera closed.")

    # ── Grab one JPEG frame → base64 ─────────────────────────────────────────
    def grab_frame(self, quality: int = 80) -> str | None:
        with self._lock:
            if self._cap is None or not self._cap.isOpened():
                return None
            ok, frame = self._cap.read()
            if not ok or frame is None:
                return None
            _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, quality])
            return base64.b64encode(buf).decode("utf-8")

    # ── Grab raw BGR ndarray (used by /camera/predict) ────────────────────────
    def grab_bgr(self) -> np.ndarray | None:
        with self._lock:
            if self._cap is None or not self._cap.isOpened():
                return None
            ok, frame = self._cap.read()
            return frame if ok else None

    @property
    def is_open(self) -> bool:
        return self._active and self._cap is not None


_cam_mgr = CameraManager()


# ── Camera routes ─────────────────────────────────────────────────────────────

@app.route("/camera/list", methods=["GET"])
def camera_list():
    """รายชื่อกล้องทั้งหมดที่ระบบเห็น"""
    cameras = _cam_mgr.list_cameras()
    return jsonify(success=True, cameras=cameras, count=len(cameras))


@app.route("/camera/open", methods=["POST"])
def camera_open():
    """
    เปิดกล้อง
    Body JSON: { "index": 0 }   (default 0)
    """
    data  = request.get_json(silent=True) or {}
    index = int(data.get("index", 0))
    result = _cam_mgr.open(index)
    return jsonify(result), (200 if result["success"] else 400)


@app.route("/camera/close", methods=["POST"])
def camera_close():
    """ปิดกล้อง"""
    _cam_mgr.close()
    return jsonify(success=True)


@app.route("/camera/frame", methods=["GET"])
def camera_frame():
    """
    ดึง 1 frame จากกล้องที่เปิดอยู่
    Query: ?quality=80
    Returns: { success, image (base64 JPEG) }
    """
    if not _cam_mgr.is_open:
        return jsonify(success=False, error="Camera not open"), 400

    quality = int(request.args.get("quality", 80))
    encoded = _cam_mgr.grab_frame(quality)

    if encoded is None:
        return jsonify(success=False, error="Failed to grab frame"), 500

    return jsonify(success=True, image=encoded)


@app.route("/camera/predict", methods=["POST"])
def camera_predict():
    """
    จับ frame จากกล้องแล้วรัน AI ทันที — Flutter ไม่ต้องส่งรูปมาเอง
    Body form-data:
        model_type, conf_threshold, px_threshold  (เหมือน /predict)
    """
    if not _cam_mgr.is_open:
        return jsonify(success=False, error="Camera not open — call /camera/open first"), 400

    try:
        model_type     = request.form.get("model_type",     "defect")
        conf_threshold = float(request.form.get("conf_threshold", 0.35))
        px_threshold   = int(request.form.get("px_threshold",     500))

        img_bgr = _cam_mgr.grab_bgr()
        if img_bgr is None:
            return jsonify(success=False, error="Failed to grab frame"), 500

        h_orig, w_orig = img_bgr.shape[:2]

        model = get_model(model_type)
        if model is None:
            return jsonify(success=False, error="No model available"), 503

        input_size = get_input_size(model_type)
        img_input  = preprocess(img_bgr, input_size)
        pred_mask  = model.predict(img_input, verbose=0)[0]

        if pred_mask.ndim == 3:
            pred_mask = pred_mask[:, :, 0]

        mask_binary = (pred_mask > conf_threshold).astype(np.uint8)
        mask_full   = cv2.resize(mask_binary, (w_orig, h_orig),
                                  interpolation=cv2.INTER_NEAREST)
        pixel_count = int(np.sum(mask_full))

        img_rgb    = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        result_bgr = build_result_image(img_rgb, mask_full, px_threshold)

        ok, buffer = cv2.imencode(".jpg", result_bgr,
                                   [cv2.IMWRITE_JPEG_QUALITY, 88])
        if not ok:
            return jsonify(success=False, error="Encode failed"), 500

        status  = "MISSING" if pixel_count >= px_threshold else "GOOD"
        encoded = base64.b64encode(buffer).decode("utf-8")

        log.info("CamPredict | model=%-10s → %s (%d px)", model_type, status, pixel_count)

        return jsonify(success=True, status=status,
                       pixel_count=pixel_count, image=encoded)

    except Exception as exc:
        log.exception("Error in /camera/predict")
        return jsonify(success=False, error=str(exc)), 500


@app.route("/models", methods=["GET"])
def list_models():
    """Return which models are currently loaded and their input sizes."""
    return jsonify(
        loaded={
            name: {"input_size": MODEL_REGISTRY[name]["input_size"]}
            for name in _models
        },
        available=list(MODEL_REGISTRY.keys()),
    )


@app.route("/health", methods=["GET"])
def health():
    """Simple health-check endpoint."""
    return jsonify(status="ok", models_loaded=len(_models))


# ─────────────────────────────────────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    load_models()

    port  = int(os.environ.get("PORT", 7860))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"

    log.info("Starting R2U-NET API on http://0.0.0.0:%d", port)
    app.run(host="0.0.0.0", port=port, debug=debug)