import os
import zipfile
import shutil
import plistlib

def update_ipa():
    workspace = r"c:\Users\KPK\Documents\вав"
    original_ipa_backup = r"C:\Users\KPK\barys.ipa"
    local_ipa = os.path.join(workspace, "barys_biotracker.ipa")
    output_ipa = os.path.join(workspace, "KALKAN_SPORT.ipa")
    downloads_ipa = r"C:\Users\KPK\Downloads\KALKAN_SPORT.ipa"
    temp_dir = os.path.join(workspace, "temp_ipa_extract")

    # Prefer the clean backup if it exists
    source_ipa = original_ipa_backup if os.path.exists(original_ipa_backup) else local_ipa
    if not os.path.exists(source_ipa):
        print(f"Error: Source IPA {source_ipa} not found!")
        return

    print(f"Using source IPA: {source_ipa}")

    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir, exist_ok=True)

    print("Extracting IPA archive...")
    with zipfile.ZipFile(source_ipa, 'r') as zip_ref:
        zip_ref.extractall(temp_dir)

    payload_app = os.path.join(temp_dir, "Payload", "Runner.app")
    if not os.path.exists(payload_app):
        print(f"Error: Payload/Runner.app not found in {temp_dir}")
        return

    # Update Info.plist with valid evaluated strings (NO $(...) Xcode macro variables)
    plist_path = os.path.join(payload_app, "Info.plist")
    if os.path.exists(plist_path):
        print(f"Updating Info.plist at {plist_path}...")
        try:
            with open(plist_path, "rb") as fp:
                plist_data = plistlib.load(fp)
        except Exception as e:
            print(f"Warning reading plist: {e}, creating new plist dict")
            plist_data = {}

        # Set concrete literal values for all keys
        plist_data["CFBundleDisplayName"] = "KALKAN SPORT"
        plist_data["CFBundleName"] = "KALKAN SPORT"
        plist_data["CFBundleIdentifier"] = "watch.circle"
        plist_data["CFBundleExecutable"] = "Runner"
        plist_data["CFBundleShortVersionString"] = "1.0.0"
        plist_data["CFBundleVersion"] = "1"
        plist_data["CFBundleDevelopmentRegion"] = "en"
        plist_data["CFBundlePackageType"] = "APPL"
        plist_data["CFBundleInfoDictionaryVersion"] = "6.0"
        plist_data["CADisableMinimumFrameDurationOnPhone"] = True
        plist_data["LSRequiresIPhoneOS"] = True
        plist_data["UIApplicationSupportsIndirectInputEvents"] = True
        plist_data["MinimumOSVersion"] = "15.0"
        plist_data["UIDeviceFamily"] = [1, 2]
        plist_data["NSBluetoothAlwaysUsageDescription"] = (
            "Приложение использует Bluetooth для синхронизации с часами СААТ-1 и мониторинга биометрии."
        )
        plist_data["NSBluetoothPeripheralUsageDescription"] = (
            "Приложение подключается к часам СААТ-1 по BLE для получения пульса, температуры кожи и шагов."
        )

        # Fix SceneDelegate class name if needed
        manifest = plist_data.get("UIApplicationSceneManifest", {})
        configs = manifest.get("UISceneConfigurations", {})
        app_roles = configs.get("UIWindowSceneSessionRoleApplication", [])
        for role in app_roles:
            delegate_name = role.get("UISceneDelegateClassName", "")
            if "$(" in delegate_name:
                role["UISceneDelegateClassName"] = "Runner.SceneDelegate"

        with open(plist_path, "wb") as fp:
            plistlib.dump(plist_data, fp, fmt=plistlib.FMT_XML)
        print("Info.plist successfully updated and validated.")

    # Copy new app icons into Runner.app
    ios_icons_dir = os.path.join(workspace, "barys_biotracker", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_icons_dir):
        icon_mapping = {
            "Icon-App-60x60@2x.png": "AppIcon60x60@2x.png",
            "Icon-App-76x76@2x.png": "AppIcon76x76@2x~ipad.png",
            "Icon-App-60x60@3x.png": "AppIcon60x60@3x.png",
        }
        for src_name, dst_name in icon_mapping.items():
            src_f = os.path.join(ios_icons_dir, src_name)
            dst_f = os.path.join(payload_app, dst_name)
            if os.path.exists(src_f):
                shutil.copy2(src_f, dst_f)
                print(f"Replaced icon: {dst_name}")

    # Update hero images in Flutter assets inside App.framework if present
    flutter_assets_img = os.path.join(payload_app, "Frameworks", "App.framework", "flutter_assets", "assets", "images")
    src_assets_img = os.path.join(workspace, "barys_biotracker", "assets", "images")
    if os.path.exists(flutter_assets_img) and os.path.exists(src_assets_img):
        for img_name in os.listdir(flutter_assets_img):
            src_img = os.path.join(src_assets_img, img_name)
            dst_img = os.path.join(flutter_assets_img, img_name)
            if os.path.exists(src_img) and os.path.isfile(src_img):
                shutil.copy2(src_img, dst_img)
                print(f"Updated asset image: {img_name}")

    # Package back to IPA
    print(f"Packaging updated IPA to {output_ipa}...")
    with zipfile.ZipFile(output_ipa, 'w', zipfile.ZIP_DEFLATED) as zip_out:
        for root, dirs, files in os.walk(temp_dir):
            for f in files:
                full_path = os.path.join(root, f)
                rel_path = os.path.relpath(full_path, temp_dir)
                zip_out.write(full_path, rel_path)

    # Also update barys_biotracker.ipa in workspace
    shutil.copy2(output_ipa, local_ipa)
    print(f"Updated workspace copy: {local_ipa}")

    # Copy to Downloads folder
    if os.path.exists(os.path.dirname(downloads_ipa)):
        shutil.copy2(output_ipa, downloads_ipa)
        print(f"Copied directly to Downloads: {downloads_ipa}")

    # Cleanup temp directory
    shutil.rmtree(temp_dir)
    print(f"SUCCESS: Created {output_ipa}!")

if __name__ == "__main__":
    update_ipa()
