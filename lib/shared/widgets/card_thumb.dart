import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../utils/image_loader.dart';

/// A card picture at the real 63 × 88 mm shape, big enough to recognise the
/// artwork. TCGdex has no image at all for a fair number of cards (older
/// promos especially), so the "no artwork" state is a first-class layout with
/// the name and number in it, not a broken-image icon.
class CardThumb extends StatelessWidget {
  const CardThumb({
    super.key,
    required this.imageUrl,
    this.name,
    this.number,
    this.width,
  });

  final String? imageUrl;
  final String? name;
  final String? number;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final child = AspectRatio(
      aspectRatio: AppConstants.cardAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl == null
            ? _Placeholder(name: name, number: number, reason: 'No artwork')
            : _LoadedImage(
                url: imageUrl!,
                name: name,
                number: number,
              ),
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

/// Paints an image fetched through [imageLoader].
///
/// Deliberately not a FutureBuilder over a fresh future: the whole point is
/// that scrolling back to a tile repaints from bytes we already hold instead
/// of asking the network again. Bytes already in the cache paint on the first
/// frame, with no spinner flash.
class _LoadedImage extends StatefulWidget {
  const _LoadedImage({required this.url, this.name, this.number});

  final String url;
  final String? name;
  final String? number;

  @override
  State<_LoadedImage> createState() => _LoadedImageState();
}

class _LoadedImageState extends State<_LoadedImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_LoadedImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _bytes = null;
      _failed = false;
      _start();
    }
  }

  void _start() {
    final ready = imageLoader.cached(widget.url);
    if (ready != null) {
      _bytes = ready;
      return;
    }
    final url = widget.url;
    imageLoader.load(url).then((bytes) {
      // The tile may have been recycled onto another card while we waited.
      if (!mounted || url != widget.url) return;
      setState(() {
        _bytes = bytes;
        _failed = bytes == null;
      });
    });
  }

  void _retry() {
    imageLoader.retryFailures();
    setState(() => _failed = false);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            _Placeholder(name: widget.name, number: widget.number, reason: 'Unreadable image'),
      );
    }
    if (_failed) {
      return _Placeholder(
        name: widget.name,
        number: widget.number,
        reason: 'Tap to retry',
        onTap: _retry,
      );
    }
    return const _Loading();
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.name, this.number, required this.reason, this.onTap});
  final String? name;
  final String? number;
  final String reason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final body = Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hide_image_outlined, color: scheme.outline),
          const SizedBox(height: 6),
          if (name != null)
            Text(
              name!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          if (number != null)
            Text(number!, style: text.labelSmall?.copyWith(color: scheme.outline)),
          const SizedBox(height: 4),
          Text(reason,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(
                  color: onTap == null ? scheme.outline : scheme.primary)),
        ],
      ),
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

/// One tappable search result: picture, name, and — the part that was missing
/// — which set it is from and what its number is, so two Pikachus are
/// telling apart without opening both.
class CardResultTile extends StatelessWidget {
  const CardResultTile({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.onTap,
    this.setName,
    this.number,
    this.trailingNote,
    this.selected = false,
  });

  final String? imageUrl;
  final String name;
  final String? setName;
  final String? number;
  final String? trailingNote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: selected
                    ? Border.all(color: scheme.primary, width: 3)
                    : Border.all(color: Colors.transparent, width: 3),
              ),
              child: CardThumb(imageUrl: imageUrl, name: name, number: number),
            ),
            const SizedBox(height: 6),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (setName != null)
              Text(setName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            if (number != null || trailingNote != null)
              Text(
                [?number, ?trailingNote].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: scheme.outline),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small non-card image (a set logo or symbol) through the same throttled
/// loader, so the logo list cannot starve the card grid of request slots.
/// Renders nothing at all when the asset is missing — a lot of sets have no
/// logo, and an error icon in a list is worse than a gap.
class RemoteIcon extends StatelessWidget {
  const RemoteIcon({super.key, required this.url, this.fit = BoxFit.contain, this.fallback});

  final String? url;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (url == null) return fallback ?? const SizedBox.shrink();
    return _LoadedIcon(url: url!, fit: fit, fallback: fallback);
  }
}

class _LoadedIcon extends StatefulWidget {
  const _LoadedIcon({required this.url, required this.fit, this.fallback});
  final String url;
  final BoxFit fit;
  final Widget? fallback;

  @override
  State<_LoadedIcon> createState() => _LoadedIconState();
}

class _LoadedIconState extends State<_LoadedIcon> {
  Uint8List? _bytes;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _bytes = imageLoader.cached(widget.url);
    if (_bytes != null) {
      _done = true;
      return;
    }
    final url = widget.url;
    imageLoader.load(url).then((b) {
      if (!mounted || url != widget.url) return;
      setState(() {
        _bytes = b;
        _done = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => widget.fallback ?? const SizedBox.shrink());
    }
    return _done ? (widget.fallback ?? const SizedBox.shrink()) : const SizedBox.shrink();
  }
}

/// Grid geometry shared by every card list, so a result looks the same
/// wherever it turns up. ~2 columns on a phone, more on a wide window.
SliverGridDelegate cardGridDelegate(BuildContext context) =>
    const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 190,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: AppConstants.cardAspectRatio * 0.78,
    );
