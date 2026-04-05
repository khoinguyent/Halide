🎞️ Halide Technical Spec: Precision Light Metering

1. Objective

To implement a cross-platform (Flutter) reflected light meter that provides consistent, "photographic-grade" exposure values ($EV$) across iOS and Android, calibrated to match professional mirrorless cameras (e.g., Fuji XT-20) and physical Sekonic meters.

2. The Core Mathematical Engine

We cannot rely on raw Lux sensors (blocked on iOS). Instead, we use the Camera Metadata Method.

Phase A: Calculate Raw Scene EV

Read the current auto-exposure values from the device camera:

$N_{dev}$: Device Aperture (e.g., f/1.8 or f/1.5)

$t_{dev}$: Device Shutter Speed (seconds)

$ISO_{dev}$: Device ISO

$$EV_{100} = \log_2\left(\frac{N_{dev}^2}{t_{dev}}\right) - \log_2\left(\frac{ISO_{dev}}{100}\right)$$

Phase B: The "Halide" Calibration (The Fix)

Modern smartphones protect highlights aggressively, making them "faster" than film. To align with a Fuji XT-20, a global offset is mandatory.

[!IMPORTANT]
Mandatory Offset: $EV_{final} = EV_{100} - 2.0$
Without this -2.0 stop correction, the app will suggest 1/1000 when the correct film exposure is 1/250.

3. Implementation Requirements

🛠️ Hardware & Platform Strategy

Feature

iOS Implementation (av_foundation)

Android Implementation (camera2)

Exposure Data

AVCaptureDevice.exposureDuration, ISO

CaptureResult.SENSOR_EXPOSURE_TIME, SENSITIVITY

Aperture

Fixed (e.g., f/1.8). Read from lensAperture.

Variable or Fixed. Read from LENS_APERTURE.

Sampling

Center-Weighted Average (25% of frame)

Center-Weighted Average (25% of frame)

Haptics

UIImpactFeedbackGenerator (Medium)

HapticFeedback.vibrate()

🎯 Sampling Logic (Preventing "Jumpiness")

Do not use a single-pixel spot meter.

Define a "Metering Circle" in the center of the UI (20-25% of the viewport).

The camera controller must use this region for ExposureMode.autoExpose.

Average the luminance values within this circle to stabilize the $EV$ readout.

4. Reciprocal Calculation (The User Output)

Once $EV_{final}$ is locked, calculate the suggested Shutter Speed ($t_{sug}$) based on the user's Film ISO ($ISO_{f}$) and Target Aperture ($N_{f}$):

Calculate $EV$ at Film ISO:


$$EV_{f} = EV_{final} + \log_2\left(\frac{ISO_{f}}{100}\right)$$

Solve for Shutter Speed:


$$t_{sug} = \frac{N_{f}^2}{2^{EV_{f}}}$$

5. The "Snap" Logic (UX Requirement)

Users cannot set 1/1138 on a film camera. The UI must "snap" to the nearest standard value.

Standard Shutter Array:
[..., 1/15, 1/30, 1/60, 1/125, 1/250, 1/500, 1/1000, 1/2000, ...]

Standard Aperture Array:
[f/1.4, f/2, f/2.8, f/4, f/5.6, f/8, f/11, f/16, f/22]

Algorithm:

double snapToStandard(double calculatedValue, List<double> standards) {
  return standards.reduce((a, b) => 
    (calculatedValue - a).abs() < (calculatedValue - b).abs() ? a : b);
}


6. UI/UX Workflow

Continuous Preview: $EV$ updates in real-time as the user moves the phone.

Lock Exposure: User taps the "Lock" button. The $EV$ is frozen.

Reciprocity Mode: User can now slide the Aperture (e.g., from f/2.8 to f/8) and the Shutter Speed will automatically update while keeping the $EV$ constant.

Lux Display (Visual Only): Convert $EV$ to Lux for the "Precision" feel:


$$Lux = 2.5 \times 2^{EV_{final}}$$

7. Quality Assurance (The "Fuji Test")

To pass Sprint 06, the developer must verify:

Point Fuji XT-20 at a scene -> Note Exposure (e.g., f/2.8, 1/250).

Point Halide App at the same scene.

If Halide suggests 1/250 (+/- 0.3 stops), the task is DONE.

If Halide suggests 1/1000, the -2.0 EV Offset has not been applied correctly.