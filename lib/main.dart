// Keep the legacy Explore implementation available while the Video tab replaces it.
// ignore_for_file: unused_element

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
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF202124),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8F6),
        useMaterial3: true,
      ),
      home: const OpenLensShell(),
    );
  }
}

class _CameraScreen extends StatefulWidget {
  const _CameraScreen({super.key, this.initialPreset, this.startInVideo = false});
  final _SignaturePreset? initialPreset;
  final bool startInVideo;

  @override
  State<_CameraScreen> createState() => __CameraScreenState();
}

class __CameraScreenState extends State<_CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _busy = false;
  bool _recording = false;
  bool _grid = true;
  bool _hdrEnabled = false;
  bool _levelerEnabled = true;
  String? _lastPhotoPath;
  bool _wideAspect = false;
  bool _showRetroTuning = false;
  bool _timestampOverlay = false;
  double _grainIntensity = 0.22;
  double _colorBleed = 0.18;
  double _trackingDistortion = 0.12;
  final String _compositionGuide = 'Thirds';
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
  List<String> _quickLookNames = ['Auto', 'Monsoon Chrome', 'Neon Bazaar', 'Moonmilk'];
  static const String _quickLooksKey = 'openlens_quick_looks_v1';
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
  _SignaturePreset('VHS', 'Muted tape colors and warm shadows', Icons.videocam_rounded, 0.04, 1, FlashMode.off, category: 'Retro Video', brightness: -0.035, contrast: 0.82, saturation: 0.66, warmth: 0.38, tint: 0.12),
  _SignaturePreset('8mm', 'Golden vintage film with punchy contrast', Icons.movie_filter_rounded, 0.08, 1, FlashMode.off, category: 'Retro Video', brightness: 0.07, contrast: 1.24, saturation: 0.82, warmth: 0.60, tint: -0.08),
  _SignaturePreset('Camcorder', 'Cool blue early-digital video', Icons.video_camera_back_rounded, 0, 1, FlashMode.off, category: 'Retro Video', brightness: 0.01, contrast: 1.17, saturation: 1.32, warmth: -0.52, tint: -0.10),
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
    _SignaturePreset('Monsoon Chrome', 'Bright skies', Icons.water_drop_rounded, 0.3, 1.0, FlashMode.off, category: 'Signature', brightness: 0.04, contrast: 1.18, saturation: 1.24, warmth: -0.12, tint: -0.02),
    _SignaturePreset('Neon Bazaar', 'Night lights', Icons.bolt_rounded, -0.3, 1.0, FlashMode.off, category: 'Signature', brightness: -0.04, contrast: 1.32, saturation: 1.38, warmth: -0.08, tint: -0.10),
    _SignaturePreset('Moonmilk', 'Soft low light', Icons.nightlight_round, 0.7, 1.0, FlashMode.off, category: 'Signature', brightness: 0.10, contrast: 0.82, saturation: 0.82, warmth: 0.16, tint: 0.05),
    _SignaturePreset('Dust & Gold', 'Warm daylight', Icons.wb_sunny_rounded, 0.3, 1.0, FlashMode.off, category: 'Signature', brightness: 0.04, contrast: 1.08, saturation: 0.92, warmth: 0.42, tint: 0.04),
    _SignaturePreset('Quiet Detail', 'Closer framing', Icons.center_focus_strong_rounded, 0.0, 1.4, FlashMode.off, category: 'Signature', brightness: 0.01, contrast: 1.24, saturation: 0.96, warmth: 0.02, tint: 0.00),
    _SignaturePreset('Shadow Atlas', 'Deep contrast', Icons.landscape_rounded, -0.7, 1.0, FlashMode.off, category: 'Signature', brightness: -0.06, contrast: 1.42, saturation: 0.76, warmth: -0.08, tint: -0.02),
    _SignaturePreset('Candle Keeper', 'Extra light', Icons.flare_rounded, 0.3, 1.0, FlashMode.auto, category: 'Signature', brightness: 0.12, contrast: 0.94, saturation: 0.88, warmth: 0.34, tint: 0.04),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.startInVideo) _mode = 'VIDEO';
    if (widget.initialPreset != null) {
      final p = widget.initialPreset!;
      _activePreset = p.name;
      _gradeBrightness = p.brightness;
      _gradeContrast = p.contrast;
      _gradeSaturation = p.saturation;
      _gradeWarmth = p.warmth;
      _gradeTint = p.tint;
    }
    _loadCustomPresets();
    _loadQuickLooks();
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
      if (widget.initialPreset != null && mounted) {
        await _applyPreset(widget.initialPreset!);
        if (mounted) setState(() => _mode = widget.startInVideo ? 'VIDEO' : _mode);
      }
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


  List<_SignaturePreset> get _allPresets => [..._presets, ..._libraryPresets, ..._customPresets];

  Future<void> _loadQuickLooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_quickLooksKey);
      if (!mounted || saved == null || saved.isEmpty) return;
      final validNames = _allPresets.map((p) => p.name).toSet();
      setState(() => _quickLookNames = saved.where(validNames.contains).take(6).toList());
    } catch (_) {
      // Quick looks are a convenience; never block camera startup.
    }
  }

  Future<void> _rememberQuickLook(_SignaturePreset preset) async {
    final next = <String>[preset.name, ..._quickLookNames.where((name) => name != preset.name)];
    if (next.length > 6) next.removeRange(6, next.length);
    if (mounted) setState(() => _quickLookNames = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_quickLooksKey, next);
    } catch (_) {
      // Keep the in-memory quick look even if persistence is unavailable.
    }
  }



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
        if (mounted && shot == 0) setState(() => _lastPhotoPath = savedPath);
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
          final brightness = (_gradeBrightness + _gradeWarmth * 0.025).clamp(-0.5, 0.5).toStringAsFixed(3);
          final contrast = _gradeContrast.clamp(0.5, 2.0).toStringAsFixed(3);
          final saturation = _gradeSaturation.clamp(0.0, 2.0).toStringAsFixed(3);
          final red = (_gradeWarmth * 0.12 + _gradeTint * 0.025).clamp(-0.2, 0.2).toStringAsFixed(3);
          final blue = (-_gradeWarmth * 0.12 + _gradeTint * 0.025).clamp(-0.2, 0.2).toStringAsFixed(3);
          final green = (-_gradeTint * 0.05).clamp(-0.1, 0.1).toStringAsFixed(3);
          var filter = 'eq=brightness=$brightness:contrast=$contrast:saturation=$saturation,colorbalance=rs=$red:gs=$green:bs=$blue';
          // Distinct analog-video processing is baked into the exported recording,
          // not just painted over the live preview.
          switch (_activePreset.toLowerCase()) {
            case 'vhs':
              filter += ',noise=alls=18:allf=t+u,eq=saturation=0.78:contrast=1.18,vignette=PI/5';
              break;
            case '8mm':
              filter += ',noise=alls=28:allf=t+u,eq=saturation=0.72:contrast=1.22:brightness=0.025,vignette=PI/4';
              break;
            case 'camcorder':
              filter += ',noise=alls=10:allf=t+u,eq=saturation=1.12:contrast=1.08,drawgrid=w=iw:h=4:t=1:c=black@0.10';
              break;
            case 'faded film':
              filter += ',noise=alls=8:allf=t+u,eq=contrast=0.88:saturation=0.72:brightness=0.04';
              break;
          }
          try {
            final session = await FFmpegKit.executeWithArguments([
              '-y', '-i', video.path, '-vf', filter, '-c:v', 'mpeg4',
              '-q:v', '3', '-c:a', 'copy', '-movflags', '+faststart', gradedPath,
            ]);
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

    // Apply the software grade first. Hardware exposure, zoom and flash controls
    // are optional: a device-specific camera-control error must never cancel the
    // actual color filter or leave the selected preset looking inactive.
    if (mounted) {
      setState(() {
        _activePreset = preset.name;
        _gradeBrightness = preset.brightness;
        _gradeContrast = preset.contrast;
        _gradeSaturation = preset.saturation;
        _gradeWarmth = preset.warmth;
        _gradeTint = preset.tint;
        _showSettings = false;
      });
    }

    await _rememberQuickLook(preset);

    final targetExposure = preset.exposure.clamp(_minExposure, _maxExposure).toDouble();
    final targetZoom = (_minZoom * preset.zoomFactor).clamp(_minZoom, _maxZoom).toDouble();
    var hardwareWarning = false;

    try {
      await camera.setExposureOffset(targetExposure);
      if (mounted) setState(() => _exposure = targetExposure);
    } catch (_) {
      hardwareWarning = true;
    }
    try {
      await camera.setZoomLevel(targetZoom);
      if (mounted) setState(() => _zoom = targetZoom);
    } catch (_) {
      hardwareWarning = true;
    }
    try {
      await camera.setFlashMode(preset.flash);
      if (mounted) setState(() => _flash = preset.flash);
    } catch (_) {
      // Flash is optional; preserve the software filter if unavailable.
      hardwareWarning = true;
    }

    _showMessage(hardwareWarning
        ? '${preset.name} filter applied. Some camera controls are unsupported.'
        : '${preset.name} filter applied.');
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

  Future<void> _openLooks() async {
    final preset = await Navigator.of(context).push<_SignaturePreset>(
      MaterialPageRoute<_SignaturePreset>(
        builder: (_) => _PresetLibraryPage(
          presets: [..._presets, ..._libraryPresets, ..._customPresets],
          activePreset: _activePreset,
          onApply: (preset) => Navigator.of(context).pop(preset),
        ),
      ),
    );
    if (preset != null && mounted) await _applyPreset(preset);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _controller;
    final previewSize = camera?.value.previewSize;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Color(0xFF08090D),
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF08090D),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Keep the sensor preview at its natural aspect ratio. Clip only
                // the excess edges instead of stretching the image to the screen.
                if (camera != null && camera.value.isInitialized)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _tapToFocus(details, context),
                      onHorizontalDragEnd: (details) {
                        if (_recording || (details.primaryVelocity ?? 0).abs() < 180) return;
                        const modes = ['PHOTO', 'VIDEO', 'PORTRAIT', 'PRO'];
                        final current = modes.indexOf(_mode);
                        final direction = (details.primaryVelocity ?? 0) < 0 ? 1 : -1;
                        setState(() => _mode = modes[(current + direction + modes.length) % modes.length]);
                      },
                      child: ClipRect(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(_gradeMatrix),
                          child: previewSize == null
                              ? CameraPreview(camera)
                              : Center(
                                  child: AspectRatio(
                                    aspectRatio: _wideAspect ? 16 / 9 : 4 / 3,
                                    child: CameraPreview(camera),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned.fill(child: _cameraPlaceholder()),
                if (_mode == 'VIDEO') ...[
                  Positioned.fill(child: IgnorePointer(child: CustomPaint(
                    painter: _RetroTexturePainter(grain: _grainIntensity, bleed: _colorBleed, tracking: _trackingDistortion, preset: _activePreset),
                  ))),
                  if (_timestampOverlay)
                    Positioned(left: 20, bottom: 270, child: IgnorePointer(child: Text(
                      'OCT 23 1998',
                      style: TextStyle(color: const Color(0xFFFF9B45), fontFamily: 'monospace',
                        fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: const Color(0xFFFF6B1A).withValues(alpha: .85), blurRadius: 12)],
                      ),
                    ))),
                  Positioned(top: 48, left: 16, right: 16, child: SafeArea(bottom: false, child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _retroTopButton(_flash == FlashMode.off ? Icons.flash_off_rounded : Icons.flash_on_rounded, _toggleFlash),
                      _retroTopButton(_wideAspect ? Icons.crop_16_9_rounded : Icons.crop_3_2_rounded, () => setState(() => _wideAspect = !_wideAspect)),
                      _retroTopButton(Icons.cameraswitch_rounded, _switchCamera),
                    ],
                  ))),
                  if (_showRetroTuning)
                    Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false, child: _retroTuningSheet())),
                ],
                // Overlays are deliberately light and never consume preview space.
                if (_grid && _mode != 'VIDEO') Positioned.fill(child: IgnorePointer(child: _CompositionGrid(mode: _compositionGuide))),
                if (_levelerEnabled && _mode != 'VIDEO') Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _LevelerPainter()))),
                if (_countdownRemaining != null)
                  Center(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: const Color(0xE6101116),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFC5FF72), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text('$_countdownRemaining',
                        style: const TextStyle(fontSize: 58, height: 1, fontWeight: FontWeight.w800, color: Color(0xFFC5FF72))),
                    ),
                  ),
                if (_showHistogram)
                  Positioned(top: 88, right: 12,
                    child: SafeArea(child: _LiveHistogram(values: _histogram, highlightPercent: _highlightPercent))),
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: _topBar(),
                    ),
                  ),
                ),
                if (_showSettings)
                  Positioned(
                    left: 12, right: 12,
                    bottom: compact ? 210 : 232,
                    child: SafeArea(top: false, child: _settingsPanel()),
                  ),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 8),
                    child: _bottomControls(compact: compact),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _minimalTopAction(tooltip: 'Flash: ${_flash.name}', icon: _flash == FlashMode.off ? Icons.flash_off_rounded : Icons.flash_on_rounded, onPressed: _toggleFlash),
      _minimalTopAction(tooltip: 'Timer: ${_selfTimerSeconds}s', icon: Icons.timer_outlined, onPressed: () => setState(() => _selfTimerSeconds = _selfTimerSeconds == 0 ? 3 : _selfTimerSeconds == 3 ? 10 : 0), active: _selfTimerSeconds > 0),
      _minimalTopAction(tooltip: _hdrEnabled ? 'HDR on' : 'HDR off', icon: Icons.hdr_on_rounded, onPressed: () => setState(() => _hdrEnabled = !_hdrEnabled), active: _hdrEnabled),
      _minimalTopAction(tooltip: _wideAspect ? 'Aspect ratio 16:9' : 'Aspect ratio 4:3', icon: _wideAspect ? Icons.crop_16_9_rounded : Icons.crop_3_2_rounded, onPressed: () => setState(() => _wideAspect = !_wideAspect), active: _wideAspect),
      _minimalTopAction(tooltip: 'Leveler and grid', icon: _levelerEnabled ? Icons.straighten_rounded : Icons.grid_off_rounded, onPressed: () => setState(() { _levelerEnabled = !_levelerEnabled; _grid = _levelerEnabled; }), active: _levelerEnabled),
    ],
  );

  Widget _minimalTopAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool active = false,
  }) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 42, height: 42),
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: .10),
      foregroundColor: active ? const Color(0xFFC5FF72) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: .10)),
      ),
    ),
    icon: Icon(icon, size: 21),
  );

  Widget _cameraPlaceholder() => Container(
    color: const Color(0xFF0D1016),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFC5FF72).withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.camera_alt_outlined, size: 32, color: Color(0xFFC5FF72)),
        ),
        const SizedBox(height: 18),
        Text(_status, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _initializeCamera,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry camera'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC5FF72),
            foregroundColor: const Color(0xFF10130B),
          ),
        ),
      ],
    ),
  );

  bool get _isVideoMode => _mode == 'VIDEO';

  Widget _modeChoice(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFC5FF72) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? const Color(0xFF15180F) : Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800,
            color: active ? const Color(0xFF15180F) : Colors.white70)),
        ]),
      ),
    );
  }

  Widget _bottomControls({required bool compact}) {
    if (_mode == 'VIDEO') {
      return Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, compact ? 6 : 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 66, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xB8121216), borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: .14))),
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final name in ['Standard', 'VHS', '8mm', 'Camcorder', ..._quickLookNames])
                Builder(builder: (context) {
                  final candidates = _allPresets.where((p) => p.name == name);
                  // Dedicated recipes: never silently map distinct video looks to Auto.
                  final preset = candidates.isNotEmpty ? candidates.first : switch (name) {
                    'VHS' => const _SignaturePreset('VHS', 'Analog tape', Icons.videocam_rounded, -.04, 1, FlashMode.off, category: 'Video', brightness: -.02, contrast: 1.28, saturation: .78, warmth: -.12, tint: -.04),
                    '8mm' => const _SignaturePreset('8mm', 'Warm grainy film', Icons.movie_filter_rounded, .02, 1, FlashMode.off, category: 'Video', brightness: .04, contrast: 1.18, saturation: .72, warmth: .32, tint: .06),
                    'Camcorder' => const _SignaturePreset('Camcorder', 'Home video', Icons.video_camera_back_rounded, .01, 1, FlashMode.off, category: 'Video', brightness: .02, contrast: 1.12, saturation: 1.12, warmth: -.08, tint: -.02),
                    _ => _allPresets.firstWhere((p) => p.name == 'Auto', orElse: () => _allPresets.first),
                  };
                  final selected = name == 'Standard' ? _activePreset == 'Auto' : _activePreset == preset.name || _activePreset == name;
                  return GestureDetector(
                    onTap: () => name == 'Standard' ? _applyPreset(_allPresets.firstWhere((p) => p.name == 'Auto', orElse: () => _allPresets.first)) : _applyPreset(preset),
                    onDoubleTap: () => setState(() => _showRetroTuning = true),
                    child: Container(width: 64, margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: .14) : Colors.transparent,
                        borderRadius: BorderRadius.circular(17), border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2 : 1)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            Color.lerp(const Color(0xFF8099B8), const Color(0xFFFFB45A), ((preset.warmth + 1) / 2).clamp(0.0, 1.0))!,
                            Color.lerp(const Color(0xFF555B70), const Color(0xFFDD7196), ((preset.saturation - 0.5) / 1.5).clamp(0.0, 1.0))!,
                          ])), child: Icon(name == 'VHS' ? Icons.videocam_rounded : name == '8mm' ? Icons.movie_filter_rounded : name == 'Camcorder' ? Icons.video_camera_back_rounded : Icons.circle_outlined, color: Colors.white, size: 15)),
                        const SizedBox(height: 3),
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  );
                }),
              IconButton(onPressed: _openLooks, icon: const Icon(Icons.tune_rounded, color: Colors.white), tooltip: 'All filters'),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _modeChoice('PHOTO', Icons.photo_camera_outlined, !_isVideoMode, () { if (!_recording) setState(() => _mode = 'PHOTO'); }),
              const SizedBox(width: 4),
              _modeChoice('VIDEO', Icons.videocam_rounded, _isVideoMode, () { if (!_recording) setState(() => _mode = 'VIDEO'); }),
            ]),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _roundAction(tooltip: 'Open gallery', icon: Icons.photo_outlined, onTap: _openGalleryPreview),
            GestureDetector(onTap: _busy ? null : _captureAction, child: Container(
              width: 74, height: 74, padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? const Color(0xFFE53935) : const Color(0xFFFF3030)),
                child: Center(child: Icon(_recording ? Icons.stop_rounded : Icons.circle, color: Colors.white, size: _recording ? 28 : 40))),
            )),
            _roundAction(tooltip: 'Retro effect tuning', icon: Icons.settings_outlined, onTap: () => setState(() => _showRetroTuning = true)),
          ]),
          const SizedBox(height: 12),
          Text(_recording ? '● RECORDING' : 'VIDEO  ·  ${_activePreset == 'Auto' ? 'Standard' : _activePreset}',
            style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: _recording ? const Color(0xFFFF4B4B) : Colors.white70)),
        ]),
      );
    }
    return Padding(
    padding: EdgeInsets.fromLTRB(18, 0, 18, compact ? 6 : 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small, readable controls float over the image rather than a large panel.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _floatingControl(
              icon: _flash == FlashMode.off ? Icons.flash_off_rounded : Icons.flash_on_rounded,
              label: _flash.name.toUpperCase(),
              onTap: _toggleFlash,
            ),
            if (_maxZoom > _minZoom)
              GestureDetector(
                onTap: () => _setZoom((_zoom + 1).clamp(_minZoom, _maxZoom).toDouble()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .38),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: .16)),
                  ),
                  child: Text('${_zoom.toStringAsFixed(1)}×',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              )
            else
              Text('${_zoom.toStringAsFixed(1)}×',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            _floatingControl(
              icon: Icons.cameraswitch_rounded,
              label: 'FLIP',
              onTap: _switchCamera,
            ),
          ],
        ),
        if (_maxZoom > _minZoom)
          SizedBox(
            height: compact ? 24 : 30,
            child: Slider(
              value: _zoom.clamp(_minZoom, _maxZoom).toDouble(),
              min: _minZoom,
              max: _maxZoom,
              onChanged: _setZoom,
              activeColor: const Color(0xFFC5FF72),
              inactiveColor: Colors.white24,
            ),
          )
        else
          SizedBox(height: compact ? 12 : 18),
        // Quick looks are visible directly in the camera for easy comparison.
        SizedBox(
          height: 66,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final lookName in _quickLookNames)
                Builder(builder: (context) {
                  final matches = _allPresets.where((p) => p.name == lookName);
                  if (matches.isEmpty) return const SizedBox.shrink();
                  final look = matches.first;
                  final selected = _activePreset == look.name;
                  return GestureDetector(
                    onTap: () => _applyPreset(look),
                    onDoubleTap: () {
                      if (_mode == 'VIDEO') setState(() => _showRetroTuning = true);
                    },
                    child: Container(
                      width: 76,
                      margin: const EdgeInsets.only(right: 9, bottom: 3),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .42),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? const Color(0xFFC5FF72) : Colors.white24, width: selected ? 2 : 1),
                      ),
                      child: Column(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: CustomPaint(painter: _LookSamplePainter(_previewColors(look)), child: const SizedBox.expand()),
                        )),
                        const SizedBox(height: 4),
                        Text(look.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                            color: selected ? const Color(0xFFC5FF72) : Colors.white)),
                      ]),
                    ),
                  );
                }),
              GestureDetector(
                onTap: _openLooks,
                child: Container(
                  width: 66,
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.tune_rounded, size: 19, color: Color(0xFFC5FF72)),
                    SizedBox(height: 3),
                    Text('All looks', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: _roundAction(
                  tooltip: 'Switch front / back camera',
                  icon: Icons.cameraswitch_rounded,
                  onTap: _switchCamera,
                ),
              ),
            ),
            GestureDetector(
              onTap: _busy ? null : _captureAction,
              child: Container(
                width: compact ? 72 : 78,
                height: compact ? 72 : 78,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 18)],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _busy ? Colors.white38 : const Color(0xFFC5FF72),
                  ),
                  child: Center(
                    child: _busy
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Icon(
                          _recording ? Icons.stop_rounded : (_mode == 'VIDEO' ? Icons.videocam_rounded : Icons.camera_alt_rounded),
                          color: const Color(0xFF10130B), size: 29),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _openGalleryPreview,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .85), width: 2), color: Colors.black.withValues(alpha: .28)),
                    clipBehavior: Clip.antiAlias,
                    child: _lastPhotoPath != null && File(_lastPhotoPath!).existsSync()
                      ? Image.file(File(_lastPhotoPath!), fit: BoxFit.cover)
                      : const Icon(Icons.photo_library_outlined, size: 21, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 14),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .20), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: .18))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _modeButton('PHOTO'),
            _modeButton('VIDEO'),
            _modeButton('PORTRAIT'),
            _modeButton('PRO'),
          ]),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 6, color: _controller?.value.isInitialized == true
                ? const Color(0xFFC5FF72) : Colors.orangeAccent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(_activePreset == 'Auto' ? _status : _activePreset,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: .2)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _openLooks,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC5FF72),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, size: 14),
                SizedBox(width: 5),
                Text('LOOKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ]),
            ),
          ],
        ),
      ],
    ),
  );
  }

  Widget _retroTopButton(IconData icon, VoidCallback onTap) => IconButton(
    onPressed: onTap, icon: Icon(icon, color: Colors.white, size: 23),
    style: IconButton.styleFrom(backgroundColor: const Color(0x66000000), shape: const CircleBorder(),
      side: BorderSide(color: Colors.white.withValues(alpha: .16))),
  );

  Widget _retroTuningSheet() => Container(
    padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
    decoration: const BoxDecoration(color: Color(0xFF121212),
      borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: GestureDetector(onVerticalDragEnd: (_) => setState(() => _showRetroTuning = false),
        child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(8)))),
      ),
      Row(children: [
        const Expanded(child: Text('Retro effect tuning', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        IconButton(onPressed: () => setState(() => _showRetroTuning = false), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
      ]),
      _retroSlider('Grain intensity', _grainIntensity, (v) => setState(() => _grainIntensity = v)),
      _retroSlider('Color bleed · RGB shift', _colorBleed, (v) => setState(() => _colorBleed = v)),
      _retroSlider('Tracking distortion', _trackingDistortion, (v) => setState(() => _trackingDistortion = v)),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero, value: _timestampOverlay,
        onChanged: (v) => setState(() => _timestampOverlay = v),
        activeThumbColor: const Color(0xFFFF9B45),
        title: const Text('Timestamp overlay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: const Text('Retro orange date stamp', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ),
    ]),
  );

  Widget _retroSlider(String label, double value, ValueChanged<double> onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))), Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.white54, fontSize: 11))]),
      Slider(value: value, min: 0, max: 1, onChanged: onChanged,
        activeColor: Colors.white, inactiveColor: Colors.white24, thumbColor: Colors.white),
    ],
  );

  Widget _floatingControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC5FF72)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70, letterSpacing: .7)),
        ],
      ),
    ),
  );

  Widget _roundAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 25, color: Colors.white),
    style: IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: .30),
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      side: BorderSide(color: Colors.white.withValues(alpha: .12)),
      fixedSize: const Size(48, 48),
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
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2118),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF455735)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded, size: 17, color: Color(0xFFB8F36B)),
                    const SizedBox(width: 7),
                    const Text('ACTIVE LOOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const Spacer(),
                    Text(_activePreset, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB8F36B))),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _gradeValueChip('Brightness', _gradeBrightness.toStringAsFixed(2)),
                      _gradeValueChip('Contrast', _gradeContrast.toStringAsFixed(2)),
                      _gradeValueChip('Saturation', _gradeSaturation.toStringAsFixed(2)),
                      _gradeValueChip('Warmth', _gradeWarmth.toStringAsFixed(2)),
                      _gradeValueChip('Tint', _gradeTint.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('These values update when you select a look. Adjust the sliders below to customize it.',
                    style: TextStyle(fontSize: 10, color: Colors.white60)),
                ],
              ),
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

  Widget _gradeValueChip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF293226),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label $value', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      );

  Widget _gradeSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70))), Expanded(child: Slider(value: value.clamp(min,max).toDouble(), min: min, max: max, onChanged: onChanged, activeColor: const Color(0xFFB8F36B))), SizedBox(width: 38, child: Text(value.toStringAsFixed(2), textAlign: TextAlign.end, style: const TextStyle(fontSize: 10)))]));

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

