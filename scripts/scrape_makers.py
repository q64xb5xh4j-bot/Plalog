#!/usr/bin/env python3
"""
Scrape model kit catalogs from official manufacturer websites.

Supported manufacturers:
  - Kotobukiya (kotobukiya.co.jp) → kotobukiya_models.csv
  - Hasegawa   (hasegawa-model.co.jp) → hasegawa_models.csv
"""

import csv
import os
import re
import time
import requests
from bs4 import BeautifulSoup
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "ja,en-US;q=0.7,en;q=0.3",
}

# ──────────────────────────────────────────────
# Kotobukiya
# ──────────────────────────────────────────────

KOTOBUKIYA_CATEGORIES = [
    # (category_slug, grade_label)
    ("mecha-modelkits",            "プラモデル"),
    ("character-modelkits",        "プラモデル"),
    ("female-character-modelkits", "プラモデル"),
]

def scrape_kotobukiya():
    """Scrape Kotobukiya product listings from kotobukiya.co.jp"""
    base_url = "https://www.kotobukiya.co.jp/product/model-kits"
    products = []

    for slug, grade_label in KOTOBUKIYA_CATEGORIES:
        page = 1
        while True:
            url = f"{base_url}/{slug}/" if page == 1 else f"{base_url}/{slug}/?page={page}"
            try:
                resp = requests.get(url, headers=HEADERS, timeout=15)
                if resp.status_code != 200:
                    break
                soup = BeautifulSoup(resp.content, "html.parser")

                plist = soup.find("ul", class_="productList_list")
                if not plist:
                    break

                items = plist.find_all("li", recursive=False)
                if not items:
                    break

                for item in items:
                    name_elem  = item.find(class_="productList_name")   # シリーズ
                    title_elem = item.find(class_="productList_title")  # 製品名
                    cat_elem   = item.find(class_="productList_category")

                    if not title_elem:
                        continue

                    series = name_elem.get_text(strip=True)  if name_elem  else ""
                    title  = title_elem.get_text(strip=True) if title_elem else ""
                    cat    = cat_elem.get_text(strip=True)   if cat_elem   else ""

                    if not title:
                        continue

                    # グレード : "ロボット/メカ プラモデル" → "プラモデル"
                    grade = cat.split()[-1] if cat else grade_label

                    products.append({
                        "jan":    "",
                        "title":  title,
                        "maker":  "Kotobukiya",
                        "series": series,
                        "grade":  grade,
                        "scale":  "",
                    })

                # ページ繰り
                pager = soup.find("ul", class_="pager_list")
                if not pager:
                    break
                all_nums = [
                    int(a.get_text(strip=True))
                    for a in pager.find_all("a")
                    if a.get_text(strip=True).isdigit()
                ]
                max_page = max(all_nums) if all_nums else 1
                if page >= max_page:
                    break
                page += 1
                time.sleep(0.5)

            except Exception as e:
                print(f"  ⚠️  Kotobukiya [{slug}] page {page}: {e}")
                break

        print(f"  Kotobukiya [{slug}]: {sum(1 for p in products if p['maker']=='Kotobukiya')} items so far")

    return products


# ──────────────────────────────────────────────
# Hasegawa
# ──────────────────────────────────────────────

def scrape_hasegawa():
    """Scrape Hasegawa product listings from hasegawa-model.co.jp"""
    products = []
    base_url = "http://www.hasegawa-model.co.jp/item"

    # 総ページ数を1ページ目から取得
    try:
        resp = requests.get(f"{base_url}/", headers=HEADERS, timeout=15, verify=False)
        soup = BeautifulSoup(resp.content, "html.parser")
        pager = soup.find("div", class_="wp-pagenavi")
        last_page = 1
        if pager:
            nums = [
                int(a.get_text(strip=True))
                for a in pager.find_all("a")
                if a.get_text(strip=True).isdigit()
            ]
            if nums:
                last_page = max(nums)
    except Exception as e:
        print(f"  ⚠️  Hasegawa: cannot fetch page count: {e}")
        return products

    print(f"  Hasegawa: {last_page} pages to scrape")

    for page in range(1, last_page + 1):
        url = f"{base_url}/" if page == 1 else f"{base_url}/page/{page}/"
        try:
            resp = requests.get(url, headers=HEADERS, timeout=15, verify=False)
            if resp.status_code != 200:
                break
            soup = BeautifulSoup(resp.content, "html.parser")

            box = soup.find("div", class_="a_item_box")
            if not box:
                break

            # 各製品は <a> タグでラップされている
            for item_a in box.find_all("a", href=True):
                title_elem = item_a.find("div", class_="a_item_title")
                scale_elem = item_a.find("div", class_="a_item_scale")
                no_elem    = item_a.find("div", class_="a_item_no")

                if not title_elem:
                    continue

                raw_title = title_elem.get_text(strip=True)
                raw_scale = scale_elem.get_text(strip=True) if scale_elem else ""
                prod_no   = no_elem.get_text(strip=True)    if no_elem    else ""

                # スケール正規化 "1:48 \nプラモデル" → "1/48"
                scale_match = re.search(r"1[:/](\d+)", raw_scale)
                scale = f"1/{scale_match.group(1)}" if scale_match else ""

                # グレード (プラモデル / キャラモデル 等)
                grade_part = raw_scale.split()[-1] if raw_scale else "プラモデル"

                products.append({
                    "jan":    "",
                    "title":  raw_title,
                    "maker":  "Hasegawa",
                    "series": "",
                    "grade":  grade_part,
                    "scale":  scale,
                })

            time.sleep(0.3)

        except Exception as e:
            print(f"  ⚠️  Hasegawa page {page}: {e}")
            continue

    return products


# ──────────────────────────────────────────────
# Save CSV
# ──────────────────────────────────────────────

def load_existing(filepath):
    existing = {}
    if os.path.exists(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                key = row.get("title", "").strip()
                if key:
                    existing[key] = row
    return existing

def save_csv(products, filepath):
    fieldnames = ["jan", "title", "maker", "series", "grade", "scale"]
    # 既存データをロードして重複チェック
    existing = load_existing(filepath)
    added = 0
    for p in products:
        key = p["title"].strip()
        if key and key not in existing:
            existing[key] = p
            added += 1
    # ソートして保存
    sorted_items = sorted(existing.values(), key=lambda x: (x.get("maker",""), x.get("title","")))
    with open(filepath, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in sorted_items:
            writer.writerow({k: row.get(k, "") for k in fieldnames})
    return added, len(existing)


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

def main():
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    print("=" * 60)
    print("🚀 Manufacturer Catalog Scraper")
    print(f"   {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    # ── Kotobukiya ──
    print("\n📦 Kotobukiya ...")
    koto_products = scrape_kotobukiya()
    koto_file = os.path.join(SCRIPT_DIR, "..", "kotobukiya_models.csv")
    added, total = save_csv(koto_products, koto_file)
    print(f"  ✅ Added: {added} | Total: {total} → {koto_file}")

    # ── Hasegawa ──
    print("\n✈️  Hasegawa ...")
    hase_products = scrape_hasegawa()
    hase_file = os.path.join(SCRIPT_DIR, "..", "hasegawa_models.csv")
    added, total = save_csv(hase_products, hase_file)
    print(f"  ✅ Added: {added} | Total: {total} → {hase_file}")

    print("\n" + "=" * 60)
    print(f"✅ Done at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)


if __name__ == "__main__":
    main()
