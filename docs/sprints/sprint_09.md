# Sprint 09: Precision Alignment & Shot Merging

Handle the "loading frames" issue by allowing users to calibrate the offset between their technical logs and scanned images.

## Objectives
- [ ] Add `shot_offset` to `Roll` database model <!-- id: 1 -->
- [ ] Implement Offset Calibration Slider in `TECHNICAL DATA` tab <!-- id: 2 -->
- [ ] Add "Linked Metadata Overlay" to the `Photos` gallery grid <!-- id: 3 -->
- [ ] Display technical settings (Aperture/Shutter) in `FullScreenViewer` when aligned <!-- id: 4 -->

## Technical Details
- **Offset Logic**: If `offset = 2`, then `shots[0]` matches `imageUrls[2]`.
- **UI/UX**: Real-time preview of which shot maps to which image.
