import datetime
import os
import subprocess
import sys

def run_cmd(args, silent=False):
    """Runs a shell command safely."""
    try:
        res = subprocess.run(
            args,
            check=True,
            text=True,
            capture_output=silent
        )
        return True, res.stdout.strip() if silent else ""
    except subprocess.CalledProcessError as e:
        return False, e.stderr.strip() if silent else str(e)

def auto_save():
    print("\n Miofa Forest Auto-Saver")
    print("====================================")

    # 1. Verify / Initialize Git repo
    if not os.path.exists(".git"):
        print("⚠️ No Git repository found. Initializing...")
        run_cmd(["git", "init"])
        run_cmd(["git", "branch", "-M", "main"])

    # 2. Check current working tree status (respects .gitignore automatically)
    _, status = run_cmd(["git", "status", "--porcelain"], silent=True)
    if not status:
        print(" Working directory clean! No new changes to save.")
    else:
        # 3. Stage changes
        print(" Staging updated files (excluding .gitignore rules)...")
        run_cmd(["git", "add", "."])

        # 4. Commit message handling
        default_msg = f"Auto-save: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        custom_msg = input(f" Commit message (Press Enter for '{default_msg}'): ").strip()
        commit_msg = custom_msg if custom_msg else default_msg

        print(f" Committing: '{commit_msg}'...")
        success, _ = run_cmd(["git", "commit", "-m", commit_msg], silent=True)
        if not success:
            print("⚠️ Commit step failed or skipped.")

    # 5. Determine Current Branch & Remote
    _, current_branch = run_cmd(["git", "branch", "--show-current"], silent=True)
    current_branch = current_branch if current_branch else "main"

    _, remotes = run_cmd(["git", "remote"], silent=True)
    if "origin" not in remotes:
        print("⚠️ Remote 'origin' not linked yet.")
        print(" Run: git remote add origin https://github.com/<user>/<repo>.git")
    else:
        print(f"☁️ Pushing changes to origin/{current_branch}...")
        push_ok, _ = run_cmd(["git", "push", "-u", "origin", current_branch], silent=False)
        if push_ok:
            print("✅ Successfully updated and synced with GitHub!")
        else:
            print("❌ Push failed. Check your network, merge conflicts, or GitHub authentication.")

if __name__ == "__main__":
    auto_save()
    input("\nPress Enter to exit...")