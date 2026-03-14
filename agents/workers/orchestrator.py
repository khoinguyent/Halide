import json
import os
import re
import subprocess
import time
from datetime import datetime

# --- CONFIGURATION PATHS ---
MASTER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MANIFEST_PATH = os.path.join(MASTER_DIR, "project_manifest.json")
SPECS_DIR = os.path.join(MASTER_DIR, "docs", "specs")
SPRINTS_DIR = os.path.join(MASTER_DIR, "docs", "sprints")
STATUS_FILE = os.path.join(MASTER_DIR, "PROJECT_STATUS.md")
LOGS_DIR = os.path.join(MASTER_DIR, "shared_logs")

class HalideOrchestrator:
    def __init__(self):
        self.specs_context = self._load_all_specs()
        print(f"✅ Orchestrator Initialized: {len(self.specs_context)} specification files loaded.")
        
    def _load_all_specs(self):
        """Ingests all .md files in docs/specs for context."""
        context = {}
        if os.path.exists(SPECS_DIR):
            for file in os.listdir(SPECS_DIR):
                if file.endswith(".md"):
                    path = os.path.join(SPECS_DIR, file)
                    with open(path, "r", encoding="utf-8") as f:
                        context[file] = f.read()
        return context

    def run_git(self, command, cwd=None):
        """Executes a git command and returns the output."""
        try:
            result = subprocess.run(command, capture_output=True, text=True, cwd=cwd, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            if "already up to date" not in e.stderr.lower():
                self._log_anomaly(f"Git Error: {e.stderr.strip()}")
            return None

    def _log_anomaly(self, message):
        """Logs tech anomalies to shared logs."""
        os.makedirs(LOGS_DIR, exist_ok=True)
        log_path = os.path.join(LOGS_DIR, "orchestrator_anomalies.log")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now()}] {message}\n")

    def sync_agent_branches(self, manifest):
        """Merges agent work branches into development branch and updates sprint status."""
        current_sprint = manifest.get("current_sprint", "sprint_01")
        sprint_file = os.path.join(SPRINTS_DIR, f"{current_sprint}.md")
        
        for role_id in manifest.get("roles", {}).keys():
            branch_name = f"feat/{current_sprint}/{role_id.lower()}"
            result = self.run_git(["git", "merge", branch_name, "--no-edit", "-m", f"auto-sync: {role_id} updates"])
            
            # If merge was successful, try to mark the task as DONE in the sprint file
            if result is not None and os.path.exists(sprint_file):
                with open(sprint_file, "r", encoding="utf-8") as f:
                    content = f.read()
                
                # Update status for the specific role's tasks if found by Assignee
                # Pattern: Look for - **Status**: TODO followed by - **Assignee**: role_id
                pattern = rf"(- \*\*Status\*\*:\s*)TODO(?=.*?- \*\*Assignee\*\*: {role_id})"
                new_content = re.sub(pattern, r"\1DONE", content, flags=re.DOTALL | re.IGNORECASE)
                
                if new_content != content:
                    with open(sprint_file, "w", encoding="utf-8") as f:
                        f.write(new_content)
                    print(f"✅ Sprint File Updated: Marked tasks for {role_id} as DONE.")

    def update_dashboard(self, manifest):
        """Parses sprint file and refreshes PROJECT_STATUS.md."""
        current_sprint = manifest.get("current_sprint", "sprint_01")
        sprint_file = os.path.join(SPRINTS_DIR, f"{current_sprint}.md")
        
        if not os.path.exists(sprint_file):
            return

        with open(sprint_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Regex for tasks: ### [ID] ... - **Status**: STATUS
        tasks = re.findall(r"### \[(.*?)\].*?-\s*\*\*Status\*\*:\s*(TODO|IN_PROGRESS|DONE|BLOCKED)", content, re.DOTALL)
        
        with open(STATUS_FILE, "w", encoding="utf-8") as f:
            f.write(f"# 🎞️ Halide Project Status: {current_sprint}\n")
            f.write(f"**Last Sync:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write("| Task ID | Status | Owner | Spec Alignment |\n")
            f.write("| :--- | :--- | :--- | :--- |\n")
            
            for tid, status in tasks:
                owner = "BE" if "BE" in tid else "FE"
                icon = "✅" if status == "DONE" else "⏳" if status == "IN_PROGRESS" else "❌" if status == "BLOCKED" else "💤"
                f.write(f"| {tid} | {icon} {status} | {owner} | Verified |\n")
        
        # If all tasks are DONE, update the manifest status
        if tasks and all(s == "DONE" for _, s in tasks):
            try:
                with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                    manifest_data = json.load(f)
                
                if manifest_data["status"].get(current_sprint) != "DONE":
                    manifest_data["status"][current_sprint] = "DONE"
                    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
                        json.dump(manifest_data, f, indent=4)
                    print(f"🎊 Sprint Complete! Updated {current_sprint} to DONE in manifest.")
            except Exception as e:
                self._log_anomaly(f"Failed to update manifest status: {e}")

        print(f"📊 Dashboard Updated: {len(tasks)} tasks processed.")

    def main_loop(self):
        """Periodically syncs and updates status."""
        print("🎬 Halide Orchestrator: Active. Monitoring Sprint...")
        while True:
            try:
                with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                    manifest = json.load(f)
                self.sync_agent_branches(manifest)
                self.update_dashboard(manifest)
                time.sleep(60)
            except Exception as e:
                self._log_anomaly(f"Loop Error: {str(e)}")
                time.sleep(10)

if __name__ == "__main__":
    orch = HalideOrchestrator()
    orch.main_loop()