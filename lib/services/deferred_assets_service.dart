import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

enum InstallStatus {
  idle,
  pending,
  downloading,
  downloaded,
  installing,
  installed,
  failed,
  canceled,
  unknown,
}

class ComponentProgress {
  final InstallStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final int errorCode;
  final String? error;

  const ComponentProgress({
    this.status = InstallStatus.idle,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.errorCode = 0,
    this.error,
  });

  double get fraction {
    if (status == InstallStatus.installed) return 1.0;
    if (status == InstallStatus.installing) return 0.98;
    if (status == InstallStatus.downloaded) return 0.95;
    if (totalBytes > 0) {
      return (bytesDownloaded / totalBytes * 0.9).clamp(0.0, 0.9);
    }
    if (status == InstallStatus.pending) return 0.02;
    return 0.0;
  }

  bool get isTerminal =>
      status == InstallStatus.installed ||
      status == InstallStatus.failed ||
      status == InstallStatus.canceled;
}

/// Installs Android deferred-component asset modules at startup and exposes
/// per-component and overall progress to the UI.
///
/// All modules are requested in a single [SplitInstallRequest]: Play Core only
/// allows one active install session per app process, so parallel per-module
/// calls race and all but the first fail with ACTIVE_SESSIONS_LIMIT_EXCEEDED.
///
/// On iOS / web / unsupported Android builds, [installAll] resolves immediately
/// with [done] = true and no progress events.
class DeferredAssetsService extends ChangeNotifier {
  DeferredAssetsService._();
  static final DeferredAssetsService instance = DeferredAssetsService._();

  static const _method = MethodChannel('reefguide/deferred');
  static const _events = EventChannel('reefguide/deferred/progress');
  static const List<String> components = ['pix1', 'pix2', 'pix3', 'pix4'];

  final Map<String, ComponentProgress> _progress = {
    for (final c in components) c: const ComponentProgress(),
  };
  StreamSubscription<dynamic>? _sub;
  Completer<void>? _sessionCompleter;
  bool _installing = false;
  bool _done = false;
  String? _error;

  Map<String, ComponentProgress> get progress => Map.unmodifiable(_progress);
  bool get installing => _installing;
  bool get done => _done;
  String? get error => _error;

  double get overallFraction {
    if (_done) return 1.0;
    final total = components.fold<double>(
      0.0,
      (acc, c) => acc + (_progress[c]?.fraction ?? 0.0),
    );
    return (total / components.length).clamp(0.0, 1.0);
  }

  int get overallPercent => (overallFraction * 100).round();

