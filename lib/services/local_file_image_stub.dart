import 'package:flutter/material.dart';

Widget buildLocalFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  return fallback;
}

Future<bool> localFileExists(String path) async => false;

Future<List<int>> readLocalFileBytes(String path) {
  throw UnsupportedError(
    'Native local file paths are not available on this platform.',
  );
}

String localFileName(String path) {
  final List<String> parts = path.split(RegExp(r'[\\/]'));
  return parts.isEmpty || parts.last.isEmpty ? 'upload.jpg' : parts.last;
}
