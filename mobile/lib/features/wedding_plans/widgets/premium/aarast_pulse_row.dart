import 'package:flutter/material.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import 'smart_dashboard_models.dart';

class AarastPulseRow extends StatelessWidget {
  const AarastPulseRow({required this.tiles, super.key});

  final List<PulseTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _PulseTile(data: tiles[i])),
        ],
      ],
    );
  }
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({required this.data});

  final PulseTileData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusMd),
            border: Border.all(color: AarastDesignTokens.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, size: 15, color: AarastDesignTokens.gold),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: AarastDesignTokens.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  color: AarastDesignTokens.ink,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: AarastDesignTokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
