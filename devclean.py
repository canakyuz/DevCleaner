#!/usr/bin/env python3
import os
import shutil
import hashlib
import argparse
import sys
from pathlib import Path
from datetime import datetime

# Terminal colours
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

class DevCleanerCLI:
    def __init__(self, dry_run=True, verbose=False):
        self.dry_run = dry_run
        self.verbose = verbose
        self.total_freed_space = 0

    def log(self, message, color=Colors.OKBLUE):
        print(f"{color}{message}{Colors.ENDC}")

    def error(self, message):
        print(f"{Colors.FAIL}[ERROR] {message}{Colors.ENDC}")

    def warn(self, message):
        print(f"{Colors.WARNING}[WARNING] {message}{Colors.ENDC}")

    def get_size(self, path):
        total_size = 0
        try:
            for dirpath, _, filenames in os.walk(path):
                for f in filenames:
                    fp = os.path.join(dirpath, f)
                    if not os.path.islink(fp):
                        total_size += os.path.getsize(fp)
        except Exception:
            pass
        return total_size

    def format_bytes(self, size):
        power = 2**10
        n = 0
        power_labels = {0 : '', 1: 'K', 2: 'M', 3: 'G', 4: 'T'}
        while size > power:
            size /= power
            n += 1
        return f"{size:.2f} {power_labels[n]}B"

    # --- MODULE 1: CACHE CLEANER ---
    def clean_caches(self):
        mode = 'DRY RUN' if self.dry_run else 'LIVE'
        self.log(f"\n🚀 Starting cache cleanup... (mode: {mode})", Colors.HEADER)

        cache_paths = [
            # Xcode
            "~/Library/Developer/Xcode/DerivedData",
            "~/Library/Developer/Xcode/Archives",
            "~/Library/Developer/Xcode/iOS DeviceSupport",
            "~/Library/Caches/com.apple.dt.Xcode",
            # Node/JS
            "~/.npm/_cacache",
            "~/Library/Caches/Yarn",
            "~/.bun/install/cache",
            # Python
            "~/Library/Caches/pip",
            # Ruby
            "~/.gem/cache",
            # Android/Gradle
            "~/.gradle/caches",
            "~/.android/cache",
            # General
            "~/Library/Caches/Google/Chrome",
            "~/Library/Caches/com.spotify.client",
            "~/.Trash"
        ]

        for raw_path in cache_paths:
            path = Path(os.path.expanduser(raw_path))
            if path.exists():
                size = self.get_size(path)
                if size > 0:
                    self.log(f"Found: {raw_path} ({self.format_bytes(size)})")
                    if not self.dry_run:
                        try:
                            # Remove the contents but recreate the directory itself:
                            # some tools crash when their cache root disappears.
                            if path.is_dir():
                                shutil.rmtree(path)
                                os.makedirs(path, exist_ok=True)
                            else:
                                os.remove(path)
                            self.log(f"  ✅ Cleaned: {raw_path}", Colors.OKGREEN)
                            self.total_freed_space += size
                        except Exception as e:
                            self.error(f"  ❌ Could not delete: {e}")
                else:
                    if self.verbose: self.log(f"Skipped (empty): {raw_path}", Colors.OKBLUE)
            else:
                if self.verbose: self.log(f"Not found: {raw_path}", Colors.OKBLUE)

    # --- MODULE 2: JUNK REMOVER (Empty Dirs, .DS_Store, Broken Links) ---
    def clean_junk(self, target_dir):
        target_path = Path(os.path.expanduser(target_dir))
        self.log(f"\n🧹 Junk file and structure analysis: {target_path}", Colors.HEADER)

        if not target_path.exists():
            self.error("Target directory does not exist.")
            return

        # 1. .DS_Store cleanup
        self.log("--- .DS_Store files ---")
        for root, dirs, files in os.walk(target_path):
            if ".DS_Store" in files:
                file_path = os.path.join(root, ".DS_Store")
                if not self.dry_run:
                    try:
                        os.remove(file_path)
                        if self.verbose: self.log(f"  Deleted: {file_path}")
                    except Exception as e:
                        self.error(f"  Error: {e}")
                else:
                    if self.verbose: self.log(f"  [Dry run] Would delete: {file_path}")

        # 2. Empty directories
        self.log("--- Empty directories ---")
        # Bottom-up traverse is needed to remove nested empty folders
        for root, dirs, files in os.walk(target_path, topdown=False):
            for name in dirs:
                full_path = os.path.join(root, name)
                try:
                    if not os.listdir(full_path): # Check if empty
                        if not self.dry_run:
                            os.rmdir(full_path)
                            self.log(f"  Deleted: {full_path}", Colors.OKGREEN)
                        else:
                            self.log(f"  [Dry run] Empty directory: {full_path}")
                except Exception:
                    pass

    # --- MODULE 3: DUPLICATE FINDER ---
    def find_duplicates(self, target_dir):
        target_path = Path(os.path.expanduser(target_dir))
        self.log(f"\n🔍 Duplicate file detection: {target_path}", Colors.HEADER)

        files_by_size = {}

        # Step 1: group by size, which is a cheap way to eliminate most candidates.
        self.log("Scanning files...", Colors.WARNING)
        for root, _, files in os.walk(target_path):
            for filename in files:
                filepath = Path(root) / filename
                if filepath.is_symlink():
                    continue
                try:
                    size = filepath.stat().st_size
                    if size < 1024: # Ignore files under 1KB, usually config
                        continue
                    if size in files_by_size:
                        files_by_size[size].append(filepath)
                    else:
                        files_by_size[size] = [filepath]
                except Exception:
                    pass

        # Step 2: hash only the groups where sizes already collide.
        potential_dupes = {s: f for s, f in files_by_size.items() if len(f) > 1}

        if not potential_dupes:
            self.log("No duplicate files found.", Colors.OKGREEN)
            return

        self.log(f"Inspecting {len(potential_dupes)} candidate size groups...", Colors.OKBLUE)

        duplicates_found = 0
        wasted_space = 0

        for size, file_list in potential_dupes.items():
            hashes = {}
            for filepath in file_list:
                try:
                    # Only the first 4KB is hashed. On large files this is far
                    # faster than a full read, but it means a match here is a
                    # strong hint rather than proof: two files that share a size
                    # and a 4KB header can still differ later on. That is why
                    # nothing is deleted automatically below.
                    with open(filepath, 'rb') as f:
                        file_hash = hashlib.md5(f.read(4096)).hexdigest()

                    if file_hash in hashes:
                        original = hashes[file_hash]
                        self.warn(f"DUPLICATE: {filepath.name}")
                        print(f"   ∟ Original: {original}")
                        print(f"   ∟ Copy:     {filepath}")
                        duplicates_found += 1
                        wasted_space += size
                    else:
                        hashes[file_hash] = filepath
                except Exception:
                    pass

        if duplicates_found > 0:
            self.log(f"\nFound {duplicates_found} duplicates. Wasted space: {self.format_bytes(wasted_space)}", Colors.FAIL)
            self.log("Note: duplicates are reported only, never deleted. Verify before removing anything.", Colors.WARNING)

