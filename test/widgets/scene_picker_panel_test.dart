import 'package:flauncher/actions.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/scene.dart';
import 'package:flauncher/providers/scenes_service.dart';
import 'package:flauncher/widgets/scene_picker_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

// ScenePickerPanel is exercised through `showDialog`, pushed on top of a plain host
// screen, rather than pumped directly as `home:`. This matters for the Back test:
// `SidePanelDialog`'s local `BackAction` calls `navigator.maybePop()`, which is a
// no-op when there is nothing beneath the current route (`canPop()` would be
// false). Pushing the panel as a real dialog route gives it something to pop back
// to, matching how it is opened in the real app.
void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = Size(1280, 720);
    binding.window.devicePixelRatioTestValue = 1.0;
    binding.platformDispatcher.textScaleFactorTestValue = 0.8;
  });

  testWidgets("Opens and lists every scene", (tester) async {
    final scenesService = _mkScenesService(activeSceneKey: SceneKeys.normal);
    await _openPicker(tester, scenesService);

    expect(find.byType(ScenePickerPanel), findsOneWidget);
    expect(find.text("Normal"), findsOneWidget);
    expect(find.text("Cinema"), findsOneWidget);
    expect(find.text("Night"), findsOneWidget);
    expect(find.text("Kids"), findsOneWidget);
  });

  testWidgets("Marks the active scene and autofocuses it", (tester) async {
    final scenesService = _mkScenesService(activeSceneKey: SceneKeys.night);
    await _openPicker(tester, scenesService);

    // Marked independently of focus: a checkmark icon, not just the focus outline.
    // Exactly one scene is active, so exactly one checkmark should be present.
    expect(find.byIcon(Icons.check), findsOneWidget);

    expect(_isFocused(tester.element(find.text("Night"))), isTrue, reason: "active scene should be autofocused");
    expect(_isFocused(tester.element(find.text("Normal"))), isFalse);
  });

  testWidgets("Selecting a different scene calls activateScene with its key and closes the picker", (tester) async {
    final scenesService = _mkScenesService(activeSceneKey: SceneKeys.normal);
    when(scenesService.activateScene(SceneKeys.cinema))
        .thenAnswer((_) => Future.value(SceneActivationResult.activated));
    await _openPicker(tester, scenesService);

    await tester.tap(find.text("Cinema"));
    await tester.pumpAndSettle();

    verify(scenesService.activateScene(SceneKeys.cinema));
    expect(find.byType(ScenePickerPanel), findsNothing);
  });

  testWidgets("Selecting the already-active scene closes without changing anything", (tester) async {
    final scenesService = _mkScenesService(activeSceneKey: SceneKeys.normal);
    when(scenesService.activateScene(SceneKeys.normal))
        .thenAnswer((_) => Future.value(SceneActivationResult.alreadyActive));
    await _openPicker(tester, scenesService);

    await tester.tap(find.text("Normal"));
    await tester.pumpAndSettle();

    verify(scenesService.activateScene(SceneKeys.normal));
    expect(find.byType(ScenePickerPanel), findsNothing);
  });

  testWidgets("Does not close and reports the error when persisting the new scene fails", (tester) async {
    final scenesService = _mkScenesService(activeSceneKey: SceneKeys.normal);
    when(scenesService.activateScene(SceneKeys.cinema))
        .thenAnswer((_) => Future.value(SceneActivationResult.persistenceFailed));
    await _openPicker(tester, scenesService);

    await tester.tap(find.text("Cinema"));
    await tester.pumpAndSettle();

    verify(scenesService.activateScene(SceneKeys.cinema));
    expect(find.byType(ScenePickerPanel), findsOneWidget, reason: "a failed write must not pretend it worked");
    expect(find.text("Could not switch scenes."), findsOneWidget);
  });

  testWidgets("Back closes without activating any scene", (tester) async {
    final scenesService = _mkScenesService(activeSceneKey: SceneKeys.normal);
    await _openPicker(tester, scenesService);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(ScenePickerPanel), findsNothing);
    verifyNever(scenesService.activateScene(any));
  });
}

MockScenesService _mkScenesService({required String activeSceneKey}) {
  final scenesService = MockScenesService();
  when(scenesService.scenes).thenReturn(Scene.defaults());
  when(scenesService.activeSceneKey).thenReturn(activeSceneKey);
  return scenesService;
}

/// Pumps a minimal host screen and opens [ScenePickerPanel] the same way the
/// real app does: via `showDialog`, pushed on top of an existing route.
Future<void> _openPicker(WidgetTester tester, ScenesService scenesService) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ScenesService>.value(
      value: scenesService,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Mirrors flauncher_app.dart's remote-control shortcut: Escape maps to
        // BackIntent, which SidePanelDialog handles locally.
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(context: context, builder: (_) => const ScenePickerPanel()),
                child: const Text("open"),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text("open"));
  await tester.pumpAndSettle();
}

/// Whether the currently focused widget visually overlaps [element]'s render box.
/// See the identically-named helper in `test/flauncher_test.dart` for why geometry
/// is used instead of `Focus.of()`.
bool _isFocused(Element element) {
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox || !renderObject.attached) return false;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  final focusRect = WidgetsBinding.instance.focusManager.primaryFocus?.rect;
  return focusRect != null && rect.overlaps(focusRect);
}
