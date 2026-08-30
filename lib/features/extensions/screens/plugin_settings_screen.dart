import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../../core/extensions/extension_manager.dart';
import '../../../core/extensions/models/extension_plugin.dart';
import '../../../core/storage/extension_repository.dart';
import '../../../core/storage/settings_repository.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../shared/widgets/custom_widgets.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../core/services/notification_service.dart';
import '../../settings/presentation/widgets/settings_widgets.dart';

class PluginSettingsScreen extends ConsumerStatefulWidget {
  final ExtensionPlugin plugin;

  const PluginSettingsScreen({super.key, required this.plugin});

  @override
  ConsumerState<PluginSettingsScreen> createState() =>
      _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends ConsumerState<PluginSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PluginSettingDefinition> _definitions = const [];
  List<PluginSubProvider> _providers = const [];
  final Map<String, String> _values = {};
  final Map<String, bool> _providerEnabled = {};
  final Map<String, TextEditingController> _controllers = {};
  String _selectedDomain = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final manager = ref.read(extensionManagerProvider.notifier);
      final definitions = await manager.getSettingsForPlugin(widget.plugin);
      final providers = manager.getProvidersForPlugin(widget.plugin);
      final storage = ref.read(extensionRepositoryProvider);
      final settingsRepository = ref.read(settingsRepositoryProvider);
      final savedBaseUrl = settingsRepository.getCustomBaseUrl(
        widget.plugin.packageName,
      );

      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _values.clear();
      _providerEnabled.clear();

      for (final definition in definitions) {
        String value;
        if (definition.isBaseUrl) {
          value =
              savedBaseUrl ??
              (definition.defaultValue.isNotEmpty
                  ? definition.defaultValue
                  : (widget.plugin.manifest['baseUrl']?.toString() ?? ''));
        } else {
          value =
              storage.getExtensionData(
                '${widget.plugin.packageName}:${definition.key}',
              ) ??
              definition.defaultValue;
        }

        if (definition.type == PluginSettingType.select &&
            definition.options.isNotEmpty &&
            !definition.options.any((option) => option.value == value)) {
          value = definition.options.first.value;
        }

        if (definition.type == PluginSettingType.toggleGroup) {
          value = _normalizedToggleGroupValue(definition, value);
        }

        _values[definition.key] = value;
        if (definition.type == PluginSettingType.text ||
            definition.type == PluginSettingType.url) {
          _controllers[definition.key] = TextEditingController(text: value);
        }
      }

      for (final provider in providers) {
        final saved = storage.getExtensionData(
          '${widget.plugin.packageName}:'
          '_provider_enabled_${provider.id}',
        );
        _providerEnabled[provider.id] = saved == null ? true : saved == 'true';
      }

      final domains = widget.plugin.domains ?? const <PluginDomain>[];
      _selectedDomain =
          savedBaseUrl ??
          (domains.isNotEmpty
              ? domains.first.url
              : (widget.plugin.manifest['baseUrl']?.toString() ?? ''));

