import csv
import time
import urllib.request
import urllib.parse
import re
import shutil
import os
import sys

# --- CONFIGURATION ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_FILE = os.path.join(SCRIPT_DIR, "..", "gunpla_catalog.csv")
BACKUP_FILE = os.path.join(SCRIPT_DIR, "..", "gunpla_catalog_before_hobbysearch.csv")

def search_hobbysearch(query, retry_count=0, max_retries=3):
    """
    Search Hobby Search (1999.co.jp) for the item and extract JAN code.
    Includes exponential backoff for rate limiting (429 errors).
    Strategy:
    1. Search for the item
    2. Get first product link (/10xxxxxxx format)
    3. Visit product page
    4. Extract JAN code from spec table
    """
    encoded_query = urllib.parse.quote(query)
    search_url = f"https://www.1999.co.jp/search?searchkey={encoded_query}&typ1_c=101"

    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ja,en-US;q=0.7,en;q=0.3',
    }

    try:
        # Step 1: Search
        req = urllib.request.Request(search_url)
        for key, value in headers.items():
            req.add_header(key, value)

        with urllib.request.urlopen(req, timeout=15) as res:
            html = res.read().decode('utf-8', errors='ignore')

            # Look for product links: /10xxxxxx (7-8 digits starting with 10)
            product_links = re.findall(r'/(\d{8})"', html)

            if not product_links:
                return None

            # Step 2: Visit first product page
            product_id = product_links[0]
            product_url = f"https://www.1999.co.jp/{product_id}"

            # Increased polite delay (2 seconds base)
            time.sleep(2.0)

            req2 = urllib.request.Request(product_url)
            for key, value in headers.items():
                req2.add_header(key, value)

            with urllib.request.urlopen(req2, timeout=15) as res2:
                product_html = res2.read().decode('utf-8', errors='ignore')

                # Step 3: Extract JAN (13 digits in table cell or near JAN label)
                # Pattern 1: In table cell
                jan_match = re.search(r'>(\d{13})<', product_html)
                if jan_match:
                    jan = jan_match.group(1)
                    # Validate it's a Japanese JAN (starts with 45 or 49)
                    if jan.startswith(('45', '49')):
                        return jan

                # Pattern 2: Near JAN label
                jan_match2 = re.search(r'JAN[コード:：\s]*[：:]*\s*(\d{13})', product_html)
                if jan_match2:
                    return jan_match2.group(1)

                # Pattern 3: Any 45/49 starting 13 digits
                jan_match3 = re.search(r'(4[59]\d{11})', product_html)
                if jan_match3:
                    return jan_match3.group(1)

    except urllib.error.HTTPError as e:
        # Handle rate limiting (429)
        if e.code == 429 and retry_count < max_retries:
            wait_time = (2 ** retry_count) * 5  # Exponential backoff: 5s, 10s, 20s
            print(f"  [429 Rate Limited] Waiting {wait_time}s before retry ({retry_count+1}/{max_retries})...")
            time.sleep(wait_time)
            return search_hobbysearch(query, retry_count + 1, max_retries)
        # Other HTTP errors (4xx, 5xx) - silently fail
        pass
    except Exception as e:
        # Silently fail on timeout, connection errors, etc.
        pass

    return None

def generate_search_queries(title, grade):
    """
    Generate multiple search query variations to maximize hit rate.
    """
    queries = []
    
    # Base parts
    prefix = ""
    if grade and grade not in title:
        prefix = f"{grade} "
    
    full_title = f"{prefix}{title}".strip()
    
    # 1. User Hint Strategy: & -> /, keep +
    # Example: "Zakuwarrioni+Blaze&Gunner" -> "Zakuwarrioni+Blaze/Gunner"
    q1 = full_title.replace('&', '/').replace('＆', '/')
    queries.append(q1)
    
    # 2. Space Strategy: Replace all symbols with space (standard cleaning)
    # Example: "Zakuwarrioni+Blaze&Gunner" -> "Zakuwarrioni Blaze Gunner"
    q2 = re.sub(r'[+＋&＆/／]', ' ', full_title)
    q2 = re.sub(r'\s+', ' ', q2).strip()
    if q2 != q1:
        queries.append(q2)
        
    # 3. Simple Strategy: Just the title part before symbols if it fails
    # Sometimes less is more
    # matches = re.match(r'^([^+&/]+)', title)
    # if matches:
    #     q3 = f"{prefix}{matches.group(1)}".strip()
    #     if len(q3) > 5 and q3 not in queries:
    #        queries.append(q3)
            
    return queries

def main():
    print("=== JAN Code Auto-Fill Tool (Multi-Query Retry Mode) ===")
    print(f"Target CSV: {TARGET_FILE}")

    # 1. Backup
    if os.path.exists(TARGET_FILE):
        shutil.copy2(TARGET_FILE, BACKUP_FILE)
        print(f"Backup saved to: {BACKUP_FILE}")
    else:
        print("Target file not found!")
        sys.exit(1)

    # 2. Read and Process
    updated_items = []
    headers = []
    
    with open(TARGET_FILE, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames
        rows = list(reader)

    total = len(rows)
    updated_count = 0
    processed_count = 0
    skipped_count = 0
    
    print(f"\nTotal items: {total}")
    
    try:
        for i, row in enumerate(rows):
            title = row.get('title', '')
            grade = row.get('grade', '')
            current_jan = row.get('jan', '')
            
            # Skip if JAN already exists
            if current_jan and len(str(current_jan)) > 7:
                updated_items.append(row)
                skipped_count += 1
                continue
                
            processed_count += 1
            print(f"[{i+1}/{total}] {title[:30]}...", end='', flush=True)
            
            # Try multiple queries
            queries = generate_search_queries(title, grade)
            found_jan = None
            
            for q in queries:
                # print(f" [Try: {q}]", end='') 
                found_jan = search_hobbysearch(q)
                if found_jan:
                    break
                    
            if found_jan:
                print(f" FOUND! ({found_jan})")
                row['jan'] = found_jan
                updated_count += 1
            else:
                print(" -")
                
            updated_items.append(row)

            # Save every 25 successful finds (reduced frequency)
            if updated_count > 0 and updated_count % 25 == 0:
                with open(TARGET_FILE, 'w', encoding='utf-8', newline='') as f:
                    writer = csv.DictWriter(f, fieldnames=headers)
                    writer.writeheader()
                    writer.writerows(updated_items + rows[i+1:])
                print(f" (Saved: {updated_count} JANs)")

    except KeyboardInterrupt:
        print("\n\nStopping...")
    
    # Final Save
    with open(TARGET_FILE, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(updated_items + rows[len(updated_items):] if len(updated_items) < len(rows) else updated_items)

    print(f"\n=== Complete ===")
    print(f"Skipped (Already filled): {skipped_count}")
    print(f"Processed (Retry): {processed_count}")
    print(f"Found JANs: {updated_count}")
    print(f"Success rate: {updated_count/processed_count*100:.1f}%" if processed_count > 0 else "N/A")

if __name__ == "__main__":
    main()
