/*
 * FLauncher
 * Copyright (C) 2026  Lemonade Launcher contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/content_shortcut_uri.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// What the results area of the page is showing. There is always exactly one of
/// these on screen: the user must never be left looking at a blank space
/// wondering whether the launcher did anything.
enum _ResolveStatus {
  /// Nothing has been submitted yet.
  prompt,

  /// What was typed is not a channel and not an address.
  invalidAddress,

  resolving,

  /// The system answered with the applications that declare a filter for it.
  targets,

  /// The system answered with *nothing*. Its own message, deliberately: see
  /// [_message] and `contentShortcutTargetsEmpty`.
  noTarget,
}

/// Where a shortcut is created and edited.
///
/// Used for both, because the fields are the same: a name, the channel or
/// address, and the application that will open it.
class ContentShortcutPanelPageArguments {
  /// The section the new shortcut goes into, or null to put it in a section of
  /// its own. Ignored when [shortcut] is given.
  final int? sectionId;

  /// The shortcut being edited, or null when creating one.
  final ContentShortcut? shortcut;

  const ContentShortcutPanelPageArguments({this.sectionId, this.shortcut});
}

class ContentShortcutPanelPage extends StatefulWidget {
  static const String routeName = "content_shortcut_panel";

  final ContentShortcutPanelPageArguments arguments;

  const ContentShortcutPanelPage({Key? key, required this.arguments}) : super(key: key);

  @override
  State<ContentShortcutPanelPage> createState() => _ContentShortcutPanelPageState();
}

class _ContentShortcutPanelPageState extends State<ContentShortcutPanelPage> {
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;

  /// Focus target for the first resolved application, so submitting the address
  /// lands the remote on something it can press. `autofocus` cannot do this job:
  /// it only fires while nothing in the scope holds focus, and here the address
  /// field still does — it is what was just submitted.
  final FocusNode _firstTargetFocusNode = FocusNode();

  _ResolveStatus _status = _ResolveStatus.prompt;
  List<Map<String, dynamic>> _targets = const [];

  /// The address as the launcher will store it, or null while there is nothing
  /// usable in the field.
  String? _uri;

  String? _targetPackage;
  String? _targetName;

  /// Discriminates the answer the user is still waiting for from the answer to a
  /// submission they have already replaced. Without it a slow first query can
  /// land after a fast second one and overwrite its results.
  int _resolveGeneration = 0;

  ContentShortcut? get _shortcut => widget.arguments.shortcut;

  bool get _creating => _shortcut == null;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: _shortcut?.label ?? "");
    _addressController = TextEditingController(text: _shortcut?.uri ?? "");
    _uri = _shortcut?.uri;
    _targetPackage = _shortcut?.targetPackage;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _firstTargetFocusNode.dispose();
    super.dispose();
  }

  /// Asks the system which installed applications declare a public intent filter
  /// for what was typed.
  ///
  /// Only ever called from the address field's submit handler. One query per
  /// keystroke would mean one platform-channel round trip for every letter of a
  /// name typed one D-pad press at a time.
  Future<void> _resolve(String rawAddress) async {
    final String? uri = normalizeContentShortcutUri(rawAddress);
    if (uri == null) {
      setState(() {
        _status = _ResolveStatus.invalidAddress;
        _targets = const [];
        // Nothing usable to save, so the save action goes away with it.
        _uri = null;
      });
      return;
    }

    // Naming the shortcut is one more thing to type with a remote, so the handle
    // is offered as a starting point — never overwriting a name already typed.
    if (_labelController.text.trim().isEmpty) {
      final String? suggestion = contentShortcutLabelSuggestion(rawAddress);
      if (suggestion != null) {
        _labelController.text = suggestion;
      }
    }

    // Read before the first await: the element may be gone by the time the
    // platform channel answers.
    final AppsService appsService = context.read<AppsService>();

    final int generation = ++_resolveGeneration;
    setState(() {
      _uri = uri;
      _status = _ResolveStatus.resolving;
      _targets = const [];
    });

    List<Map<String, dynamic>> targets;
    try {
      targets = await appsService.resolveContentShortcutTargets(uri);
    } catch (e) {
      // `resolveUriTargets` contracts to answer with an empty list rather than
      // throw. This stays as a backstop: the alternative to a message is a red
      // error screen inside the settings panel of the only home screen there is.
      debugPrint("ContentShortcutPanelPage: resolving the targets threw ($e)");
      targets = const [];
    }

    if (!mounted || generation != _resolveGeneration) {
      return;
    }
    setState(() {
      _targets = targets;
      _status = targets.isEmpty ? _ResolveStatus.noTarget : _ResolveStatus.targets;
    });
    if (targets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _firstTargetFocusNode.requestFocus();
        }
      });
    }
  }

  void _pickTarget(Map<String, dynamic> target) {
    final Object? packageName = target["packageName"];
    if (packageName is! String || packageName.isEmpty) {
      return;
    }
    final Object? name = target["name"];
    setState(() {
      _targetPackage = packageName;
      _targetName = name is String && name.isNotEmpty ? name : packageName;
    });
  }

  /// Whether there is enough to store: a name, an address, and an application to
  /// pin the intent to. The package is picked, never guessed (PRD 12.3, point 3),
  /// so no default is filled in here.
  bool get _canSave =>
      _labelController.text.trim().isNotEmpty &&
      (_uri?.isNotEmpty ?? false) &&
      (_targetPackage?.isNotEmpty ?? false);

  Future<void> _save() async {
    final String label = _labelController.text.trim();
    final String? uri = _uri;
    final String? targetPackage = _targetPackage;
    if (label.isEmpty || uri == null || targetPackage == null) {
      return;
    }

    final AppsService appsService = context.read<AppsService>();
    final NavigatorState navigator = Navigator.of(context);

    final int shortcutId;
    if (_creating) {
      shortcutId = await appsService.addContentShortcut(
        label: label,
        uri: uri,
        targetPackage: targetPackage,
        sectionId: widget.arguments.sectionId,
      );
    } else {
      shortcutId = _shortcut!.id;
      await appsService.updateContentShortcut(
        _shortcut!,
        label: label,
        uri: uri,
        targetPackage: targetPackage,
      );
    }

    if (!mounted) {
      return;
    }
    navigator.pop(shortcutId);
  }

  /// Deletes this shortcut, and with it its section when it was the last one:
  /// a shortcut section owns no row of its own, it *is* its shortcuts.
  Future<void> _delete() async {
    final ContentShortcut? shortcut = _shortcut;
    if (shortcut == null) {
      return;
    }
    final AppsService appsService = context.read<AppsService>();
    final NavigatorState navigator = Navigator.of(context);

    await appsService.deleteContentShortcut(shortcut);

    if (!mounted) {
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(
          _creating ? localizations.contentShortcutNew : localizations.contentShortcutModify,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const Divider(),
        Expanded(
          // A Column inside a scroll view rather than a ListView: every resolved
          // application has to exist in the tree for the focus request in
          // [_resolve] to reach the first one, and a lazy list would only have
          // built the handful that happen to be on screen.
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _labelController,
                    autofocus: _creating,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: localizations.name,
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _addressController,
                    // The query waits for an explicit submit. Never one per
                    // keystroke: there is no `onChanged` here on purpose.
                    onSubmitted: _resolve,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: localizations.contentShortcutAddress,
                      prefixIcon: const Icon(Icons.link),
                    ),
                  ),
                ),
                _currentTarget(context, localizations),
                ..._resolveArea(context, localizations),
                const Divider(),
                if (_canSave)
                  FocusableSettingsTile(
                    leading: const Icon(Icons.save_outlined),
                    title: Text(localizations.save, style: Theme.of(context).textTheme.bodyMedium),
                    onPressed: _save,
                  ),
                if (!_creating)
                  FocusableSettingsTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(localizations.delete, style: Theme.of(context).textTheme.bodyMedium),
                    onPressed: _delete,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _currentTarget(BuildContext context, AppLocalizations localizations) {
    final String? packageName = _targetPackage;
    final String label = packageName == null || packageName.isEmpty
        ? localizations.contentShortcutNoTarget
        : localizations.contentShortcutTarget(_targetName ?? packageName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  List<Widget> _resolveArea(BuildContext context, AppLocalizations localizations) {
    switch (_status) {
      case _ResolveStatus.prompt:
        return [_message(context, localizations.contentShortcutAddressPrompt)];
      case _ResolveStatus.invalidAddress:
        return [_message(context, localizations.contentShortcutAddressInvalid)];
      case _ResolveStatus.resolving:
        // A text line, not a spinner: an indeterminate progress animation never
        // stops scheduling frames, which would hang every `pumpAndSettle` that
        // ever renders this page.
        return [_message(context, localizations.contentShortcutResolving)];
      case _ResolveStatus.noTarget:
        // Its own message, and the highest-risk failure of the whole feature: on
        // Android 11 and later a missing package-visibility declaration comes
        // back as an empty list, indistinguishable from "nothing is installed".
        // Telling the user their address is wrong would send them editing a
        // perfectly good address forever.
        return [_message(context, localizations.contentShortcutTargetsEmpty)];
      case _ResolveStatus.targets:
        return [
          _message(context, localizations.contentShortcutChooseTarget),
          for (int i = 0; i < _targets.length; i++)
            FocusableSettingsTile(
              key: ValueKey("content_shortcut_target_${_targets[i]["packageName"]}"),
              focusNode: i == 0 ? _firstTargetFocusNode : null,
              leading: const Icon(Icons.apps),
              title: Text(_targetLabel(_targets[i]), style: Theme.of(context).textTheme.bodyMedium),
              onPressed: () => _pickTarget(_targets[i]),
            ),
        ];
    }
  }

  String _targetLabel(Map<String, dynamic> target) {
    final Object? name = target["name"];
    if (name is String && name.isNotEmpty) {
      return name;
    }
    final Object? packageName = target["packageName"];
    return packageName is String ? packageName : "";
  }

  Widget _message(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}
