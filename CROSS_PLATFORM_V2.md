# RD Online Shop Cross-Platform V2

One Flutter source tree for Windows, Android, iPhone/iPad, macOS and Web.

## V2 changes
- Removed direct `dart:io` dependencies from app pages so Web can compile.
- Added conditional native-local-file helpers. Old local-only image paths safely fall back on Web; Cloudinary URLs remain the portable image source.
- Cloudinary uploads now send `XFile` bytes rather than native filesystem paths.
- PDF/Excel exports share in-memory files and no longer require `dart:io` temp files.
- Seller GPS falls back to coordinates where reverse-geocoding is not supported.
- Android disables Kotlin incremental/classpath caches to avoid the known Windows cross-drive issue when the project is on D: but Pub cache is on C:.
- Startup keeps the visible loading/error gate instead of allowing an unexplained black window.
- iOS/macOS permissions and macOS sandbox/network/camera/location/audio entitlements are retained.

Use Flutter 3.44.4 consistently for this project. Final iPhone/iPad/macOS signing and binary validation requires macOS + Xcode.