class _LevelerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .46);
    final paint = Paint()..color = const Color(0xFFC5FF72).withValues(alpha: .72)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(center.dx - 32, center.dy), Offset(center.dx - 9, center.dy), paint);
    canvas.drawLine(Offset(center.dx + 9, center.dy), Offset(center.dx + 32, center.dy), paint);
    canvas.drawCircle(center, 8, paint);
    canvas.drawLine(Offset(center.dx, center.dy - 15), Offset(center.dx, center.dy - 8), paint);
    canvas.drawLine(Offset(center.dx, center.dy + 8), Offset(center.dx, center.dy + 15), paint);
  }
  @override
  bool shouldRepaint(covariant _LevelerPainter oldDelegate) => false;
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


List<Color> _previewColors(_SignaturePreset preset) {
  final warmth = preset.warmth;
  if (preset.saturation < .7) return const [Color(0xFFB7B7B7), Color(0xFF626A72), Color(0xFF24272C)];
  if (warmth > .2) return const [Color(0xFFFFC078), Color(0xFFCA7A45), Color(0xFF475B50)];
  if (warmth < -.15) return const [Color(0xFFB9E5F7), Color(0xFF548DAA), Color(0xFF303B6D)];
  return const [Color(0xFFFFB16B), Color(0xFF4FAF87), Color(0xFF477FE5)];
}

