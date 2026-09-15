import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/tcgdex/set_info.dart';

/// "Which set?" chooser when number/total matches several sets.
Future<SetInfo?> showSetPicker(BuildContext context, List<SetInfo> candidates) =>
    showModalBottomSheet<SetInfo>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Which set? Match the symbol on the card.',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final s in candidates)
              ListTile(
                leading: s.symbolUrl == null
                    ? const SizedBox(width: 40)
                    : SizedBox(
                        width: 40,
                        child: CachedNetworkImage(
                          imageUrl: s.symbolUrl!,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                title: Text(s.name),
                subtitle: Text('${s.serie ?? ''} · ${s.releaseDate?.substring(0, 4) ?? ''}'
                    '${s.abbreviation != null ? ' · ${s.abbreviation}' : ''}'),
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
