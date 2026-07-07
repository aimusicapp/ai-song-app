import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/song_params.dart';

/// Streams the front camera and periodically classifies the user's
/// expression into a Mood. Runs entirely on-device, nothing leaves the phone.
class CameraMoodService {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast),
  );

  bool _busy = false;
  bool _disposed = false;
  CameraDescription? _cameraDescription;

  Mood _lastMood = Mood.neutral;
  Mood get lastMood => _lastMood;

  CameraController? get controller => _controller;

  Future<bool> start({required void Function(Mood mood) onMood}) async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraDescription = front;
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      _controller = controller;

      await controller.startImageStream((CameraImage image) {
        if (_busy || _disposed) return;
        _busy = true;
        _processFrame(image, onMood).whenComplete(() {
          _busy = false;
        });
      });
      return true;
    } catch (e) {
      debugPrint('CameraMoodService: camera unavailable ($e)');
      return false;
    }
  }

  Future<void> _processFrame(CameraImage image, void Function(Mood mood) onMood) async {
    try {
      final rotation = InputImageRotationValue.fromRawValue(_cameraDescription?.sensorOrientation ?? 90) ??
          InputImageRotation.rotation90deg;

      final inputImage = InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty || _disposed) return;

      final face = faces.first;
      final double smile = face.smilingProbability ?? 0.5;
      Mood mood;
      if (smile > 0.65) {
        mood = Mood.happy;
      } else if (smile < 0.2) {
        mood = Mood.sad;
      } else {
        mood = Mood.neutral;
      }

      _lastMood = mood;
      onMood(mood);
    } catch (e) {
      debugPrint('CameraMoodService: frame processing failed ($e)');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    } catch (_) {}
    await _controller?.dispose();
    await _faceDetector.close();
  }
}
