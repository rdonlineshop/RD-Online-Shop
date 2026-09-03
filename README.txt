RD RIDE — CHAT VOICE + CORRECT MESSAGE ALIGNMENT SAFE FIX
==========================================================

PURPOSE
-------
This patch fixes the Ride Chat issues shown in the Android screenshots:
1. Customer/Driver/Admin messages no longer all stay on one side.
2. Customer view: Customer = RIGHT, Driver/Admin = LEFT.
3. Driver view: Driver = RIGHT, Customer/Admin = LEFT.
4. Admin view: Admin = RIGHT, Customer/Driver = LEFT.
5. Adds a microphone button for secure voice messages.
6. Keeps text + voice evidence immutable for customer/driver.
7. After the ride closes, customer/driver chat is hidden; Admin evidence remains available during the retention window.

FILES
-----
NEW:
  lib/ride_voice_message_player.dart

REPLACE:
  lib/ride_chat_page.dart
  lib/admin_ride_evidence_page.dart
  firestore.rules

IMPORTANT
---------
Do NOT replace other working Ride files from older ZIPs.
This patch does not replace:
- ride_driver_requests_page.dart
- ride_request_service.dart
- ride fare / commission files
- suspension / reactivation files
- customer tracking / My Rides files

The included firestore.rules is based on the latest Suspension + Reactivation rules so those permissions are preserved.

VOICE MESSAGE DESIGN
--------------------
- Maximum voice message: 20 seconds.
- Record -> Cancel or Stop & Send.
- Play / Pause + duration.
- No permanent voice file is saved on the customer/driver device by this feature.
- Chat message metadata stays in:
    ride_requests/{rideId}/messages/{messageId}
- Voice bytes are stored separately in:
    ride_requests/{rideId}/message_audio/{messageId}
  and are loaded only when Play is pressed.
- Customer/driver cannot update or delete original messages/audio.
- Admin can review text + voice evidence.
- Both metadata and audio payload include evidenceExpiresAt for 90-day TTL cleanup.

ADMIN CHAT
----------
Ride Evidence now shows "Open Admin Chat" while a ride is ACCEPTED / IN PROGRESS.
- Admin's own messages = RIGHT.
- Customer/Driver messages = LEFT.
- Once the ride is completed/closed, Admin evidence stays read-only.

DEPENDENCIES
------------
Use the project-pinned Flutter 3.44.4 SDK. Add only these two packages:

& "$env:USERPROFILE\Downloads\flutter_windows_3.44.4-stable\flutter\bin\flutter.bat" pub add record:6.2.1 audioplayers:6.5.1

Then analyze:

& "$env:USERPROFILE\Downloads\flutter_windows_3.44.4-stable\flutter\bin\flutter.bat" analyze --no-pub

Do NOT deploy rules until analyzer is clean.

After "No issues found!", deploy Firestore rules:

& "$env:APPDATA\npm\firebase.cmd" deploy --only firestore:rules

ANDROID TEST ORDER
------------------
1. Create a NEW ride.
2. Driver Accept.
3. Customer Chat:
   - customer message RIGHT
   - driver message LEFT
   - mic button visible
4. Driver Chat:
   - driver message RIGHT
   - customer message LEFT
5. Send a short voice message Customer -> Driver and play it.
6. Send a short voice message Driver -> Customer and play it.
7. Admin -> Ride Evidence -> active ride -> Open Admin Chat:
   - Admin message RIGHT
   - Customer/Driver messages LEFT
8. Complete ride and verify customer/driver chat is closed.
9. Admin Ride Evidence must still show/play evidence.

TTL NOTE
--------
The app writes evidenceExpiresAt, but Firestore TTL policy must still be enabled once for BOTH collection groups:
- messages -> evidenceExpiresAt
- message_audio -> evidenceExpiresAt
Do this only after the runtime flow is confirmed.

GIT
---
Do not commit yet. First pass analyzer + rules deploy + Android runtime tests, then Windows/Web tests.
