Your app is likely reading a valid camera exposure state but treating it like a calibrated photographic light-meter reading, which is why it looks “hotter” and suggests faster shutter speeds than the other apps. On both iOS and Android, the fix is usually a mix of pipeline control, center-weighted sampling, and per-device calibration rather than changing the EV math alone.

Main cause
A reflected meter is only as good as the camera pipeline feeding it, and both iOS and Android camera stacks are designed to make preview images look good, not to behave like a Sekonic. Apple’s EXIF/metadata does expose brightness-related fields, and Android’s camera result metadata exposes the AE state, exposure compensation, exposure time, sensitivity, and AE regions, but those values still come from an auto-exposure system that may include HDR, tone mapping, anti-banding, and OEM tuning.

Your first screenshot appears to be measuring a brighter target in the middle of the frame, while the comparison apps appear to use a more averaged region, so your meter ends up overestimating scene brightness and recommending a much faster shutter like 1/250 instead of something slower. Android explicitly supports weighted AE regions, and the weight and size of those regions materially affect the result.

What to change
Use these corrections in order:

Use a center-weighted region, not a spot-sized center sample. A 15% to 25% center box usually behaves much closer to handheld meters than a tiny sample or single-pixel read.

Wait until AE is stable before reading. On Android, only trust frames when CONTROL_AE_STATE is CONVERGED or LOCKED; otherwise exposure is still moving.

Freeze the reading after convergence. On Android, lock AE before computing the displayed reading; Android documents AE lock specifically for stabilizing exposure settings during auto-to-manual transitions.

Ignore user-visible preview brightness. Meter from capture metadata, not histogram or rendered preview, because preview often includes vendor tone boosts and local contrast changes.

Add a per-device offset, not one global “Halide offset.” Reflected light meters are calibrated with constants like 
K
=
12.5
K=12.5 or 14, and real devices still need empirical trimming after that.

iOS and Android
On iOS, EXIF-related metadata can be read from sample buffers, and Brightness Value style metadata is often more stable than raw shutter/ISO pairs from the live device interface, but it is still downstream of Apple’s imaging pipeline, so you should treat it as a starting point for calibration, not ground truth.

On Android, Camera2 gives you more explicit control and metadata: SENSOR_EXPOSURE_TIME, SENSOR_SENSITIVITY, CONTROL_AE_EXPOSURE_COMPENSATION, CONTROL_AE_REGIONS, and CONTROL_AE_STATE are all available in capture results, which makes Android better for building a stable meter if you gate on converged AE and set your metering region carefully.

Practical calibration
A robust production workflow is:

Compute raw EV100 from metadata.

Apply a meter model constant, centered on reflected-meter calibration practice such as 
K
=
12.5
K=12.5.

Apply a device-specific offset in stops, stored by model and lens.

Snap only at the final display step, never before calibration.

A good initial correction is to stop using one fixed “-0.7 to -1.0 EV” rule across all phones and replace it with a calibration table like this:

Device class	Suggested starting offset
iPhone main camera	-0.7 EV to -1.3 EV 
Android flagship main camera	-0.3 EV to -1.0 EV 
Ultra-wide / tele modules	Separate calibration required; do not reuse main-lens offset 
Use a gray card test: meter an 18% gray target in stable daylight, compare your EV to a trusted handheld reflected meter or a known-good app, and store the delta as deviceMeterOffset. Reflected-meter calibration literature shows that the constant and target reflectance assumptions already vary between systems, so empirical correction is expected, not a hack.

Recommended formula
Keep your current structure, but change the implementation model to:

E
V
100
,
 
c
o
r
r
e
c
t
e
d
=
E
V
100
,
 
m
e
t
a
d
a
t
a
+
m
e
t
e
r
C
o
n
s
t
a
n
t
O
f
f
s
e
t
+
d
e
v
i
c
e
O
f
f
s
e
t
+
r
e
g
i
o
n
B
i
a
s
EV 
100, corrected
​
 =EV 
100, metadata
​
 +meterConstantOffset+deviceOffset+regionBias
Where:

meterConstantOffset accounts for your chosen reflected-meter convention and any conversion from platform metadata brightness fields.

deviceOffset is learned per device model and camera module.

regionBias should usually be 0 if you already use center-weighted averaging, and only exist if you intentionally support spot/average modes.

