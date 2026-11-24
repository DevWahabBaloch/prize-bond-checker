import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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

    final rawFormat = image.format.raw;
    if (rawFormat is! int || image.width <= 0 || image.height <= 0 || image.planes.length != 1) return null;
    final format = InputImageFormatValue.fromRawValue(rawFormat);
    final plane = image.planes.single;
    final valid = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        format == InputImageFormat.nv21 &&
            plane.bytesPerRow == image.width &&
            plane.bytes.length == image.width * image.height * 3 ~/ 2,
      TargetPlatform.iOS =>
        format == InputImageFormat.bgra8888 &&
            plane.bytesPerRow >= image.width * 4 &&
            plane.bytes.length >= plane.bytesPerRow * image.height,
      _ => false,
    };
    if (!valid || format == null) return null;

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

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
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
