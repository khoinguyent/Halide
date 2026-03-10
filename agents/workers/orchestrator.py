import json
import os
import re
import subprocess
import time
from datetime import datetime

# --- CONFIGURATION ---
# MASTER_DIR is the root /Halide folder
MASTER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MANIFEST_PATH = os.path.join(MASTER_DIR, "project_manifest.json")
SPRINTS_DIR = os.path.join(MASTER_DIR, "docs", "sprints")
# FIXED: Points to /Halide/PROJECT_STATUS.md
STATUS_FILE = os.path.join(MASTER_DIR, "PROJECT_STATUS.md")

def run_git(command, cwd=None):
    """Helper to run git commands safely."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, cwd=cwd, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        # We print but don't crash, allowing the script to continue
        print(f"⚠️ Git Info: {e.stderr.strip()}")
        return None

def load_manifest():
    with open(MANIFEST_PATH, "r") as f:
        return json.load(f)

def save_manifest(data):
    with open(MANIFEST_PATH, "w") as f:
        json.dump(data, f, indent=4)

def setup_agent_workspaces(manifest):
    """Ensures each agent has a folder and is on the correct sprint branch."""
    sprint_id = manifest["current_sprint"]
    roles = manifest["roles"].keys()
    
    for role in roles:
        worktree_path = os.path.abspath(os.path.join(MASTER_DIR, "..", f"Halide_{role}"))
        branch_name = f"feat/{sprint_id}/{role.lower()}"
        
        # 1. FIXED: If path exists, skip the heavy Git lifting to avoid 'develop' conflicts
        if os.path.exists(worktree_path):
            print(f"✅ Workspace for {role} already exists at {worktree_path}")
            continue
            
        # 2. Create Worktree only if it doesn't exist
        print(f"📂 Creating permanent worktree for {role}...")
        # Note: 'origin' is skipped here because you are working locally
        run_git(["git", "worktree", "add", "-b", branch_name, worktree_path, "develop"])

def parse_sprint_tasks(sprint_id):
    file_path = os.path.join(SPRINTS_DIR, f"{sprint_id}.md")
    if not os.path.exists(file_path): return []
    
    with open(file_path, "r") as f:
        content = f.read()
    
    # Improved Regex to capture Assignee and Status
    pattern = r"### \[(?P<id>.*?)\] .*?\n- \*\*Status\*\*:\s*(?P<status>.*?)\n- \*\*Depends On\*\*:\s*(?P<deps>.*?)\n- \*\*Assignee\*\*:\s*(?P<assignee>.*)"
    return [m.groupdict() for m in re.finditer(pattern, content)]

def update_pm_dashboard(manifest, tasks, sprint_name):
    """Generates a dynamic Markdown dashboard for all roles."""
    
    # Calculate global progress
    be_tasks = [t for t in tasks if t["id"].startswith("BE")]
    fe_tasks = [t for t in tasks if t["id"].startswith("FE")]
    
    def get_prog(t_list):
        if not t_list: return 0
        done = len([t for t in t_list if t["status"].strip().upper() == "DONE"])
        return (done / len(t_list)) * 100

    be_total_prog = get_prog(be_tasks)
    fe_total_prog = get_prog(fe_tasks)

    with open(STATUS_FILE, "w") as f:
        f.write(f"# 🎞️ Halide: {sprint_name} Dashboard\n")
        f.write(f"**Backend Progress:** {int(be_total_prog)}% | **Frontend Progress:** {int(fe_total_prog)}%\n\n")
        f.write("| Developer | Focus | Progress |\n| :--- | :--- | :--- |\n")
        
        for role_id, focus in manifest["roles"].items():
            # Filter tasks specifically assigned to this developer
            role_tasks = [t for t in tasks if t.get("assignee") == role_id]
            
            prog = int(get_prog(role_tasks))
            bar = "█" * (prog // 10) + "░" * (10 - (prog // 10))
            f.write(f"| {role_id} | {focus} | {bar} {prog}% |\n")

def run_loop():
    print("🎬 Project Halide Orchestrator Active.")
    
    while True:
        try:
            # 1. Reload manifest
            manifest = load_manifest()
            current_sprint = manifest["current_sprint"]
            
            # 2. Ensure workspaces are ready (will skip if already exists)
            setup_agent_workspaces(manifest)
            
            # 3. Parse tasks
            tasks = parse_sprint_tasks(current_sprint)
            
            if not tasks: 
                print(f"⚠️ Waiting for {current_sprint}.md to be populated...")
                time.sleep(30)
                continue

            # 4. FIXED: Pass current_sprint to avoid NameError
            update_pm_dashboard(manifest, tasks, current_sprint)

            # 5. Check completion
            all_done = all(t["status"].strip().upper() == "DONE" for t in tasks)
            if all_done:
                print(f"🏁 Sprint {current_sprint} complete! Manual merge recommended.")
                # We stop the loop here to prevent accidental auto-merging until you're ready
                break
                
            time.sleep(60) # Poll every minute
            
        except Exception as e:
            print(f"❌ Orchestrator Error: {e}")
            time.sleep(10)

if __name__ == "__main__":
    run_loop()