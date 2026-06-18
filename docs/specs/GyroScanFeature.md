Cursor Implementation Prompt: Gyroscope Film Scan Tool

You are an expert Flutter (Mobile) and NestJS (Backend) developer. Your task is to implement the Gyroscope Film Scan Tool inside our existing camera app codebase.

Please read the following specification carefully and implement the features step-by-step.

1. Context & Architecture Review

We are integrating a hardware-assisted flat-lay negative film scanner directly into our lab status lifecycle.

Frontend Technology Stack: Flutter (Dart), BLoC / Provider pattern, camera package, sensors_plus (or motion_sensors) for Gyroscope/DeviceMotion, and path_provider for local caching.

Backend Technology Stack: NestJS, PostgreSQL (Prisma ORM), Cloudflare R2 for storage.

The "One Table, Two Roles" Rule: Both metadata shot logs and actual scanned images share the same images database table, mapped by frame_number. We do not create duplicate rows during scans; we merge them if a shot log already exists for that frame number.

2. Step-by-Step Implementation Instructions

Step 2.1: Implement the "At Lab" Dual-Choice Selector Card

In frontend/lib/views/roll_detail_view.dart, locate the state when the Roll Status is RollStatus.lab (or "At Lab") and the gallery grid is empty.
Replace the blank grid with a beautifully designed dual-card interface (see mockups):

Option A (Lab Digital Sync): Displays a modern text field for Google Drive URLs. Tapping submit calls PATCH /api/v1/rolls/{id}/drive-url and updates the UI state to syncing.

Option B (Camera Scanning): Displays a prominent CTA button labeled "Scan Negatives (Bàn Sáng)". Clicking this button opens the Gyroscope Scan HUD Camera View.

Step 2.2: Build the Gyroscope HUD Overlays & Maths

Create a new full-screen Camera View widget GyroScanHudView using the Flutter camera package:

Device Orientation Sensor Hook: Listen to gyroscope/accelerometer updates from sensors_plus.

Deviation Angle ($\theta$) Math: Calculate the real-time pitch and roll deviation from a perfect parallel plane ($180^\circ$ parallel to the flat surface):


$$\theta = \sqrt{\Delta pitch^2 + \Delta roll^2}$$

Target Ring and Gyro Dot UI:

Draw a static Target Ring in the exact center of the screen.

Render a floating Gyro Dot that shifts dynamically based on pitch and roll sensor values.

Color Feedback States:

If $\theta > 1.0^\circ$: Dot is grey (Colors.zinc). Auto-snap is locked.

If $0.15^\circ < \theta \le 1.0^\circ$: Dot glides smoothly and turns bright orange (Colors.orange).

If $\theta \le 0.15^\circ$: Dot snaps to center, turns vivid green (Colors.green), and triggers haptic feedback.

Step 2.3: Implement the hands-free Auto-Snap Engine

Implement the automated shooting logic inside your controller/cubit:

When $\theta \le 0.50^\circ$, call the camera controller to lock Auto Focus (AF) and Lock Auto Exposure (AE) on a spot-weighted central area to avoid backlight flicker.

If $\theta \le 0.15^\circ$ remains stable for exactly $300\text{ms}$:

Programmatically capture a high-res frame using takePicture().

Trigger a heavy vibration click using HapticFeedback.heavyImpact().

Briefly flash a subtle orange vignette around the screen border to show a successful capture.

Instantly advance to the next index (e.g., from Frame 01 to Frame 02) and update the bottom horizontal camera carousel.

Step 2.4: Save to Local Storage Cache First

Do not stream high-resolution images to the server dynamically while shooting. Use the local-first caching model:

Save the captured raw image locally to:
Documents/HalideArchive/rolls/roll_{roll_id}/frames/frame_{N}_raw.heic (or .jpg / .png depending on hardware limits).

Generate an optimized lightweight thumbnail at:
Documents/HalideArchive/rolls/roll_{roll_id}/frames/frame_{N}_thumb.jpg.

Add a background task to the synchronization queue containing the target { "roll_id": roll_id, "frame_number": N, "local_raw_path": path }.

Step 2.5: Write the Meta-Merging Ingestion API & Client Sync Task

On Client Sync Queue: Iteratively pick up pending scan tasks. Send the files via a multipart boundary upload to the server.

On the Server (NestJS Backend):

Check if an entry in the images table already exists for roll_id and frame_number = N.

Case A (Exists): Keep the EXIF parameters (aperture, shutter) but update the database row's image_url with the remote Cloudflare R2 path.

Case B (Does not exist): Create a new Image record with frame_number = N and assign the R2 path.

Once the server confirms success, delete the bulky local raw files from user storage to save device capacity (while keeping the lightweight thumbs for offline grid displays!).

3. Review Checklist & Safety Guardrails

Do not break backward compatibility of the roll lifecycle state machine.

Verify that shot_offset works out-of-the-box by ensuring the metadata merges cleanly based on frame_number.

Ensure all sensors are disposed of properly when the camera view is closed to avoid battery drain.