import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class InputImageConverter {
  InputImageConverter._();

  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static InputImage? fromCameraImage({
    required CameraImage image,
    required CameraController controller,
    required CameraDescription cameraDescription,
  }) {
    final rotation = _getInputImageRotation(controller, cameraDescription);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  static InputImageRotation? _getInputImageRotation(CameraController controller, CameraDescription cameraDescription) {
    final sensorOrientation = cameraDescription.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (Platform.isAndroid) {
      final deviceOrientation = controller.value.deviceOrientation;
      final baseRotation = _orientationDegrees[deviceOrientation];
      if (baseRotation == null) return null;

      int rotationCompensation;
      if (cameraDescription.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + baseRotation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - baseRotation + 360) % 360;
      }
      return InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    return null;
  }
}
