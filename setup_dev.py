import os
import subprocess
import sys

def create_symlink(src, dst):
    if os.path.exists(dst):
        return
    
    src_abs = os.path.abspath(src)
    dst_abs = os.path.abspath(dst)
    
    print(f"  + Linking {src} -> {dst}")
    try:
        os.symlink(src_abs, dst_abs)
    except OSError:
        # Windows fallback (requires Admin or Developer Mode usually, or use Junction)
        subprocess.run(f'mklink /J "{dst_abs}" "{src_abs}"', shell=True)

def main():
    print("🔧 Setting up Feature Testbed...")
    
    # Features run inside .testbed/
    target_dir = ".testbed/addons"
    
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)
        
    # Clone Core into the testbed
    if not os.path.exists(f"{target_dir}/aerobeat-core"):
        print("  + Cloning Core into Testbed...")
        subprocess.run(["git", "clone", "https://github.com/AeroBeat-Workouts/aerobeat-core.git", f"{target_dir}/aerobeat-core"])

    # Clone GUT (Required for Testing)
    if not os.path.exists(f"{target_dir}/gut"):
        print("  + Cloning GUT into Testbed...")
        subprocess.run(["git", "clone", "https://github.com/bitwes/Gut.git", f"{target_dir}/gut"])

    # Symlink Source & Tests
    create_symlink("src", ".testbed/src")
    create_symlink("test", ".testbed/test")

if __name__ == "__main__":
    main()