class _RetroTexturePainter extends CustomPainter {
  _RetroTexturePainter({required this.grain, required this.bleed, required this.tracking, required this.preset});
  final double grain;
  final double bleed;
  final double tracking;
  final String preset;
  @override
  void paint(Canvas canvas, Size size) {
    final look = preset.toLowerCase();
    final isVhs = look == 'vhs';
    final is8mm = look == '8mm';
    final isCamcorder = look == 'camcorder';
    final scan = Paint()..color = Colors.black.withValues(alpha: isVhs ? .20 : isCamcorder ? .14 : is8mm ? .07 : .035 + tracking * .06);
    final step = isVhs ? 3.0 : isCamcorder ? 4.0 : is8mm ? 6.0 : 5.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, isVhs ? 1.4 : 1), scan);
    }
    if (isVhs || isCamcorder) {
      final offset = size.height * (isVhs ? .64 : .82);
      canvas.drawRect(Rect.fromLTWH(0, offset, size.width, isVhs ? 5 : 2), Paint()..color = Colors.white.withValues(alpha: isVhs ? .22 : .12));
      if (isVhs) {
        canvas.drawRect(Rect.fromLTWH(0, offset + 8, size.width * .42, 3), Paint()..color = const Color(0xFF00E5FF).withValues(alpha: .24));
        canvas.drawRect(Rect.fromLTWH(size.width * .57, offset + 8, size.width * .43, 3), Paint()..color = const Color(0xFFFF3040).withValues(alpha: .22));
      }
    }
    if (is8mm) {
      final edge = Paint()..color = const Color(0xFFFFC078).withValues(alpha: .09);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), edge);
      for (double y = 10; y < size.height; y += 73) {
        canvas.drawCircle(Offset(size.width * .93, y), 1.4, Paint()..color = Colors.white.withValues(alpha: .65));
      }
    }
    if (bleed > .01) {
      final tint = Paint()..color = const Color(0xFFFF3030).withValues(alpha: bleed * .10);
      canvas.drawRect(Rect.fromLTWH(size.width * .02, size.height * .42, size.width * .96, size.height * .018), tint);
      final cyan = Paint()..color = const Color(0xFF00E5FF).withValues(alpha: bleed * .08);
      canvas.drawRect(Rect.fromLTWH(0, size.height * .72, size.width, size.height * .012), cyan);
    }
    if (tracking > .02) {
      final line = Paint()..color = Colors.white.withValues(alpha: tracking * .13);
      canvas.drawRect(Rect.fromLTWH(0, size.height * (.28 + tracking * .2), size.width, 1.5 + tracking * 2), line);
    }
    if (grain > .01) {
      final dot = Paint()..color = Colors.white.withValues(alpha: grain * .11);
      // Deterministic fine grain texture; intentionally subtle over the live preview.
      for (int i = 0; i < 360; i++) {
        final x = (i * 73.17) % size.width;
        final y = (i * 139.73) % size.height;
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), dot);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _RetroTexturePainter old) => old.grain != grain || old.bleed != bleed || old.tracking != tracking;
}

