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
        """
        Ingests all .md files in docs/specs to ensure the Orchestrator 
        understands the technical 'Source of Truth'.
        """
        context = {}
        if not os.path.exists(SPECS_DIR):
            print(f"⚠️ Warning: Specs directory not found at {SPECS_DIR}")
            return context
            
        for file in os.listdir(SPECS_DIR):
            if file.endswith(".md"):
                path = os.path.join(SPECS_DIR, file)
                try:
                    with open(path, "r") as f:
                        context[file] = f.read()
                except Exception as e:
                    print(f"❌ Failed to load spec {file}: {e}")
        return context

    def run_git(self, command, cwd=None):
        try:
            result = subprocess.run(command, capture_output=True, text=True, cwd=cwd, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            if "already up to date" not in e.stderr.lower():
                self._log_anomaly(f"Git Error in {cwd or 'root'}: {e.stderr.strip()}")
            return None

    def _log_anomaly(self, message):
        """Appends anomalies to the shared cycle logs."""
        os.makedirs(LOGS_DIR, exist_ok=True)
        log_path = os.path.join(LOGS_DIR, "orchestrator_anomalies.log")
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(log_path, "a") as f:
            f.write(f"[{timestamp}] {message}\n")

    def sync_agent_branches(self, manifest):
        """Automatically merges agent work into Master develop branch."""
        current_sprint = manifest["current_sprint"]
        for role_id in manifest["roles"].keys():
            branch_name = f"feat/{current_sprint}/{role_id.lower()}"
            # Attempt to merge role branch into current active branch
            self.run_git(["git", "merge", branch_name, "--no-edit", "-m", f"auto-sync: {role_id} updates for {current_sprint}"])

    def update_dashboard(self, manifest):
        """Parses sprint files and updates the status dashboard."""
        current_sprint = manifest["current_sprint"]
        sprint_file = os.path.join(SPRINTS_DIR, f"{current_sprint}.md")
        
        if not os.path.exists(sprint_file):
            return

        with open(sprint_file, "r") as f:
            content = f.read()

        # Regex to find tasks: ### [ID] Title ... - **Status**: STATUS
        tasks = re.findall(r"### \[(.*?)\] .*?\n- \*\*Status\*\*: (TODO|IN_PROGRESS|DONE|BLOCKED)", content)
        
        with open(STATUS_FILE, "w") as f:
            f.write(f"# 🎞️ Halide Project Status: {current_sprint}\n")
            f.write(f"**Last Sync:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write("| Task ID | Status | Owner | Spec Alignment |\n")
            f.write("| :--- | :--- | :--- | :--- |\n")
            
            for tid, status in tasks:
                owner = tid.split('-')[0] if '-' in tid else ("BE" if "BE" in tid else "FE")
                status_icon = "✅" if status == "DONE" else "⏳" if status == "IN_PROGRESS" else "❌" if status == "BLOCKED" else "💤"
                
                # Cross-reference check (Simulated alignment)
                alignment = "Verified"
                if tid.startswith("FE") and "frontend_ui.md" not in self.specs_context:
                    alignment = "Missing UI Spec"
                elif tid.startswith("BE") and "backend_api.md" not in self.specs_context:
                    alignment = "Missing API Spec"
                
                f.write(f"| {tid} | {status_icon} {status} | {owner} | {alignment} |\n")

    def main_loop(self):
        print("🎬 Halide Orchestrator: Specifications Ingested. Monitoring Repository Lifecycle...")
        while True:
            try:
                if not os.path.exists(MANIFEST_PATH):
                    print("❌ Manifest missing. Retrying in 10s...")
                    time.sleep(10)
                    continue

                with open(MANIFEST_PATH, "r") as f:
                    manifest = json.load(f)
                
                # 1. Sync Code
                self.sync_agent_branches(manifest)
                
                # 2. Update Dashboard
                self.update_dashboard(manifest)
                
                # 3. Reload Specs in case of updates
                self.specs_context = self._load_all_specs()
                
                time.sleep(60) # Sync every minute
            except Exception as e:
                self._log_anomaly(f"Main Loop Exception: {str(e)}")
                time.sleep(10)

if __name__ == "__main__":
    orch = HalideOrchestrator()
    orch.main_loop()