def main():
    parser = argparse.ArgumentParser(description="DevCleaner: system cleanup tool for developers")

    # Subcommands
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # 'cache' command
    cmd_cache = subparsers.add_parser("cache", help="Clean developer caches")
    cmd_cache.add_argument("--force", action="store_true", help="Actually delete (default: preview only)")

    # 'junk' command
    cmd_junk = subparsers.add_parser("junk", help="Remove junk files (.DS_Store, empty directories)")
    cmd_junk.add_argument("--path", required=True, help="Directory to scan")
    cmd_junk.add_argument("--force", action="store_true", help="Actually delete")

    # 'dedup' command
    cmd_dedup = subparsers.add_parser("dedup", help="Find duplicate files")
    cmd_dedup.add_argument("--path", required=True, help="Directory to scan")

    args = parser.parse_args()

    if args.command == "cache":
        # Without --force the cache command stays in dry run.
        tool = DevCleanerCLI(dry_run=not args.force, verbose=True)
        tool.clean_caches()

    elif args.command == "junk":
        tool = DevCleanerCLI(dry_run=not args.force, verbose=True)
        tool.clean_junk(args.path)

    elif args.command == "dedup":
        tool = DevCleanerCLI(dry_run=True, verbose=True)
        tool.find_duplicates(args.path)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