class _LookSamplePainter extends CustomPainter {
  _LookSamplePainter(this.colors);
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [colors[0], colors[1], colors[2]],
      stops: const [0, .58, 1],
    ).createShader(rect));
    final sunPaint = Paint()..color = const Color(0xFFFFE5A3).withValues(alpha: .88);
    canvas.drawCircle(Offset(size.width * .72, size.height * .27), size.shortestSide * .12, sunPaint);
    final hillPaint = Paint()..color = colors[2].withValues(alpha: .88);
    final hill = Path()
      ..moveTo(0, size.height * .78)
      ..quadraticBezierTo(size.width * .25, size.height * .38, size.width * .48, size.height * .73)
      ..quadraticBezierTo(size.width * .75, size.height * .45, size.width, size.height * .68)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, hillPaint);
    final foreground = Paint()..color = const Color(0xFF17231F).withValues(alpha: .8);
    final silhouette = Path()
      ..moveTo(size.width * .18, size.height)
      ..lineTo(size.width * .30, size.height * .58)
      ..lineTo(size.width * .39, size.height * .58)
      ..lineTo(size.width * .52, size.height)
      ..close();
    canvas.drawPath(silhouette, foreground);
    canvas.drawCircle(Offset(size.width * .345, size.height * .51), size.shortestSide * .075, foreground);
  }
  @override
  bool shouldRepaint(covariant _LookSamplePainter oldDelegate) => oldDelegate.colors != colors;
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


  List<Color> _swatchColors(_SignaturePreset preset) {
    final warmth = preset.warmth * 0.22;
    final tint = preset.tint * 0.12;
    final saturation = preset.saturation.clamp(0.0, 1.6);
    final contrast = preset.contrast.clamp(0.5, 1.6);
    Color tone(double r, double g, double b) {
      final luma = 0.213 * r + 0.715 * g + 0.072 * b;
      double grade(double value, double warm, double tintShift) =>
          ((luma + (value - luma) * saturation - 0.5) * contrast + 0.5 +
           preset.brightness * 0.65 + warm * warmth + tintShift * tint).clamp(0.0, 1.0).toDouble();
      int ch(double value) => (value * 255).round().clamp(0, 255).toInt();
      return Color.fromARGB(255, ch(grade(r, 1, 0)), ch(grade(g, 0, 1)), ch(grade(b, -1, -0.35)));
    }
    return [tone(0.96, 0.56, 0.35), tone(0.27, 0.60, 0.42), tone(0.33, 0.48, 0.82)];
  }

  Widget _lookCard(_SignaturePreset preset) {
    final selected = preset.name == widget.activePreset;
    final favorite = _favorites.contains(preset.name);
    final colors = _swatchColors(preset);
    return Material(
      color: selected ? const Color(0xFF202B19) : const Color(0xFF14191D),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          widget.onApply(preset);
          _recordRecent(preset.name).catchError((_) {});
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? const Color(0xFFC5FF72) : const Color(0xFF30383D), width: selected ? 1.7 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: SizedBox(height: 94, child: Stack(fit: StackFit.expand, children: [
                CustomPaint(painter: _LookSamplePainter(colors), child: const SizedBox.expand()),
                Positioned(left: 10, right: 10, bottom: 10, child: Container(
                  height: 29,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white.withValues(alpha: .15))),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Icon(preset.icon, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(child: Text(preset.category.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8, letterSpacing: .8, fontWeight: FontWeight.w900, color: Colors.white))),
                  ]),
                )),
                if (selected) const Positioned(top: 8, left: 8, child: Icon(Icons.check_circle_rounded, color: Color(0xFFC5FF72), size: 23)),
                Positioned(top: 1, right: 1, child: IconButton(
                  tooltip: favorite ? 'Remove favourite' : 'Add favourite',
                  onPressed: () => _toggleFavorite(preset.name),
                  icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: favorite ? const Color(0xFFFF8795) : Colors.white, size: 19),
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: .27), minimumSize: const Size(34, 34), padding: EdgeInsets.zero),
                )),
              ])),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(11, 10, 11, 10), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(preset.hint, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white60)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(selected ? 'APPLIED' : 'TAP TO APPLY',
                    style: TextStyle(fontSize: 9, letterSpacing: .8, fontWeight: FontWeight.w900,
                      color: selected ? const Color(0xFFC5FF72) : Colors.white54))),
                  Icon(selected ? Icons.check_rounded : Icons.arrow_outward_rounded, size: 15,
                    color: selected ? const Color(0xFFC5FF72) : Colors.white54),
                ]),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = widget.presets.map((p) => p.category).where((c) => c != 'Signature').toSet().toList()..sort();
    final categories = <String>['All', ...categoryNames];
    final query = _query.trim().toLowerCase();
    final filtered = widget.presets.where((p) =>
      (_category == 'All' || p.category == _category) &&
      (_view != 'Favorites' || _favorites.contains(p.name)) &&
      (_view != 'Recent' || _recent.contains(p.name)) &&
      ('${p.name} ${p.hint} ${p.category}'.toLowerCase().contains(query))).toList()
      ..sort((a, b) => _view == 'Recent' ? _recent.indexOf(a.name).compareTo(_recent.indexOf(b.name)) : 0);
    final activePresets = widget.presets.where((p) => p.name == widget.activePreset).toList();
    final _SignaturePreset? active = activePresets.isEmpty ? null : activePresets.first;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080A0C), surfaceTintColor: Colors.transparent, titleSpacing: 18,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Looks', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -.4)),
          Text('Find a mood. Apply it instantly.', style: TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
        actions: [IconButton(tooltip: 'Reset to Auto', onPressed: () {
          final auto = widget.presets.where((p) => p.name == 'Auto');
          if (auto.isNotEmpty) widget.onApply(auto.first);
        }, icon: const Icon(Icons.restart_alt_rounded)), const SizedBox(width: 6)],
      ),
      body: Column(children: [
        if (active != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12), padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF202B19), Color(0xFF151C17)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFF50683A))),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFC5FF72).withValues(alpha: .13), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFC5FF72))),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CURRENT LOOK', style: TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Text(active.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              ])),
              const Icon(Icons.check_circle_rounded, color: Color(0xFFC5FF72), size: 22),
            ]),
          ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: TextField(
          onChanged: (value) => setState(() => _query = value), textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search looks, film, mood…', prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty ? null : IconButton(tooltip: 'Clear search', onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.close_rounded)),
            filled: true, fillColor: const Color(0xFF151A1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF30383D))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFC5FF72), width: 1.4)),
            isDense: true,
          ),
        )),
        SizedBox(height: 42, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final category = categories[index]; final selected = _category == category;
            return ChoiceChip(
              label: Text(category == 'All' ? 'All looks' : category), selected: selected,
              onSelected: (_) => setState(() => _category = category), selectedColor: const Color(0xFFC5FF72),
              labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
              side: BorderSide(color: selected ? const Color(0xFFC5FF72) : const Color(0xFF30383D)),
              visualDensity: VisualDensity.compact,
            );
          },
        )),
        Padding(padding: const EdgeInsets.fromLTRB(16, 5, 16, 5), child: Row(children: [
          Expanded(child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'All', label: Text('Explore'), icon: Icon(Icons.grid_view_rounded, size: 16)),
              ButtonSegment(value: 'Favorites', label: Text('Saved'), icon: Icon(Icons.favorite_border_rounded, size: 16)),
              ButtonSegment(value: 'Recent', label: Text('Recent'), icon: Icon(Icons.history_rounded, size: 16)),
            ],
            selected: {_view}, onSelectionChanged: (value) => setState(() => _view = value.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(selectedBackgroundColor: const Color(0xFFC5FF72),
              selectedForegroundColor: const Color(0xFF10130B), foregroundColor: Colors.white70,
              side: const BorderSide(color: Color(0xFF30383D)),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          )),
          const SizedBox(width: 10),
          Text('${filtered.length}', style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w800)),
        ])),
        Expanded(child: filtered.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.filter_alt_off_rounded, size: 42, color: Colors.white38),
              const SizedBox(height: 10),
              const Text('No looks found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Try another search or clear the active filters.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => setState(() { _query = ''; _category = 'All'; _view = 'All'; }), child: const Text('Show all looks')),
            ])))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 230, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 205),
              itemCount: filtered.length, itemBuilder: (context, index) => _lookCard(filtered[index]),
            )),
      ]),
    );
  }
}