  Future<void> installAll() async {
    if (_installing || _done) return;
    if (kIsWeb || !Platform.isAndroid) {
      _done = true;
      notifyListeners();
      return;
    }

    _installing = true;
    _error = null;
    notifyListeners();

    _sub ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) => debugPrint('DeferredAssets event error: $e'),
    );

    List<String> alreadyInstalled = const [];
    try {
      alreadyInstalled =
          await _method.invokeListMethod<String>('installedModules') ?? const [];
    } on MissingPluginException {
      _markAllInstalled();
      _installing = false;
      _done = true;
      notifyListeners();
      return;
    } catch (e) {
      debugPrint('DeferredAssets installedModules failed: $e');
    }

    for (final c in alreadyInstalled) {
      if (_progress.containsKey(c)) {
        _progress[c] = const ComponentProgress(status: InstallStatus.installed);
      }
    }

    final toInstall = components
        .where((c) => _progress[c]?.status != InstallStatus.installed)
        .toList();
    if (toInstall.isEmpty) {
      _installing = false;
      // Assets are on disk but still need to be wired into the Flutter engine's
      // AssetManager — same as after a fresh install.
      await _registerAssets(alreadyInstalled);
      _done = true;
      notifyListeners();
      return;
    }

    for (final c in toInstall) {
      _progress[c] = const ComponentProgress(status: InstallStatus.pending);
    }
    notifyListeners();

    final completer = Completer<void>();
    _sessionCompleter = completer;

    try {
      await _method.invokeMethod<bool>('installAll', {'names': toInstall});
    } catch (e) {
      debugPrint('DeferredAssets installAll error: $e');
      for (final c in toInstall) {
        _progress[c] = ComponentProgress(
          status: InstallStatus.failed,
          errorCode: -1,
          error: '$e',
        );
      }
      _error = '$e';
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future.timeout(
      const Duration(minutes: 15),
      onTimeout: () {
        for (final c in toInstall) {
          if (_progress[c]?.status != InstallStatus.installed) {
            _progress[c] = const ComponentProgress(
              status: InstallStatus.failed,
              error: 'Install timeout',
            );
          }
        }
      },
    );

    // Wire the newly-installed modules into the Flutter engine's AssetManager
    // so rootBundle / Image.asset can see them. SplitInstallManager put the
    // files on disk; without this step the engine keeps using the base
    // AssetManager and every Image.asset() for the module returns "not found".
    // We call DeferredComponentManager.loadAssets() directly instead of
    // DeferredComponent.installDeferredComponent() — the latter hangs when
    // startInstall() fails for an already-installed module, because Flutter's
    // failure path doesn't complete the method-channel result.
    final installedOk = components
        .where((c) => _progress[c]?.status == InstallStatus.installed)
        .toList();
    await _registerAssets(installedOk);

    _installing = false;
    _done = components.every(
      (c) => _progress[c]?.status == InstallStatus.installed,
    );
    if (!_done) {
      _error ??= 'One or more components failed to install';
    }
    notifyListeners();
  }

  Future<void> _registerAssets(List<String> modules) async {
    if (modules.isEmpty) return;
    try {
      await _method.invokeMethod<bool>('registerAssets', {'names': modules});
    } catch (e) {
      debugPrint('DeferredAssets: registerAssets failed: $e');
    }
    // Evict any image entries cached as "failed" before the modules became
    // available, so the next Image.asset() retries from the fresh bundle.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final m = Map<String, dynamic>.from(event);
    final modules = (m['modules'] as List?)?.cast<String>() ?? const <String>[];
    final installedList =
        (m['installedModules'] as List?)?.cast<String>() ?? const <String>[];
    final status = _parseStatus(m['status'] as String?);
    final bytesDownloaded = (m['bytesDownloaded'] as num?)?.toInt() ?? 0;
    final totalBytes = (m['totalBytesToDownload'] as num?)?.toInt() ?? 0;
    final errorCode = (m['errorCode'] as num?)?.toInt() ?? 0;
    final err = m['error'] as String?;

    // Everything Play says is installed is authoritative.
    for (final c in installedList) {
      if (_progress.containsKey(c)) {
        _progress[c] = const ComponentProgress(status: InstallStatus.installed);
      }
    }

    // The session's progress applies to every module in that session that
    // isn't already installed. Play Core reports bytes for the session as a
    // whole, not per module.
    for (final c in modules) {
      if (_progress[c]?.status == InstallStatus.installed) continue;
      _progress[c] = ComponentProgress(
        status: status,
        bytesDownloaded: bytesDownloaded,
        totalBytes: totalBytes,
        errorCode: errorCode,
        error: err,
      );
    }

    notifyListeners();

    final terminal = status == InstallStatus.installed ||
        status == InstallStatus.failed ||
        status == InstallStatus.canceled;
    if (terminal) {
      final c = _sessionCompleter;
      if (c != null && !c.isCompleted) c.complete();
      _sessionCompleter = null;
    }
  }

  InstallStatus _parseStatus(String? s) {
    switch (s) {
      case 'PENDING':
      case 'REQUIRES_USER_CONFIRMATION':
        return InstallStatus.pending;
      case 'DOWNLOADING':
        return InstallStatus.downloading;
      case 'DOWNLOADED':
        return InstallStatus.downloaded;
      case 'INSTALLING':
        return InstallStatus.installing;
      case 'INSTALLED':
        return InstallStatus.installed;
      case 'FAILED':
        return InstallStatus.failed;
      case 'CANCELED':
      case 'CANCELING':
        return InstallStatus.canceled;
      default:
        return InstallStatus.unknown;
    }
  }

  void _markAllInstalled() {
    for (final c in components) {
      _progress[c] = const ComponentProgress(status: InstallStatus.installed);
    }
  }
}