      if (!mounted) return;
      setState(() {
        _definitions = definitions;
        _providers = providers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  bool _boolValue(String key) {
    final value = (_values[key] ?? '').trim().toLowerCase();
    return value == 'true' || value == '1' || value == 'yes' || value == 'on';
  }

  bool _boolFromDynamic(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value == null) return fallback;

    final normalized = value.toString().trim().toLowerCase();
    if (const {'true', '1', 'yes', 'on'}.contains(normalized)) return true;
    if (const {'false', '0', 'no', 'off'}.contains(normalized)) return false;
    return fallback;
  }

  Map<String, bool> _toggleGroupValues(
    PluginSettingDefinition definition, [
    String? rawValue,
  ]) {
    final values = <String, bool>{
      for (final option in definition.options) option.value: option.defaultBool,
    };

    final raw = rawValue ?? _values[definition.key] ?? definition.defaultValue;
    if (raw.trim().isEmpty) return values;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final option in definition.options) {
          values[option.value] = _boolFromDynamic(
            decoded[option.value],
            fallback: option.defaultBool,
          );
        }
      }
    } catch (_) {
      // Invalid or legacy values fall back to each option's default.
    }

    return values;
  }

  String _normalizedToggleGroupValue(
    PluginSettingDefinition definition,
    String rawValue,
  ) {
    return jsonEncode(_toggleGroupValues(definition, rawValue));
  }

  IconData _toggleGroupOptionIcon(PluginSettingOption option) {
    final icon = (option.icon ?? option.value).toLowerCase();

    if (icon.contains('trailer') || icon.contains('video')) {
      return Icons.movie_outlined;
    }
    if (icon.contains('character') || icon.contains('cast')) {
      return Icons.people_outline_rounded;
    }
    if (icon.contains('score') || icon.contains('rating')) {
      return Icons.star_outline_rounded;
    }
    if (icon.contains('year') || icon.contains('date')) {
      return Icons.calendar_today_outlined;
    }
    if (icon.contains('status')) return Icons.sensors_rounded;
    if (icon.contains('duration')) return Icons.timer_outlined;
    if (icon.contains('count')) return Icons.format_list_numbered_rounded;
    if (icon.contains('next') || icon.contains('airing')) {
      return Icons.schedule_rounded;
    }
    if (icon.contains('season')) return Icons.layers_outlined;
    if (icon.contains('banner') || icon.contains('image')) {
      return Icons.image_outlined;
    }
    if (icon.contains('title')) return Icons.title_rounded;
    if (icon.contains('description') || icon.contains('overview')) {
      return Icons.description_outlined;
    }
    if (icon.contains('genre')) return Icons.category_outlined;
    if (icon.contains('studio')) return Icons.business_outlined;
    if (icon.contains('format') || icon.contains('type')) {
      return Icons.movie_filter_outlined;
    }
    if (icon.contains('source')) return Icons.auto_stories_outlined;

    return Icons.tune_rounded;
  }

  String _toggleGroupSummary(PluginSettingDefinition definition) {
    final values = _toggleGroupValues(definition);
    final enabled = values.values.where((value) => value).length;
    final total = definition.options.length;

    if (Localizations.localeOf(context).languageCode == 'ar') {
      return '$enabled من $total مفعّلة';
    }
    return '$enabled of $total enabled';
  }

  Future<void> _showToggleGroupDialog(
    PluginSettingDefinition definition,
  ) async {
    if (_saving || definition.options.isEmpty) return;

    final values = _toggleGroupValues(definition);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              surfaceTintColor: Colors.transparent,
              title: Text(definition.title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: definition.options
                      .map((option) {
                        final description = option.description?.trim();

                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(_toggleGroupOptionIcon(option)),
                          title: Text(option.label),
                          subtitle: description == null || description.isEmpty
                              ? null
                              : Text(description),
                          value: values[option.value] ?? option.defaultBool,
                          onChanged: (enabled) {
                            values[option.value] = enabled;
                            setDialogState(() {});

                            if (!mounted) return;
                            setState(() {
                              _values[definition.key] = jsonEncode(values);
                            });
                          },
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(dialogContext)!.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _normalizedUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
      value = 'https://$value';
    }

    value = value.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Enter a valid HTTP or HTTPS URL');
    }

    return uri.origin;
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);

    try {
      final storage = ref.read(extensionRepositoryProvider);
      final settingsRepository = ref.read(settingsRepositoryProvider);
      final manager = ref.read(extensionManagerProvider.notifier);
      var shouldReload = false;
      final hasScriptBaseUrl = _definitions.any(
        (definition) => definition.isBaseUrl,
      );

      for (final definition in _definitions) {
        var value =
            _controllers[definition.key]?.text ??
            _values[definition.key] ??
            definition.defaultValue;

        if (definition.type == PluginSettingType.url) {
          value = _normalizedUrl(value);
        } else if (definition.type == PluginSettingType.toggleGroup) {
          value = _normalizedToggleGroupValue(definition, value);
        }

        if (definition.isBaseUrl) {
          await settingsRepository.setCustomBaseUrl(
            widget.plugin.packageName,
            value.isEmpty ? null : value,
          );
          shouldReload = true;
        } else {
          await storage.setExtensionData(
            '${widget.plugin.packageName}:${definition.key}',
            value,
          );
          shouldReload = shouldReload || definition.reloadOnChange;
        }

        _values[definition.key] = value;
      }

      if (!hasScriptBaseUrl && (widget.plugin.domains?.isNotEmpty ?? false)) {
        await settingsRepository.setCustomBaseUrl(
          widget.plugin.packageName,
          _selectedDomain.isEmpty ? null : _selectedDomain,
        );
        shouldReload = true;
      }

      for (final provider in _providers) {
        await storage.setExtensionData(
          '${widget.plugin.packageName}:'
          '_provider_enabled_${provider.id}',
          (_providerEnabled[provider.id] ?? true) ? 'true' : 'false',
        );
        shouldReload = true;
      }

      if (shouldReload) {
        await manager.reloadPlugin(widget.plugin);
      }

      if (!mounted) return;
      ref
          .read(notificationServiceProvider)
          .showExtension(
            'Extension settings saved',
            title: widget.plugin.name,
            icon: Icons.extension_rounded,
          );
    } catch (error) {
      if (!mounted) return;
      ref
          .read(notificationServiceProvider)
          .showError(
            'Failed to save settings: $error',
            title: widget.plugin.name,
            icon: Icons.extension_rounded,
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  IconData _iconForSetting(PluginSettingDefinition definition) {
    switch (definition.type) {
      case PluginSettingType.toggle:
        return Icons.toggle_on_rounded;
      case PluginSettingType.toggleGroup:
        return Icons.tune_rounded;
      case PluginSettingType.select:
        return Icons.dns_rounded;
      case PluginSettingType.text:
        return Icons.text_fields_rounded;
      case PluginSettingType.url:
        return Icons.link_rounded;
    }
  }

  String _selectedOptionLabel(PluginSettingDefinition definition) {
    final value = _values[definition.key] ?? definition.defaultValue;
    for (final option in definition.options) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  String? _settingSubtitle(PluginSettingDefinition definition) {
    final description = definition.description?.trim();

    final value = switch (definition.type) {
      PluginSettingType.toggle =>
        _boolValue(definition.key) ? 'Enabled' : 'Disabled',
      PluginSettingType.toggleGroup => _toggleGroupSummary(definition),
      PluginSettingType.select => _selectedOptionLabel(definition),
      PluginSettingType.text || PluginSettingType.url =>
        _controllers[definition.key]?.text ??
            _values[definition.key] ??
            definition.defaultValue,
    };

    if (description != null && description.isNotEmpty && value.isNotEmpty) {
      return '$value\n$description';
    }
    if (value.isNotEmpty) return value;
    return description;
  }

  void _setToggleValue(String key, bool value) {
    if (_saving) return;
    setState(() => _values[key] = value ? 'true' : 'false');
  }

  Future<void> _showSelectDialog(PluginSettingDefinition definition) async {
    if (_saving || definition.options.isEmpty) return;

    final current = _values[definition.key] ?? definition.defaultValue;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Text(definition.title),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value == null || !mounted) return;
            setState(() => _values[definition.key] = value);
            Navigator.of(dialogContext).pop();
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: definition.options
                  .map(
                    (option) => ListTile(
                      title: Text(option.label),
                      leading: Radio<String>(value: option.value),
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _values[definition.key] = option.value;
                        });
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTextDialog(PluginSettingDefinition definition) async {
    if (_saving) return;

    final editor = TextEditingController(
      text:
          _controllers[definition.key]?.text ??
          _values[definition.key] ??
          definition.defaultValue,
    );

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: Text(definition.title),
        content: CustomTextField(
          controller: editor,
          autofocus: true,
          keyboardType: definition.type == PluginSettingType.url
              ? TextInputType.url
              : TextInputType.text,
          hintText: definition.type == PluginSettingType.url
              ? 'https://example.com'
              : null,
          decoration: InputDecoration(
            helperText: definition.description,
            alignLabelWithHint: true,
          ),
          onSubmitted: (submitted) {
            Navigator.of(dialogContext).pop(submitted);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(editor.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    editor.dispose();

    if (value == null || !mounted) return;
    setState(() {
      _values[definition.key] = value;
      _controllers[definition.key]?.text = value;
    });
  }

  Future<void> _showDomainDialog(List<PluginDomain> domains) async {
    if (_saving || domains.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Text('Website address'),
        content: RadioGroup<String>(
          groupValue: _selectedDomain,
          onChanged: (value) {
            if (value == null || !mounted) return;
            setState(() => _selectedDomain = value);
            Navigator.of(dialogContext).pop();
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: domains
                  .map(
                    (domain) => ListTile(
                      title: Text(domain.name),
                      subtitle: Text(domain.url),
                      leading: Radio<String>(value: domain.url),
                      onTap: () {
                        if (!mounted) return;
                        setState(() => _selectedDomain = domain.url);
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  String _selectedDomainLabel(List<PluginDomain> domains) {
    for (final domain in domains) {
      if (domain.url == _selectedDomain) {
        return '${domain.name}\n${domain.url}';
      }
    }
    return _selectedDomain;
  }

  Widget _buildSettingTile(
    PluginSettingDefinition definition, {
    required bool isLast,
  }) {
    switch (definition.type) {
      case PluginSettingType.toggle:
        final value = _boolValue(definition.key);
        return SettingsTile(
          icon: _iconForSetting(definition),
          title: definition.title,
          subtitle: definition.description,
          trailing: Switch(
            value: value,
            onChanged: _saving
                ? null
                : (next) => _setToggleValue(definition.key, next),
          ),
          onTap: _saving ? null : () => _setToggleValue(definition.key, !value),
          isLast: isLast,
        );

      case PluginSettingType.toggleGroup:
        return SettingsTile(
          icon: _iconForSetting(definition),
          title: definition.title,
          subtitle: _settingSubtitle(definition),
          onTap: _saving ? null : () => _showToggleGroupDialog(definition),
          isLast: isLast,
        );

      case PluginSettingType.select:
        return SettingsTile(
          icon: _iconForSetting(definition),
          title: definition.title,
          subtitle: _settingSubtitle(definition),
          onTap: _saving ? null : () => _showSelectDialog(definition),
          isLast: isLast,
        );

      case PluginSettingType.text:
      case PluginSettingType.url:
        return SettingsTile(
          icon: _iconForSetting(definition),
          title: definition.title,
          subtitle: _settingSubtitle(definition),
          onTap: _saving ? null : () => _showTextDialog(definition),
          isLast: isLast,
        );
    }
  }

  Widget _buildContent(List<PluginDomain> domains, bool hasScriptBaseUrl) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutConstants.contentMaxWidth,
        ),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: LayoutConstants.spacingLg),
            children: [
            const SizedBox(height: LayoutConstants.spacingXs),
            if (_definitions.isNotEmpty)
              SettingsGroup(
                title: 'Extension settings',
                children: List.generate(
                  _definitions.length,
                  (index) => _buildSettingTile(
                    _definitions[index],
                    isLast: index == _definitions.length - 1,
                  ),
                ),
              ),
            if (_definitions.isNotEmpty &&
                ((domains.isNotEmpty && !hasScriptBaseUrl) ||
                    _providers.isNotEmpty))
              const SizedBox(height: LayoutConstants.spacingLg),
            if (domains.isNotEmpty && !hasScriptBaseUrl)
              SettingsGroup(
                title: 'Website address',
                children: [
                  SettingsTile(
                    icon: Icons.language_rounded,
                    title: 'Selected website',
                    subtitle: _selectedDomainLabel(domains),
                    onTap: _saving ? null : () => _showDomainDialog(domains),
                    isLast: true,
                  ),
                ],
              ),
            if (domains.isNotEmpty &&
                !hasScriptBaseUrl &&
                _providers.isNotEmpty)
              const SizedBox(height: LayoutConstants.spacingLg),
            if (_providers.isNotEmpty)
              SettingsGroup(
                title: 'Providers',
                children: List.generate(_providers.length, (index) {
                  final provider = _providers[index];
                  final enabled = _providerEnabled[provider.id] ?? true;

                  return SettingsTile(
                    icon: Icons.extension_rounded,
                    title: provider.name,
                    subtitle: provider.id,
                    trailing: Switch(
                      value: enabled,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _providerEnabled[provider.id] = value;
                              });
                            },
                    ),
                    onTap: _saving
                        ? null
                        : () {
                            setState(() {
                              _providerEnabled[provider.id] = !enabled;
                            });
                          },
                    isLast: index == _providers.length - 1,
                  );
                }),
              ),
            const SizedBox(height: LayoutConstants.spacingLg),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LayoutConstants.spacingMd,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const AppLoadingIndicator(
                          constraints: BoxConstraints.tightFor(
                            width: 18,
                            height: 18,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save settings'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final domains = widget.plugin.domains ?? const <PluginDomain>[];
    final hasScriptBaseUrl = _definitions.any(
      (definition) => definition.isBaseUrl,
    );
    final hasContent =
        _definitions.isNotEmpty ||
        _providers.isNotEmpty ||
        (domains.isNotEmpty && !hasScriptBaseUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pluginSettings(widget.plugin.name)),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _loading || _saving ? null : _save,
            icon: _saving
                ? const AppLoadingIndicator(
                    constraints: BoxConstraints.tightFor(width: 20, height: 20),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : !hasContent
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This extension does not define configurable settings.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _buildContent(domains, hasScriptBaseUrl),
    );
  }
}
