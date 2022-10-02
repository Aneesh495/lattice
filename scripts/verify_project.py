#!/usr/bin/env python3
"""
verify_project.py: Comprehensive Verification and Zero-Em-Dash Linter for Lattice
"""

import os
import sys
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

FORBIDDEN_CHARS = {
    "\u2014": "Em dash (U+2014)",
    "\u2013": "En dash (U+2013)",
}

IGNORED_DIRS = {
    ".git",
    "build",
    "lib",
    "data",
    "__pycache__",
    ".pytest_cache",
}

def check_no_em_dashes():
    print("[1/5] Scanning codebase for em dashes and en dashes...")
    violations = []

    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS]
        for f in files:
            path = Path(root) / f
            # Only check text files
            if f.endswith((".st", ".c", ".h", ".py", ".md", ".sh", "Makefile", "lattice", "LICENSE", ".gitignore")):
                try:
                    with open(path, "r", encoding="utf-8", errors="replace") as fh:
                        for line_idx, line in enumerate(fh, start=1):
                            for char, name in FORBIDDEN_CHARS.items():
                                if char in line:
                                    violations.append((path.relative_to(REPO_ROOT), line_idx, name, line.strip()))
                except Exception as e:
                    print(f"Warning: could not read {path}: {e}")

    if violations:
        print(f"FAILED: Found {len(violations)} forbidden dash characters:")
        for file_path, line_no, name, content in violations:
            print(f"  {file_path}:{line_no} [{name}]: {content}")
        return False
    else:
        print("  Passed: 0 em dashes or en dashes detected across all files.")
        return True


def run_command(cmd, desc):
    print(f"Running: {desc} ({cmd})...")
    res = subprocess.run(cmd, shell=True, cwd=REPO_ROOT, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"  FAILED: {desc}")
        print("STDOUT:\n", res.stdout)
        print("STDERR:\n", res.stderr)
        return False
    else:
        print(f"  Passed: {desc}")
        return True


def main():
    print("=================================================================")
    print(" Lattice Comprehensive Verification Pass                         ")
    print("=================================================================")

    all_passed = True

    if not check_no_em_dashes():
        all_passed = False

    print("\n[2/5] Running Native C Test Suite...")
    if not run_command("make test-native", "Native liblatticenet C tests"):
        all_passed = False

    print("\n[3/5] Running Smalltalk Unit & Integration Tests...")
    if not run_command("make test-unit", "Smalltalk unit test suite"):
        all_passed = False

    if not run_command("make test-integration", "Multi-node integration test suite"):
        all_passed = False

    print("\n[4/5] Running Fault-Injection Stress Tests...")
    if not run_command("make test-stress", "Fault-injection stress test suite"):
        all_passed = False

    print("\n[5/5] Running Python Client Tests...")
    if not run_command("make test-python", "Python client unittest suite"):
        all_passed = False

    print("\n=================================================================")
    if all_passed:
        print("=> ALL VERIFICATION CHECKS PASSED PERFECTLY")
        print("=================================================================")
        return 0
    else:
        print("=> VERIFICATION FAILED")
        print("=================================================================")
        return 1


if __name__ == "__main__":
    sys.exit(main())
