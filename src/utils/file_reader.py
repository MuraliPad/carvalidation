
import re
import csv



class FileParser:
    UK_REG_PATTERN = r'\b[A-Z]{2}\d{2}\s?[A-Z]{3}\b'  # Improved pattern

    @classmethod
    def get_reg_numbers(cls, file_path):
        with open(file_path) as f:
            content = f.read()
        return [reg.replace(" ", "") for reg in re.findall(cls.UK_REG_PATTERN, content)]



    @classmethod
    def get_expected_records(cls, file_path):
        """Read CSV output file and create normalized expected records"""
        expected = {}
        with open(file_path) as f:
            reader = csv.DictReader(f)

            for row in reader:
                # Normalize registration and store full record
                reg = row['VARIANT_REG'].replace(" ", "").upper()
                expected[reg] = {
                    'variant_reg': row['VARIANT_REG'].strip(),
                    'make_model': row['MAKE_MODEL'].strip(),
                    'year': row['YEAR'].strip()
                }
        return expected