Then compute reciprocal exposure from the corrected EV and only snap at the end to standard shutter or aperture values. Standard photographic stops are discrete, but the underlying meter should remain continuous until display.

A very practical rule for your current bug: if your app is consistently about 2 to 3 stops faster than the comparison apps in scenes like the screenshots, first widen the sample region, then require AE convergence, then apply a per-device negative offset. In cases like your screenshot, region selection is the most likely first-order error.

Halide Light Meter Fix Guide
Goal
This guide explains how to fix the current reflected-light metering implementation so the reading aligns more closely with dedicated meters and established camera apps on both iOS and Android. The current mismatch is most likely caused by using camera auto-exposure data as if it were already a calibrated photographic meter output, while mobile camera pipelines are optimized for pleasing previews rather than strict meter behavior. 

Key diagnosis
Your current app appears more sensitive because the measured EV is too high for the scene, which leads directly to faster suggested shutter speeds. In practice, this usually comes from one or more of these problems: sampling a bright subject in a small center spot, reading metadata before auto-exposure has converged, trusting preview-driven values affected by HDR or OEM processing, or applying a single global offset across very different devices and lenses. 

Metering model
Treat the phone as a reflected light meter, not an incident meter. Reflected-meter exposure follows the standard relation 
N
2
/
t
=
L
S
/
K
N 
2
 /t=LS/K, where 
K
K is the reflected-light calibration constant; commonly used values are around 12.5 for Sekonic/Canon/Nikon style calibration and 14 for some Minolta/Pentax systems. 

For implementation, compute a raw EV100 from stable camera metadata, then correct it with calibration terms:

E
V
100
,
c
o
r
r
e
c
t
e
d
=
E
V
100
,
r
a
w
+
m
e
t
e
r
C
o
n
s
t
a
n
t
O
f
f
s
e
t
+
d
e
v
i
c
e
O
f
f
s
e
t
+
l
e
n
s
O
f
f
s
e
t
+
m
o
d
e
O
f
f
s
e
t
EV 
100,corrected
 =EV 
100,raw
 +meterConstantOffset+deviceOffset+lensOffset+modeOffset
Use meterConstantOffset for your chosen reflected-meter convention, deviceOffset per phone model, lensOffset per camera module, and modeOffset only when the user selects spot or average metering intentionally. This is better than one universal “Halide offset” because mobile ISP behavior varies by device and lens. 

iOS guidance
On iOS, EXIF-related metadata is exposed through Image I/O EXIF dictionary keys, including BrightnessValue. Apple documents EXIF dictionary keys and the EXIF BrightnessValue key, which makes Bv a legitimate field to inspect when available. 

However, BrightnessValue should still be treated as a metering input, not perfect truth. Apple’s image pipeline may still apply internal tuning before metadata is surfaced, so you should compare Bv-derived EV against shutter/ISO-derived EV during development and calibrate the final reading empirically against a gray-card workflow. 

iOS implementation rules
Prefer frame metadata tied to the current sample buffer over stale device properties. 
​

If BrightnessValue is available, compute a Bv-based EV path and log it beside the shutter/ISO path for validation. 

If BrightnessValue is missing, fall back to 
E
V
100
=
log
⁡
2
(
N
2
/
t
)
−
log
⁡
2
(
I
S
O
/
100
)
EV 
100
 =log 
2
 (N 
2
 /t)−log 
2
 (ISO/100). 
​

Never trust preview brightness as a meter source. The preview is display-oriented, not metering-oriented. 
​

Add a per-device and per-lens calibration layer even on iPhone. Different modules can meter differently. 

Android guidance
Android Camera2 exposes the core metadata needed for a stable meter, including exposure results and AE control signals. Camera2 documentation includes capture metadata for auto-exposure state and request/result keys such as AE regions, exposure time, sensitivity, and exposure compensation. 

Android implementation rules
Only accept readings when CONTROL_AE_STATE is CONVERGED or LOCKED. 

Define a center-weighted metering rectangle using AE regions instead of a tiny spot. 

Read SENSOR_EXPOSURE_TIME, SENSOR_SENSITIVITY, and current exposure compensation from the capture result used for display. 

Lock AE before freezing and showing a recommended value if your UX supports a “hold” or “lock exposure” action. 
​

