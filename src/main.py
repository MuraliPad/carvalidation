# src/main.py
import sys
from selenium import webdriver
from src.config.settings import INPUT_PATH, OUTPUT_PATH, DRIVER_PATH
from src.utils.file_reader import FileParser
from src.utils.validator import ValuationValidator
from src.pages.valuation_page import ValuationPage


def main():
    # Initialize browser driver
    driver = webdriver.Chrome(executable_path=DRIVER_PATH)
    page = ValuationPage(driver)

    try:
        # Get registration numbers and expected values
        registrations = FileParser.get_reg_numbers(INPUT_PATH)
        expected_data = FileParser.get_expected_records(OUTPUT_PATH)

        # Track validation results
        results = {
            'total': 0,
            'passed': 0,
            'failed': 0,
            'errors': 0
        }

        for reg in registrations:
            results['total'] += 1
            try:
                print(f"\nProcessing registration: {reg}")

                # Perform vehicle search
                page.open()
                page.search_registration(reg)

                # Get actual details from website
                actual_details = page.get_vehicle_details()
                if not actual_details:
                    print(f"Error: No details found for {reg}")
                    results['errors'] += 1
                    continue

                # Get expected details
                expected = expected_data.get(reg)
                if not expected:
                    print(f"Warning: No expected data for {reg}")
                    results['errors'] += 1
                    continue

                # Validate details
                if ValuationValidator.compare_details(actual_details, expected):
                    print(f"✅ Match for {reg}")
                    results['passed'] += 1
                else:
                    print(f"❌ Mismatch for {reg}")
                    print(f"   Expected: {expected}")
                    print(f"   Actual:   {actual_details}")
                    results['failed'] += 1

            except Exception as e:
                print(f"⚠️  Error processing {reg}: {str(e)}")
                results['errors'] += 1

        # Print summary
        print("\n=== Validation Summary ===")
        print(f"Total registrations: {results['total']}")
        print(f"Passed: {results['passed']}")
        print(f"Failed: {results['failed']}")
        print(f"Errors: {results['errors']}")

        # Exit with appropriate status code
        if results['failed'] > 0 or results['errors'] > 0:
            sys.exit(1)

    finally:
        driver.quit()


if __name__ == "__main__":
    main()