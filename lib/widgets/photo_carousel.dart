import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../models/species.dart';
import '../services/data_service.dart';

class PhotoCarousel extends StatefulWidget {
  final Species species;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  const PhotoCarousel({super.key, required this.species, this.initialPage = 0, this.onPageChanged});

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;
  late final TransformationController _transformController;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final zoomed = _transformController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  @override
  void didUpdateWidget(PhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to first photo when species changes.
    // Note: PhotoCarousel is keyed with ValueKey(species.id) in SpeciesScreen,
    // so this guard is redundant today but kept for safety if the key is removed.
    if (oldWidget.species.id != widget.species.id) {
      _currentPage = 0;
      _pageController.jumpToPage(0);
      _transformController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.species.photos;
    if (photos.isEmpty) {
      return _buildPlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Photo area
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: photos.length,
                onPageChanged: (page) {
                  _transformController.value = Matrix4.identity();
                  setState(() => _currentPage = page);
                  widget.onPageChanged?.call(page);
                },
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.asset(
                      pixPath(widget.species.id, photo.id),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.camera_alt, color: Colors.grey, size: 48),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Page counter badge (top-right)
            if (photos.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${_currentPage + 1}/${photos.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Web-only navigation arrows
            if ((kIsWeb || defaultTargetPlatform == TargetPlatform.linux) && photos.length > 1) ...[
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CarouselArrowButton(
                    icon: Icons.chevron_left,
                    enabled: _currentPage > 0,
                    onTap: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CarouselArrowButton(
                    icon: Icons.chevron_right,
                    enabled: _currentPage < photos.length - 1,
                    onTap: () =>
                        _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                  ),
                ),
              ),
            ],
            // Photo location + type caption (bottom)
            Builder(
              builder: (context) {
                final photo = photos[_currentPage];
                final location = photo.location;
                final type = photo.type;
                final comment = photo.comment;
                if (location.isEmpty && type.isEmpty && comment.isEmpty) return const SizedBox.shrink();
                final parts = [
                  if (location.isNotEmpty && location != 'N/A') location,
                  if (type.isNotEmpty) type,
                  if (comment.isNotEmpty) comment,
                ];
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black45,
                    child: Text(
                      parts.join('  -  '),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        // Dot indicator
        if (photos.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(photos.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentPage ? 10 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _currentPage ? Colors.blue[700] : Colors.grey[400],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: Colors.grey[200],
        child: const Icon(Icons.camera_alt, color: Colors.grey, size: 48),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Arrow button (web carousel navigation)
// -----------------------------------------------------------------------------

class _CarouselArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CarouselArrowButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
