import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import 'package:dpad/dpad.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import '../player_controller.dart';
import 'hotstar_player_style.dart';

// Unified settings card container that highlights border when any of its children are focused
class DpadSettingCard extends StatelessWidget {
  final Widget child;

  const DpadSettingCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      descendantsAreFocusable: true,
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161720),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocused
                    ? HotstarPlayerStyle.accent
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: HotstarPlayerStyle.accent.withValues(
                          alpha: 0.15,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

// Custom Slider that handles vertical D-pad navigation and displays a caret drop indicator bubble that moves with the thumb
class DpadSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String labelText;
  final ValueChanged<double> onChanged;

  const DpadSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions = 20,
    required this.labelText,
    required this.onChanged,
  });

  @override
  State<DpadSlider> createState() => _DpadSliderState();
}

class _DpadSliderState extends State<DpadSlider> {
  bool _isFocused = false;
  final FocusNode _sliderFocusNode = FocusNode(canRequestFocus: false);

  @override
  void dispose() {
    _sliderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate fractional position to align the bubble above the thumb
    final fraction = (widget.value - widget.min) / (widget.max - widget.min);
    final alignment = Alignment(fraction * 2.0 - 1.0, 0.0);

    return Focus(
      descendantsAreFocusable: false,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            final step = (widget.max - widget.min) / widget.divisions;
            if (key == LogicalKeyboardKey.arrowLeft) {
              final newValue = (widget.value - step).clamp(
                widget.min,
                widget.max,
              );
              widget.onChanged(newValue);
            } else if (key == LogicalKeyboardKey.arrowRight) {
              final newValue = (widget.value + step).clamp(
                widget.min,
                widget.max,
              );
              widget.onChanged(newValue);
            } else if (key == LogicalKeyboardKey.arrowDown) {
              node.nextFocus();
            } else if (key == LogicalKeyboardKey.arrowUp) {
              node.previousFocus();
            }
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: Align(
                alignment: alignment,
                child: AnimatedOpacity(
                  opacity: _isFocused ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 150),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isFocused
                              ? HotstarPlayerStyle.accent
                              : const Color(0xFF202130),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isFocused
                              ? [
                                  BoxShadow(
                                    color: HotstarPlayerStyle.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          widget.labelText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      CustomPaint(
                        size: const Size(10, 5),
                        painter: _CaretPainter(
                          color: _isFocused
                              ? HotstarPlayerStyle.accent
                              : const Color(0xFF202130),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: HotstarPlayerStyle.accent,
                inactiveTrackColor: Colors.grey.shade800,
                thumbColor: _isFocused
                    ? Colors.white
                    : HotstarPlayerStyle.accent,
                overlayColor: HotstarPlayerStyle.accent.withValues(alpha: 0.12),
                valueIndicatorColor: HotstarPlayerStyle.accent,
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: _isFocused ? 8 : 6,
                ),
              ),
              child: Slider(
                value: widget.value,
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                focusNode: _sliderFocusNode,
                onChanged: widget.onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  final Color color;
  const _CaretPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Focusable color circle widget that magnifies from 28 to 38 when focused via DpadFocusable
class DpadColorCircle extends StatelessWidget {
  final int colorValue;
  final bool isSelected;
  final VoidCallback onTap;

  const DpadColorCircle({
    super.key,
    required this.colorValue,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTransparent = colorValue == 0x00000000;

    final parentCardNode = Focus.of(context);

    return Focus(
      skipTraversal: true,
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown) {
            if (key == LogicalKeyboardKey.arrowUp) {
              parentCardNode.focusInDirection(TraversalDirection.up);
            } else {
              parentCardNode.focusInDirection(TraversalDirection.down);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: DpadFocusable(
        onSelect: onTap,
        child: const SizedBox.shrink(),
        builder: (context, state, child) {
          final isFocused = state.focused;
          final size = isFocused ? 38.0 : 28.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? HotstarPlayerStyle.accent
                    : (isFocused ? Colors.white : Colors.grey.shade700),
                width: isSelected ? 2.5 : (isFocused ? 2.0 : 1.0),
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(size / 2),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTransparent ? Colors.transparent : Color(colorValue),
                ),
                child: isTransparent
                    ? const Center(
                        child: Icon(
                          Icons.disabled_by_default_outlined,
                          size: 16,
                          color: Colors.red,
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Highly visible D-pad button wrapping DpadFocusable for navigation and action bar highlights
class DpadButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const DpadButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onSelect: onPressed,
      child: const SizedBox.shrink(),
      builder: (context, state, child) {
        final isFocused = state.focused;
        final baseColor = isPrimary
            ? HotstarPlayerStyle.accent
            : Colors.transparent;
        final focusedColor = isPrimary
            ? Colors.white
            : HotstarPlayerStyle.accent.withValues(alpha: 0.2);
        final textColor = isPrimary
            ? (isFocused ? Colors.black : Colors.white)
            : (isFocused
                  ? HotstarPlayerStyle.accent
                  : HotstarPlayerStyle.secondaryText);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isFocused ? focusedColor : baseColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused
                      ? HotstarPlayerStyle.accent
                      : (isPrimary ? Colors.transparent : Colors.grey.shade800),
                  width: 1.5,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: HotstarPlayerStyle.accent.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SubtitleAppearanceDialog extends ConsumerStatefulWidget {
  final bool wasPlaying;
  const SubtitleAppearanceDialog({super.key, required this.wasPlaying});

  @override
  ConsumerState<SubtitleAppearanceDialog> createState() =>
      _SubtitleAppearanceDialogState();
}

class _SubtitleAppearanceDialogState
    extends ConsumerState<SubtitleAppearanceDialog> {
  late PlayerSettings _localSettings;
  bool _customFontLoading = false;
  bool _customFontLoaded = false;
  late final PlayerController _playerController;

  final List<int> _textColors = const [
    0xFFFFFFFF, // White
    0xFFFFFF00, // Yellow
    0xFF00FFFF, // Cyan
    0xFFFF00FF, // Magenta
    0xFF00FF00, // Green
    0xFFFF0000, // Red
    0xFF2196F3, // Blue
    0xFFFF9800, // Orange
    0xFF000000, // Black
  ];

  final List<int> _bgColors = const [
    0x00000000, // Transparent
    0xFF000000, // Black
    0xFF333333, // Dark Grey
    0xFF1A1A1A, // Very Dark Grey
    0xFF001F3F, // Navy
  ];

  final List<String> _builtInFonts = const [
    'Normal (system sans-serif)',
    'Trebuchet MS',
    'Netflix Sans',
    'Google Sans',
    'Open Sans',
    'Futura',
    'Consola',
    'Gotham',
    'Lucida Grande',
    'STIX General',
    'Times New Roman',
    'Verdana',
    'Ubuntu',
    'Comic Sans',
    'Poppins',
  ];

  TextStyle _getSubtitleTextStyle(String? fontFamily, TextStyle baseStyle) {
    if (fontFamily == null) return baseStyle;
    switch (fontFamily.toLowerCase()) {
      case 'open sans':
        return GoogleFonts.openSans(textStyle: baseStyle);
      case 'poppins':
        return GoogleFonts.poppins(textStyle: baseStyle);
      case 'ubuntu':
        return GoogleFonts.ubuntu(textStyle: baseStyle);
      default:
        return baseStyle.copyWith(fontFamily: fontFamily);
    }
  }

  @override
  void initState() {
    super.initState();
    _playerController = ref.read(playerControllerProvider.notifier);
    if (widget.wasPlaying) {
      unawaited(_playerController.pause());
    }
    final currentSettings =
        ref.read(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    _localSettings = currentSettings;
    _loadCustomFontIfNeeded();
  }

  @override
  void dispose() {
    if (widget.wasPlaying) {
      unawaited(_playerController.play());
    }
    super.dispose();
  }

  Future<void> _loadCustomFontIfNeeded() async {
    final path = _localSettings.subTypefaceFilePath;
    if (path != null && path.isNotEmpty) {
      setState(() => _customFontLoading = true);
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fontLoader = FontLoader('CustomSubtitleFont');
          fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
          await fontLoader.load();
          if (mounted) {
            setState(() {
              _customFontLoaded = true;
              _customFontLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _customFontLoading = false);
        }
      } catch (e) {
        debugPrint("Failed to load custom font: $e");
        if (mounted) setState(() => _customFontLoading = false);
      }
    }
  }

  Future<void> _pickCustomFont() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );
      if (picked?.path != null) {
        final path = picked!.path!;
        setState(() {
          _localSettings = _localSettings.copyWith(
            subTypefaceFilePath: () => path,
            subTypeface: () => null,
          );
        });
        await _loadCustomFontIfNeeded();
      }
    } catch (e) {
      debugPrint("Error picking custom font: $e");
    }
  }

  void _resetAll() {
    setState(() {
      _localSettings = _localSettings.copyWith(
        subFixedTextSize: () => null,
        subTypeface: () => null,
        subTypefaceFilePath: () => null,
        subEdgeType: 1,
        subEdgeSize: () => null,
        subBackgroundRadius: () => null,
        subElevation: 20,
        subRemoveBloat: true,
        subRemoveCaptions: false,
        subUpperCase: false,
        subBold: false,
        subItalic: false,
        subForegroundColor: 0xFFFFFFFF,
        subBackgroundColor: 0x00000000,
        subEdgeColor: 0xFF000000,
        subBackgroundOpacity: 0.5,
        subAlignment: () => null,
      );
      _customFontLoaded = false;
    });
  }

  void _applyAndSave() {
    ref
        .read(playerSettingsProvider.notifier)
        .setSubtitleAppearanceSettings(_localSettings);
    ref.read(playerControllerProvider.notifier).applySubtitleSettings();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HotstarPlayerStyle.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Subtitle Appearance",
          style: TextStyle(
            color: HotstarPlayerStyle.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: HotstarPlayerStyle.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // On small screens (mobile), keep the preview compact.
          // On large screens (TV/desktop), allow more space.
          final previewHeight = constraints.maxHeight < 600
              ? 100.0
              : (constraints.maxHeight < 900 ? 130.0 : 160.0);

          return Column(
            children: [
              SizedBox(height: previewHeight, child: _buildPreviewPane()),
              const Divider(color: HotstarPlayerStyle.divider, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("Font Settings"),
                      _buildFontSizeRow(),
                      _buildTypefaceRow(),
                      _buildBoldRow(),
                      _buildItalicRow(),
                      _buildTextColorRow(),

                      _buildSectionHeader("Edge Settings"),
                      _buildEdgeTypeRow(),
                      _buildEdgeSizeRow(),
                      _buildEdgeColorRow(),

                      _buildSectionHeader("Background & Layout"),
                      _buildBackgroundColorRow(),
                      _buildBackgroundOpacityRow(),
                      _buildBackgroundRadiusRow(),
                      _buildElevationRow(),
                      _buildAlignmentRow(),

                      _buildSectionHeader("Content Cleaning & Filtering"),
                      _buildRemoveBloatRow(),
                      _buildRemoveCaptionsRow(),
                      _buildUppercaseRow(),

                      const SizedBox(height: 32),
                      Row(
                        children: [
                          DpadButton(
                            label: "Reset to Default",
                            isPrimary: false,
                            onPressed: _resetAll,
                          ),
                          const Spacer(),
                          DpadButton(
                            label: "Cancel",
                            isPrimary: false,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          DpadButton(
                            label: "Apply Settings",
                            isPrimary: true,
                            onPressed: _applyAndSave,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: HotstarPlayerStyle.accent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildPreviewPane() {
    String? fontFamily;
    if (_localSettings.subTypefaceFilePath != null && _customFontLoaded) {
      fontFamily = 'CustomSubtitleFont';
    } else if (_localSettings.subTypeface != null &&
        _localSettings.subTypeface! >= 0 &&
        _localSettings.subTypeface! < _builtInFonts.length) {
      if (_localSettings.subTypeface == 0) {
        fontFamily = null;
      } else {
        fontFamily = _builtInFonts[_localSettings.subTypeface!];
      }
    }

    final fontSize = _localSettings.subFixedTextSize ?? 22.0;

    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: _localSettings.subBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _localSettings.subItalic ? FontStyle.italic : FontStyle.normal,
      color: Color(_localSettings.subForegroundColor),
    );

    final textStyle = _getSubtitleTextStyle(fontFamily, baseStyle);
    final edgeColor = Color(_localSettings.subEdgeColor);

    final sampleText = _localSettings.subUpperCase
        ? "SAMPLE SUBTITLE LINE\nSECOND LINE OF PREVIEW"
        : "Sample Subtitle Line\nSecond Line of Preview";

    final splitLines = sampleText.split('\n');

    final alignmentCode = _localSettings.subAlignment ?? 2;
    final alignment = switch (alignmentCode) {
      1 => Alignment.bottomLeft,
      3 => Alignment.bottomRight,
      4 => Alignment.centerLeft,
      5 => Alignment.center,
      6 => Alignment.centerRight,
      7 => Alignment.topLeft,
      8 => Alignment.topCenter,
      9 => Alignment.topRight,
      _ => Alignment.bottomCenter,
    };

    final crossAxisAlignment = switch (alignmentCode) {
      1 || 4 || 7 => CrossAxisAlignment.start,
      3 || 6 || 9 => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };

    final textAlign = switch (alignmentCode) {
      1 || 4 || 7 => TextAlign.left,
      3 || 6 || 9 => TextAlign.right,
      _ => TextAlign.center,
    };

    Widget buildPreviewText(String line) {
      final List<Widget> lineChildren = [];

      if (_localSettings.subEdgeType == 1) {
        lineChildren.add(
          Text(
            line,
            style: textStyle.copyWith(
              color: null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = _localSettings.subEdgeSize ?? 2.0
                ..color = edgeColor,
            ),
            textAlign: textAlign,
          ),
        );
      }

      List<Shadow>? shadows;
      if (_localSettings.subEdgeType == 2) {
        shadows = [
          Shadow(
            offset: const Offset(-1, -1),
            color: edgeColor.withValues(alpha: 0.5),
          ),
          Shadow(
            offset: const Offset(1, 1),
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ];
      } else if (_localSettings.subEdgeType == 3) {
        shadows = [
          Shadow(offset: const Offset(2, 2), blurRadius: 2.0, color: edgeColor),
        ];
      } else if (_localSettings.subEdgeType == 4) {
        shadows = [
          Shadow(offset: const Offset(1, 1), color: edgeColor),
          Shadow(
            offset: const Offset(2, 2),
            color: edgeColor.withValues(alpha: 0.5),
          ),
        ];
      }

      lineChildren.add(
        Text(
          line,
          style: textStyle.copyWith(shadows: shadows),
          textAlign: textAlign,
        ),
      );

      Widget resultLine = Stack(children: lineChildren);

      final bgColor = Color(_localSettings.subBackgroundColor);
      if (bgColor.a > 0 && _localSettings.subBackgroundOpacity > 0) {
        final paddingVal =
            2.0 + (_localSettings.subBackgroundRadius ?? 0.0) * 0.5;
        resultLine = Container(
          padding: EdgeInsets.symmetric(horizontal: paddingVal, vertical: 2.0),
          decoration: BoxDecoration(
            color: bgColor.withValues(
              alpha: _localSettings.subBackgroundOpacity,
            ),
            borderRadius: _localSettings.subBackgroundRadius != null
                ? BorderRadius.circular(_localSettings.subBackgroundRadius!)
                : BorderRadius.zero,
          ),
          child: resultLine,
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: resultLine,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image layer
        Image.asset(
          'assets/images/subtitles_preview_background.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          // The source is 5120x3413 — 66.6 MB once decoded to ARGB, for a
          // backdrop behind a subtitle preview. cacheWidth decodes it at a
          // sensible size instead: 1280 wide is ~4.2 MB, and BoxFit.cover
          // scales from there with no visible difference at this size.
          cacheWidth: 1280,
          errorBuilder: (context, error, stackTrace) {
            // Fallback gradient when image fails to load
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            );
          },
        ),
        // Subtitle preview text layer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: alignment,
            child: Transform.translate(
              offset: Offset(
                0.0,
                alignment.y >= 0
                    ? -_localSettings.subElevation.toDouble() * 0.2
                    : _localSettings.subElevation.toDouble() * 0.2,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: crossAxisAlignment,
                  children: splitLines.map(buildPreviewText).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Generic Chevron Picker Row layout
  Widget _buildChevronPickerRow({
    required String label,
    required String subtitle,
    required String currentValueText,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return DpadSettingCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: HotstarPlayerStyle.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentValueText,
                    style: const TextStyle(
                      color: HotstarPlayerStyle.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: HotstarPlayerStyle.accent,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: HotstarPlayerStyle.mutedText,
                      size: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSizePicker() {
    final sizeList = List<int>.generate(55, (i) => i + 6);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161720),
          title: const Text(
            "Select Font Size",
            style: TextStyle(
              color: HotstarPlayerStyle.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView(
              children: [
                ListTile(
                  title: const Text(
                    "File Default",
                    style: TextStyle(color: HotstarPlayerStyle.primaryText),
                  ),
                  selected: _localSettings.subFixedTextSize == null,
                  selectedColor: HotstarPlayerStyle.accent,
                  onTap: () {
                    setState(() {
                      _localSettings = _localSettings.copyWith(
                        subFixedTextSize: () => null,
                      );
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ...sizeList.map((size) {
                  final val = size.toDouble();
                  return ListTile(
                    title: Text(
                      "${size}sp",
                      style: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                      ),
                    ),
                    selected: _localSettings.subFixedTextSize == val,
                    selectedColor: HotstarPlayerStyle.accent,
                    onTap: () {
                      setState(() {
                        _localSettings = _localSettings.copyWith(
                          subFixedTextSize: () => val,
                        );
                      });
                      Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontSizeRow() {
    final valText = _localSettings.subFixedTextSize == null
        ? "File Default"
        : "${_localSettings.subFixedTextSize!.round()}sp";
    return _buildChevronPickerRow(
      label: "Font Size",
      subtitle: "Overriding text size from subtitle files (6sp-60sp)",
      currentValueText: valText,
      onTap: _showFontSizePicker,
    );
  }

  void _showTypefacePicker() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161720),
          title: const Text(
            "Select Font Typeface",
            style: TextStyle(
              color: HotstarPlayerStyle.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView(
              children: [
                ...List.generate(_builtInFonts.length, (idx) {
                  final isSelected =
                      _localSettings.subTypefaceFilePath == null &&
                      _localSettings.subTypeface == idx;
                  return ListTile(
                    title: Text(
                      _builtInFonts[idx],
                      style: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: HotstarPlayerStyle.accent,
                    onTap: () {
                      setState(() {
                        _localSettings = _localSettings.copyWith(
                          subTypeface: () => idx,
                          subTypefaceFilePath: () => null,
                        );
                      });
                      _customFontLoaded = false;
                      Navigator.of(context).pop();
                    },
                  );
                }),
                ListTile(
                  title: const Text(
                    "Custom Font File...",
                    style: TextStyle(color: HotstarPlayerStyle.primaryText),
                  ),
                  selected: _localSettings.subTypefaceFilePath != null,
                  selectedColor: HotstarPlayerStyle.accent,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickCustomFont();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypefaceRow() {
    final valText = _localSettings.subTypefaceFilePath != null
        ? "Custom: ${p.basename(_localSettings.subTypefaceFilePath!)}"
        : _builtInFonts[_localSettings.subTypeface ?? 0];
    return _buildChevronPickerRow(
      label: "Font Typeface",
      subtitle: "Choose from 15 built-in fonts or load custom OTF/TTF",
      currentValueText: valText,
      onTap: _showTypefacePicker,
      isLoading: _customFontLoading,
    );
  }

  Widget _buildBoldRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bold Text Style",
                    style: TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Make subtitle text bold",
                    style: TextStyle(
                      color: HotstarPlayerStyle.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _localSettings.subBold,
              activeThumbColor: Colors.white,
              activeTrackColor: HotstarPlayerStyle.accent,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade800,
              onChanged: (val) {
                setState(() {
                  _localSettings = _localSettings.copyWith(subBold: val);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItalicRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Italic Text Style",
                    style: TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Make subtitle text slanted",
                    style: TextStyle(
                      color: HotstarPlayerStyle.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _localSettings.subItalic,
              activeThumbColor: Colors.white,
              activeTrackColor: HotstarPlayerStyle.accent,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade800,
              onChanged: (val) {
                setState(() {
                  _localSettings = _localSettings.copyWith(subItalic: val);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextColorRow() {
    return _buildColorRow(
      "Text Color",
      "colors",
      _localSettings.subForegroundColor,
      (color) {
        setState(() {
          _localSettings = _localSettings.copyWith(subForegroundColor: color);
        });
      },
    );
  }

  void _showEdgeTypePicker() {
    final edgeTypes = ["None", "Outline", "Depressed", "Drop Shadow", "Raised"];

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161720),
          title: const Text(
            "Select Edge Type",
            style: TextStyle(
              color: HotstarPlayerStyle.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView(
              children: List.generate(edgeTypes.length, (int i) {
                return ListTile(
                  title: Text(
                    edgeTypes[i],
                    style: const TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                    ),
                  ),
                  selected: _localSettings.subEdgeType == i,
                  selectedColor: HotstarPlayerStyle.accent,
                  onTap: () {
                    setState(() {
                      _localSettings = _localSettings.copyWith(subEdgeType: i);
                    });
                    Navigator.of(context).pop();
                  },
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEdgeTypeRow() {
    final edgeTypesText = [
      "None",
      "Outline",
      "Depressed",
      "Drop Shadow",
      "Raised",
    ];
    return _buildChevronPickerRow(
      label: "Edge Type",
      subtitle: "Text borders/shadows (outline default)",
      currentValueText: edgeTypesText[_localSettings.subEdgeType],
      onTap: _showEdgeTypePicker,
    );
  }

  Widget _buildEdgeSizeRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Edge Stroke Size",
                        style: TextStyle(
                          color: HotstarPlayerStyle.primaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Thicker outline borders (1px-60px)",
                        style: TextStyle(
                          color: HotstarPlayerStyle.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _localSettings.subEdgeSize != null,
                  activeThumbColor: Colors.white,
                  activeTrackColor: HotstarPlayerStyle.accent,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade800,
                  onChanged: (val) {
                    setState(() {
                      _localSettings = _localSettings.copyWith(
                        subEdgeSize: () => val ? 2.0 : null,
                      );
                    });
                  },
                ),
              ],
            ),
            if (_localSettings.subEdgeSize != null) ...[
              const SizedBox(height: 8),
              DpadSlider(
                value: _localSettings.subEdgeSize!,
                min: 1.0,
                max: 60.0,
                divisions: 59,
                labelText: "${_localSettings.subEdgeSize!.round()}px",
                onChanged: (val) {
                  setState(() {
                    _localSettings = _localSettings.copyWith(
                      subEdgeSize: () => val,
                    );
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEdgeColorRow() {
    return _buildColorRow(
      "Outline Color",
      "edgeColor",
      _localSettings.subEdgeColor,
      (color) {
        setState(() {
          _localSettings = _localSettings.copyWith(subEdgeColor: color);
        });
      },
    );
  }

  Widget _buildBackgroundColorRow() {
    return _buildColorRow(
      "Background Pill Color",
      "colors",
      _localSettings.subBackgroundColor,
      (color) {
        setState(() {
          _localSettings = _localSettings.copyWith(subBackgroundColor: color);
        });
      },
    );
  }

  Widget _buildBackgroundOpacityRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Background Opacity",
              style: TextStyle(
                color: HotstarPlayerStyle.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "Pill opacity level (0% to 100%)",
              style: TextStyle(
                color: HotstarPlayerStyle.mutedText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            DpadSlider(
              value: _localSettings.subBackgroundOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              labelText:
                  "${(_localSettings.subBackgroundOpacity * 100).round()}%",
              onChanged: (val) {
                setState(() {
                  _localSettings = _localSettings.copyWith(
                    subBackgroundOpacity: val,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBackgroundRadiusPicker() {
    final steps = List<int>.generate(10, (i) => (i + 1) * 5);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161720),
          title: const Text(
            "Select Corner Radius",
            style: TextStyle(
              color: HotstarPlayerStyle.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 300,
            height: 350,
            child: ListView(
              children: [
                ListTile(
                  title: const Text(
                    "None (Sharp)",
                    style: TextStyle(color: HotstarPlayerStyle.primaryText),
                  ),
                  selected: _localSettings.subBackgroundRadius == null,
                  selectedColor: HotstarPlayerStyle.accent,
                  onTap: () {
                    setState(() {
                      _localSettings = _localSettings.copyWith(
                        subBackgroundRadius: () => null,
                      );
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ...steps.map((step) {
                  final val = step.toDouble();
                  return ListTile(
                    title: Text(
                      "${step}px",
                      style: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                      ),
                    ),
                    selected: _localSettings.subBackgroundRadius == val,
                    selectedColor: HotstarPlayerStyle.accent,
                    onTap: () {
                      setState(() {
                        _localSettings = _localSettings.copyWith(
                          subBackgroundRadius: () => val,
                        );
                      });
                      Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundRadiusRow() {
    final valText = _localSettings.subBackgroundRadius == null
        ? "None (Sharp)"
        : "${_localSettings.subBackgroundRadius!.round()}px";
    return _buildChevronPickerRow(
      label: "Background Corner Radius",
      subtitle: "Round background corners (5px-50px)",
      currentValueText: valText,
      onTap: _showBackgroundRadiusPicker,
    );
  }

  Widget _buildElevationRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Elevation (Bottom padding)",
              style: TextStyle(
                color: HotstarPlayerStyle.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "Push subtitles higher (0dp-400dp)",
              style: TextStyle(
                color: HotstarPlayerStyle.mutedText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            DpadSlider(
              value: _localSettings.subElevation.toDouble(),
              min: 0.0,
              max: 400.0,
              divisions: 40,
              labelText: "${_localSettings.subElevation}dp",
              onChanged: (val) {
                setState(() {
                  _localSettings = _localSettings.copyWith(
                    subElevation: val.round(),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAlignmentPicker() {
    final list = [
      (1, "SSA 1 - Bottom Left"),
      (2, "SSA 2 - Bottom Center"),
      (3, "SSA 3 - Bottom Right"),
      (4, "SSA 4 - Middle Left"),
      (5, "SSA 5 - Center"),
      (6, "SSA 6 - Middle Right"),
      (7, "SSA 7 - Top Left"),
      (8, "SSA 8 - Top Center"),
      (9, "SSA 9 - Top Right"),
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161720),
          title: const Text(
            "Select Alignment",
            style: TextStyle(
              color: HotstarPlayerStyle.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 300,
            height: 380,
            child: ListView(
              children: [
                ListTile(
                  title: const Text(
                    "Auto (Exo/Ass default)",
                    style: TextStyle(color: HotstarPlayerStyle.primaryText),
                  ),
                  selected: _localSettings.subAlignment == null,
                  selectedColor: HotstarPlayerStyle.accent,
                  onTap: () {
                    setState(() {
                      _localSettings = _localSettings.copyWith(
                        subAlignment: () => null,
                      );
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ...list.map((item) {
                  return ListTile(
                    title: Text(
                      item.$2,
                      style: const TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                      ),
                    ),
                    selected: _localSettings.subAlignment == item.$1,
                    selectedColor: HotstarPlayerStyle.accent,
                    onTap: () {
                      setState(() {
                        _localSettings = _localSettings.copyWith(
                          subAlignment: () => item.$1,
                        );
                      });
                      Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlignmentRow() {
    final valText = _localSettings.subAlignment == null
        ? "Auto"
        : "SSA ${_localSettings.subAlignment}";
    return _buildChevronPickerRow(
      label: "Alignment",
      subtitle: "Screen alignment (SSA 1-9 coordinates)",
      currentValueText: valText,
      onTap: _showAlignmentPicker,
    );
  }

  Widget _buildRemoveBloatRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Remove Bloat",
                    style: TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Strip OpenSubtitles ads/promos (re-parses stream)",
                    style: TextStyle(
                      color: HotstarPlayerStyle.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _localSettings.subRemoveBloat,
              activeThumbColor: Colors.white,
              activeTrackColor: HotstarPlayerStyle.accent,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade800,
              onChanged: (val) {
                setState(() {
                  _localSettings = _localSettings.copyWith(subRemoveBloat: val);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoveCaptionsRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Remove Captions",
                    style: TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Strips bracketed text like [Music] or (cough)",
                    style: TextStyle(
                      color: HotstarPlayerStyle.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _localSettings.subRemoveCaptions,
              activeThumbColor: Colors.white,
              activeTrackColor: HotstarPlayerStyle.accent,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade800,
              onChanged: (val) {
                setState(() {
                  _localSettings = _localSettings.copyWith(
                    subRemoveCaptions: val,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUppercaseRow() {
    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Force Uppercase",
                    style: TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Display all subtitle cues in capital letters",
                    style: TextStyle(
                      color: HotstarPlayerStyle.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _localSettings.subUpperCase,
              activeThumbColor: Colors.white,
              activeTrackColor: HotstarPlayerStyle.accent,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade800,
              onChanged: (val) {
                setState(() {
                  _localSettings = _localSettings.copyWith(subUpperCase: val);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow(
    String label,
    String fieldKey,
    int selectedColor,
    void Function(int) onSelected,
  ) {
    final palette = fieldKey == 'edgeColor'
        ? [0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFFFFFF00]
        : _textColors;
    final finalPalette =
        fieldKey == 'colors' && label == 'Background Pill Color'
        ? _bgColors
        : palette;

    return DpadSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: HotstarPlayerStyle.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Navigate and select color",
                    style: TextStyle(
                      color: HotstarPlayerStyle.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: finalPalette.map((colorValue) {
                return DpadColorCircle(
                  colorValue: colorValue,
                  isSelected: selectedColor == colorValue,
                  onTap: () => onSelected(colorValue),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
