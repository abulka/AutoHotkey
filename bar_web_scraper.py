import requests
from bs4 import BeautifulSoup
import time

class UnitScraper:
    def __init__(self):
        self.base_urls = {
            'Bots': 'https://www.beyondallreason.info/units/armada-bots',
            'Vehicles': 'https://www.beyondallreason.info/units/armada-vehicles',
            'Aircraft': 'https://www.beyondallreason.info/units/armada-aircraft',
            'Ships': 'https://www.beyondallreason.info/units/armada-ships',
            'Hovercraft': 'https://www.beyondallreason.info/units/armada-hovercraft',
            'Factories': 'https://www.beyondallreason.info/units/armada-factories',
            'Defense Buildings': 'https://www.beyondallreason.info/units/armada-defense-buildings',
            'Buildings': 'https://www.beyondallreason.info/units/armada-buildings'
        }
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        self.results = {}

    def get_tech_level(self, item):
        # Check for tech levels in order
        for level in range(1, 4):
            tech_div = item.find('div', {'title': f'Tech Level {level}'}, class_='flex-unit-grid-tech')
            if tech_div and not 'w-condition-invisible' in tech_div.get('class', []):
                return f'Tech Level {level}'
        return 'Unknown Tech Level'

    def get_dynamic_value(self, category, tech_level):
        if category in ['Bots', 'Vehicles', 'Aircraft']:
            return 10
        elif category in ['Buildings', 'Factories']:
            return 1
        elif tech_level == 'Tech Level 3':
            return 5
        return 1

    def extract_unit_info(self, item, category):
        try:
            # Extract href
            link = item.find('a')
            href = link['href'] if link else ''
            unit_code = href.split('/')[-1] if href else ''
            
            # Extract text block info
            text_block = item.find('div', class_='flex-unit-grid-text-block')
            if text_block:
                # Look for the name (it's directly in flex-unit-grid-text)
                name_div = text_block.find('div', class_='flex-unit-grid-text', recursive=False)
                # Look for description (it has both classes)
                desc_div = text_block.find('div', class_='flex-unit-grid-text unit-grid-text sub')
                
                name = name_div.text.strip() if name_div else ''
                description = desc_div.text.strip() if desc_div else ''
                tech_level = self.get_tech_level(item)
                
                dynamic_value = self.get_dynamic_value(category, tech_level)
                
                print(f"Debug - Found unit: {name} - {description} - {tech_level}")  # Debug line
                if name and description:  # Only return if we found both name and description
                    return f"{name} - {description} - {tech_level}|/give {dynamic_value} {unit_code} 0"
        except Exception as e:
            print(f"Error extracting unit info: {str(e)}")
        return None

    def scrape_page(self, url, category):
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            print(f"Debug - Response status code: {response.status_code}")  # Debug line
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Find all items with the correct class
            items = soup.find_all('div', class_='flex-unit-grid-item')
            
            print(f"Debug - Found {len(items)} items")  # Debug line
            
            results = []
            for item in items:
                info = self.extract_unit_info(item, category)
                if info:
                    results.append(info)
            
            return results
            
        except Exception as e:
            print(f"Error scraping {url}: {str(e)}")
            return []

    def scrape_all(self):
        for category, url in self.base_urls.items():
            print(f"\nScraping {category}...")
            units = self.scrape_page(url, category)
            self.results[category] = units
            print(f"Found {len(units)} units in {category}")
            time.sleep(1)  # Be nice to the server

    def save_results(self, filename='bar_units.txt'):
        with open(filename, 'w', encoding='utf-8') as f:
            for category, units in self.results.items():
                f.write(f"_{category}\n")
                for unit in units:
                    f.write(f"    {unit}\n")
                f.write("\n")
        print(f"Results saved to {filename}")

def main():
    scraper = UnitScraper()
    scraper.scrape_all()
    scraper.save_results()
    
    # Print final debug summary
    print("\nFinal Results Summary:")
    for category, units in scraper.results.items():
        print(f"{category}: {len(units)} units")

if __name__ == "__main__":
    main()