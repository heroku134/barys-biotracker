import os
import zipfile
import shutil

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    
    desktop_complete = os.path.expanduser(r"~\Desktop\kalkan_sport_complete_source.zip")
    desktop_source = os.path.expanduser(r"~\Desktop\kalkan_sport_source.zip")
    artifact_zip = r"C:\Users\KPK\.gemini\antigravity\brain\16482f10-ac02-4fe0-90f1-c7b0d41ee2ca\kalkan_sport_complete_source.zip"
    
    exclude_dir_names = {
        '.git', '.gradle', 'build', '.dart_tool', '.kotlin', 'ephemeral', '.symlinks'
    }
    
    exclude_file_exts = {
        '.zip', '.apk', '.ipa', '.tmp'
    }
    
    print(f"Scanning and packaging from {root_dir}...")
    
    # We will write to a temp file first, then copy to targets
    temp_zip = os.path.join(root_dir, "_temp_complete_archive.zip")
    if os.path.exists(temp_zip):
        os.remove(temp_zip)
        
    count = 0
    with zipfile.ZipFile(temp_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for root, dirs, files in os.walk(root_dir):
            # Prune excluded directories in-place
            dirs[:] = [d for d in dirs if d not in exclude_dir_names]
            
            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in exclude_file_exts or file.startswith('_temp_'):
                    continue
                
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, root_dir).replace('\\', '/')
                zf.write(full_path, rel_path)
                count += 1
                
    zip_size = os.path.getsize(temp_zip)
    print(f"Archive successfully generated with {count} files, size: {zip_size:,} bytes ({zip_size / (1024*1024):.2f} MB)")
    
    # Copy to destinations
    shutil.copy2(temp_zip, desktop_complete)
    print(f"Copied -> {desktop_complete}")
    
    shutil.copy2(temp_zip, desktop_source)
    print(f"Copied -> {desktop_source}")
    
    shutil.copy2(temp_zip, artifact_zip)
    print(f"Copied -> {artifact_zip}")
    
    if os.path.exists(temp_zip):
        os.remove(temp_zip)
        
    # Verify critical files inside the archive
    print("\nVerifying contents of the created archive:")
    with zipfile.ZipFile(desktop_complete, 'r') as zf:
        names = set(zf.namelist())
        
        must_have = [
            "android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanBleService.kt",
            "android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanNotify.kt",
            "android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanAlarmReceiver.kt",
            "android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanHomeWidgetProvider.kt",
            "android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/MainActivity.kt",
            "android/app/src/main/AndroidManifest.xml",
            "android/build.gradle.kts",
            "android/app/build.gradle.kts",
            "ios/Runner/AppDelegate.swift",
            "ios/Runner/Info.plist",
            "ios/Podfile",
            "pubspec.yaml",
            "pubspec.lock",
            "analysis_options.yaml",
            "firestore.rules",
            ".github/workflows/build_ios.yml",
            "lib/main.dart",
            "lib/domain/intelligence/readiness_engine.dart",
            "lib/domain/models/readiness.dart",
            "lib/domain/models/telemetry.dart",
            "assets/fonts/Manrope-Bold.ttf",
            "assets/images/mascot_charged.jpg",
        ]
        
        all_present = True
        for mh in must_have:
            if mh in names:
                print(f" [OK] {mh}")
            else:
                print(f" [MISSING] {mh}")
                all_present = False
                
        print(f"\nTotal files in archive: {len(names)}")
        print(f"All required key files present: {all_present}")

if __name__ == "__main__":
    main()
