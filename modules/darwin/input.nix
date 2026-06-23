{
  system.defaults.NSGlobalDomain = {
    # Enable tap-to-click and force click while keeping pointer/repeat speed alone.
    "com.apple.mouse.tapBehavior" = 1;
    "com.apple.trackpad.enableSecondaryClick" = true;
    "com.apple.trackpad.forceClick" = true;
    "com.apple.keyboard.fnState" = true;

    "com.apple.trackpad.trackpadCornerClickBehavior" = null;

    # Prevent macOS from changing the characters or words typed into native text fields.
    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
    NSAutomaticInlinePredictionEnabled = false;
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;
  };

  # Extra text-input defaults not exposed as typed nix-darwin options.
  # These cover grammar, saved text replacements, and WebKit-backed text fields.
  system.defaults.CustomUserPreferences = {
    NSGlobalDomain = {
      NSAutomaticGrammarCheckingEnabled = false;
      NSAutomaticTextCompletionEnabled = false;
      NSAutomaticTextReplacementEnabled = false;
      WebAutomaticDashSubstitutionEnabled = false;
      WebAutomaticQuoteSubstitutionEnabled = false;
      WebAutomaticSpellingCorrectionEnabled = false;
      WebAutomaticTextReplacementEnabled = false;
      WebContinuousSpellCheckingEnabled = false;
    };
  };

  # Trackpad gestures and click behavior. Key repeat settings are intentionally unmanaged.
  system.defaults.trackpad = {
    Clicking = true;
    DragLock = true;
    Dragging = true;
    ForceSuppressed = false;
    TrackpadFourFingerHorizSwipeGesture = 2;
    TrackpadPinch = true;
    TrackpadRightClick = true;
    TrackpadRotate = true;
    TrackpadThreeFingerDrag = true;
    TrackpadThreeFingerHorizSwipeGesture = 0;
    TrackpadThreeFingerVertSwipeGesture = 0;
    TrackpadThreeFingerTapGesture = 0;
    TrackpadTwoFingerDoubleTapGesture = true;
    TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
  };

  # Hardware key mapping only; repeat rate and press-and-hold behavior stay unchanged.
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;
}
