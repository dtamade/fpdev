import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
I18N_SOURCE = REPO_ROOT / 'src' / 'fpc.i18n.pas'


class WindowsI18nContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = I18N_SOURCE.read_text(encoding='utf-8')

    def test_windows_i18n_declares_local_ui_language_compat_symbols(self):
        self.assertIn('TFPDevLangID = Word;', self.text)
        self.assertIn(
            "external 'kernel32.dll' name 'GetUserDefaultUILanguage';",
            self.text,
        )
        self.assertIn('LangID: TFPDevLangID;', self.text)
        self.assertIn('LangID := FpdevGetUserDefaultUILanguage;', self.text)

    def test_windows_i18n_does_not_depend_on_missing_windows_unit_symbols(self):
        self.assertNotIn('LangID: LANGID;', self.text)
        self.assertNotIn('LangID := GetUserDefaultUILanguage;', self.text)


if __name__ == '__main__':
    unittest.main()
