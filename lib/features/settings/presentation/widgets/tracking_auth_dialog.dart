import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/loading_indicator.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';

class TrackingAuthDialog extends ConsumerStatefulWidget {
  final String providerName;
  final String verificationUrl;
  final String userCode;

  const TrackingAuthDialog({
    super.key,
    required this.providerName,
    required this.verificationUrl,
    required this.userCode,
  });

  @override
  ConsumerState<TrackingAuthDialog> createState() => _TrackingAuthDialogState();
}

class _TrackingAuthDialogState extends ConsumerState<TrackingAuthDialog> {
  @override
  void initState() {
    super.initState();
    _copyToClipboard();
  }

  void _copyToClipboard({bool isManual = false}) {
    Clipboard.setData(ClipboardData(text: widget.userCode));
  }

  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.verificationUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ref
            .read(notificationServiceProvider)
            .showError(
              'Could not launch ${widget.verificationUrl}',
              title: widget.providerName,
              icon: Icons.open_in_browser_rounded,
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool isWide = MediaQuery.of(context).size.width > 600;

    final qrWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: 200.0,
            height: 200.0,
            child: QrImageView(
              data: widget.verificationUrl,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _launchUrl,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              widget.verificationUrl,
              style: TextStyle(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );

    final codeWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('2. Enter the following code:', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _copyToClipboard(isManual: true),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.userCode,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.copy, color: theme.colorScheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '(Code copied to clipboard automatically)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        const AppLoadingIndicator(),
        const SizedBox(height: 16),
        Text(
          'Waiting for authorization...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text('Login to ${widget.providerName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '1. Scan the QR code or click the link below to open the verification page.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: qrWidget),
                  const SizedBox(width: 32),
                  Expanded(child: codeWidget),
                ],
              )
            else ...[
              qrWidget,
              const SizedBox(height: 24),
              codeWidget,
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
