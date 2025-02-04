# src/tests/test_valuation.py (Updated)
import unittest
from selenium import webdriver
from src.pages.valuation_page import ValuationPage
from src.utils.file_reader import FileParser
from src.utils.validator import ValuationValidator
from src.config.settings import INPUT_PATH, OUTPUT_PATH, DRIVER_PATH


class TestCarValuation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.driver = webdriver.Chrome(executable_path=DRIVER_PATH)
        cls.reg_numbers = FileParser.get_reg_numbers(INPUT_PATH)
        cls.expected_records = FileParser.get_expected_records(OUTPUT_PATH)

    def test_all_valuations(self):
        page = ValuationPage(self.driver)
        for reg in self.reg_numbers:
            with self.subTest(registration=reg):
                page.open()
                page.search_registration(reg)

                actual_record = page.get_vehicle_details()
                self.assertIsNotNone(actual_record, f"No details found for {reg}")

                expected_record = self.expected_records.get(reg)
                self.assertIsNotNone(expected_record, f"No expected record for {reg}")

                self.assertTrue(
                    ValuationValidator.compare_records(actual_record, expected_record),
                    f"Mismatch for {reg}:\nExpected: {expected_record}\nActual: {actual_record}"
                )

    @classmethod
    def tearDownClass(cls):
        cls.driver.quit()