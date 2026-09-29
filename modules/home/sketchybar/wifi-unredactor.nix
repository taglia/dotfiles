# Private SketchyBar dependency, not a global package or Homebrew installation.
# Upstream has no release tags; pin both revision and content hash.
{
  lib,
  stdenv,
  fetchFromGitHub,
  swift,
  swiftpm,
}:
stdenv.mkDerivation {
  pname = "sketchybar-wifi-unredactor";
  version = "0-unstable-c4acc3e";

  src = fetchFromGitHub {
    owner = "noperator";
    repo = "wifi-unredactor";
    rev = "c4acc3e1f8093c6a365195f1240546b342aa0f56";
    hash = "sha256-mPYI60m7PACQ6xItvTshDJBwfVTtm4N/UeIvEthgci8=";
  };

  nativeBuildInputs = [
    swift
    swiftpm
  ];

  # Routine probes must never request permission or leave an app running.
  # An explicit GUI launch retains upstream's permission-request behavior.
  postPatch = ''
    substituteInPlace wifi-unredactor.app/Contents/MacOS/wifi-unredactor.swift \
      --replace-fail 'locationManager?.requestAlwaysAuthorization()' '
        if CommandLine.arguments.contains("--status") {
            self.locationManager(locationManager!, didChangeAuthorization: locationManager!.authorizationStatus)
        } else {
            locationManager?.requestAlwaysAuthorization()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (CommandLine.arguments.contains("--status") ? 10 : 60)) {
            print("{\"error\":\"location services timed out\"}")
            NSApp.terminate(nil)
        }' \
      --replace-fail 'if status == .authorizedAlways || status == .authorized {' '
        if status == .notDetermined && !CommandLine.arguments.contains("--status") {
            return
        }
        if status == .authorizedAlways || status == .authorized {'
  '';

  buildPhase = ''
    runHook preBuild
    swiftc -O wifi-unredactor.app/Contents/MacOS/wifi-unredactor.swift \
      -o wifi-unredactor.app/Contents/MacOS/wifi-unredactor
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    rm wifi-unredactor.app/Contents/MacOS/wifi-unredactor.swift
    cp -R wifi-unredactor.app "$out/Applications/"
    runHook postInstall
  '';

  # Bind the Info.plist/bundle identity as well as signing the Mach-O executable.
  # Ad-hoc signing is not a Developer ID certificate or a persistence guarantee.
  postFixup = ''
    /usr/bin/codesign --force --sign - "$out/Applications/wifi-unredactor.app"
  '';

  meta = {
    description = "One-shot Location Services-authorized SSID reader for SketchyBar";
    homepage = "https://github.com/noperator/wifi-unredactor";
    platforms = lib.platforms.darwin;
  };
}