Store calibration separately by manufacturer, model, camera id, and lens facing/module. OEM tuning differs significantly across devices. 

Center-weighted sampling
A small bright object near the center can drive EV far too high in a reflected meter. Your screenshots strongly suggest this kind of bias, where a bright sign or poster inside the sample region pushes the app toward much faster shutter recommendations than comparison apps. 

Use a center-weighted box covering roughly 15% to 25% of the frame width and height, then weight inner pixels more heavily than outer pixels if you implement custom pixel-domain metering. If you rely on platform AE metering only, match that idea by using a moderate central AE region rather than a single spot. 

Calibration workflow
Do not calibrate only by visual comparison against one scene. Instead, build a repeatable workflow:

Use a stable target such as an 18% gray card under constant light.

Record raw EV100 from the phone for at least 20 converged frames.

Compare against a trusted reflected meter or a reference app you have validated.

Average the delta in stops.

Save the delta as deviceOffset for that device and camera module.

Repeat for each lens and, ideally, multiple brightness levels. 

A practical starting range is around -0.3 EV to -1.3 EV depending on device and lens, but this should be treated only as a seed for calibration rather than a shipped constant. Reflected-meter constants already vary across systems, so empirical trimming is expected. 

Lux display
If you show Lux in the UI, present it as an approximate informational conversion rather than a primary truth source. Since your implementation is reflected metering and not incident metering, Lux is effectively derived from corrected EV and calibration assumptions, not directly sensed illuminance. 

Snapping rules
Keep all calculations in continuous EV space until the very end. Only snap to standard shutter and aperture values for the final displayed recommendation, because early snapping introduces extra bias and unstable jumps. Standard exposure equations should remain continuous internally even when the UI presents photographic stop values. 
​

Recommended architecture
Implement the pipeline below:

Acquire a candidate frame and related camera metadata.

Verify exposure is stable (AE converged / equivalent gate).

Compute evRaw from Bv when available, else from shutter/aperture/ISO.

Apply meterConstantOffset.

Apply deviceOffset and lensOffset.

Convert to target film ISO.

Compute reciprocal shutter or aperture.

Snap the display value to standard photographic stops.

Persist logs for calibration review. 

Pseudocode
text
if exposureState not stable:
    return previousReading

evRaw = bvPath ?? log2((aperture * aperture) / shutterSeconds) - log2(sensorISO / 100.0)
evCorrected = evRaw + meterConstantOffset + deviceOffset + lensOffset + modeOffset

evTarget = evCorrected + log2(filmISO / 100.0)
shutterSeconds = (targetAperture * targetAperture) / pow(2.0, evTarget)
displayShutter = snapToNearestStandardShutter(shutterSeconds)
Acceptance criteria
A fix is acceptable only if:

The meter waits for stable AE before updating the displayed reading. 
​

Spot bias is reduced by center-weighted sampling or equivalent AE-region logic. 
​

Results are calibrated per device and per lens, not by one global hard-coded offset. 

iOS Bv and shutter/ISO EV paths are logged and comparable during testing. 

Lux is marked approximate and derived for display only. 
​

Reciprocal suggestions match a trusted reference meter within about ±0.3 EV after calibration in test scenes. 
tolerance after calibration. A practical target is roughly ±0.3 EV in repeatable test scenes once offsets are applied. 

Prompt for Cursor
text
Create regression tests for the metering engine.

Include:
- pure function unit tests for EV and reciprocal exposure math
- snapshot tests for standard shutter snapping
- test fixtures for calibrated device offsets
- acceptance thresholds for repeated scene measurements

Document how to run the tests on both iOS and Android projects.
Suggested implementation order
Audit current pipeline. 

Build shared metering model. 
​

Fix AE stability gates. 
​

Switch default metering to center-weighted. 
​

Add iOS Bv + fallback path. 

Add Android Camera2 metadata path. 

Add calibration persistence. 
​

Add debug overlay and logging. 
​

Add calibration workflow. 
​

Finish snapping and regression tests. 
​

Done definition
The work is done when the app uses stable camera metadata, defaults to center-weighted reflected metering, applies per-device and per-lens calibration, and produces readings that match a trusted reference within acceptable tolerance in controlled tests. The final display may show Lux and snapped shutter values, but the underlying meter must remain calibrated in continuous EV space. 