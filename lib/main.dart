import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _showSettings = false;
  String _status = 'Starting camera…';
  String _mode = 'PHOTO';
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _exposure = 0;
  double _minExposure = 0;
  double _maxExposure = 0;
  FlashMode _flash = FlashMode.off;
  XFile? _lastPhoto;
  String _activePreset = 'Auto';

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
      _showMessage('Imported \${imported.length} custom preset(s).');
    } catch (_) { _showMessage('Import failed. Choose a valid OpenLens JSON preset file.'); }
  }

  Future<void> _exportPresetFormat() async {
    final sample = {'format':'openlens-grade-v1','presets':[{'name':'My Film','brightness':0.02,'contrast':1.12,'saturation':0.9,'warmth':0.25,'tint':0.03,'exposure':0.0,'zoomFactor':1.0,'flash':'off'}]};
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(sample)));
    _showMessage('OpenLens JSON preset template copied to clipboard.');
  }

  Future<void> _openGalleryPreview() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
      if (picked == null || !mounted) return;
      await showDialog<void>(context: context, builder: (context) => Dialog.fullscreen(child: Scaffold(
        appBar: AppBar(title: const Text('GALLERY PREVIEW'), actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        body: Center(child: InteractiveViewer(child: ColorFiltered(colorFilter: ColorFilter.matrix(_gradeMatrix), child: Image.file(File(picked.path), fit: BoxFit.contain)))),
        bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Text('Previewing with \$_activePreset grade. Original gallery file is unchanged.', textAlign: TextAlign.center))),
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
    setState(() => _busy = true);
    try {
      final photo = await camera.takePicture();
      var savedPath = photo.path;
      if (_activePreset != 'Auto' || _gradeBrightness != 0 || _gradeContrast != 1 || _gradeSaturation != 1 || _gradeWarmth != 0 || _gradeTint != 0) {
        savedPath = '${photo.path}.graded.jpg';
        await _applyGradeToFile(photo.path, savedPath);
      }
      await Gal.putImage(savedPath, album: 'OpenLens Pro');
      if (!mounted) return;
      setState(() {
        _lastPhoto = XFile(savedPath);
        _status = 'Graded photo saved to gallery · ${photo.name}';
      });
      _showMessage('Photo saved to your gallery.');
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Capture failed: $e');
        _showMessage('Capture failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleVideoRecording() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    if (_recording) {
      setState(() => _busy = true);
      try {
        final video = await camera.stopVideoRecording();
        await Gal.putVideo(video.path, album: 'OpenLens Pro');
        if (!mounted) return;
        setState(() {
          _recording = false;
          _status = 'Video saved to gallery · ${video.name}';
        });
        _showMessage('Video saved to your gallery.');
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
    _controller?.dispose();
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
                  if (_grid) const IgnorePointer(child: _CompositionGrid()),
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
              tooltip: 'Composition grid',
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(_grid ? Icons.grid_on_rounded : Icons.grid_off_rounded),
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
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xD9080A0C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x443F474D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('SIGNATURE PRESETS · COLOUR GRADING',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                const Spacer(),
                Text(_activePreset.toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: Color(0xFFB8F36B), letterSpacing: 1)),
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
            Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _importCustomPreset, icon: const Icon(Icons.file_open_rounded, size: 16), label: const Text('Import preset JSON'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: _exportPresetFormat, icon: const Icon(Icons.content_copy_rounded, size: 16), label: const Text('Preset template')))]),
            _gradeSlider('Brightness', _gradeBrightness, -0.35, 0.35, (v) => setState(() { _gradeBrightness = v; _activePreset = 'Custom'; })),
            _gradeSlider('Contrast', _gradeContrast, 0.5, 1.8, (v) => setState(() { _gradeContrast = v; _activePreset = 'Custom'; })),
            _gradeSlider('Saturation', _gradeSaturation, 0, 2, (v) => setState(() { _gradeSaturation = v; _activePreset = 'Custom'; })),
            _gradeSlider('Warmth', _gradeWarmth, -1, 1, (v) => setState(() { _gradeWarmth = v; _activePreset = 'Custom'; })),
            _gradeSlider('Tint', _gradeTint, -1, 1, (v) => setState(() { _gradeTint = v; _activePreset = 'Custom'; })),
            const Text('Tap any point in the preview to set focus/exposure when supported.',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
            const SizedBox(height: 4),
            const Text('ISO and shutter speed require a future Camera2 manual-control layer.',
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

class _CompositionGrid extends StatelessWidget {
  const _CompositionGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final cornerPaint = Paint()
      ..color = const Color(0xFFB8F36B)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const length = 22.0;
    const inset = 16.0;
    for (final x in [inset, size.width - inset]) {
      for (final y in [inset, size.height - inset]) {
        final dx = x == inset ? 1.0 : -1.0;
        final dy = y == inset ? 1.0 : -1.0;
        canvas.drawLine(Offset(x, y), Offset(x + dx * length, y), cornerPaint);
        canvas.drawLine(Offset(x, y), Offset(x, y + dy * length), cornerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _SignaturePreset {
  final String name;
  final String hint;
  final IconData icon;
  final double exposure;
  final double zoomFactor;
  final FlashMode flash;
  final double brightness, contrast, saturation, warmth, tint;
  const _SignaturePreset(this.name, this.hint, this.icon, this.exposure, this.zoomFactor, this.flash,
    {this.brightness = 0, this.contrast = 1, this.saturation = 1, this.warmth = 0, this.tint = 0});

  Map<String, dynamic> toJson() => {'name':name,'hint':hint,'brightness':brightness,'contrast':contrast,'saturation':saturation,'warmth':warmth,'tint':tint,'exposure':exposure,'zoomFactor':zoomFactor,'flash':flash.name};

  factory _SignaturePreset.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ?? '';
    if (name.isEmpty || name.length > 32) throw const FormatException('Invalid preset name');
    double number(String key, double fallback, double min, double max) {
      final value = (json[key] as num?)?.toDouble() ?? fallback;
      if (!value.isFinite || value < min || value > max) throw FormatException('Invalid $key');
      return value;
    }
    final flashName = json['flash'] as String? ?? 'off';
    final flash = FlashMode.values.where((v) => v.name == flashName).firstOrNull ?? FlashMode.off;
    return _SignaturePreset(name, (json['hint'] as String?) ?? 'Imported grade', Icons.palette_outlined,
      number('exposure',0,-4,4), number('zoomFactor',1,1,4), flash,
      brightness:number('brightness',0,-0.35,0.35), contrast:number('contrast',1,0.5,1.8),
      saturation:number('saturation',1,0,2), warmth:number('warmth',0,-1,1), tint:number('tint',0,-1,1));
  }
}
