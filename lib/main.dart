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

  Future<void> _takePhoto() async {
    final camera = _controller;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final photo = await camera.takePicture();
      await Gal.putImage(photo.path, album: 'OpenLens Pro');
      if (!mounted) return;
      setState(() {
        _lastPhoto = photo;
        _status = 'Photo saved to gallery · ${photo.name}';
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
                      child: CameraPreview(camera),
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
                Expanded(
                  child: _lastPhoto == null
                      ? const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 28)
                      : IconButton(
                          tooltip: 'Last captured photo path',
                          onPressed: () => _showMessage('Saved to: ${_lastPhoto!.path}'),
                          icon: const Icon(Icons.photo, color: Color(0xFFB8F36B), size: 28),
                        ),
                ),
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
                const Text('SIGNATURE PRESETS',
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
                itemCount: _presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final preset = _presets[index];
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
            const Text('Tap any point in the preview to set focus/exposure when supported.',
                style: TextStyle(fontSize: 11, color: Colors.white60)),
            const SizedBox(height: 4),
            const Text('ISO and shutter speed require a future Camera2 manual-control layer.',
                style: TextStyle(fontSize: 10, color: Colors.orangeAccent)),
          ],
        ),
      );

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

  const _SignaturePreset(
    this.name,
    this.hint,
    this.icon,
    this.exposure,
    this.zoomFactor,
    this.flash,
  );
}
