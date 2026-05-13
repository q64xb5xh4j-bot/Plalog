#!/usr/bin/env python3
"""
Scrape model kit catalog from HobbySearch for multiple manufacturers.
Supports: Kotobukiya, Tamiya, Hasegawa, Aoshima
"""

import requests
from bs4 import BeautifulSoup
import csv
import re
from datetime import datetime
from urllib.parse import urljoin, parse_qs, urlparse

# Manufacturer configurations
MANUFACTURERS = {
    'kotobukiya': {
        'name': 'Kotobukiya',
        'search_url': 'https://www.1999.co.jp/eng/search?typ1=series&searchkey=figma&list=2',  # Fallback
        'output_file': 'kotobukiya_models.csv',
        'grade_map': {'figma': 'Figma', 'nendo': 'Nendoroid', 'scale': 'Scale Model'},
    },
    'tamiya': {
        'name': 'Tamiya',
        'search_url': 'https://www.tamiya.com/english/products/catalog.html',
        'output_file': 'tamiya_military.csv',
        'grade_map': {'MM': 'Military Miniature', '1/35': '1/35', '1/48': '1/48'},
    },
    'hasegawa': {
        'name': 'Hasegawa',
        'search_url': 'https://www.hasegawa-model.co.jp/products/',
        'output_file': 'hasegawa_aircraft.csv',
        'grade_map': {'Aircraft': 'Aircraft', '1/72': '1/72', '1/48': '1/48'},
    },
    'aoshima': {
        'name': 'Aoshima',
        'search_url': 'https://www.aoshima-bk.co.jp/product/',
        'output_file': 'aoshima_cars.csv',
        'grade_map': {'Car': 'The Model Car', '1/24': '1/24', '1/32': '1/32'},
    },
}

def scrape_hobbysearch_products(manufacturer_key):
    """
    Scrape product data from HobbySearch for a specific manufacturer.
    """
    mfg = MANUFACTURERS[manufacturer_key]
    products = []

    try:
        print(f"\n🔍 Scraping {mfg['name']} from HobbySearch...")

        # HobbySearch search URL (generic product search)
        search_url = f"https://www.hobbysearch.com/search/?q={mfg['name']}"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
        }

        response = requests.get(search_url, headers=headers, timeout=10)
        response.encoding = 'utf-8'

        if response.status_code != 200:
            print(f"⚠️  HobbySearch request failed: {response.status_code}")
            return products

        soup = BeautifulSoup(response.content, 'html.parser')

        # Extract product listings (adjust selector based on HobbySearch structure)
        items = soup.find_all('div', class_='item')

        for item in items[:50]:  # Limit to 50 products per brand for testing
            try:
                title_elem = item.find('h2') or item.find('a')
                if not title_elem:
                    continue

                title = title_elem.get_text(strip=True)
                if not title:
                    continue

                # Try to extract JAN from data attributes or text
                jan = ''
                jan_elem = item.find('span', class_='jan-code')
                if jan_elem:
                    jan = jan_elem.get_text(strip=True).replace('JAN:', '').strip()

                # Extract price for fallback info
                price_elem = item.find('span', class_='price')
                price = price_elem.get_text(strip=True) if price_elem else ''

                # Basic metadata extraction
                maker = mfg['name']
                series = mfg['name']  # Default series to brand name
                grade = 'Scale Model'
                scale = ''

                # Try to extract scale from title
                scale_match = re.search(r'(1/\d+)', title)
                if scale_match:
                    scale = scale_match.group(1)

                product = {
                    'jan': jan,
                    'title': title,
                    'maker': maker,
                    'series': series,
                    'grade': grade,
                    'scale': scale,
                }

                products.append(product)
                print(f"  ✓ {title[:50]}...")

            except Exception as e:
                print(f"  ⚠️  Error parsing item: {e}")
                continue

        print(f"✅ Extracted {len(products)} products from {mfg['name']}")
        return products

    except Exception as e:
        print(f"❌ Error scraping {mfg['name']}: {e}")
        return products

def save_products_to_csv(products, output_file):
    """Save products to CSV file."""
    if not products:
        print(f"⚠️  No products to save for {output_file}")
        return

    try:
        with open(output_file, 'w', encoding='utf-8', newline='') as f:
            fieldnames = ['jan', 'title', 'maker', 'series', 'grade', 'scale']
            writer = csv.DictWriter(f, fieldnames=fieldnames)

            writer.writeheader()
            for product in products:
                writer.writerow({
                    'jan': product.get('jan', ''),
                    'title': product.get('title', ''),
                    'maker': product.get('maker', ''),
                    'series': product.get('series', ''),
                    'grade': product.get('grade', ''),
                    'scale': product.get('scale', ''),
                })

        print(f"💾 Saved to {output_file}")

    except Exception as e:
        print(f"❌ Error saving {output_file}: {e}")

def main():
    print("=" * 60)
    print("🚀 Multi-Manufacturer Catalog Scraper (HobbySearch)")
    print("=" * 60)

    # Scrape priority manufacturers
    priority_brands = ['kotobukiya', 'tamiya', 'hasegawa']

    for brand in priority_brands:
        if brand not in MANUFACTURERS:
            print(f"⚠️  Unknown brand: {brand}")
            continue

        mfg = MANUFACTURERS[brand]
        products = scrape_hobbysearch_products(brand)

        if products:
            save_products_to_csv(products, mfg['output_file'])

    print("\n" + "=" * 60)
    print(f"✅ Catalog update complete at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

if __name__ == '__main__':
    main()
