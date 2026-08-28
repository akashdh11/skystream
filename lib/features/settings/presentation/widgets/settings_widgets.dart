import 'package:flutter/material.dart';
import '../../../../core/utils/layout_constants.dart';

class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LayoutConstants.spacingMd,
            vertical: LayoutConstants.spacingSm,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: LayoutConstants.spacingMd,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class SettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;
  final bool isBeta;
  final FocusNode? focusNode;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
    this.isBeta = false,
    this.focusNode,
  });

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Focus(
          // Passive observer — we want the inner ListTile's InkWell to remain
          // the actual focus target (it's what handles onTap when OK is
          // pressed). hasFocus on this node reflects "any descendant focused"
          // so onFocusChange still fires when the tile is reached.
          focusNode: widget.focusNode,
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) {
            setState(() => _isFocused = f);
            if (f) {
              // Center the focused setting row in the viewport.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ctx = FocusManager.instance.primaryFocus?.context;
                final ro = ctx?.findRenderObject();
                if (ctx != null && ctx.mounted && ro != null) {
                  Scrollable.maybeOf(ctx)?.position.ensureVisible(
                    ro,
                    alignment: 0.5,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.fastOutSlowIn,
                  );
                }
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _isFocused
                  ? primary.withValues(alpha: 0.22)
                  : Colors.transparent,
              border: Border.all(
                color: _isFocused ? primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                focusColor: Colors.transparent,
                hoverColor: primary.withValues(alpha: 0.10),
                leading: Container(
                  padding: const EdgeInsets.all(LayoutConstants.spacingXs),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: primary, size: 20),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (widget.isBeta) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "BETA",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: widget.subtitle != null
                    ? Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      )
                    : null,
                trailing: widget.trailing != null
                    ? (_isFocused
                        ? SwitchTheme(
                            data: SwitchThemeData(
                              thumbIcon:
                                  WidgetStateProperty.resolveWith<Icon?>((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                  );
                                } else {
                                  return const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                  );
                                }
                              }),
                            ),
                            child: widget.trailing!,
                          )
                        : widget.trailing)
                    : const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: widget.onTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        if (!widget.isLast && !_isFocused)
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
          ),
      ],
    );
  }
}
