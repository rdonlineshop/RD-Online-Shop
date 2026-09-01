import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLocalFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  required Widget fallback,
}) {
  try {
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return fallback;
      },
    );
  } catch (_) {
    return fallback;
  }
}

Future<bool> localFileExists(String path) => File(path).exists();

Future<List<int>> readLocalFileBytes(String path) => File(path).readAsBytes();

String localFileName(String path) {
  final List<String> parts = path.split(RegExp(r'[\\/]'));
  return parts.isEmpty || parts.last.isEmpty ? 'upload.jpg' : parts.last;
}
