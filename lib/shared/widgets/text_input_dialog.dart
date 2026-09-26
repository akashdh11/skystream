import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'custom_widgets.dart';

/// Asks for one line of text and pops with the trimmed value, or `null` on
/// cancel.
///
/// What confirms it: the field's own Enter / numpad-Enter (its IME action),
/// or an explicit press on the confirm button. Select is deliberately bound
/// to nothing in this dialog — on Android TV it is the leanback keyboard's
/// letter-select key, and a dialog that claimed it would make mid-word entry
/// impossible while the field is focused.
///
/// The controller lives in this widget's State on purpose. `await showDialog`
/// resolves the moment the route is popped, but the dialog's element tree
/// stays mounted for the exit transition and TextField re-subscribes to its
/// controller on every rebuild in that window. A controller created next to
/// the `showDialog` call and disposed right after the await is therefore
/// always disposed too early; one owned by the dialog's own State is disposed
/// when the element unmounts, which is after the animation by construction.
class TextInputDialog extends StatefulWidget {
  final String title;

  /// Explanatory copy shown above the field.
  final String? message;
  final String initialText;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final TextInputType? keyboardType;
  final String confirmLabel;

  /// When false, confirming with nothing but whitespace is a no-op so the
  /// dialog stays open; when true an empty string is a legitimate answer.
  final bool allowEmpty;

  /// Whether the answer is trimmed before it is returned.
  ///
  /// Right for a URL or a key, wrong for a value the caller stores verbatim -
  /// a plugin's text setting may legitimately carry a trailing space, and
  /// stripping it here would silently rewrite persisted third-party data.
  final bool trim;

  /// The field takes initial focus by default. Some callers want the confirm
  /// button focused first on TV so a remote press acts immediately.
  final bool autofocusField;
  final bool showPasteButton;
  final double? width;

  const TextInputDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.message,
    this.initialText = '',
    this.hintText,
    this.labelText,
    this.helperText,
    this.keyboardType,
    this.allowEmpty = false,
    this.trim = true,
    this.autofocusField = true,
    this.showPasteButton = false,
    this.width,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? message,
    String initialText = '',
    String? hintText,
    String? labelText,
    String? helperText,
    TextInputType? keyboardType,
    bool allowEmpty = false,
    bool trim = true,
    bool autofocusField = true,
    bool showPasteButton = false,
    double? width,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => TextInputDialog(
        title: title,
        confirmLabel: confirmLabel,
        message: message,
        initialText: initialText,
        hintText: hintText,
        labelText: labelText,
        helperText: helperText,
        keyboardType: keyboardType,
        allowEmpty: allowEmpty,
        trim: trim,
        autofocusField: autofocusField,
        showPasteButton: showPasteButton,
        width: width,
      ),
    );
  }

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final raw = _controller.text;
    final value = widget.trim ? raw.trim() : raw;
    if (value.isEmpty && !widget.allowEmpty) return;
    Navigator.pop(context, value);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && mounted) {
      _controller.text = widget.trim ? text.trim() : text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final field = CustomTextField(
      controller: _controller,
      autofocus: widget.autofocusField,
      hintText: widget.hintText,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        alignLabelWithHint: widget.helperText != null,
        suffixIcon: widget.showPasteButton
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).pasteButtonLabel,
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _paste,
              )
            : null,
      ),
      onSubmitted: (_) => _confirm(),
    );

    final message = widget.message;
    Widget content = message == null
        ? field
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              field,
            ],
          );
    if (widget.width != null) {
      content = SizedBox(width: widget.width, child: content);
    }

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      title: Text(widget.title),
      content: content,
      actions: [
        CustomButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.cancel,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        CustomButton(
          isPrimary: true,
          autofocus: !widget.autofocusField,
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
