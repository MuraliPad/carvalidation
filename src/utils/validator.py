class ValuationValidator:
    @staticmethod
    def normalize_text(text):
        return text.lower().strip()

    @classmethod
    def compare_details(cls, actual, expected):
        return (
                cls.normalize_text(actual['make_model']) == cls.normalize_text(expected['make_model'])
                and cls.normalize_text(actual['year']) == cls.normalize_text(expected['year'])
        )