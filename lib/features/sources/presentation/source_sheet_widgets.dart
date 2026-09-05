import 'package:flutter/material.dart';

import '../../../core/network/link_probe_service.dart';

/// Why a sources sheet was opened. Both actions stay on every row; the mode
/// only decides the default tap action and the initial filtering.
enum SourcesMode { play, download }

/// Small coloured pill used for quality/source tags.
class SourceTag extends StatelessWidget {
  final String text;
  final Color color;
  const SourceTag({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Working / dead / testing indicator driven by [LinkProbeService].
class ProbeBadge extends StatelessWidget {
  final LinkProbeResult? probe;
  final bool probing;
  final bool isPeerToPeer;

  const ProbeBadge({
    super.key,
    required this.probe,
    required this.probing,
    this.isPeerToPeer = false,
  });

  static String _shortReason(String? reason) {
    if (reason == null || reason.isEmpty) return 'Dead link';
    final lower = reason.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection terminated')) {
      return 'Unreachable';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Timed out';
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Blocked (403)';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'Not found (404)';
    }
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503')) {
      return 'Server error';
    }
    if (reason.length > 18) {
      return 'Dead link';
    }
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (isPeerToPeer) {
      return Text(
        'P2P',
        style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    if (probing) {
      return SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.primary),
      );
    }
    final result = probe;
    if (result == null) return const SizedBox.shrink();
    if (result.reachable) {
      return const SizedBox.shrink();
    }

    final reason = _shortReason(result.failureReason);
    final isNotFound = reason.toLowerCase().contains('not found');
    final isUnreachable = reason.toLowerCase().contains('unreachable');
    final Color badgeColor = isNotFound
        ? const Color(0xFFEF4444) // var(--text-danger)
        : (isUnreachable ? const Color(0xFFF59E0B) : cs.error); // var(--text-warning)
    final IconData badgeIcon = isNotFound
        ? Icons.cancel_rounded // circle-x
        : (isUnreachable ? Icons.warning_amber_rounded : Icons.error_outline_rounded); // alert-triangle

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Title block shared by the sources sheets.
class SourceSheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const SourceSheetHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Best-guess container extension for a link, used when naming downloads.
String extensionForUrl(String url) {
  final clean = url.split('?').first.toLowerCase();
  for (final ext in const ['.mp4', '.mkv', '.webm', '.avi', '.mov']) {
    if (clean.endsWith(ext)) return ext;
  }
  return '.mp4';
}
