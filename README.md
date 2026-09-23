# Cable Locator

An offline, native iPhone prototype for recording cable ends before wall lining and finding them afterward. It is a separate Xcode app inside this workspace; it does not change Note Taker.

## Field workflow

1. Create a site and scan the wall **before gyprock**. Include permanent features such as a door opening, window, masonry edge, or floor junction in the scan.
2. Aim the crosshair at the wall surface at the cable end and save a mark. The app stores an AR anchor, a photo, a room name, notes, and distances across and up from a described fixed reference.
3. After lining, open the mark and choose **Find in AR**. Start near the original scan position and move slowly until the saved map aligns. The orange point then appears in the camera view.
4. Compare the point with the original photo and tape measurements before cutting. Use a cable tracer or another physical check if the references or AR alignment disagree.

ARKit combines the camera and motion tracking; on a LiDAR equipped iPhone it also supplies scene depth and a room mesh. The standard iPhone 17 has no rear LiDAR scanner, while iPhone 17 Pro and Pro Max do. The app checks capability at runtime and can still use camera based world tracking on supported iPhones. GPS, compass, barometer, Face ID, and ambient light sensors do not provide reliable cable location inside a wall, so they are not used as position measurements.

**Accuracy limit:** AR tracking is an estimate, and a saved `ARWorldMap` can fail to align after gyprock changes the appearance of the room. The app hides the AR point until alignment succeeds. The recorded photo and physical offsets are the dependable fallback. This prototype has not been validated on a physical site or calibrated for a guaranteed tolerance.

## Build

Open [CableLocator.xcodeproj](CableLocator.xcodeproj) in Xcode, select a physical iPhone and your Apple signing team, then run. iOS 17 or later is required. The simulator can show the project list but cannot validate camera, LiDAR, or AR tracking.

The project is generated from `project.yml` with `xcodegen generate`. XcodeGen is needed only if you change the project configuration; Xcode can open the checked in `.xcodeproj` directly. Data stays in the app's Documents directory and is included in normal device backups. There is no account or cloud sync in this prototype.
