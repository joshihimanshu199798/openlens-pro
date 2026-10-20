import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OpenLensApp());
}

class OpenLensApp extends StatelessWidget {
  const OpenLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenLens Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8F36B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF080A0C),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _busy = false;
  bool _recording = false;
  bool _grid = true;
  String _compositionGuide = 'Thirds';
  bool _showSettings = false;
  bool _focusLocked = false;
  bool _exposureLocked = false;
  bool _showHistogram = false;
  int _selfTimerSeconds = 0;
  bool _burstMode = false;
  int? _countdownRemaining;
  bool _histogramStreamRunning = false;
  List<double> _histogram = List<double>.filled(32, 0);
  double _highlightPercent = 0;
  DateTime _lastHistogramUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  String _status = 'Starting camera…';
  String _mode = 'PHOTO';
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _exposure = 0;
  double _minExposure = 0;
  double _maxExposure = 0;
  FlashMode _flash = FlashMode.off;
  String _activePreset = 'Auto';
  static const String _customPresetsKey = 'openlens_custom_presets_v1';
  List<_SignaturePreset> _customPresets = [];
  double _gradeBrightness = 0;
  double _gradeContrast = 1;
  double _gradeSaturation = 1;
  double _gradeWarmth = 0;
  double _gradeTint = 0;

  // Curated original recipes inspired by widely used film, portrait, cinematic,
  // travel, street, monochrome, social, night, and product-grading aesthetics.
  static const List<_SignaturePreset> _libraryPresets = [
  _SignaturePreset('Portra Glow', 'Film look', Icons.camera_roll_rounded, 0.06, 1.0, FlashMode.off, category: 'Film', brightness: 0.03, contrast: 1.03, saturation: 0.92, warmth: 0.22, tint: 0.02),
  _SignaturePreset('Gold 200', 'Film look', Icons.camera_roll_rounded, 0.10, 1.0, FlashMode.off, category: 'Film', brightness: 0.05, contrast: 1.12, saturation: 1.12, warmth: 0.35, tint: 0.01),
  _SignaturePreset('Chrome Slide', 'Film look', Icons.camera_roll_rounded, 0.00, 1.0, FlashMode.off, category: 'Film', brightness: 0.00, contrast: 1.22, saturation: 1.22, warmth: 0.06, tint: -0.02),
  _SignaturePreset('Soft Negative', 'Film look', Icons.camera_roll_rounded, 0.12, 1.0, FlashMode.off, category: 'Film', brightness: 0.06, contrast: 0.92, saturation: 0.88, warmth: 0.18, tint: 0.04),
  _SignaturePreset('Classic 400', 'Film look', Icons.camera_roll_rounded, 0.02, 1.0, FlashMode.off, category: 'Film', brightness: 0.01, contrast: 1.14, saturation: 1.05, warmth: 0.12, tint: 0.00),
  _SignaturePreset('Faded Film', 'Film look', Icons.camera_roll_rounded, 0.16, 1.0, FlashMode.off, category: 'Film', brightness: 0.08, contrast: 0.86, saturation: 0.78, warmth: 0.16, tint: 0.03),
  _SignaturePreset('Ektar Pop', 'Film look', Icons.camera_roll_rounded, 0.00, 1.0, FlashMode.off, category: 'Film', brightness: 0.00, contrast: 1.20, saturation: 1.28, warmth: 0.04, tint: -0.01),
  _SignaturePreset('Superia Green', 'Film look', Icons.camera_roll_rounded, 0.00, 1.0, FlashMode.off, category: 'Film', brightness: 0.00, contrast: 1.08, saturation: 1.06, warmth: -0.02, tint: -0.08),
  _SignaturePreset('Warm Print', 'Film look', Icons.camera_roll_rounded, 0.08, 1.0, FlashMode.off, category: 'Film', brightness: 0.04, contrast: 1.05, saturation: 0.96, warmth: 0.28, tint: 0.02),
  _SignaturePreset('Slide Punch', 'Film look', Icons.camera_roll_rounded, 0.00, 1.0, FlashMode.off, category: 'Film', brightness: 0.00, contrast: 1.28, saturation: 1.18, warmth: 0.03, tint: 0.00),
  _SignaturePreset('Teal & Amber', 'Cinematic look', Icons.movie_filter_rounded, -0.04, 1.0, FlashMode.off, category: 'Cinematic', brightness: -0.02, contrast: 1.22, saturation: 0.94, warmth: 0.18, tint: -0.06),
  _SignaturePreset('Blockbuster', 'Cinematic look', Icons.movie_filter_rounded, 0.00, 1.0, FlashMode.off, category: 'Cinematic', brightness: 0.00, contrast: 1.28, saturation: 1.10, warmth: 0.10, tint: -0.03),
  _SignaturePreset('Indie Frame', 'Cinematic look', Icons.movie_filter_rounded, 0.10, 1.0, FlashMode.off, category: 'Cinematic', brightness: 0.05, contrast: 0.92, saturation: 0.82, warmth: 0.12, tint: 0.05),
  _SignaturePreset('Bleach Bypass', 'Cinematic look', Icons.movie_filter_rounded, -0.06, 1.0, FlashMode.off, category: 'Cinematic', brightness: -0.03, contrast: 1.42, saturation: 0.62, warmth: -0.04, tint: 0.00),
  _SignaturePreset('Desert Cinema', 'Cinematic look', Icons.movie_filter_rounded, 0.04, 1.0, FlashMode.off, category: 'Cinematic', brightness: 0.02, contrast: 1.16, saturation: 0.91, warmth: 0.31, tint: 0.02),
  _SignaturePreset('Arctic Thriller', 'Cinematic look', Icons.movie_filter_rounded, -0.04, 1.0, FlashMode.off, category: 'Cinematic', brightness: -0.02, contrast: 1.18, saturation: 0.82, warmth: -0.25, tint: -0.02),
  _SignaturePreset('Neo Noir', 'Cinematic look', Icons.movie_filter_rounded, -0.24, 1.0, FlashMode.off, category: 'Cinematic', brightness: -0.12, contrast: 1.38, saturation: 0.78, warmth: -0.08, tint: 0.01),
  _SignaturePreset('Golden Scene', 'Cinematic look', Icons.movie_filter_rounded, 0.12, 1.0, FlashMode.off, category: 'Cinematic', brightness: 0.06, contrast: 1.10, saturation: 1.02, warmth: 0.32, tint: 0.02),
  _SignaturePreset('Muted Drama', 'Cinematic look', Icons.movie_filter_rounded, -0.04, 1.0, FlashMode.off, category: 'Cinematic', brightness: -0.02, contrast: 1.16, saturation: 0.72, warmth: 0.02, tint: 0.03),
  _SignaturePreset('Dream Sequence', 'Cinematic look', Icons.movie_filter_rounded, 0.16, 1.0, FlashMode.off, category: 'Cinematic', brightness: 0.08, contrast: 0.88, saturation: 0.86, warmth: 0.15, tint: 0.06),
  _SignaturePreset('Natural Skin', 'Portrait look', Icons.face_retouching_natural_rounded, 0.08, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.04, contrast: 0.98, saturation: 0.92, warmth: 0.08, tint: 0.01),
  _SignaturePreset('Soft Portrait', 'Portrait look', Icons.face_retouching_natural_rounded, 0.16, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.08, contrast: 0.88, saturation: 0.88, warmth: 0.12, tint: 0.03),
  _SignaturePreset('Golden Skin', 'Portrait look', Icons.face_retouching_natural_rounded, 0.08, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.04, contrast: 1.05, saturation: 1.00, warmth: 0.24, tint: 0.02),
  _SignaturePreset('Editorial Clean', 'Portrait look', Icons.face_retouching_natural_rounded, 0.04, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.02, contrast: 1.12, saturation: 0.94, warmth: 0.04, tint: 0.00),
  _SignaturePreset('Pastel Portrait', 'Portrait look', Icons.face_retouching_natural_rounded, 0.18, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.09, contrast: 0.90, saturation: 0.80, warmth: 0.10, tint: 0.05),
  _SignaturePreset('Deep Skin Rich', 'Portrait look', Icons.face_retouching_natural_rounded, 0.02, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.01, contrast: 1.16, saturation: 1.04, warmth: 0.12, tint: 0.02),
  _SignaturePreset('Studio Neutral', 'Portrait look', Icons.face_retouching_natural_rounded, 0.00, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.00, contrast: 1.08, saturation: 0.96, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Romantic Glow', 'Portrait look', Icons.face_retouching_natural_rounded, 0.20, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.10, contrast: 0.90, saturation: 0.90, warmth: 0.20, tint: 0.04),
  _SignaturePreset('Fashion Contrast', 'Portrait look', Icons.face_retouching_natural_rounded, -0.04, 1.0, FlashMode.off, category: 'Portrait', brightness: -0.02, contrast: 1.28, saturation: 1.02, warmth: 0.06, tint: -0.01),
  _SignaturePreset('Monochrome Portrait', 'Portrait look', Icons.face_retouching_natural_rounded, 0.02, 1.0, FlashMode.off, category: 'Portrait', brightness: 0.01, contrast: 1.20, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Alpine Clarity', 'Landscape & Travel look', Icons.landscape_rounded, 0.04, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.02, contrast: 1.20, saturation: 1.16, warmth: -0.06, tint: -0.01),
  _SignaturePreset('Tropical Aqua', 'Landscape & Travel look', Icons.landscape_rounded, 0.06, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.03, contrast: 1.10, saturation: 1.24, warmth: 0.08, tint: -0.04),
  _SignaturePreset('Desert Earth', 'Landscape & Travel look', Icons.landscape_rounded, 0.06, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.03, contrast: 1.10, saturation: 0.96, warmth: 0.28, tint: 0.02),
  _SignaturePreset('Iceland Blue', 'Landscape & Travel look', Icons.landscape_rounded, -0.04, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: -0.02, contrast: 1.18, saturation: 0.92, warmth: -0.24, tint: -0.02),
  _SignaturePreset('Forest Depth', 'Landscape & Travel look', Icons.landscape_rounded, -0.08, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: -0.04, contrast: 1.22, saturation: 0.92, warmth: -0.06, tint: -0.05),
  _SignaturePreset('Coastal Air', 'Landscape & Travel look', Icons.landscape_rounded, 0.16, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.08, contrast: 0.92, saturation: 0.88, warmth: -0.06, tint: 0.02),
  _SignaturePreset('Golden Hour', 'Landscape & Travel look', Icons.landscape_rounded, 0.16, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.08, contrast: 1.04, saturation: 1.08, warmth: 0.36, tint: 0.02),
  _SignaturePreset('Travel Vivid', 'Landscape & Travel look', Icons.landscape_rounded, 0.04, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.02, contrast: 1.16, saturation: 1.30, warmth: 0.08, tint: 0.00),
  _SignaturePreset('Misty Mountains', 'Landscape & Travel look', Icons.landscape_rounded, 0.12, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.06, contrast: 0.86, saturation: 0.78, warmth: -0.10, tint: 0.02),
  _SignaturePreset('City Explorer', 'Landscape & Travel look', Icons.landscape_rounded, 0.00, 1.0, FlashMode.off, category: 'Landscape & Travel', brightness: 0.00, contrast: 1.16, saturation: 1.08, warmth: 0.02, tint: -0.01),
  _SignaturePreset('Tokyo Crosswalk', 'Street & Urban look', Icons.location_city_rounded, 0.00, 1.0, FlashMode.off, category: 'Street & Urban', brightness: 0.00, contrast: 1.20, saturation: 1.08, warmth: -0.04, tint: -0.03),
  _SignaturePreset('Concrete Fade', 'Street & Urban look', Icons.location_city_rounded, 0.10, 1.0, FlashMode.off, category: 'Street & Urban', brightness: 0.05, contrast: 0.90, saturation: 0.78, warmth: -0.04, tint: 0.02),
  _SignaturePreset('Urban Grit', 'Street & Urban look', Icons.location_city_rounded, -0.16, 1.0, FlashMode.off, category: 'Street & Urban', brightness: -0.08, contrast: 1.32, saturation: 0.92, warmth: -0.05, tint: 0.00),
  _SignaturePreset('Street Chrome', 'Street & Urban look', Icons.location_city_rounded, 0.00, 1.0, FlashMode.off, category: 'Street & Urban', brightness: 0.00, contrast: 1.18, saturation: 1.20, warmth: -0.02, tint: -0.02),
  _SignaturePreset('Rainy Avenue', 'Street & Urban look', Icons.location_city_rounded, -0.06, 1.0, FlashMode.off, category: 'Street & Urban', brightness: -0.03, contrast: 1.12, saturation: 0.78, warmth: -0.12, tint: 0.00),
  _SignaturePreset('Market Colors', 'Street & Urban look', Icons.location_city_rounded, 0.06, 1.0, FlashMode.off, category: 'Street & Urban', brightness: 0.03, contrast: 1.10, saturation: 1.20, warmth: 0.10, tint: 0.01),
  _SignaturePreset('Subway Green', 'Street & Urban look', Icons.location_city_rounded, -0.04, 1.0, FlashMode.off, category: 'Street & Urban', brightness: -0.02, contrast: 1.18, saturation: 0.92, warmth: -0.03, tint: -0.08),
  _SignaturePreset('Cross Process', 'Street & Urban look', Icons.location_city_rounded, 0.02, 1.0, FlashMode.off, category: 'Street & Urban', brightness: 0.01, contrast: 1.20, saturation: 1.18, warmth: 0.02, tint: 0.08),
  _SignaturePreset('Dusty Sidewalk', 'Street & Urban look', Icons.location_city_rounded, 0.04, 1.0, FlashMode.off, category: 'Street & Urban', brightness: 0.02, contrast: 0.96, saturation: 0.86, warmth: 0.10, tint: 0.01),
  _SignaturePreset('Hard Sun Street', 'Street & Urban look', Icons.location_city_rounded, -0.04, 1.0, FlashMode.off, category: 'Street & Urban', brightness: -0.02, contrast: 1.34, saturation: 1.06, warmth: 0.04, tint: 0.00),
  _SignaturePreset('Analog Memories', 'Vintage & Retro look', Icons.history_rounded, 0.14, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.07, contrast: 0.88, saturation: 0.82, warmth: 0.18, tint: 0.03),
  _SignaturePreset('Sepia Journal', 'Vintage & Retro look', Icons.history_rounded, 0.08, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.04, contrast: 0.98, saturation: 0.48, warmth: 0.25, tint: 0.02),
  _SignaturePreset('Polaroid Fade', 'Vintage & Retro look', Icons.history_rounded, 0.20, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.10, contrast: 0.82, saturation: 0.76, warmth: 0.16, tint: 0.02),
  _SignaturePreset('Retro Pop', 'Vintage & Retro look', Icons.history_rounded, 0.04, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.02, contrast: 1.16, saturation: 1.20, warmth: 0.14, tint: 0.02),
  _SignaturePreset('Old Newspaper', 'Vintage & Retro look', Icons.history_rounded, 0.04, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.02, contrast: 1.12, saturation: 0.10, warmth: 0.02, tint: 0.00),
  _SignaturePreset('70s Warmth', 'Vintage & Retro look', Icons.history_rounded, 0.12, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.06, contrast: 0.96, saturation: 0.96, warmth: 0.32, tint: 0.02),
  _SignaturePreset('80s Flash', 'Vintage & Retro look', Icons.history_rounded, 0.16, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.08, contrast: 1.18, saturation: 1.18, warmth: 0.12, tint: 0.01),
  _SignaturePreset('90s Disposable', 'Vintage & Retro look', Icons.history_rounded, 0.06, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.03, contrast: 1.10, saturation: 1.08, warmth: 0.14, tint: 0.02),
  _SignaturePreset('Matte Memories', 'Vintage & Retro look', Icons.history_rounded, 0.16, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.08, contrast: 0.82, saturation: 0.82, warmth: 0.10, tint: 0.04),
  _SignaturePreset('Retro Teal', 'Vintage & Retro look', Icons.history_rounded, 0.04, 1.0, FlashMode.off, category: 'Vintage & Retro', brightness: 0.02, contrast: 1.06, saturation: 0.88, warmth: 0.04, tint: -0.04),
  _SignaturePreset('Silver Gelatin', 'Black & White look', Icons.tonality_rounded, 0.00, 1.0, FlashMode.off, category: 'Black & White', brightness: 0.00, contrast: 1.28, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Classic Mono', 'Black & White look', Icons.tonality_rounded, 0.04, 1.0, FlashMode.off, category: 'Black & White', brightness: 0.02, contrast: 1.12, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Noir Contrast', 'Black & White look', Icons.tonality_rounded, -0.16, 1.0, FlashMode.off, category: 'Black & White', brightness: -0.08, contrast: 1.48, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Soft Mono', 'Black & White look', Icons.tonality_rounded, 0.16, 1.0, FlashMode.off, category: 'Black & White', brightness: 0.08, contrast: 0.86, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Matte B&W', 'Black & White look', Icons.tonality_rounded, 0.16, 1.0, FlashMode.off, category: 'Black & White', brightness: 0.08, contrast: 0.82, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Street Mono', 'Black & White look', Icons.tonality_rounded, -0.06, 1.0, FlashMode.off, category: 'Black & White', brightness: -0.03, contrast: 1.36, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('High Key Mono', 'Black & White look', Icons.tonality_rounded, 0.28, 1.0, FlashMode.off, category: 'Black & White', brightness: 0.14, contrast: 1.04, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Low Key Mono', 'Black & White look', Icons.tonality_rounded, -0.30, 1.0, FlashMode.off, category: 'Black & White', brightness: -0.15, contrast: 1.28, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Warm Monochrome', 'Black & White look', Icons.tonality_rounded, 0.06, 1.0, FlashMode.off, category: 'Black & White', brightness: 0.03, contrast: 1.10, saturation: 0.00, warmth: 0.12, tint: 0.00),
  _SignaturePreset('Fine Art Mono', 'Black & White look', Icons.tonality_rounded, 0.08, 1.0, FlashMode.off, category: 'Black & White', brightness: 0.04, contrast: 1.18, saturation: 0.00, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Creator Bright', 'Social & Vibrant look', Icons.bolt_rounded, 0.20, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.10, contrast: 1.04, saturation: 1.18, warmth: 0.08, tint: 0.00),
  _SignaturePreset('Candy Colors', 'Social & Vibrant look', Icons.bolt_rounded, 0.12, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.06, contrast: 1.00, saturation: 1.42, warmth: 0.10, tint: 0.03),
  _SignaturePreset('Punchy Pop', 'Social & Vibrant look', Icons.bolt_rounded, 0.00, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.00, contrast: 1.24, saturation: 1.42, warmth: 0.04, tint: 0.00),
  _SignaturePreset('Pastel Feed', 'Social & Vibrant look', Icons.bolt_rounded, 0.20, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.10, contrast: 0.88, saturation: 0.86, warmth: 0.12, tint: 0.04),
  _SignaturePreset('Clean Influencer', 'Social & Vibrant look', Icons.bolt_rounded, 0.12, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.06, contrast: 1.00, saturation: 1.04, warmth: 0.08, tint: 0.00),
  _SignaturePreset('Summer Splash', 'Social & Vibrant look', Icons.bolt_rounded, 0.16, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.08, contrast: 1.08, saturation: 1.32, warmth: 0.22, tint: -0.02),
  _SignaturePreset('Electric Color', 'Social & Vibrant look', Icons.bolt_rounded, 0.00, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.00, contrast: 1.20, saturation: 1.48, warmth: -0.02, tint: -0.04),
  _SignaturePreset('Fresh Greens', 'Social & Vibrant look', Icons.bolt_rounded, 0.08, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.04, contrast: 1.08, saturation: 1.16, warmth: -0.02, tint: -0.06),
  _SignaturePreset('Peachy Glow', 'Social & Vibrant look', Icons.bolt_rounded, 0.16, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.08, contrast: 0.92, saturation: 1.02, warmth: 0.24, tint: 0.04),
  _SignaturePreset('Bold Thumbnail', 'Social & Vibrant look', Icons.bolt_rounded, 0.04, 1.0, FlashMode.off, category: 'Social & Vibrant', brightness: 0.02, contrast: 1.32, saturation: 1.34, warmth: 0.08, tint: 0.00),
  _SignaturePreset('Neon Tokyo', 'Night & Neon look', Icons.nightlight_round, -0.16, 1.0, FlashMode.off, category: 'Night & Neon', brightness: -0.08, contrast: 1.28, saturation: 1.24, warmth: -0.12, tint: -0.04),
  _SignaturePreset('Midnight Blue', 'Night & Neon look', Icons.nightlight_round, -0.24, 1.0, FlashMode.off, category: 'Night & Neon', brightness: -0.12, contrast: 1.22, saturation: 0.86, warmth: -0.24, tint: -0.02),
  _SignaturePreset('Cyberpunk Magenta', 'Night & Neon look', Icons.nightlight_round, -0.08, 1.0, FlashMode.off, category: 'Night & Neon', brightness: -0.04, contrast: 1.20, saturation: 1.22, warmth: -0.02, tint: 0.14),
  _SignaturePreset('Night Market', 'Night & Neon look', Icons.nightlight_round, 0.00, 1.0, FlashMode.off, category: 'Night & Neon', brightness: 0.00, contrast: 1.14, saturation: 1.18, warmth: 0.06, tint: -0.02),
  _SignaturePreset('Blue Hour', 'Night & Neon look', Icons.nightlight_round, -0.04, 1.0, FlashMode.off, category: 'Night & Neon', brightness: -0.02, contrast: 1.12, saturation: 0.92, warmth: -0.18, tint: -0.01),
  _SignaturePreset('Neon Rain', 'Night & Neon look', Icons.nightlight_round, -0.12, 1.0, FlashMode.off, category: 'Night & Neon', brightness: -0.06, contrast: 1.26, saturation: 1.12, warmth: -0.10, tint: 0.04),
  _SignaturePreset('Warm Streetlamp', 'Night & Neon look', Icons.nightlight_round, 0.04, 1.0, FlashMode.off, category: 'Night & Neon', brightness: 0.02, contrast: 1.12, saturation: 0.96, warmth: 0.30, tint: 0.02),
  _SignaturePreset('Club Lights', 'Night & Neon look', Icons.nightlight_round, -0.20, 1.0, FlashMode.off, category: 'Night & Neon', brightness: -0.10, contrast: 1.34, saturation: 1.30, warmth: -0.06, tint: 0.04),
  _SignaturePreset('Moonlit Fog', 'Night & Neon look', Icons.nightlight_round, 0.08, 1.0, FlashMode.off, category: 'Night & Neon', brightness: 0.04, contrast: 0.88, saturation: 0.72, warmth: -0.18, tint: 0.02),
  _SignaturePreset('Dark City', 'Night & Neon look', Icons.nightlight_round, -0.28, 1.0, FlashMode.off, category: 'Night & Neon', brightness: -0.14, contrast: 1.32, saturation: 0.82, warmth: -0.08, tint: 0.00),
  _SignaturePreset('Cafe Warmth', 'Food & Product look', Icons.restaurant_rounded, 0.10, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.05, contrast: 1.04, saturation: 1.02, warmth: 0.22, tint: 0.01),
  _SignaturePreset('Fresh Plate', 'Food & Product look', Icons.restaurant_rounded, 0.16, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.08, contrast: 1.02, saturation: 1.12, warmth: 0.06, tint: 0.00),
  _SignaturePreset('Bakery Gold', 'Food & Product look', Icons.restaurant_rounded, 0.10, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.05, contrast: 1.10, saturation: 1.06, warmth: 0.30, tint: 0.01),
  _SignaturePreset('Menu Clean', 'Food & Product look', Icons.restaurant_rounded, 0.16, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.08, contrast: 0.96, saturation: 0.98, warmth: 0.04, tint: 0.00),
  _SignaturePreset('Rich Espresso', 'Food & Product look', Icons.restaurant_rounded, -0.04, 1.0, FlashMode.off, category: 'Food & Product', brightness: -0.02, contrast: 1.24, saturation: 0.90, warmth: 0.16, tint: 0.01),
  _SignaturePreset('Dessert Pop', 'Food & Product look', Icons.restaurant_rounded, 0.12, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.06, contrast: 1.08, saturation: 1.24, warmth: 0.14, tint: 0.02),
  _SignaturePreset('Product White', 'Food & Product look', Icons.restaurant_rounded, 0.24, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.12, contrast: 0.92, saturation: 0.94, warmth: 0.00, tint: 0.00),
  _SignaturePreset('Moody Restaurant', 'Food & Product look', Icons.restaurant_rounded, -0.16, 1.0, FlashMode.off, category: 'Food & Product', brightness: -0.08, contrast: 1.26, saturation: 0.82, warmth: 0.12, tint: 0.00),
  _SignaturePreset('Farm Fresh', 'Food & Product look', Icons.restaurant_rounded, 0.08, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.04, contrast: 1.04, saturation: 1.10, warmth: -0.02, tint: -0.04),
  _SignaturePreset('Luxury Gold', 'Food & Product look', Icons.restaurant_rounded, 0.04, 1.0, FlashMode.off, category: 'Food & Product', brightness: 0.02, contrast: 1.18, saturation: 0.96, warmth: 0.24, tint: 0.00),
  ];

  // Original OpenLens presets use real camera controls supported by the device.
  static const List<_SignaturePreset> _presets = [
    _SignaturePreset('Auto', 'Balanced', Icons.auto_awesome_rounded, 0.0, 1.0, FlashMode.off),
    _SignaturePreset('Monsoon Chrome', 'Bright skies', Icons.water_drop_rounded, 0.3, 1.0, FlashMode.off),
    _SignaturePreset('Neon Bazaar', 'Night lights', Icons.bolt_rounded, -0.3, 1.0, FlashMode.off),
    _SignaturePreset('Moonmilk', 'Soft low light', Icons.nightlight_round, 0.7, 1.0, FlashMode.off),
    _SignaturePreset('Dust & Gold', 'Warm daylight', Icons.wb_sunny_rounded, 0.3, 1.0, FlashMode.off),
    _SignaturePreset('Quiet Detail', 'Closer framing', Icons.center_focus_strong_rounded, 0.0, 1.4, FlashMode.off),
    _SignaturePreset('Shadow Atlas', 'Deep contrast', Icons.landscape_rounded, -0.7, 1.0, FlashMode.off),
    _SignaturePreset('Candle Keeper', 'Extra light', Icons.flare_rounded, 0.3, 1.0, FlashMode.auto),
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomPresets();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (mounted) setState(() => _status = 'Checking camera permission…');
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) setState(() => _status = 'Camera permission is required.');
        return;
      }
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _status = 'No camera found on this device.');
        return;
      }
      await _openCamera(_cameraIndex);
    } catch (e) {
      if (mounted) setState(() => _status = 'Camera unavailable: $e');
    }
  }

  Future<void> _openCamera(int index) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    final next = CameraController(
      _cameras[index],
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await next.initialize();
      _minZoom = await next.getMinZoomLevel();
      _maxZoom = await next.getMaxZoomLevel();
      _minExposure = await next.getMinExposureOffset();
      _maxExposure = await next.getMaxExposureOffset();
      _zoom = _minZoom;
      _exposure = 0.clamp(_minExposure, _maxExposure).toDouble();
      if (mounted) {
        setState(() {
          _controller = next;
          _status = 'Ready · ${_cameras[index].lensDirection.name} camera';
        });
        if (_showHistogram) await _startHistogramStream(next);
      } else {
        await next.dispose();
      }
    } catch (e) {
      await next.dispose();
      if (mounted) setState(() => _status = 'Could not start camera: $e');
    }
  }


  List<_SignaturePreset> get _allPresets => [..._presets, ..._customPresets];

  Future<void> _loadCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_customPresetsKey);
    if (encoded == null || encoded.isEmpty) return;
    try {
      final list = (jsonDecode(encoded) as List<dynamic>).map((item) =>
        _SignaturePreset.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      if (mounted) setState(() => _customPresets = list);
    } catch (_) { _showMessage('Saved custom presets could not be loaded.'); }
  }

  Future<void> _importCustomPreset() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw const FormatException();
      final decoded = jsonDecode(utf8.decode(bytes));
      final entries = decoded is Map && decoded['presets'] is List ? decoded['presets'] as List : decoded is List ? decoded : [decoded];
      final imported = entries.map((entry) => _SignaturePreset.fromJson(Map<String, dynamic>.from(entry as Map))).toList();
      if (imported.isEmpty || imported.length > 30) throw const FormatException();
      final names = <String>{..._presets.map((p) => p.name.toLowerCase()), ..._customPresets.map((p) => p.name.toLowerCase())};
      for (final preset in imported) { if (!names.add(preset.name.toLowerCase())) throw const FormatException(); }
      final next = [..._customPresets, ...imported];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customPresetsKey, jsonEncode(next.map((p) => p.toJson()).toList()));
      if (!mounted) return;
      setState(() => _customPresets = next);
      _showMessage('Imported ${imported.length} custom preset(s).');
    } catch (_) { _showMessage('Import failed. Choose a valid OpenLens JSON preset file.'); }
  }

  Future<void> _exportPresetFormat() async {
    final entries = _customPresets.isEmpty
        ? <Map<String, dynamic>>[
            {'name':'My Film','hint':'Example custom grade','category':'Film','brightness':0.02,'contrast':1.12,'saturation':0.9,'warmth':0.25,'tint':0.03,'exposure':0.0,'zoomFactor':1.0,'flash':'off'},
          ]
        : _customPresets.map((preset) => preset.toJson()).toList();
    final payload = {
      'format': 'openlens-grade-v1',
      'presets': entries,
    };
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)));
    _showMessage(_customPresets.isEmpty
        ? 'Example preset JSON copied. Add custom looks to export your own.'
        : 'Exported ${_customPresets.length} custom preset(s) as JSON to clipboard.');
  }

  Future<void> _openGalleryPreview() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
      if (picked == null || !mounted) return;
      await showDialog<void>(context: context, builder: (context) => Dialog.fullscreen(child: Scaffold(
        appBar: AppBar(title: const Text('GALLERY PREVIEW'), actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        body: Center(child: InteractiveViewer(child: ColorFiltered(colorFilter: ColorFilter.matrix(_gradeMatrix), child: Image.file(File(picked.path), fit: BoxFit.contain)))),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Previewing with $_activePreset grade. The original photo stays unchanged.', textAlign: TextAlign.center),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save graded copy'),
                    onPressed: () async {
                      final outputPath = '${picked.path}.openlens-graded.jpg';
                      try {
                        await _applyGradeToFile(picked.path, outputPath);
                        await Gal.putImage(outputPath, album: 'OpenLens Pro Edited');
                        if (context.mounted) Navigator.of(context).pop();
                        _showMessage('Edited copy saved to the OpenLens Pro Edited album.');
                      } catch (_) {
                        _showMessage('Could not save the edited copy. Try another photo.');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      )));
    } catch (_) { _showMessage('Could not open the gallery. Check photo access and try again.'); }
  }

  List<double> get _gradeMatrix {
    final sat = _gradeSaturation, c = _gradeContrast;
    final offset = _gradeBrightness * 255 + (1 - c) * 128;
    const lr = 0.213, lg = 0.715, lb = 0.072;
    final a = (1 - sat) * lr, d = (1 - sat) * lg, e = (1 - sat) * lb;
    final warm = _gradeWarmth * 35, tint = _gradeTint * 22;
    return [(a+sat)*c,d*c,e*c,0,offset+warm, a*c,(d+sat)*c,e*c,0,offset+tint, a*c,d*c,(e+sat)*c,0,offset-warm-tint*0.35, 0,0,0,1,0];
  }

  Future<void> _applyGradeToFile(String sourcePath, String outputPath) async {
    final decoded = img.decodeImage(await File(sourcePath).readAsBytes());
    if (decoded == null) throw const FormatException('Image could not be decoded');
    for (final px in decoded) {
      final r = px.r.toDouble(), g = px.g.toDouble(), b = px.b.toDouble();
      final luma = 0.213*r + 0.715*g + 0.072*b;
      final rr = luma + (r-luma)*_gradeSaturation, gg = luma + (g-luma)*_gradeSaturation, bb = luma + (b-luma)*_gradeSaturation;
      px.r = ((rr-128)*_gradeContrast+128+_gradeBrightness*255+_gradeWarmth*35).clamp(0,255).round();
      px.g = ((gg-128)*_gradeContrast+128+_gradeBrightness*255+_gradeTint*22).clamp(0,255).round();
      px.b = ((bb-128)*_gradeContrast+128+_gradeBrightness*255-_gradeWarmth*35-_gradeTint*8).clamp(0,255).round();
    }
    await File(outputPath).writeAsBytes(img.encodeJpg(decoded, quality: 94), flush: true);
  }

  Future<void> _takePhoto() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    setState(() {
      _busy = true;
      _countdownRemaining = null;
    });
    try {
      if (_selfTimerSeconds > 0) {
        for (var remaining = _selfTimerSeconds; remaining > 0; remaining--) {
          if (!mounted) return;
          setState(() => _countdownRemaining = remaining);
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (mounted) setState(() => _countdownRemaining = null);
      }
      final shotCount = _burstMode ? 3 : 1;
      for (var shot = 0; shot < shotCount; shot++) {
        final photo = await camera.takePicture();
        var savedPath = photo.path;
        if (_activePreset != 'Auto' || _gradeBrightness != 0 || _gradeContrast != 1 || _gradeSaturation != 1 || _gradeWarmth != 0 || _gradeTint != 0) {
          savedPath = '${photo.path}.graded.jpg';
          await _applyGradeToFile(photo.path, savedPath);
        }
        await Gal.putImage(savedPath, album: 'OpenLens Pro');
        if (shot + 1 < shotCount) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      if (!mounted) return;
      setState(() {
        _status = shotCount == 1
            ? 'Photo saved to gallery'
            : 'Burst complete · $shotCount photos saved';
      });
      _showMessage(shotCount == 1
          ? 'Photo saved to your gallery.'
          : '$shotCount burst photos saved to your gallery.');
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Capture failed: $e');
        _showMessage('Capture failed. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _countdownRemaining = null;
        });
      }
    }
  }

  Future<void> _toggleVideoRecording() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    if (_recording) {
      setState(() => _busy = true);
      try {
        final video = await camera.stopVideoRecording();
        var savedVideoPath = video.path;
        final hasGrade = _activePreset != 'Auto' || _gradeBrightness != 0 || _gradeContrast != 1 || _gradeSaturation != 1 || _gradeWarmth != 0 || _gradeTint != 0;
        if (hasGrade) {
          final gradedPath = '${video.path}.openlens-graded.mp4';
          final input = _ffmpegQuote(video.path);
          final output = _ffmpegQuote(gradedPath);
          final brightness = (_gradeBrightness + _gradeWarmth * 0.025).clamp(-0.5, 0.5).toStringAsFixed(3);
          final contrast = _gradeContrast.clamp(0.5, 2.0).toStringAsFixed(3);
          final saturation = _gradeSaturation.clamp(0.0, 2.0).toStringAsFixed(3);
          final red = (_gradeWarmth * 0.12 + _gradeTint * 0.025).clamp(-0.2, 0.2).toStringAsFixed(3);
          final blue = (-_gradeWarmth * 0.12 + _gradeTint * 0.025).clamp(-0.2, 0.2).toStringAsFixed(3);
          final green = (-_gradeTint * 0.05).clamp(-0.1, 0.1).toStringAsFixed(3);
          final filter = 'eq=brightness=$brightness:contrast=$contrast:saturation=$saturation,colorbalance=rs=$red:gs=$green:bs=$blue';
          try {
            final session = await FFmpegKit.execute('-y -i $input -vf "$filter" -c:v mpeg4 -q:v 3 -c:a copy -movflags +faststart $output');
            final code = await session.getReturnCode();
            if (ReturnCode.isSuccess(code) && await File(gradedPath).exists() && await File(gradedPath).length() > 0) {
              savedVideoPath = gradedPath;
            } else {
              _showMessage('Could not export the video grade; saving the original recording instead.');
            }
          } catch (_) {
            _showMessage('Video grading failed; saving the original recording instead.');
          }
        }
        await Gal.putVideo(savedVideoPath, album: 'OpenLens Pro');
        if (!mounted) return;
        setState(() {
          _recording = false;
          _status = hasGrade && savedVideoPath != video.path ? 'Graded video saved to gallery' : 'Video saved to gallery · ${video.name}';
        });
        _showMessage(hasGrade && savedVideoPath != video.path ? 'Filtered video saved to your gallery.' : 'Video saved to your gallery.');
      } catch (e) {
        if (mounted) {
          setState(() => _status = 'Could not save video: $e');
          _showMessage('Video could not be saved. Please try again.');
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    try {
      final microphone = await Permission.microphone.request();
      if (!microphone.isGranted) {
        _showMessage('Microphone permission is needed to record video with audio.');
        return;
      }
      await camera.startVideoRecording();
      if (mounted) {
        setState(() {
          _recording = true;
          _status = 'Recording video…';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Could not start recording: $e');
        _showMessage('Video recording could not start on this camera.');
      }
    }
  }

  String _ffmpegQuote(String path) => "'${path.replaceAll("'", "'\\\\''")}'";

  Future<void> _captureAction() async {
    if (_mode == 'VIDEO') {
      await _toggleVideoRecording();
    } else {
      await _takePhoto();
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _controller;
    if (camera == null) return;
    final modes = <FlashMode>[FlashMode.off, FlashMode.auto, FlashMode.always, FlashMode.torch];
    final next = modes[(modes.indexOf(_flash) + 1) % modes.length];
    try {
      await camera.setFlashMode(next);
      if (mounted) setState(() => _flash = next);
    } catch (_) {
      _showMessage('Flash mode is not supported by this camera.');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _busy) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(_cameraIndex);
  }

  Future<void> _setZoom(double value) async {
    final camera = _controller;
    if (camera == null) return;
    final safeValue = value.clamp(_minZoom, _maxZoom).toDouble();
    try {
      await camera.setZoomLevel(safeValue);
      if (mounted) setState(() => _zoom = safeValue);
    } catch (_) {
      _showMessage('Zoom adjustment is unavailable.');
    }
  }

  Future<void> _applyPreset(_SignaturePreset preset) async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized) {
      _showMessage('Start the camera before applying a preset.');
      return;
    }
    if (_recording) {
      _showMessage('Stop recording before changing presets.');
      return;
    }
    final targetExposure = preset.exposure.clamp(_minExposure, _maxExposure).toDouble();
    final targetZoom = (_minZoom * preset.zoomFactor).clamp(_minZoom, _maxZoom).toDouble();
    try {
      await camera.setExposureOffset(targetExposure);
      await camera.setZoomLevel(targetZoom);
      try {
        await camera.setFlashMode(preset.flash);
        _flash = preset.flash;
      } catch (_) {
        // Flash is optional; keep the rest of the preset when unavailable.
      }
      if (!mounted) return;
      setState(() {
        _activePreset = preset.name;
        _exposure = targetExposure;
        _zoom = targetZoom;
        _gradeBrightness = preset.brightness;
        _gradeContrast = preset.contrast;
        _gradeSaturation = preset.saturation;
        _gradeWarmth = preset.warmth;
        _gradeTint = preset.tint;
        _showSettings = false;
      });
      _showMessage('${preset.name} preset applied.');
    } catch (_) {
      _showMessage('This preset could not be fully applied on this camera.');
    }
  }

  Future<void> _setExposure(double value) async {
    final camera = _controller;
    if (camera == null) return;
    final safeValue = value.clamp(_minExposure, _maxExposure).toDouble();
    try {
      await camera.setExposureOffset(safeValue);
      if (mounted) setState(() => _exposure = safeValue);
    } catch (_) {
      _showMessage('Exposure adjustment is unavailable.');
    }
  }

  Future<void> _toggleHistogram() async {
    final enable = !_showHistogram;
    setState(() => _showHistogram = enable);
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized) {
      if (enable) _showMessage('Start the camera before enabling the histogram.');
      return;
    }
    if (enable) {
      await _startHistogramStream(camera);
    } else {
      await _stopHistogramStream(camera);
    }
  }

  Future<void> _startHistogramStream(CameraController camera) async {
    if (_histogramStreamRunning || camera.value.isStreamingImages) return;
    try {
      await camera.startImageStream(_onCameraImage);
      _histogramStreamRunning = true;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _showHistogram = false;
          _histogramStreamRunning = false;
        });
        _showMessage('Live histogram is not supported while this camera mode is active.');
      }
    }
  }

  Future<void> _stopHistogramStream(CameraController camera) async {
    if (!_histogramStreamRunning && !camera.value.isStreamingImages) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {
      // The camera may already have stopped its image stream during a mode change.
    } finally {
      _histogramStreamRunning = false;
    }
  }

  void _onCameraImage(CameraImage image) {
    if (!_showHistogram || image.planes.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastHistogramUpdate).inMilliseconds < 180) return;
    _lastHistogramUpdate = now;
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 1;
    final bins = List<int>.filled(32, 0);
    var samples = 0;
    var highlights = 0;
    for (var y = 0; y < image.height; y += 8) {
      final row = y * rowStride;
      for (var x = 0; x < image.width; x += 8) {
        final index = row + x * pixelStride;
        if (index < 0 || index >= bytes.length) continue;
        final luminance = bytes[index];
        bins[luminance ~/ 8]++;
        samples++;
        if (luminance >= 235) highlights++;
      }
    }
    if (samples == 0 || !mounted) return;
    final peak = bins.reduce((a, b) => a > b ? a : b);
    final normalized = bins.map((value) => peak == 0 ? 0.0 : value / peak).toList();
    setState(() {
      _histogram = normalized;
      _highlightPercent = highlights * 100 / samples;
    });
  }

  Future<void> _toggleFocusLock() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized) return;
    final next = !_focusLocked;
    try {
      await camera.setFocusMode(next ? FocusMode.locked : FocusMode.auto);
      if (mounted) setState(() => _focusLocked = next);
      _showMessage(next ? 'Focus locked. Tap PRO to unlock and refocus.' : 'Autofocus restored.');
    } catch (_) {
      _showMessage('Focus lock is not supported by this camera.');
    }
  }

  Future<void> _toggleExposureLock() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized) return;
    final next = !_exposureLocked;
    try {
      await camera.setExposureMode(next ? ExposureMode.locked : ExposureMode.auto);
      if (mounted) setState(() => _exposureLocked = next);
      _showMessage(next ? 'Auto exposure locked.' : 'Auto exposure restored.');
    } catch (_) {
      _showMessage('Exposure lock is not supported by this camera.');
    }
  }

  Future<void> _resetExposure() async {
    final camera = _controller;
    if (camera == null) return;
    try {
      if (_exposureLocked) {
        await camera.setExposureMode(ExposureMode.auto);
        _exposureLocked = false;
      }
      final zero = 0.0.clamp(_minExposure, _maxExposure).toDouble();
      await camera.setExposureOffset(zero);
      if (mounted) setState(() => _exposure = zero);
    } catch (_) {
      _showMessage('Could not reset exposure on this camera.');
    }
  }

  Future<void> _tapToFocus(TapDownDetails details, BuildContext context) async {
    final camera = _controller;
    if (camera == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final point = Offset(
      (local.dx / box.size.width).clamp(0.0, 1.0).toDouble(),
      (local.dy / box.size.height).clamp(0.0, 1.0).toDouble(),
    );
    try {
      await camera.setFocusPoint(point);
      await camera.setExposurePoint(point);
      if (mounted) _showMessage('Focus and exposure point updated.');
    } catch (_) {
      _showMessage('Tap-to-focus is not supported on this camera.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    final camera = _controller;
    if (camera != null && camera.value.isStreamingImages) {
      camera.stopImageStream().catchError((_) {});
    }
    camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _controller;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Material(
                color: const Color(0xFF171D19),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _PresetLibraryPage(
                      presets: [..._presets, ..._libraryPresets, ..._customPresets],
                      activePreset: _activePreset,
                      onApply: (preset) { Navigator.of(context).pop(); _applyPreset(preset); },
                    ),
                  )),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF35432C)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFB8F36B), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.palette_rounded, color: Colors.black, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        const Text('CURRENT LOOK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white60, letterSpacing: 1.1)),
                        const SizedBox(height: 2),
                        Text(_activePreset, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('Tap to browse and apply a look', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .68))),
                      ])),
                      const SizedBox(width: 8),
                      const Icon(Icons.tune_rounded, color: Color(0xFFB8F36B), size: 22),
                    ]),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (camera != null && camera.value.isInitialized)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _tapToFocus(details, context),
                      child: ColorFiltered(colorFilter: ColorFilter.matrix(_gradeMatrix), child: CameraPreview(camera)),
                    )
                  else
                    _cameraPlaceholder(),
                  if (_grid) IgnorePointer(child: _CompositionGrid(mode: _compositionGuide)),
                  if (_countdownRemaining != null)
                    Center(
                      child: Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .68),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFB8F36B), width: 3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$_countdownRemaining',
                          style: const TextStyle(fontSize: 64, height: 1, fontWeight: FontWeight.w900, color: Color(0xFFB8F36B)),
                        ),
                      ),
                    ),
                  if (_showHistogram)
                    Positioned(
                      top: 58,
                      right: 12,
                      child: _LiveHistogram(values: _histogram, highlightPercent: _highlightPercent),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 14,
                    child: Row(
                      children: [
                        _pill('LIVE', const Color(0xFFB8F36B), Colors.black),
                        const Spacer(),
                        _pill(_mode, Colors.black.withValues(alpha: .62), Colors.white),
                      ],
                    ),
                  ),
                  if (!_showSettings)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: _presetTray(),
                    ),
                  if (_showSettings)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _settingsPanel(),
                    ),
                ],
              ),
            ),
            _bottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFB8F36B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.black),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OPENLENS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('PRO CAMERA', style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 2)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Toggle composition guide',
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(_grid ? Icons.grid_on_rounded : Icons.grid_off_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'Choose composition guide',
              initialValue: _compositionGuide,
              onSelected: (value) => setState(() { _compositionGuide = value; _grid = true; }),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'Thirds', child: Text('Rule of thirds')),
                PopupMenuItem(value: 'Center', child: Text('Center crosshair')),
                PopupMenuItem(value: 'Portrait', child: Text('Portrait frame')),
                PopupMenuItem(value: 'Golden', child: Text('Golden ratio')),
              ],
              icon: const Icon(Icons.crop_free_rounded),
            ),
            IconButton(
              tooltip: 'Camera settings',
              onPressed: () => setState(() => _showSettings = !_showSettings),
              icon: Icon(_showSettings ? Icons.tune_rounded : Icons.settings_rounded),
            ),
          ],
        ),
      );

  Widget _cameraPlaceholder() => Container(
        color: const Color(0xFF15191C),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_outdoor_rounded, size: 52, color: Color(0xFFB8F36B)),
            const SizedBox(height: 12),
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _initializeCamera, child: const Text('Retry camera')),
          ],
        ),
      );

  Widget _bottomControls() => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1012),
          border: Border(top: BorderSide(color: Color(0xFF24282B))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _smallControl(Icons.flash_on_rounded, _flash.name.toUpperCase(), _toggleFlash)),
                Expanded(
                  child: Column(
                    children: [
                      Text('${_zoom.toStringAsFixed(1)}×', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Text('ZOOM', style: TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: 1.5)),
                    ],
                  ),
                ),
                Expanded(child: _smallControl(Icons.cameraswitch_rounded, 'FLIP', _switchCamera)),
              ],
            ),
            if (_maxZoom > _minZoom)
              Slider(
                value: _zoom.clamp(_minZoom, _maxZoom).toDouble(),
                min: _minZoom,
                max: _maxZoom,
                onChanged: _setZoom,
                activeColor: const Color(0xFFB8F36B),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: IconButton(tooltip: 'Preview a photo from gallery', onPressed: _openGalleryPreview, icon: const Icon(Icons.photo_library_outlined, color: Color(0xFFB8F36B), size: 28))),
                GestureDetector(
                  onTap: _busy ? null : _captureAction,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _busy ? Colors.white38 : const Color(0xFFB8F36B),
                          shape: BoxShape.circle,
                        ),
                        child: _busy
                            ? const Padding(
                                padding: EdgeInsets.all(17),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Icon(_recording ? Icons.stop_rounded : (_mode == 'VIDEO' ? Icons.videocam_rounded : Icons.camera_alt_rounded), color: Colors.black, size: 28),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: IconButton(
                    tooltip: 'Exposure settings',
                    onPressed: () => setState(() => _showSettings = !_showSettings),
                    icon: const Icon(Icons.exposure_rounded, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modeButton('PHOTO'),
                const SizedBox(width: 20),
                _modeButton('PRO'),
                const SizedBox(width: 20),
                _modeButton('VIDEO'),
              ],
            ),
            const SizedBox(height: 8),
            Text(_status, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
      );

  Widget _presetTray() => Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xE6101315),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x55465056)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFFB8F36B)),
                const SizedBox(width: 6),
                const Text('QUICK LOOKS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _PresetLibraryPage(
                      presets: [..._presets, ..._libraryPresets, ..._customPresets],
                      activePreset: _activePreset,
                      onApply: (preset) { Navigator.of(context).pop(); _applyPreset(preset); },
                    ),
                  )),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                  child: const Text('All looks  ›', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _allPresets.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  if (index == _allPresets.length) return InkWell(borderRadius: BorderRadius.circular(13), onTap: _importCustomPreset, child: Container(width: 82, decoration: BoxDecoration(color: const Color(0xFF1A2023), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFB8F36B))), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, color: Color(0xFFB8F36B), size: 19), SizedBox(height: 3), Text('IMPORT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800))])));
                  final preset = _allPresets[index];
                  final selected = preset.name == _activePreset;
                  return InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => _applyPreset(preset),
                    child: Container(
                      width: 91,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFB8F36B) : const Color(0xFF1A2023),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: selected ? const Color(0xFFB8F36B) : const Color(0xFF343B3F)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(preset.icon, size: 17, color: selected ? Colors.black : const Color(0xFFB8F36B)),
                          const SizedBox(height: 3),
                          Text(preset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                  color: selected ? Colors.black : Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _settingsPanel() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xF20D1012),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF353B3F)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('QUICK MANUAL CONTROLS',
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _showSettings = false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Row(
              children: [
                const Text('SELF TIMER', style: TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: .6)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selfTimerSeconds,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Off')),
                      DropdownMenuItem(value: 3, child: Text('3 seconds')),
                      DropdownMenuItem(value: 5, child: Text('5 seconds')),
                      DropdownMenuItem(value: 10, child: Text('10 seconds')),
                    ],
                    onChanged: _busy ? null : (value) {
                      if (value != null) setState(() => _selfTimerSeconds = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Burst ×3', style: TextStyle(fontSize: 11)),
                Switch.adaptive(
                  value: _burstMode,
                  activeThumbColor: const Color(0xFFB8F36B),
                  onChanged: _busy ? null : (value) => setState(() => _burstMode = value),
                ),
              ],
            ),
            const Text('EXPOSURE COMPENSATION', style: TextStyle(fontSize: 10, color: Colors.white60)),
            Row(
              children: [
                Text(_minExposure.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
                Expanded(
                  child: Slider(
                    value: _exposure.clamp(_minExposure, _maxExposure).toDouble(),
                    min: _minExposure,
                    max: _maxExposure > _minExposure ? _maxExposure : _minExposure + 0.01,
                    onChanged: _setExposure,
                    activeColor: const Color(0xFFB8F36B),
                  ),
                ),
                Text(_exposure.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
              ],
            ),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _toggleHistogram,
                icon: Icon(_showHistogram ? Icons.show_chart_rounded : Icons.monitor_heart_outlined, size: 16),
                label: Text(_showHistogram ? 'Hide histogram' : 'Live histogram'),
                style: OutlinedButton.styleFrom(foregroundColor: _showHistogram ? const Color(0xFFB8F36B) : Colors.white),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: _toggleFocusLock,
                icon: Icon(_focusLocked ? Icons.lock_rounded : Icons.center_focus_strong_rounded, size: 16),
                label: Text(_focusLocked ? 'Focus locked' : 'Lock focus'),
                style: OutlinedButton.styleFrom(foregroundColor: _focusLocked ? const Color(0xFFB8F36B) : Colors.white),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: _toggleExposureLock,
                icon: Icon(_exposureLocked ? Icons.lock_rounded : Icons.exposure_rounded, size: 16),
                label: Text(_exposureLocked ? 'Exposure locked' : 'Lock exposure'),
                style: OutlinedButton.styleFrom(foregroundColor: _exposureLocked ? const Color(0xFFB8F36B) : Colors.white),
              )),
            ]),
            _gradeSlider('Zoom', _zoom, _minZoom, _maxZoom > _minZoom ? _maxZoom : _minZoom + 0.01, _setZoom),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: _resetExposure,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset exposure'),
            )),
            Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _importCustomPreset, icon: const Icon(Icons.file_open_rounded, size: 16), label: const Text('Import preset JSON'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: _exportPresetFormat, icon: const Icon(Icons.content_copy_rounded, size: 16), label: const Text('Export JSON')))]),
            _gradeSlider('Brightness', _gradeBrightness, -0.35, 0.35, (v) => setState(() { _gradeBrightness = v; _activePreset = 'Custom'; })),
            _gradeSlider('Contrast', _gradeContrast, 0.5, 1.8, (v) => setState(() { _gradeContrast = v; _activePreset = 'Custom'; })),
            _gradeSlider('Saturation', _gradeSaturation, 0, 2, (v) => setState(() { _gradeSaturation = v; _activePreset = 'Custom'; })),
            _gradeSlider('Warmth', _gradeWarmth, -1, 1, (v) => setState(() { _gradeWarmth = v; _activePreset = 'Custom'; })),
            _gradeSlider('Tint', _gradeTint, -1, 1, (v) => setState(() { _gradeTint = v; _activePreset = 'Custom'; })),
            const Text('Tap any point in the preview to set focus/exposure when supported.',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
            const SizedBox(height: 4),
            const Text('Device limitation: true manual ISO, shutter speed, Kelvin white balance, RAW/DNG and frame-rate controls need a native Camera2 capture layer. These controls are not simulated here.',
                style: TextStyle(fontSize: 10, color: Colors.orangeAccent)),
          ],
        ),
      );

  Widget _gradeSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70))), Expanded(child: Slider(value: value.clamp(min,max).toDouble(), min: min, max: max, onChanged: onChanged, activeColor: const Color(0xFFB8F36B))), SizedBox(width: 38, child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end, style: const TextStyle(fontSize: 10)))]));

  Widget _smallControl(IconData icon, String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Column(
          children: [
            Icon(icon, size: 21),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 1)),
          ],
        ),
      );

  Widget _modeButton(String mode) => InkWell(
        onTap: () {
          if (_recording && mode != 'VIDEO') {
            _showMessage('Stop recording before changing modes.');
            return;
          }
          setState(() => _mode = mode);
          if (mode == 'VIDEO') _showMessage('Video mode ready. Tap the record control to start or stop.');
          if (mode == 'PRO') setState(() => _showSettings = true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _mode == mode ? const Color(0xFFB8F36B) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            mode,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: _mode == mode ? Colors.black : Colors.white54,
            ),
          ),
        ),
      );

  Widget _pill(String text, Color background, Color foreground) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      );
}

