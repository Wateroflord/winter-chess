"""Настраивает Android-проект: разрешения и название."""
import pathlib, re
ROOT = pathlib.Path("android/app")
m = ROOT / "src/main/AndroidManifest.xml"
t = m.read_text(encoding="utf-8")
for p in ["android.permission.INTERNET"]:
    if p not in t:
        t = re.sub(r"(<manifest[^>]*>)", rf'\1\n    <uses-permission android:name="{p}"/>', t, count=1)
t = re.sub(r'android:label="[^"]*"', 'android:label="Шахматы"', t, count=1)

if "extractNativeLibs" not in t:
    t = t.replace("<application", '<application android:extractNativeLibs="true"', 1)
# Канал, чтобы узнать папку с движком Stockfish.
kt = ROOT / "src/main/kotlin/com/winterhub/winter_chess"
kt.mkdir(parents=True, exist_ok=True)
for old in ROOT.glob("src/main/kotlin/**/MainActivity.kt"):
    old.unlink()
(kt / "MainActivity.kt").write_text("""package com.winterhub.winter_chess

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "winterchess/engine").setMethodCallHandler { call, result ->
            if (call.method == "libDir") result.success(applicationInfo.nativeLibraryDir) else result.notImplemented()
        }
    }
}
""", encoding="utf-8")
g = ROOT / "build.gradle.kts"
gs = g.read_text(encoding="utf-8")
if "useLegacyPackaging" not in gs:
    gs = gs.replace("android {", "android {\n    packaging {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }", 1)
g.write_text(gs, encoding="utf-8")

m.write_text(t, encoding="utf-8")
print("patched")
