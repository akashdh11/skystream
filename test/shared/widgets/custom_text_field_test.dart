/// [CustomTextField] as a remote meets it: the field in every settings dialog
/// - a subtitle provider's key, a login, a DNS address - on a television,
/// which has no screen to tap.
///
/// Both halves of the rule are pinned: with the keyboard up the arrows are
/// the keyboard's, and with it put away they are the only way out of the
/// field, which used to be a dead end in front of the dialog's Save.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/shared/widgets/custom_widgets.dart';

void main() {
  /// A dialog's shape: a field with a button above it and one below.
  Future<void> pumpField(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextButton(onPressed: () {}, child: const Text('above')),
              const CustomTextField(hintText: 'API key', autofocus: true),
              TextButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool inField() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>() !=
      null;

  String? focusedButton() {
    final context = FocusManager.instance.primaryFocus?.context;
    final button = context?.findAncestorWidgetOfExactType<TextButton>();
    return (button?.child as Text?)?.data;
  }

  testWidgets('Next stops on the following field', (tester) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final third = TextEditingController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(third.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              CustomTextField(
                controller: first,
                autofocus: true,
                textInputAction: TextInputAction.next,
                hintText: 'server',
              ),
              CustomTextField(
                controller: second,
                textInputAction: TextInputAction.next,
                hintText: 'username',
              ),
              CustomTextField(controller: third, hintText: 'password'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final focused = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<TextField>();
    expect(focused?.decoration?.hintText, 'username');
  });

  testWidgets('with the keyboard put away, down and up leave the field', (
    tester,
  ) async {
    await pumpField(tester);
    expect(inField(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focusedButton(), 'Save', reason: 'the way to the dialog\'s Save');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(inField(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focusedButton(), 'above');
  });

  testWidgets('with the keyboard up the arrows are the keyboard\'s', (
    tester,
  ) async {
    // Android TV's keyboard walks its letter grid with all four. Taking them
    // moved focus out of the field and closed the keyboard mid-word.
    await pumpField(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(inField(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(inField(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an iPad\'s shortcuts bar leaves the arrows their way out', (
    tester,
  ) async {
    // Flutter reports the bar an iPad shows over a hardware keyboard as a
    // docked keyboard. Only Android's keyboards use the arrows.
    await pumpField(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 69);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focusedButton(), 'Save');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Select brings the keyboard back once it is put away', (
    tester,
  ) async {
    // Back on a remote puts the keyboard away and leaves focus in the
    // field; OK is the only way back into typing, and did nothing.
    await pumpField(tester);
    tester.testTextInput.hide();
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(inField(), isTrue);
  });

  testWidgets('controller A reopens a dismissed TV keyboard', (tester) async {
    // Flutter maps a remote's OK (DPAD_CENTER) to Select; some remotes send
    // BUTTON_A instead, which arrives as gameButtonA.
    await pumpField(tester);
    tester.testTextInput.hide();
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(inField(), isTrue);
  });

  // A repository's address or code is not a word: autocorrect turned
  // "universe" into "Universe", and codes are case-sensitive. Suggestions
  // stay on: with them off, Flutter's Android engine asks for a visible
  // password field instead, whose keyboard - on a phone or a television -
  // has no "/" or ".com".
  testWidgets('an address field is not corrected, and keeps the URL keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CustomTextField(keyboardType: TextInputType.url)),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.url);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isTrue);
  });

  testWidgets('a text field is still corrected and completed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CustomTextField())),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isTrue);
    expect(field.enableSuggestions, isTrue);
  });
}