class _LiveHistogram extends StatelessWidget {
  const _LiveHistogram({required this.values, required this.highlightPercent});
  final List<double> values;
  final double highlightPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xD9080A0C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x667E8A90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LIVE LUMA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 3),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: CustomPaint(painter: _HistogramPainter(values)),
          ),
          Row(children: [
            const Expanded(child: Text('HIGHLIGHTS', style: TextStyle(fontSize: 8, color: Colors.white60))),
            Text('${highlightPercent.toStringAsFixed(1)}%', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: highlightPercent >= 5 ? Colors.orangeAccent : const Color(0xFFB8F36B),
            )),
          ]),
        ],
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  const _HistogramPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), grid);
    if (values.isEmpty) return;
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - values[i].clamp(0.0, 1.0));
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    final fill = Paint()
      ..color = const Color(0xFFB8F36B).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
    final stroke = Paint()
      ..color = const Color(0xFFB8F36B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(size.width * i / (values.length - 1), size.height * (1 - values[i].clamp(0.0, 1.0)));
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(line, stroke);
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) => oldDelegate.values != values;
}

class _CompositionGrid extends StatelessWidget {
  const _CompositionGrid({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter(mode));
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.mode);
  final String mode;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.42)..strokeWidth = 0.8;
    if (mode == 'Thirds' || mode == 'Golden') {
      final ratio = mode == 'Golden' ? 0.382 : 1 / 3;
      for (final fraction in [ratio, 1 - ratio]) {
        canvas.drawLine(Offset(size.width * fraction, 0), Offset(size.width * fraction, size.height), paint);
        canvas.drawLine(Offset(0, size.height * fraction), Offset(size.width, size.height * fraction), paint);
      }
    } else if (mode == 'Center') {
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
      final centerPaint = Paint()..color = const Color(0xFFB8F36B)..style = PaintingStyle.stroke..strokeWidth = 1.5;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 20, centerPaint);
    } else {
      final frame = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * 0.68, height: size.height * 0.62);
      final framePaint = Paint()..color = const Color(0xFFB8F36B)..style = PaintingStyle.stroke..strokeWidth = 1.6;
      canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(70)), framePaint);
      canvas.drawLine(Offset(size.width / 2, frame.top), Offset(size.width / 2, frame.bottom), paint..color = Colors.white.withValues(alpha: 0.20));
    }
    final cornerPaint = Paint()..color = const Color(0xFFB8F36B)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    const length = 22.0, inset = 16.0;
    for (final x in [inset, size.width - inset]) {
      for (final y in [inset, size.height - inset]) {
        final dx = x == inset ? 1.0 : -1.0, dy = y == inset ? 1.0 : -1.0;
        canvas.drawLine(Offset(x, y), Offset(x + dx * length, y), cornerPaint);
        canvas.drawLine(Offset(x, y), Offset(x, y + dy * length), cornerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.mode != mode;
}


class _SignaturePreset {
  final String name;
  final String hint;
  final IconData icon;
  final String category;
  final double exposure;
  final double zoomFactor;
  final FlashMode flash;
  final double brightness, contrast, saturation, warmth, tint;
  const _SignaturePreset(this.name, this.hint, this.icon, this.exposure, this.zoomFactor, this.flash,
    {this.category = 'Signature', this.brightness = 0, this.contrast = 1, this.saturation = 1, this.warmth = 0, this.tint = 0});

  Map<String, dynamic> toJson() => {'name':name,'hint':hint,'category':category,'brightness':brightness,'contrast':contrast,'saturation':saturation,'warmth':warmth,'tint':tint,'exposure':exposure,'zoomFactor':zoomFactor,'flash':flash.name};

  factory _SignaturePreset.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ?? '';
    if (name.isEmpty || name.length > 32) throw const FormatException('Invalid preset name');
    double number(String key, double fallback, double min, double max) {
      final value = (json[key] as num?)?.toDouble() ?? fallback;
      if (!value.isFinite || value < min || value > max) throw FormatException('Invalid $key');
      return value;
    }
    final flashName = json['flash'] as String? ?? 'off';
    final flash = FlashMode.values.firstWhere((v) => v.name == flashName, orElse: () => FlashMode.off);
    return _SignaturePreset(name, (json['hint'] as String?) ?? 'Imported grade', Icons.palette_outlined,
      number('exposure',0,-4,4), number('zoomFactor',1,1,4), flash,
      category: (json['category'] as String?) ?? 'Imported', brightness:number('brightness',0,-0.35,0.35), contrast:number('contrast',1,0.5,1.8),
      saturation:number('saturation',1,0,2), warmth:number('warmth',0,-1,1), tint:number('tint',0,-1,1));
  }
}


class _PresetLibraryPage extends StatefulWidget {
  const _PresetLibraryPage({required this.presets, required this.activePreset, required this.onApply});
  final List<_SignaturePreset> presets;
  final String activePreset;
  final ValueChanged<_SignaturePreset> onApply;

  @override
  State<_PresetLibraryPage> createState() => _PresetLibraryPageState();
}

class _PresetLibraryPageState extends State<_PresetLibraryPage> {
  static const String _favoritesKey = 'openlens_favorite_presets_v1';
  static const String _recentKey = 'openlens_recent_presets_v1';
  String _category = 'All';
  String _query = '';
  String _view = 'All';
  Set<String> _favorites = {};
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadPersonalLists();
  }

  Future<void> _loadPersonalLists() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favorites = (prefs.getStringList(_favoritesKey) ?? []).toSet();
      _recent = prefs.getStringList(_recentKey) ?? [];
    });
  }

  Future<void> _toggleFavorite(String name) async {
    final next = Set<String>.from(_favorites);
    if (!next.add(name)) next.remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, next.toList()..sort());
    if (mounted) setState(() => _favorites = next);
  }

  Future<void> _recordRecent(String name) async {
    final next = <String>[name, ..._recent.where((item) => item != name)];
    if (next.length > 8) next.removeRange(8, next.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, next);
    if (mounted) setState(() => _recent = next);
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = widget.presets
        .map((p) => p.category)
        .where((c) => c != 'Signature')
        .toSet()
        .toList()
      ..sort();
    final categories = <String>['All', ...categoryNames];
    final query = _query.trim().toLowerCase();
    final filtered = widget.presets.where((p) =>
      (_category == 'All' || p.category == _category) &&
      (_view != 'Favorites' || _favorites.contains(p.name)) &&
      (_view != 'Recent' || _recent.contains(p.name)) &&
      ('${p.name} ${p.hint} ${p.category}'.toLowerCase().contains(query))).toList()
      ..sort((a, b) {
        if (_view == 'Recent') return _recent.indexOf(a.name).compareTo(_recent.indexOf(b.name));
        return 0;
      });
    final activePresets = widget.presets.where((p) => p.name == widget.activePreset).toList();
    final _SignaturePreset? active = activePresets.isEmpty ? null : activePresets.first;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find your look', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
            Text('Search, preview and apply in one tap', style: TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
        backgroundColor: const Color(0xFF080A0C),
      ),
      body: Column(
        children: [
          if (active != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2417),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF455735)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFFB8F36B), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('APPLIED NOW', style: TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(active.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ])),
                TextButton(
                  onPressed: () => widget.onApply(widget.presets.firstWhere((p) => p.name == 'Auto', orElse: () => widget.presets.first)),
                  child: const Text('Reset'),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by look or mood…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty ? null : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () => setState(() => _query = ''),
                  icon: const Icon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: const Color(0xFF171C1F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2B3338))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB8F36B), width: 1.4)),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              const Icon(Icons.filter_list_rounded, color: Color(0xFFB8F36B), size: 20),
              const SizedBox(width: 8),
              const Text('Category', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171C1F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30383D)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF171C1F),
                      borderRadius: BorderRadius.circular(12),
                      items: categories.map((category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category == 'All' ? 'All looks' : category, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (value) { if (value != null) setState(() => _category = value); },
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              children: ['All', 'Favorites', 'Recent'].map((view) => ChoiceChip(
                label: Text(view),
                selected: _view == view,
                onSelected: (_) => setState(() => _view = view),
                selectedColor: const Color(0xFFB8F36B),
                labelStyle: TextStyle(
                  color: _view == view ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(color: _view == view ? const Color(0xFFB8F36B) : const Color(0xFF30383D)),
              )).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
            child: Row(children: [
              Text('${filtered.length} looks', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              const Text('Tap a look to apply it', style: TextStyle(fontSize: 11, color: Colors.white54)),
            ]),
          ),
          Expanded(
            child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.search_off_rounded, size: 42, color: Colors.white38),
                      const SizedBox(height: 10),
                      const Text('No matching looks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      const Text('Try another name or choose a different category.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: () => setState(() { _query = ''; _category = 'All'; }), child: const Text('Clear filters')),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final preset = filtered[index];
                    final selected = preset.name == widget.activePreset;
                    return Material(
                      color: selected ? const Color(0xFF202B19) : const Color(0xFF14191C),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await _recordRecent(preset.name);
                          if (context.mounted) widget.onApply(preset);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? const Color(0xFFB8F36B) : const Color(0xFF2B3338)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFB8F36B) : const Color(0xFF252D31),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(preset.icon, color: selected ? Colors.black : const Color(0xFFB8F36B), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 3),
                              Text(preset.category == 'Signature' ? preset.hint : preset.category,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white60)),
                            ])),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: _favorites.contains(preset.name) ? 'Remove favorite' : 'Add favorite',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _toggleFavorite(preset.name),
                              icon: Icon(
                                _favorites.contains(preset.name) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _favorites.contains(preset.name) ? const Color(0xFFFF7B8B) : Colors.white54,
                                size: 20,
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFFB8F36B), size: 22)
                            else
                              const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 24),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
