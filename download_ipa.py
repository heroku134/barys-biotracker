import urllib.request
import json
import os
import shutil

def download_latest_ipa():
    url = 'https://api.github.com/repos/heroku134/barys-biotracker/releases/tags/v1.0.87'
    req = urllib.request.Request(url, headers={'User-Agent': 'Python'})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))

    ipa_asset = None
    for a in data.get('assets', []):
        if a['name'].endswith('.ipa'):
            ipa_asset = a
            break

    if not ipa_asset:
        print('No IPA asset found')
        return

    download_url = ipa_asset['browser_download_url']
    dest = os.path.expanduser(r'~\Desktop\KALKAN_SPORT.ipa')
    artifact_dest = r'C:\Users\KPK\.gemini\antigravity\brain\16482f10-ac02-4fe0-90f1-c7b0d41ee2ca\KALKAN_SPORT.ipa'
    
    print(f"Downloading {ipa_asset['name']} ({ipa_asset['size']} bytes) to {dest}...")
    urllib.request.urlretrieve(download_url, dest)
    shutil.copy2(dest, artifact_dest)
    print(f"Successfully downloaded: {os.path.getsize(dest)} bytes")

if __name__ == '__main__':
    download_latest_ipa()
