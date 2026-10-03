import urllib.request
import json

def check():
    runs_url = 'https://api.github.com/repos/heroku134/barys-biotracker/actions/runs?per_page=6'
    req = urllib.request.Request(runs_url, headers={'User-Agent': 'Python'})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        print("Recent Workflow Runs:")
        for r in data.get('workflow_runs', []):
            print(f"Run #{r.get('run_number')} (SHA: {r.get('head_sha','')[:7]}): status={r.get('status')}, conclusion={r.get('conclusion')}, event={r.get('event')}, title={r.get('display_title')}")
    except Exception as e:
        print("Error fetching runs:", e)

    rel_url = 'https://api.github.com/repos/heroku134/barys-biotracker/releases?per_page=3'
    req2 = urllib.request.Request(rel_url, headers={'User-Agent': 'Python'})
    try:
        with urllib.request.urlopen(req2) as resp:
            rels = json.loads(resp.read().decode('utf-8'))
        print("\nRecent Releases:")
        for rel in rels:
            assets = [f"{a['name']} ({a['size']}B)" for a in rel.get('assets', [])]
            print(f"Tag: {rel.get('tag_name')}, Assets: {', '.join(assets)}")
    except Exception as e:
        print("Error fetching releases:", e)

if __name__ == '__main__':
    check()