// -----------------------------------------------------------------------------
// Light-theme photo workspace. The original live camera and Looks library remain
// available as dedicated destinations rather than being replaced by mock screens.
// -----------------------------------------------------------------------------
const Color _workspaceInk = Color(0xFF202124);
const Color _workspaceMuted = Color(0xFF858585);
const Color _workspacePaper = Color(0xFFF8F8F6);
const Color _workspaceAccent = Color(0xFFB8F36B);

class OpenLensShell extends StatefulWidget {
  const OpenLensShell({super.key});

  @override
  State<OpenLensShell> createState() => _OpenLensShellState();
}

class _OpenLensShellState extends State<OpenLensShell> {
  int _tab = 1;
  _SignaturePreset? _videoPreset;
  final List<XFile> _recent = [];
  XFile? _editingImage;

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final picker = ImagePicker();
      final image = source == ImageSource.camera
          ? await picker.pickImage(source: ImageSource.camera)
          : await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      setState(() {
        _editingImage = image;
        _recent.removeWhere((item) => item.path == image.path);
        _recent.insert(0, image);
        _tab = 3;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that image. Check photo permissions and try again.')),
        );
      }
    }
  }

  void _openEditor(XFile image) {
    setState(() {
      _editingImage = image;
      _recent.removeWhere((item) => item.path == image.path);
      _recent.insert(0, image);
      _tab = 3;
    });
  }

  void _rememberEdited(XFile image) {
    setState(() {
      _recent.removeWhere((item) => item.path == image.path);
      _recent.insert(0, image);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeDashboard(
        recent: _recent,
        onPick: _pickImage,
        onOpen: _openEditor,
        onCamera: () => setState(() => _tab = 1),
        onBrowse: () => setState(() => _tab = 1),
      ),
      _CameraScreen(key: ValueKey(_videoPreset?.name ?? 'default-camera'), initialPreset: _videoPreset, startInVideo: _videoPreset != null),
      _PhotoEditorScreen(
        image: _editingImage,
        onPick: _pickImage,
        onSaved: _rememberEdited,
        onAssistant: (controller) => _showAssistant(controller),
      ),
      _ProfileWorkspace(onPick: _pickImage, onCamera: () => setState(() => _tab = 1)),
    ];
    return Scaffold(
      backgroundColor: _workspacePaper,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _WorkspaceNavigation(
        selected: _tab == 0 ? 0 : _tab == 2 ? 1 : _tab == 3 ? 2 : -1,
        onSelected: (index) => setState(() => _tab = index == 0 ? 0 : index == 1 ? 2 : 3),
      ),
    );
  }

  Future<void> _showAssistant(_PhotoEditorScreenState controller) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .58),
      builder: (sheetContext) => _VoiceAssistantSheet(
        onAction: (action) {
          Navigator.of(sheetContext).pop();
          controller.applyAssistantAction(action);
        },
      ),
    );
  }
}

