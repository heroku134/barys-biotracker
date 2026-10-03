import os
import re
import subprocess
import urllib.request
import json

def get_auth_token():
    try:
        url = subprocess.check_output(['git', 'config', '--get', 'remote.origin.url'], text=True).strip()
        m = re.search(r'https://([^@]+)@github\.com', url)
        if m:
            return m.group(1)
    except Exception:
        pass
    return os.environ.get('GITHUB_TOKEN', '')

def check():
    token = get_auth_token()
    headers = {'User-Agent': 'Python'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    runs_url = 'https://api.github.com/repos/heroku134/barys-biotracker/actions/runs?per_page=6'
    req = urllib.request.Request(runs_url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        print("Recent Workflow Runs:")
        for r in data.get('workflow_runs', []):
            print(f"Run #{r.get('run_number')} (SHA: {r.get('head_sha','')[:7]}): status={r.get('status')}, conclusion={r.get('conclusion')}, title={r.get('display_title')}")
            if r.get('status') == 'in_progress' or (r.get('run_number') in [100, 101]):
                try:
                    jobs_url = r.get('jobs_url')
                    if jobs_url:
                        j_req = urllib.request.Request(jobs_url, headers=headers)
                        with urllib.request.urlopen(j_req) as j_resp:
                            j_data = json.loads(j_resp.read().decode('utf-8'))
                            for job in j_data.get('jobs', []):
                                print(f"   -> Job: {job.get('name')} [{job.get('status')}, {job.get('conclusion')}]")
                                for step in job.get('steps', []):
                                    if step.get('status') == 'in_progress':
                                        print(f"      [IN PROGRESS] Step: {step.get('name')}")
                                    elif step.get('conclusion') == 'failure':
                                        print(f"      [FAILED] Step: {step.get('name')}")
                except Exception as je:
                    print(f"   (Failed fetching jobs: {je})")
    except Exception as e:
        print("Error fetching runs:", e)

    rel_url = 'https://api.github.com/repos/heroku134/barys-biotracker/releases?per_page=3'
    req2 = urllib.request.Request(rel_url, headers=headers)
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
