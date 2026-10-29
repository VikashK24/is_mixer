import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Spoken alerts through the browser's built-in text-to-speech
/// (Web Speech API). No audio files or extra packages are needed.
///
/// Browsers only allow speech after the user has interacted with the page, and
/// iOS Safari wants the very first utterance to start inside a tap. That is
/// why [primeOnFirstTap] quietly "unlocks" speech on the first tap, and why the
/// dashboard also shows an explicit "Enable sound alerts" button.
class SoundAlertService {
  static bool _enabled = false;
  static bool _primed = false;
  static StreamSubscription<web.Event>? _tapSub;

  /// True once the player pressed "Enable sound alerts" on this page load.
  static bool get isEnabled => _enabled;

  /// Silently unlocks speech on the first tap anywhere on the page.
  static void primeOnFirstTap() {
    if (_primed || _tapSub != null) return;
    _tapSub = const web.EventStreamProvider<web.Event>('pointerup')
        .forTarget(web.document)
        .listen((_) {
      _prime();
      _tapSub?.cancel();
      _tapSub = null;
    });
  }

  static void _prime() {
    if (_primed) return;
    _primed = true;
    try {
      final utterance = web.SpeechSynthesisUtterance(' ');
      utterance.volume = 0; // inaudible, only unlocks the speech engine
      web.window.speechSynthesis.speak(utterance);
    } catch (e) {
      debugPrint('Speech prime failed: $e');
    }
  }

  /// Called from the "Enable sound alerts" button (a real tap).
  static void enable() {
    _enabled = true;
    _prime();
    _speak('Sound alerts are on.');
  }

  /// Short check so players can set their volume.
  static void test(String username) {
    _speak('$username eliminated! This is only a test.');
  }

  /// The real alert, played on the eliminated player's own device.
  /// Said twice so it carries across a noisy room.
  static void announceElimination(String username) {
    _speak('$username eliminated!', repeat: 2);
  }

  static void _speak(String text, {int repeat = 1}) {
    try {
      final synth = web.window.speechSynthesis;
      synth.cancel(); // drop anything still queued
      for (var i = 0; i < repeat; i++) {
        final utterance = web.SpeechSynthesisUtterance(text);
        utterance.volume = 1.0; // maximum; device volume still applies
        utterance.rate = 0.9;
        utterance.pitch = 1.0;
        utterance.lang = 'en-US';
        synth.speak(utterance);
      }
    } catch (e) {
      debugPrint('Speech failed: $e');
    }
  }
}