#!/usr/bin/env bash
# Recreates the build environment in a fresh cloud container (GitHub release downloads only;
# dl.google.com is blocked here, so the Android SDK is assembled from uber-apk-signer's bundled apksigner/zipalign).
set -euo pipefail
GV=4.6-stable
mkdir -p /opt/godot && cd /opt/godot
[ -x Godot_v${GV}_linux.x86_64 ] || { curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/$GV/Godot_v${GV}_linux.x86_64.zip && unzip -oq g.zip && rm g.zip; }
ln -sf /opt/godot/Godot_v${GV}_linux.x86_64 /usr/local/bin/godot
T=~/.local/share/godot/export_templates/4.6.stable
[ -f $T/android_debug.apk ] || { curl -sSL -o t.tpz https://github.com/godotengine/godot/releases/download/$GV/Godot_v${GV}_export_templates.tpz && mkdir -p ~/.local/share/godot/export_templates && cd ~/.local/share/godot/export_templates && unzip -oq /opt/godot/t.tpz && mv templates 4.6.stable && rm /opt/godot/t.tpz; }
S=/opt/android-sdk; B=$S/build-tools/35.0.0
if [ ! -x $B/apksigner ]; then
  mkdir -p /opt/apktools $B/lib $B/lib64 $S/platform-tools && cd /opt/apktools
  curl -sSL -o uber.jar https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar
  unzip -oqj uber.jar lib/apksigner_33_0_2.jar -d $B/lib && mv $B/lib/apksigner_33_0_2.jar $B/lib/apksigner.jar
  unzip -oqj uber.jar 'binary-lib/linux-lib64-33_0_2/*' -d $B/lib64
  unzip -oqj uber.jar linux-zipalign-33_0_2 -d $B && mv $B/linux-zipalign-33_0_2 $B/zipalign
  printf '#!/bin/sh\nexec java -jar "$(dirname "$0")/lib/apksigner.jar" "$@"\n' > $B/apksigner
  printf '#!/bin/sh\necho "Android Debug Bridge version 1.0.41"\n' > $S/platform-tools/adb
  chmod +x $B/apksigner $B/zipalign $S/platform-tools/adb
fi
# Editor settings: generate once, then point at the SDK (Godot creates its own debug keystore).
E=~/.config/godot/editor_settings-4.6.tres
[ -f $E ] || (cd "$(dirname "$0")/.." && timeout 120 godot --headless --editor --quit --path . >/dev/null 2>&1 || true)
sed -i 's#^export/android/android_sdk_path = .*#export/android/android_sdk_path = "/opt/android-sdk"#' $E
grep -q debug_keystore_user $E || sed -i 's#^export/android/debug_keystore_pass = .*#&\nexport/android/debug_keystore_user = "androiddebugkey"#' $E
echo "env ready"
