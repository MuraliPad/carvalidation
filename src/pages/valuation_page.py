from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from src.config.settings import VALUATION_URL


class ValuationPage:
    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, 15)

    def open(self):
        self.driver.get(VALUATION_URL)

    def search_registration(self, reg_number):
        reg_input = self.wait.until(
            EC.presence_of_element_located((By.ID, 'vrm-input'))
        )
        reg_input.clear()
        reg_input.send_keys(reg_number)

        submit_btn = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, "//button[contains(., 'Value your car')]"))



        )
        submit_btn.click()

    def get_vehicle_details(self):
        try:
            # make_model = self.wait.until(
            #     EC.presence_of_element_located((By.CSS_SELECTOR, 'HeroVehicle__title-FAmg'))
            # ).text.strip()

            # Wait for the h1 element to be visible
            # make_model = self.wait.until(
            #     EC.visibility_of_element_located(
            #         (By.CSS_SELECTOR, "h1[data-cy='vehicleMakeAndModel']")
            #     )
            # )
            make_model = self.wait.until(
                EC.presence_of_element_located((By.XPATH, "//h1[@class='HeroVehicle__title-FAmG']"))
            )

            ul_element = self.wait.until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "ul[data-cy='vehicleSpecifics']"))
            )

            # Find all <li> elements within the <ul>
            li_elements = ul_element.find_elements(By.TAG_NAME, "li")

            # Extract the text content of each <li> element
            list_items = []
            for li in li_elements:
                list_items.append(li.text.strip())



            # Extract the year (assuming it's the first four digits)
            year = list_items[0]
            #year = text_content.split('Black')[0]
            return {'make_model': make_model.text.strip(), 'year': year}

        except Exception as e:
            print(f"Error getting vehicle details: {str(e)}")
            return None