import os
import zipfile
import shutil

def create_review_bundle():
    root = os.path.dirname(os.path.abspath(__file__))
    zip_name = "kalkan_logic_ui_brains_review.zip"
    zip_path = os.path.join(root, zip_name)
    desktop_path = os.path.expanduser(r"~\Desktop\kalkan_logic_ui_brains_review.zip")
    artifact_dir = r"C:\Users\KPK\.gemini\antigravity\brain\16482f10-ac02-4fe0-90f1-c7b0d41ee2ca"

    included_root_files = {
        'pubspec.yaml',
        'pubspec.lock',
        'analysis_options.yaml',
        'firestore.rules',
        'README.md',
        'README_FOR_REVIEWER.md',
        'ARCHITECTURE_REVIEW.md',
    }

    included_native_files = {
        os.path.normpath('android/app/build.gradle'),
        os.path.normpath('android/app/src/main/AndroidManifest.xml'),
        os.path.normpath('android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/MainActivity.kt'),
        os.path.normpath('android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanBleService.kt'),
        os.path.normpath('android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanNotify.kt'),
        os.path.normpath('android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanAlarmReceiver.kt'),
        os.path.normpath('android/app/src/main/kotlin/com/yc/nadalsdk/barys_biotracker/KalkanHomeWidgetProvider.kt'),
        os.path.normpath('ios/Podfile'),
        os.path.normpath('ios/Runner/Info.plist'),
        os.path.normpath('ios/Runner/AppDelegate.swift'),
        os.path.normpath('ios/Runner/SceneDelegate.swift'),
        os.path.normpath('.github/workflows/build_ios.yml'),
    }

    def should_include(rel_path):
        norm = os.path.normpath(rel_path)
        parts = norm.split(os.sep)

        # 1. Whole lib/ folder (UI, Logic, Brains, Core)
        if parts[0] == 'lib' and norm.endswith('.dart'):
            return True

        # 2. Whole test/ folder (Unit, integration, and UI tests)
        if parts[0] == 'test' and norm.endswith('.dart'):
            return True

        # 3. Whole docs/ folder (.md and .svg)
        if parts[0] == 'docs' and (norm.endswith('.md') or norm.endswith('.svg')):
            return True

        # 4. Root documentation and configuration
        if len(parts) == 1 and parts[0] in included_root_files:
            return True

        # 5. Key native platform bridge files
        if norm in included_native_files:
            return True

        return False

    file_count = 0
    total_bytes = 0

    print(f"Packing review bundle: {zip_path} ...")
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for foldername, subfolders, filenames in os.walk(root):
            # Prune excluded directories immediately to speed up traversal
            subfolders[:] = [
                d for d in subfolders
                if d not in {
                    'build', '.dart_tool', '.git', '.gradle', '.idea',
                    'Pods', '.symlinks', '.flutter-plugins-dependencies',
                    'assets'
                } and not d.startswith('.tmp')
            ]

            for filename in filenames:
                full_path = os.path.join(foldername, filename)
                rel_path = os.path.relpath(full_path, root)

                if should_include(rel_path):
                    # Store with forward slashes for clean cross-platform unzipping
                    arcname = rel_path.replace(os.sep, '/')
                    zf.write(full_path, arcname)
                    file_count += 1
                    total_bytes += os.path.getsize(full_path)

    compressed_size = os.path.getsize(zip_path)
    print(f"Created {zip_name}:")
    print(f"  - Total files: {file_count}")
    print(f"  - Uncompressed: {total_bytes:,} bytes")
    print(f"  - Compressed:   {compressed_size:,} bytes ({compressed_size / 1024:.1f} KB)")

    # Copy to Desktop
    try:
        shutil.copy2(zip_path, desktop_path)
        print(f"Copied to Desktop: {desktop_path}")
    except Exception as e:
        print(f"Desktop copy notice: {e}")

    # Copy to Artifact directory
    if os.path.isdir(artifact_dir):
        try:
            art_review = os.path.join(artifact_dir, zip_name)
            art_sport = os.path.join(artifact_dir, "kalkan_sport_review.zip")
            shutil.copy2(zip_path, art_review)
            shutil.copy2(zip_path, art_sport)
            print(f"Copied to Artifact dir: {art_review}")
        except Exception as e:
            print(f"Artifact copy notice: {e}")

if __name__ == "__main__":
    create_review_bundle()
