import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/deferred_assets_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minSplashDuration = Duration(seconds: 2);

  final DeferredAssetsService _service = DeferredAssetsService.instance;
  final Stopwatch _elapsed = Stopwatch()..start();
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_maybeAdvance);
    // No-op if main.dart already kicked this off or install is done.
    _service.installAll();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAdvance());
  }

  @override
  void dispose() {
    _service.removeListener(_maybeAdvance);
    super.dispose();
  }

  void _maybeAdvance() {
    if (_advanced || !mounted) return;
    if (!_service.done) {
      setState(() {}); // progress update — rebuild the progress indicator
      return;
    }
    final remaining = _minSplashDuration - _elapsed.elapsed;
    if (remaining > Duration.zero) {
      Future.delayed(remaining, _goHome);
    } else {
      _goHome();
    }
  }

  void _goHome() {
    if (_advanced || !mounted) return;
    _advanced = true;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final percent = _service.overallPercent;
    final done = _service.done;
    final error = _service.error;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'asset/img/splash.png',
                fit: BoxFit.fitWidth,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: _ProgressPanel(
                percent: percent,
                done: done,
                error: error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final int percent;
  final bool done;
  final String? error;

  const _ProgressPanel({
    required this.percent,
    required this.done,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final message = done
        ? 'Ready'
        : error != null
            ? 'Some content unavailable — continuing'
            : 'Downloading species photos… $percent%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: done ? 1.0 : (percent / 100.0),
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