class __CameraScreenPresets {
  static List<_SignaturePreset> get all => [
    const _SignaturePreset('Auto', 'Natural camera', Icons.auto_awesome_rounded, 0, 1, FlashMode.off, category: 'Natural'),
    const _SignaturePreset('Portra Glow', 'Warm skin, soft film', Icons.camera_roll_rounded, .06, 1, FlashMode.off, category: 'Film', brightness: .03, contrast: 1.03, saturation: .92, warmth: .22, tint: .02),
    const _SignaturePreset('Gold 200', 'Golden vintage film', Icons.camera_roll_rounded, .10, 1, FlashMode.off, category: 'Film', brightness: .05, contrast: 1.12, saturation: 1.12, warmth: .35, tint: .01),
    const _SignaturePreset('Faded Film', 'Soft, faded memories', Icons.camera_roll_rounded, .16, 1, FlashMode.off, category: 'Film', brightness: .08, contrast: .86, saturation: .78, warmth: .16, tint: .03),
    const _SignaturePreset('Classic 400', 'Classic analog tones', Icons.camera_roll_rounded, .02, 1, FlashMode.off, category: 'Film', brightness: .01, contrast: 1.14, saturation: 1.05, warmth: .12),
    const _SignaturePreset('Soft Negative', 'Matte, muted colors', Icons.camera_roll_rounded, .12, 1, FlashMode.off, category: 'Film', brightness: .06, contrast: .92, saturation: .88, warmth: .18, tint: .04),
    const _SignaturePreset('Chrome Slide', 'Rich vivid colors', Icons.camera_roll_rounded, 0, 1, FlashMode.off, category: 'Film', contrast: 1.22, saturation: 1.22, warmth: .06, tint: -.02),
    const _SignaturePreset('Teal & Amber', 'Cinematic movie tones', Icons.movie_filter_rounded, -.04, 1, FlashMode.off, category: 'Cinematic', brightness: -.02, contrast: 1.22, saturation: .94, warmth: .18, tint: -.06),
    const _SignaturePreset('Neo Noir', 'Moody dark cinema', Icons.movie_filter_rounded, -.24, 1, FlashMode.off, category: 'Cinematic', brightness: -.12, contrast: 1.38, saturation: .78, warmth: -.08, tint: .01),
    const _SignaturePreset('Bleach Bypass', 'High contrast movie look', Icons.movie_filter_rounded, -.06, 1, FlashMode.off, category: 'Cinematic', brightness: -.03, contrast: 1.42, saturation: .62, warmth: -.04),
    const _SignaturePreset('Monochrome', 'Classic black and white', Icons.filter_b_and_w_rounded, 0, 1, FlashMode.off, category: 'Black & White', contrast: 1.12, saturation: 0),
    const _SignaturePreset('Dust & Gold', 'Warm daylight', Icons.wb_sunny_rounded, .3, 1, FlashMode.off, category: 'Vintage', brightness: .04, contrast: 1.08, saturation: .92, warmth: .42, tint: .04),
    const _SignaturePreset('Moonmilk', 'Soft low-light mood', Icons.nightlight_round, 0, 1, FlashMode.off, category: 'Vintage', brightness: .04, contrast: .92, saturation: .78, warmth: -.08),
    const _SignaturePreset('Neon Bazaar', 'Vibrant night lights', Icons.bolt_rounded, 0, 1, FlashMode.off, category: 'Creative', contrast: 1.2, saturation: 1.3, warmth: -.05, tint: -.04),
    const _SignaturePreset('Monsoon Chrome', 'Bright, punchy skies', Icons.water_drop_rounded, 0, 1, FlashMode.off, category: 'Creative', contrast: 1.12, saturation: 1.18, warmth: -.04),
  ];
}

class _VideoLookPickerPage extends StatefulWidget {
  const _VideoLookPickerPage({required this.presets, required this.onSelected});
  final List<_SignaturePreset> presets;
  final ValueChanged<_SignaturePreset> onSelected;
  @override
  State<_VideoLookPickerPage> createState() => _VideoLookPickerPageState();
}

class _VideoLookPickerPageState extends State<_VideoLookPickerPage> {
  String _category = 'All';
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...widget.presets.map((p) => p.category).toSet().toList()..sort()];
    final query = _search.toLowerCase().trim();
    final looks = widget.presets.where((p) =>
      (_category == 'All' || p.category == _category) &&
      ('${p.name} ${p.hint} ${p.category}'.toLowerCase().contains(query))).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF090B0E),
      appBar: AppBar(title: const Text('Video looks', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF090B0E)),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 8), child: Text('Choose a look first. Your camera opens in video mode with that look selected.',
          style: TextStyle(color: Color(0xFF777777), fontSize: 13))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'Search retro filters', prefixIcon: const Icon(Icons.search_rounded),
            filled: true, fillColor: const Color(0xFF171B20), hintStyle: const TextStyle(color: Color(0xFF9AA1AA)), prefixIconColor: const Color(0xFFB8F36B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF343A42)))),
        )),
        const SizedBox(height: 10),
        SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [for (final c in categories) Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
            label: Text(c), selected: c == _category, onSelected: (_) => setState(() => _category = c),
            selectedColor: const Color(0xFFB8F36B), backgroundColor: const Color(0xFF171B20), side: const BorderSide(color: Color(0xFF343A42)), labelStyle: TextStyle(fontWeight: FontWeight.w800, color: c == _category ? Colors.black : Colors.white),
          ))])),
        const Padding(padding: EdgeInsets.fromLTRB(18, 10, 18, 8), child: Text('TAP A PREVIEW TO OPEN VIDEO CAMERA', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900, color: Color(0xFF777777)))),
        Expanded(child: GridView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .92),
          itemCount: looks.length, itemBuilder: (context, i) {
            final p = looks[i];
            return Material(color: const Color(0xFF171B20), borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: () => widget.onSelected(p), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Stack(fit: StackFit.expand, children: [
                  CustomPaint(painter: _LookSamplePainter(_previewColors(p)), child: const SizedBox.expand()),
                  Positioned(left: 9, top: 9, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(9)),
                    child: Text(p.category.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)))),
                  const Positioned(right: 9, bottom: 9, child: CircleAvatar(radius: 15, backgroundColor: Color(0xFFC5FF72), child: Icon(Icons.videocam_rounded, color: Colors.black, size: 17))),
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(10, 9, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(p.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFFB5BAC2))),
                ])),
              ])),
            );
          })),
      ]),
    );
  }
}

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.tune_rounded, 'Edit'),
    (Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, -4))],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 66,
        child: Row(children: List.generate(_items.length, (index) {
          final item = _items[index];
          final active = selected == index;
          return Expanded(child: InkWell(
            onTap: () => onSelected(index),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42, height: 29,
                decoration: BoxDecoration(
                  color: active ? _workspaceInk : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.$1, size: 20, color: active ? Colors.white : const Color(0xFF929292)),
              ),
              const SizedBox(height: 4),
              Text(item.$2, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? _workspaceInk : _workspaceMuted)),
            ]),
          ));
        })),
      ),
    ),
  );
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.recent, required this.onPick, required this.onOpen, required this.onCamera, required this.onBrowse});
  final List<XFile> recent;
  final Future<void> Function() onPick;
  final ValueChanged<XFile> onOpen;
  final VoidCallback onCamera;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final albums = [
      ('All photos', Icons.photo_library_outlined, const [Color(0xFFD9E4D4), Color(0xFF8CA18C)]),
      ('Portraits', Icons.face_retouching_natural_outlined, const [Color(0xFFF1D5C7), Color(0xFFC28E77)]),
      ('Travel', Icons.landscape_outlined, const [Color(0xFFD5E6EC), Color(0xFF7799A8)]),
      ('Favorites', Icons.favorite_border_rounded, const [Color(0xFFE8D8E8), Color(0xFFAD8BA9)]),
    ];
    return Scaffold(
      backgroundColor: _workspacePaper,
      body: SafeArea(child: CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 0), sliver: SliverToBoxAdapter(child: Row(children: [
          Container(width: 42, height: 42, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE7E8E2)),
            child: const Icon(Icons.person_rounded, color: _workspaceInk, size: 24)),
          const Spacer(),
          IconButton(onPressed: onPick, tooltip: 'Search photos', icon: const Icon(Icons.search_rounded, color: _workspaceInk)),
          IconButton(onPressed: onBrowse, tooltip: 'Explore albums', icon: const Icon(Icons.more_horiz_rounded, color: _workspaceInk)),
        ]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(22, 16, 22, 12), sliver: SliverToBoxAdapter(child: Row(children: [
          const Expanded(child: Text('Albums', style: TextStyle(fontSize: 28, height: 1.1, letterSpacing: -.7, color: _workspaceInk, fontWeight: FontWeight.w900))),
          TextButton(onPressed: onBrowse, child: const Text('See all', style: TextStyle(color: _workspaceInk, fontWeight: FontWeight.w700))),
        ]))),
        SliverToBoxAdapter(child: SizedBox(height: 206, child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 22), scrollDirection: Axis.horizontal,
          itemCount: albums.length, separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final album = albums[index];
            final image = recent.isNotEmpty ? recent[index % recent.length] : null;
            return GestureDetector(
              onTap: image != null ? () => onOpen(image) : onPick,
              child: Container(width: 142, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: album.$3)),
                clipBehavior: Clip.antiAlias,
                child: Stack(fit: StackFit.expand, children: [
                  if (image != null) Image.file(File(image.path), fit: BoxFit.cover)
                  else Center(child: Icon(album.$2, size: 46, color: Colors.white.withValues(alpha: .85))),
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: .62)]))),
                  Positioned(left: 13, right: 8, bottom: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(album.$1, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(image != null ? '${recent.length} recent photos' : 'Tap to add photos',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ])),
                ]),
              ),
            );
          },
        ))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(22, 27, 22, 5), sliver: SliverToBoxAdapter(child: Row(children: [
          const Expanded(child: Text('Recent Editing', style: TextStyle(fontSize: 23, letterSpacing: -.5, color: _workspaceInk, fontWeight: FontWeight.w900))),
          IconButton(onPressed: onPick, tooltip: 'Add photo', icon: const Icon(Icons.add_circle_outline_rounded, color: _workspaceInk)),
        ]))),
        const SliverPadding(padding: EdgeInsets.fromLTRB(22, 0, 22, 12), sliver: SliverToBoxAdapter(child: Text('Pick up where your creativity left off', style: TextStyle(fontSize: 12, color: _workspaceMuted)))),
        if (recent.isEmpty)
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 30), child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(24),
            child: Container(height: 185, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(24)), border: Border.fromBorderSide(BorderSide(color: Color(0xFFE4E4DF)))),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, size: 38, color: _workspaceMuted),
                SizedBox(height: 10),
                Text('Start with a photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _workspaceInk)),
                SizedBox(height: 4),
                Text('Choose an image to open the editor', style: TextStyle(fontSize: 12, color: _workspaceMuted)),
              ]),
            ),
          )))
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(22, 7, 22, 28), sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: .78),
            delegate: SliverChildBuilderDelegate((context, index) {
              final image = recent[index];
              return GestureDetector(
                onTap: () => onOpen(image),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(width: double.infinity,
                    child: Image.file(File(image.path), fit: BoxFit.cover))),
                  ),
                  const SizedBox(height: 8),
                  Text('Photo project ${index + 1}', style: const TextStyle(color: _workspaceInk, fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Tap to continue editing', style: TextStyle(color: _workspaceMuted, fontSize: 10)),
                ]),
              );
            }, childCount: recent.length),
          )),
      ])),
    );
  }
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.recent, required this.onPick, required this.onOpen});
  final List<XFile> recent;
  final Future<void> Function() onPick;
  final ValueChanged<XFile> onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _workspacePaper,
    appBar: AppBar(backgroundColor: _workspacePaper, foregroundColor: _workspaceInk, title: const Text('Explore photos', style: TextStyle(fontWeight: FontWeight.w900))),
    body: recent.isEmpty
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined, size: 44, color: _workspaceMuted),
          const SizedBox(height: 12),
          const Text('Your photo space starts here', style: TextStyle(color: _workspaceInk, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FilledButton(onPressed: onPick, child: const Text('Choose photos')),
        ]))
      : GridView.builder(
          padding: const EdgeInsets.all(18),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .8),
          itemCount: recent.length + 1,
          itemBuilder: (context, index) => index == recent.length
            ? InkWell(onTap: onPick, borderRadius: BorderRadius.circular(18), child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE1E1DC))),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, size: 32), Text('Add photo')]),
              ))
            : GestureDetector(onTap: () => onOpen(recent[index]), child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(File(recent[index].path), fit: BoxFit.cover))),
        ),
  );
}

