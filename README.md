# RD Online Shop — Cross-Platform V2

This source tree is prepared for Windows, Android, iPhone/iPad (iOS), macOS and Web using one Flutter codebase.

Recommended Flutter SDK for reproducible builds: **Flutter 3.44.4 / Dart 3.12.x**.

Important platform notes:
- Windows, Android and Web can be built/tested on Windows.
- iPhone/iPad and macOS final binary/signing validation requires a Mac with Xcode.
- Android Gradle settings intentionally disable Kotlin incremental/classpath caches because this project is commonly run from `D:` while the Windows Pub cache is under `C:`. That cross-drive layout is a known trigger for `Could not close incremental caches` failures.
- Old native-only image paths are isolated behind conditional imports. Portable product/shop photos should be Cloudinary/network URLs.
