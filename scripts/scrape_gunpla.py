import requests
from bs4 import BeautifulSoup
import csv
import re
import os
from datetime import datetime

# Target URLs and their default metadata
TARGETS = [
    {
        "grade": "HGUC", "scale": "1/144",
        "url": "https://ja.wikipedia.org/wiki/ハイグレード・ユニバーサルセンチュリー",
        "series_default": "Universal Century"
    },
    {
        "grade": "MG", "scale": "1/100",
        "url": "https://ja.wikipedia.org/wiki/マスターグレード",
        "series_default": ""
    },
    {
        "grade": "RG", "scale": "1/144",
        "url": "https://ja.wikipedia.org/wiki/リアルグレード",
        "series_default": ""
    },
    {
        "grade": "PG", "scale": "1/60",
        "url": "https://ja.wikipedia.org/wiki/パーフェクトグレード",
        "series_default": ""
    },
    {
        "grade": "EG", "scale": "1/144",
        "url": "https://ja.wikipedia.org/wiki/ENTRY_GRADE",
        "series_default": ""
    },
    {
        "grade": "RE/100", "scale": "1/100",
        "url": "https://ja.wikipedia.org/wiki/RE/100",
        "series_default": ""
    }
]

import os
# Use relative path (works in GitHub Actions too)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(SCRIPT_DIR, "..", "gunpla_catalog.csv")

def get_soup(url):
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        return BeautifulSoup(response.content, 'html.parser')
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return None

def normalize_text(text):
    if not text: return ""
    # Remove citations like [1], [注 1]
    text = re.sub(r'\[.*?\]', '', text)
    # Remove explicit sales type markers if any (though we remove specific one later)
    text = text.replace("【抽選販売】", "").replace("【一般販売】", "")
    return text.strip()

def extract_year(date_str):
    # Try to find YYYY年
    match = re.search(r'(\d{4})年', date_str)
    if match:
        return match.group(1)
    # Try YYYY.MM
    match = re.search(r'(\d{4})\.', date_str)
    if match:
        return match.group(1)
    return ""

def scrape_page(target):
    soup = get_soup(target["url"])
    if not soup: return []
    
    items = []
    print(f"Scraping {target['grade']} from {target['url']}...")
    
    # Tables are usually class "wikitable"
    tables = soup.find_all('table', class_='wikitable')
    
    for table in tables:
        # Check headers to see if it looks like a product list
        headers = [th.get_text(strip=True) for th in table.find_all('th')]
        if not headers: continue
        
        # Heuristic: headers should contain "No" or "No." or "製品名" or "商品名" or "発売"
        header_text = "".join(headers)
        if "No" not in header_text and "製品名" not in header_text and "商品名" not in header_text and "発売" not in header_text:
            continue
            
        rows = table.find_all('tr')
        for row in rows:
            cells = row.find_all('td')
            if not cells: continue
            
            # Map columns loosely based on position
            # Usually: No | Product Name | Price | Date | ...
            # Or: No | Product Name | Date | ...
            
            # Find title (usually linked or in 2nd col)
            title = ""
            date_str = ""
            
        # Identify columns
        title_idx = -1
        date_idx = -1
        
        for i, h in enumerate(headers):
            if "製品名" in h or "商品名" in h or "機体名" in h:
                title_idx = i
            elif "発売" in h:
                date_idx = i
        
        rows = table.find_all('tr')
        for row in rows:
            cells = row.find_all('td')
            if not cells: continue
            
            # If explicit headers didn't work, try heuristics on the row
            current_title = ""
            current_date = ""
            
            if title_idx != -1 and title_idx < len(cells):
                 current_title = normalize_text(cells[title_idx].get_text())
            else:
                # Heuristic: Find first cell with Japanese text that isn't price
                for cell in cells:
                    txt = normalize_text(cell.get_text())
                    # Check if contains Kana/Kanji
                    if re.search(r'[ァ-ン一-龥]', txt) and "円" not in txt and "月" not in txt and "年" not in txt:
                        current_title = txt
                        break
                # Fallback: Col 1 (index 1) if Col 0 is Number
                if not current_title and len(cells) >= 2:
                     current_title = normalize_text(cells[1].get_text())

            if date_idx != -1 and date_idx < len(cells):
                current_date = normalize_text(cells[date_idx].get_text())
            else:
                 # Heuristic date
                 for cell in cells:
                    txt = cell.get_text()
                    if "年" in txt:
                        current_date = normalize_text(txt)
                        break

            if not current_title or len(current_title) < 2: continue
            if "円" in current_title: continue 
            
            # Check if title looks like a model number only (e.g. "MS-06")
            # If matches pattern like "MS-06" or "RX-78-2" and has no Japanese, try to find better
            if re.match(r'^[A-Za-z0-9\-\s]+$', current_title):
                 for cell in cells:
                     txt = normalize_text(cell.get_text())
                     # Look for Japanese text that is NOT the current title
                     if txt != current_title and re.search(r'[ァ-ン一-龥]', txt) and "円" not in txt and "年" not in txt:
                        current_title = txt
                        break

            year = extract_year(current_date)
            
            # Format Title with Year: "Title (YYYY)"
            final_title = current_title
            if year:
                final_title = f"{current_title} ({year})"
            
            item = {
                "jan": "", # Scraped data usually lacks JAN
                "title": final_title,
                "maker": "BANDAI SPIRITS",
                "series": target["series_default"] or "Universal Century", # Default fallback
                "grade": target["grade"],
                "scale": target["scale"]
            }
            items.append(item)
            
    print(f"  Found {len(items)} items.")
    return items

def main():
    # 1. Load existing
    existing_items = {}
    if os.path.exists(CSV_PATH):
        with open(CSV_PATH, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Key validation: use title as key
                key = row.get('title', '').strip()
                if key:
                    existing_items[key] = row
    
    print(f"Existing items: {len(existing_items)}")
    
    # 2. Scrape
    new_count = 0
    scraped_total = 0
    
    for target in TARGETS:
        scraped = scrape_page(target)
        scraped_total += len(scraped)
        
        for item in scraped:
            key = item['title'].strip()
            # Simple duplicate check
            if key not in existing_items:
                existing_items[key] = item
                new_count += 1
            else:
                # Update existing if needed? For now, prefer existing to keep JANs if present
                pass

    print(f"Total Scraped: {scraped_total}")
    print(f"New Items Added: {new_count}")
    print(f"Total Database: {len(existing_items)}")
    
    # 3. Save
    fieldnames = ['jan', 'title', 'maker', 'series', 'grade', 'scale']
    
    # Sort by Grade then Title for tidiness
    sorted_items = sorted(existing_items.values(), key=lambda x: (x.get('grade', ''), x.get('title', '')))
    
    with open(CSV_PATH, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for item in sorted_items:
            # Ensure all fields exist
            row = {k: item.get(k, '') for k in fieldnames}
            writer.writerow(row)
            
    print("CSV Update Complete.")

if __name__ == "__main__":
    main()