class _CameraLanding extends StatelessWidget {
  const _CameraLanding();
  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Color(0xFF08090D), body: Center(child: CircularProgressIndicator()));
}

class _ProfileWorkspace extends StatelessWidget {
  const _ProfileWorkspace({required this.onPick, required this.onCamera});
  final Future<void> Function() onPick;
  final VoidCallback onCamera;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _workspacePaper,
    appBar: AppBar(backgroundColor: _workspacePaper, foregroundColor: _workspaceInk, title: const Text('Your workspace', style: TextStyle(fontWeight: FontWeight.w900))),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Column(children: [
          CircleAvatar(radius: 34, backgroundColor: Color(0xFFE8E9E2), child: Icon(Icons.person_rounded, size: 36, color: _workspaceInk)),
          SizedBox(height: 12), Text('OpenLens creator', style: TextStyle(color: _workspaceInk, fontWeight: FontWeight.w900, fontSize: 18)),
          SizedBox(height: 4), Text('Your photos stay on your device', style: TextStyle(color: _workspaceMuted, fontSize: 12)),
        ])),
      const SizedBox(height: 14),
      ListTile(leading: const Icon(Icons.add_photo_alternate_outlined), title: const Text('Import a photo'), trailing: const Icon(Icons.chevron_right_rounded), onTap: onPick),
      ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Open live camera'), trailing: const Icon(Icons.chevron_right_rounded), onTap: onCamera),
      const Padding(padding: EdgeInsets.all(12), child: Text('OpenLens Pro · Local photo workspace', style: TextStyle(color: _workspaceMuted, fontSize: 11))),
    ]),
  );
}

