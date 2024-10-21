from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import requests
from bs4 import BeautifulSoup
import time
from PIL import Image
import pillow_avif
import io
import os

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
        self.image_dir = 'unit_images'
        os.makedirs(self.image_dir, exist_ok=True)

    def get_tech_level(self, item):
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

    def download_and_resize_image(self, img_url, unit_code):
        try:
            # Download image
            response = requests.get(img_url, headers=self.headers)
            response.raise_for_status()
            
            # Save AVIF temporarily to handle the format
            temp_avif = io.BytesIO(response.content)
            
            # Open with Pillow (pillow_avif plugin will handle the AVIF format)
            img = Image.open(temp_avif)
            
            # Convert to RGB if necessary
            if img.mode != 'RGB':
                img = img.convert('RGB')
            
            img = img.resize((256, 256), Image.Resampling.LANCZOS)
            
            # Save the image
            output_path = os.path.join(self.image_dir, f"{unit_code}.png")
            img.save(output_path, 'PNG')
            print(f"Saved image: {output_path}")
            return True
            
        except Exception as e:
            print(f"Error downloading/processing image for {unit_code}: {str(e)}")
            return False

    def extract_unit_info(self, item, category):
        try:
            # Extract href and unit code
            link = item.find('a')
            href = link['href'] if link else ''
            unit_code = href.split('/')[-1] if href else ''
            
            # Extract image URL - specifically getting the flex-unit-grid-img
            img_tag = item.find('img', class_='flex-unit-grid-img')
            if img_tag and 'src' in img_tag.attrs:
                img_url = img_tag['src']
                self.download_and_resize_image(img_url, unit_code)
            
            # Extract text block info
            text_block = item.find('div', class_='flex-unit-grid-text-block')
            if text_block:
                name_div = text_block.find('div', class_='flex-unit-grid-text')
                desc_div = text_block.find('div', class_='flex-unit-grid-text unit-grid-text sub')
                
                name = name_div.text.strip() if name_div else ''
                description = desc_div.text.strip() if desc_div else ''
                tech_level = self.get_tech_level(item)
                
                dynamic_value = self.get_dynamic_value(category, tech_level)
                
                print(f"Debug - Found unit: {name} - {description} - {tech_level}")
                if name and description:
                    return f"{name} - {description} - {tech_level}|/give {dynamic_value} {unit_code} 0"
        except Exception as e:
            print(f"Error extracting unit info: {str(e)}")
        return None

    def scrape_page(self, url, category):
        try:
            results = []
            
            # Set up Selenium WebDriver
            options = Options()
            options.headless = True
            driver = webdriver.Chrome(service=ChromeService(ChromeDriverManager().install()), options=options)
            driver.get(url)
            
            # Wait for the page to load completely
            time.sleep(5)
            
            # Get the page source and parse it with BeautifulSoup
            soup = BeautifulSoup(driver.page_source, 'html.parser')
            driver.quit()
            
            # Update the selector to match the provided HTML structure
            container = soup.select_one('div[data-w-tab="Grid"] > div.w-dyn-list > div.flex-unit-grid.w-dyn-items')
            if not container:
                print(f"Warning: Could not find main container for {category}")
                return []
                
            # Find all unit items within the container
            items = container.find_all('div', class_='flex-unit-grid-item')
            
            print(f"Debug - Found {len(items)} items")
            
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
    
    print("\nFinal Results Summary:")
    for category, units in scraper.results.items():
        print(f"{category}: {len(units)} units")

if __name__ == "__main__":
    main()