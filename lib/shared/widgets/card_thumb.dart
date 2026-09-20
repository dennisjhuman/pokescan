import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';

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
    final radius = BorderRadius.circular(8);
    final child = AspectRatio(
      aspectRatio: AppConstants.cardAspectRatio,
      child: ClipRRect(
        borderRadius: radius,
        child: imageUrl == null
            ? _Placeholder(name: name, number: number, reason: 'No artwork')
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, _) => const _Loading(),
                errorWidget: (_, _, _) =>
                    _Placeholder(name: name, number: number, reason: 'Image unavailable'),
              ),
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
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
  const _Placeholder({this.name, this.number, required this.reason});
  final String? name;
  final String? number;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
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
              style: text.labelSmall?.copyWith(color: scheme.outline)),
        ],
      ),
    );
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

/// Grid geometry shared by every card list, so a result looks the same
/// wherever it turns up. ~2 columns on a phone, more on a wide window.
SliverGridDelegate cardGridDelegate(BuildContext context) =>
    const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 190,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: AppConstants.cardAspectRatio * 0.78,
    );