class _PhotoEditorScreen extends StatefulWidget {
  const _PhotoEditorScreen({required this.image, required this.onPick, required this.onSaved, required this.onAssistant});
  final XFile? image;
  final Future<void> Function() onPick;
  final ValueChanged<XFile> onSaved;
  final Future<void> Function(_PhotoEditorScreenState controller) onAssistant;
  @override
  State<_PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<_PhotoEditorScreen> {
  String _tool = 'Adjust';
  double _adjustment = 0;
  double _contrast = 1;
  int _rotation = 0;
  bool _frame = false;
  bool _saving = false;

  List<double> get _matrix {
    final contrast = _contrast;
    final offset = _adjustment * 255 + (1 - contrast) * 128;
    return [contrast,0,0,0,offset, 0,contrast,0,0,offset, 0,0,contrast,0,offset, 0,0,0,1,0];
  }

  void applyAssistantAction(String action) {
    setState(() {
      switch (action) {
        case 'Next Adjustment':
          _tool = 'Adjust';
          _adjustment = (_adjustment + .08).clamp(-.35, .35);
          break;
        case 'Edit Stroke Reference':
          _tool = 'Frame';
          _frame = !_frame;
          break;
        case 'Warm Film Look':
          _tool = 'Filter';
          _adjustment = .06;
          _contrast = 1.12;
          break;
        default:
          _adjustment = 0;
          _contrast = 1;
          _rotation = 0;
          _frame = false;
      }
    });
  }

  Future<void> _save() async {
    final image = widget.image;
    if (image == null || _saving) return;
    setState(() => _saving = true);
    try {
      final decoded = img.decodeImage(await File(image.path).readAsBytes());
      if (decoded == null) throw const FormatException('Image could not be decoded');
      final contrast = _contrast;
      final brightness = _adjustment * 255;
      for (final px in decoded) {
        px.r = ((px.r.toDouble() - 128) * contrast + 128 + brightness).clamp(0, 255).round();
        px.g = ((px.g.toDouble() - 128) * contrast + 128 + brightness).clamp(0, 255).round();
        px.b = ((px.b.toDouble() - 128) * contrast + 128 + brightness).clamp(0, 255).round();
      }
      var output = decoded;
      if (_rotation != 0) output = img.copyRotate(output, angle: _rotation * 90);
      final outPath = '${image.path}.openlens-edit-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(img.encodeJpg(output, quality: 94), flush: true);
      await Gal.putImage(outPath, album: 'OpenLens Pro Edited');
      final edited = XFile(outPath);
      widget.onSaved(edited);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edited copy saved to your gallery. Original kept unchanged.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this edit. Try another image.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    return Scaffold(
      backgroundColor: _workspacePaper,
      appBar: AppBar(
        backgroundColor: _workspacePaper, foregroundColor: _workspaceInk, elevation: 0,
        leadingWidth: 104,
        leading: Row(children: [
          IconButton(tooltip: 'Undo', onPressed: () => setState(() { _adjustment = 0; _contrast = 1; _rotation = 0; }), icon: const Icon(Icons.undo_rounded)),
          IconButton(tooltip: 'Redo', onPressed: () => setState(() { _adjustment = .05; _contrast = 1.05; }), icon: const Icon(Icons.redo_rounded)),
        ]),
        title: const Text('Edit photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save', style: TextStyle(color: _workspaceInk, fontWeight: FontWeight.w900))), const SizedBox(width: 8)],
      ),
      body: Column(children: [
        Expanded(flex: 6, child: Center(
          child: AspectRatio(aspectRatio: 1, child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xFFE8E8E3), borderRadius: BorderRadius.circular(_frame ? 0 : 6),
              border: _frame ? Border.all(color: _workspaceInk, width: 9) : null),
            child: image == null
              ? InkWell(onTap: widget.onPick, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 42, color: _workspaceMuted),
                  SizedBox(height: 10), Text('Choose a photo', style: TextStyle(color: _workspaceInk, fontWeight: FontWeight.w800)),
                ]))
              : Stack(fit: StackFit.expand, children: [
                  Transform.rotate(angle: _rotation * 3.141592653589793 / 2,
                    child: ColorFiltered(colorFilter: ColorFilter.matrix(_matrix), child: Image.file(File(image.path), fit: BoxFit.cover))),
                  IgnorePointer(child: CustomPaint(painter: _CropCornerPainter())),
                ]),
          )),
        )),
        const SizedBox(height: 12),
        SizedBox(height: 78, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
          _EditToolButton(label: 'Frame', icon: Icons.crop_free_rounded, active: _tool == 'Frame', onTap: () => setState(() { _tool = 'Frame'; _frame = !_frame; })),
          _EditToolButton(label: 'Rotate', icon: Icons.rotate_right_rounded, active: _tool == 'Rotate', onTap: () => setState(() { _tool = 'Rotate'; _rotation = (_rotation + 1) % 4; })),
          _EditToolButton(label: 'Adjust', icon: Icons.tune_rounded, active: _tool == 'Adjust', onTap: () => setState(() => _tool = 'Adjust')),
          _EditToolButton(label: 'Contrast', icon: Icons.contrast_rounded, active: _tool == 'Contrast', onTap: () => setState(() => _tool = 'Contrast')),
          _EditToolButton(label: 'Filter', icon: Icons.auto_awesome_rounded, active: _tool == 'Filter', onTap: () => setState(() { _tool = 'Filter'; _adjustment = .05; _contrast = 1.08; })),
          _EditToolButton(label: 'Assistant', icon: Icons.mic_none_rounded, active: false, onTap: () => widget.onAssistant(this)),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 12), child: Column(children: [
          Row(children: [
            Text(_tool == 'Contrast' ? 'Contrast' : _tool == 'Rotate' ? 'Rotation' : _tool == 'Frame' ? 'Frame' : 'Intensity',
              style: const TextStyle(color: _workspaceInk, fontWeight: FontWeight.w800, fontSize: 12)),
            const Spacer(),
            Text(_tool == 'Contrast' ? _contrast.toStringAsFixed(2) : _tool == 'Rotate' ? '${_rotation * 90}°' : _adjustment.toStringAsFixed(2),
              style: const TextStyle(color: _workspaceMuted, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          Slider(
            value: _tool == 'Contrast' ? _contrast.clamp(.5, 1.8).toDouble() : _adjustment.clamp(-.35, .35).toDouble(),
            min: _tool == 'Contrast' ? .5 : -.35,
            max: _tool == 'Contrast' ? 1.8 : .35,
            onChanged: (value) => setState(() {
              if (_tool == 'Contrast') { _contrast = value; } else { _adjustment = value; }
            }),
            activeColor: _workspaceInk, inactiveColor: const Color(0xFFD7D7D2),
          ),
          SizedBox(height: 18, child: CustomPaint(size: Size.infinite, painter: _RulerPainter())),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 12), child: Row(children: [
          _BottomEditAction(icon: Icons.crop_rounded, label: 'Crop', onTap: () => setState(() { _tool = 'Frame'; _frame = !_frame; })),
          _BottomEditAction(icon: Icons.rotate_90_degrees_ccw_rounded, label: 'Rotate', onTap: () => setState(() { _tool = 'Rotate'; _rotation = (_rotation + 1) % 4; })),
          Expanded(child: Center(child: InkWell(
            onTap: () => widget.onAssistant(this),
            borderRadius: BorderRadius.circular(40),
            child: Container(width: 58, height: 58, decoration: const BoxDecoration(color: _workspaceInk, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25)),
          ))),
          _BottomEditAction(icon: Icons.tune_rounded, label: 'Adjust', onTap: () => setState(() => _tool = 'Adjust')),
          _BottomEditAction(icon: Icons.check_circle_outline_rounded, label: 'Done', onTap: _save),
        ])),
      ]),
    );
  }
}

class _EditToolButton extends StatelessWidget {
  const _EditToolButton({required this.label, required this.icon, required this.active, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 18), child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(width: 55, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: active ? _workspaceInk : Colors.transparent, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: active ? Colors.white : _workspaceMuted)),
      const SizedBox(height: 5),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? _workspaceInk : _workspaceMuted)),
    ])),
  ));
}

class _BottomEditAction extends StatelessWidget {
  const _BottomEditAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: _workspaceInk, size: 21),
    const SizedBox(height: 5),
    Text(label, style: const TextStyle(fontSize: 9, color: _workspaceMuted, fontWeight: FontWeight.w700)),
  ])));
}

class _CropCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white..strokeWidth = 3.2..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    const len = 20.0, inset = 12.0;
    for (final x in [inset, size.width - inset]) {
      for (final y in [inset, size.height - inset]) {
        final dx = x == inset ? 1.0 : -1.0, dy = y == inset ? 1.0 : -1.0;
        canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), p);
        canvas.drawLine(Offset(x, y), Offset(x, y + dy * len), p);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = const Color(0xFFD4D4CF)..strokeWidth = 1;
    final center = size.width / 2;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), line);
    for (var i = 0; i <= 40; i++) {
      final x = size.width * i / 40;
      final major = i % 5 == 0;
      canvas.drawLine(Offset(x, size.height / 2 - (major ? 7 : 3)), Offset(x, size.height / 2 + (major ? 7 : 3)), line);
    }
    final marker = Paint()..color = _workspaceInk..strokeWidth = 2.2;
    canvas.drawLine(Offset(center, 0), Offset(center, size.height), marker);
    canvas.drawCircle(Offset(center, size.height / 2), 3.5, Paint()..color = _workspaceAccent);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VoiceAssistantSheet extends StatefulWidget {
  const _VoiceAssistantSheet({required this.onAction});
  final ValueChanged<String> onAction;
  @override
  State<_VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<_VoiceAssistantSheet> {
  bool _listening = false;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: MediaQuery.of(context).size.height * .58,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(children: [
        Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFE1E1E1), borderRadius: BorderRadius.circular(5))),
        const SizedBox(height: 22),
        InkWell(
          onTap: () => setState(() => _listening = !_listening),
          borderRadius: BorderRadius.circular(40),
          child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 68, height: 68,
            decoration: BoxDecoration(color: _workspaceInk, shape: BoxShape.circle, border: _listening ? Border.all(color: _workspaceAccent, width: 4) : null),
            child: Icon(_listening ? Icons.graphic_eq_rounded : Icons.mic_rounded, color: Colors.white, size: 29)),
        ),
        const SizedBox(height: 16),
        const Text('Hi, Cent!', style: TextStyle(color: _workspaceInk, fontSize: 28, letterSpacing: -.7, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_listening ? 'Voice capture is not connected yet. Try a quick action below.' : 'What would you like to change in your photo?',
          textAlign: TextAlign.center, style: const TextStyle(color: _workspaceMuted, fontSize: 12)),
        const SizedBox(height: 20),
        _AssistantAction(label: 'Edit Stroke Reference', icon: Icons.crop_free_rounded, onTap: () => widget.onAction('Edit Stroke Reference')),
        const SizedBox(height: 9),
        _AssistantAction(label: 'Next Adjustment', icon: Icons.tune_rounded, onTap: () => widget.onAction('Next Adjustment')),
        const SizedBox(height: 9),
        _AssistantAction(label: 'Try a Warm Film Look', icon: Icons.wb_sunny_outlined, onTap: () => widget.onAction('Warm Film Look')),
        const SizedBox(height: 9),
        _AssistantAction(label: 'Reset all adjustments', icon: Icons.restart_alt_rounded, onTap: () => widget.onAction('Reset')),
        const Spacer(),
        const Text('Quick actions work offline. Speech recognition is not connected.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: _workspaceMuted)),
      ]),
    ),
  );
}

class _AssistantAction extends StatelessWidget {
  const _AssistantAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 43, child: OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(foregroundColor: _workspaceInk, side: const BorderSide(color: Color(0xFFE0E0E0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 14)),
    child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 11), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.chevron_right_rounded, size: 18)]),
  ));
}
