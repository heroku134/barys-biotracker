import urllib.request
import json
import os
import shutil

def download_latest_ipa():
    url = 'https://api.github.com/repos/heroku134/barys-biotracker/releases'
    req = urllib.request.Request(url, headers={'User-Agent': 'Python'})
    with urllib.request.urlopen(req) as resp:
        releases = json.loads(resp.read().decode('utf-8'))

    if not releases:
        print('No releases found')
        return

    latest_release = releases[0]
    tag = latest_release.get('tag_name', 'unknown')
    print(f"Checking latest release: {tag}")

    ipa_asset = None
    for a in latest_release.get('assets', []):
        if a['name'].endswith('.ipa'):
            ipa_asset = a
            break

    if not ipa_asset:
        print(f'No IPA asset found in release {tag}')
        return

    download_url = ipa_asset['browser_download_url']
    dest = os.path.expanduser(r'~\Desktop\KALKAN_SPORT.ipa')
    artifact_dest = r'C:\Users\KPK\.gemini\antigravity\brain\16482f10-ac02-4fe0-90f1-c7b0d41ee2ca\KALKAN_SPORT.ipa'
    
    print(f"Downloading {ipa_asset['name']} ({ipa_asset['size']} bytes) from {tag} to {dest}...")
    urllib.request.urlretrieve(download_url, dest)
    shutil.copy2(dest, artifact_dest)
    print(f"Successfully downloaded {tag} IPA: {os.path.getsize(dest)} bytes")

if __name__ == '__main__':
    download_latest_ipa()
