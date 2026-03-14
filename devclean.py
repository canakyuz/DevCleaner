#!/usr/bin/env python3
import os
import shutil
import hashlib
import argparse
import sys
from pathlib import Path
from datetime import datetime

# Renkli Çıktılar için
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
        print(f"{Colors.FAIL}[HATA] {message}{Colors.ENDC}")

    def warn(self, message):
        print(f"{Colors.WARNING}[UYARI] {message}{Colors.ENDC}")

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
        self.log(f"\n🚀 Cache Temizliği Başlatılıyor... (Mod: {'SİMÜLASYON' if self.dry_run else 'GERÇEK'})", Colors.HEADER)
        
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
                    self.log(f"Tespit edildi: {raw_path} ({self.format_bytes(size)})")
                    if not self.dry_run:
                        try:
                            # Sadece içeriği sil, ana klasörü koru (bazı uygulamalar çökebilir)
                            if path.is_dir():
                                shutil.rmtree(path)
                                os.makedirs(path, exist_ok=True)
                            else:
                                os.remove(path)
                            self.log(f"  ✅ Temizlendi: {raw_path}", Colors.OKGREEN)
                            self.total_freed_space += size
                        except Exception as e:
                            self.error(f"  ❌ Silinemedi: {e}")
                else:
                    if self.verbose: self.log(f"Pas geçildi (Boş): {raw_path}", Colors.OKBLUE)
            else:
                if self.verbose: self.log(f"Bulunamadı: {raw_path}", Colors.OKBLUE)

    # --- MODULE 2: JUNK REMOVER (Empty Dirs, .DS_Store, Broken Links) ---
    def clean_junk(self, target_dir):
        target_path = Path(os.path.expanduser(target_dir))
        self.log(f"\n🧹 Çöp Dosya ve Yapı Analizi: {target_path}", Colors.HEADER)
        
        if not target_path.exists():
            self.error("Hedef klasör mevcut değil.")
            return

        # 1. .DS_Store Temizliği
        self.log("--- .DS_Store Dosyaları ---")
        for root, dirs, files in os.walk(target_path):
            if ".DS_Store" in files:
                file_path = os.path.join(root, ".DS_Store")
                if not self.dry_run:
                    try:
                        os.remove(file_path)
                        if self.verbose: self.log(f"  Silindi: {file_path}")
                    except Exception as e:
                        self.error(f"  Hata: {e}")
                else:
                    if self.verbose: self.log(f"  [Dry-Run] Silinecek: {file_path}")

        # 2. Boş Klasörler
        self.log("--- Boş Klasörler ---")
        # Bottom-up traverse is needed to remove nested empty folders
        for root, dirs, files in os.walk(target_path, topdown=False):
            for name in dirs:
                full_path = os.path.join(root, name)
                try:
                    if not os.listdir(full_path): # Check if empty
                        if not self.dry_run:
                            os.rmdir(full_path)
                            self.log(f"  Silindi: {full_path}", Colors.OKGREEN)
                        else:
                            self.log(f"  [Dry-Run] Boş klasör: {full_path}")
                except Exception:
                    pass

    # --- MODULE 3: DUPLICATE FINDER ---
    def find_duplicates(self, target_dir):
        target_path = Path(os.path.expanduser(target_dir))
        self.log(f"\n🔍 Tekrarlı Dosya Tespiti: {target_path}", Colors.HEADER)
        
        files_by_size = {}
        
        # Adım 1: Boyuta göre grupla (Hızlı eleme)
        self.log("Dosyalar taranıyor...", Colors.WARNING)
        for root, _, files in os.walk(target_path):
            for filename in files:
                filepath = Path(root) / filename
                if filepath.is_symlink():
                    continue
                try:
                    size = filepath.stat().st_size
                    if size < 1024: # 1KB altı dosyaları yoksay (genelde config vs)
                        continue
                    if size in files_by_size:
                        files_by_size[size].append(filepath)
                    else:
                        files_by_size[size] = [filepath]
                except Exception:
                    pass

        # Adım 2: Hash kontrolü (Sadece boyutu aynı olanlar için)
        potential_dupes = {s: f for s, f in files_by_size.items() if len(f) > 1}
        
        if not potential_dupes:
            self.log("Tekrarlı dosya bulunamadı.", Colors.OKGREEN)
            return

        self.log(f"{len(potential_dupes)} adet potansiyel boyut grubu inceleniyor...", Colors.OKBLUE)
        
        duplicates_found = 0
        wasted_space = 0

        for size, file_list in potential_dupes.items():
            hashes = {}
            for filepath in file_list:
                try:
                    # Performans için: Önce ilk 1024 byte'ı hashle
                    with open(filepath, 'rb') as f:
                        file_hash = hashlib.md5(f.read(4096)).hexdigest()
                        # Çarpışma riski düşük ama tam kontrol için tam okuma eklenebilir
                        # Büyük dosyalarda bu yöntem çok hız kazandırır.
                    
                    if file_hash in hashes:
                        original = hashes[file_hash]
                        self.warn(f"TEKRAR: {filepath.name}")
                        print(f"   ∟ Orijinal: {original}")
                        print(f"   ∟ Kopya:    {filepath}")
                        duplicates_found += 1
                        wasted_space += size
                        
                        # Burada silme işlemi opsiyoneldir, kullanıcıya sormak en iyisi
                        # Şimdilik sadece raporluyoruz.
                    else:
                        hashes[file_hash] = filepath
                except Exception as e:
                    pass
        
        if duplicates_found > 0:
            self.log(f"\nToplam {duplicates_found} tekrar bulundu. Boşa giden alan: {self.format_bytes(wasted_space)}", Colors.FAIL)
            self.log("Not: Tekrarlı dosyalar otomatik silinmez, manuel kontrol önerilir.", Colors.WARNING)

def main():
    parser = argparse.ArgumentParser(description="DevCleaner: Geliştiriciler için Sistem Temizlik Aracı")
    
    # Subcommands
    subparsers = parser.add_subparsers(dest="command", help="Komutlar")
    
    # 'cache' command
    cmd_cache = subparsers.add_parser("cache", help="Geliştirici önbelleklerini temizle")
    cmd_cache.add_argument("--force", action="store_true", help="Gerçekten sil (Varsayılan: Sadece göster)")
    
    # 'junk' command
    cmd_junk = subparsers.add_parser("junk", help="Gereksiz dosyaları (DS_Store, Boş Klasör) temizle")
    cmd_junk.add_argument("--path", required=True, help="Taranacak klasör")
    cmd_junk.add_argument("--force", action="store_true", help="Gerçekten sil")

    # 'dedup' command
    cmd_dedup = subparsers.add_parser("dedup", help="Tekrarlı dosyaları bul")
    cmd_dedup.add_argument("--path", required=True, help="Taranacak klasör")

    args = parser.parse_args()
    
    if args.command == "cache":
        # Cache için force yoksa dry_run=True
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
