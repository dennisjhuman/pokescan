import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/utils/card_crop.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/error_banner.dart';
import 'card_guide_overlay.dart';
import 'card_text_parser.dart';
import 'find_card_view.dart';
import 'scan_outcome.dart';
import 'scan_pipeline.dart';

/// Camera with a card-shaped guide. Shutter → crop → OCR → parse → route.
///
/// Native only: this file pulls in `dart:io` (cropping) and ML Kit. The web
/// build gets `camera_scan_view_stub.dart` instead, picked by the conditional
/// import in `scan_screen.dart`.
class CameraScanView extends ConsumerStatefulWidget {
  const CameraScanView({super.key});

  @override
  ConsumerState<CameraScanView> createState() => _CameraScanViewState();
}

class _CameraScanViewState extends ConsumerState<CameraScanView> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _cameraError;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _cameraError = 'No camera found. Use a photo or manual entry.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      await ctrl.setFlashMode(FlashMode.off);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _camera = ctrl;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Camera unavailable: $e');
    }
  }

  Future<void> _shoot() async {
    final cam = _camera;
    if (cam == null || _busy) return;
    final size = cam.value.previewSize;
    // previewSize is landscape-oriented on both platforms; the guide is
    // computed on the portrait frame the user sees.
    final portrait = size == null ? const Size(3, 4) : Size(size.height, size.width);
    final guide = guideRectFor(portrait);
    try {
      final file = await cam.takePicture();
      await _process(file.path, guide: guide);
    } catch (e) {
      setState(() => _error = describeError(e));
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;
    await _process(picked.path, guide: null);
  }

  Future<void> _process(String path, {required Rect? guide}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref.read(scanPipelineProvider).run(path, guide: guide);
      ref.read(lastScanProvider.notifier).set(outcome);
      if (!mounted) return;
      await _route(outcome);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _route(ScanOutcome outcome) async {
    final parsed = outcome.parsed;
    if (parsed.isConfident) {
      _open(outcome, parsed.candidateIds.single);
      return;
    }
    // Anything less than confident goes to the finder, pre-filled with
    // whatever OCR managed to read. It shows the candidate artwork, which is
    // the only question the user can actually answer with the card in hand.
    if (!mounted) return;
    final id = await FindCardView.pick(context, initialQuery: _seedQuery(parsed));
    if (id != null && mounted) _open(outcome, id);
  }

  /// OCR output as the finder's search box would have been typed.
  static String _seedQuery(ParsedCard parsed) {
    if (parsed.number != null) {
      return [
        if (parsed.setCode != null) parsed.setCode!,
        parsed.total == null ? parsed.number! : '${parsed.number}/${parsed.total}',
      ].join(' ');
    }
    return parsed.name ?? '';
  }

  /// Tie the scan to the card it was opened as, so the detail screen knows the
  /// crop and OCR text belong to what it is showing.
  void _open(ScanOutcome outcome, String cardId) {
    ref.read(lastScanProvider.notifier).set(outcome.resolvedAs(cardId));
    context.push('/card/$cardId');
  }

  @override
  Widget build(BuildContext context) {
    final cam = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (cam != null && cam.value.isInitialized)
            _Preview(camera: cam)
          else
            Center(
              child: _cameraError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_cameraError!,
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    ),
            ),
          if (_busy)
            const ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Reading card…', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ErrorBanner(message: _error!),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Photo',
                        onTap: _busy ? null : _pickPhoto,
                      ),
                      GestureDetector(
                        onTap: (_busy || cam == null) ? null : _shoot,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white38, width: 6),
                          ),
                        ),
                      ),
                      _RoundButton(
                        icon: Icons.keyboard_outlined,
                        label: 'Type',
                        onTap: _busy ? null : () => FindCardView.showAsSheet(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera preview cropped to fill, with the guide overlay on top.
class _Preview extends StatelessWidget {
  const _Preview({required this.camera});
  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    final ps = camera.value.previewSize ?? const Size(1080, 1920);
    final portrait = Size(ps.height, ps.width);
    final guide = guideRectFor(portrait);
    return LayoutBuilder(
      builder: (_, c) => ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: portrait.width,
              height: portrait.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(camera),
                  CardGuideOverlay(guide: guide, hint: 'Fill the frame with the card'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(onPressed: onTap, icon: Icon(icon), iconSize: 28),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
}
