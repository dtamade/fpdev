import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CROSS_SEARCH = REPO_ROOT / 'src' / 'fpdev.cross.search.pas'


class CrossSearchBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CROSS_SEARCH.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.text.split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_search_imports_searchpaths_unit(self):
        self.assertIn('fpdev.cross.searchpaths', self.text)

    def test_search_imports_searchdiag_unit(self):
        self.assertIn('fpdev.cross.searchdiag', self.text)

    def test_search_imports_searchflow_unit(self):
        self.assertIn('fpdev.cross.searchflow', self.text)

    def test_get_prefix_candidates_delegates_to_helper(self):
        section = self._section(
            'function TCrossToolchainSearch.GetPrefixCandidates(const ATarget: TCrossTarget): TStringArray;',
            'function TCrossToolchainSearch.SearchLayer1_FPDevManaged(',
        )

        self.assertIn('GetCrossPrefixCandidatesCore(ATarget)', section)
        self.assertNotIn("if CPU = 'arm' then", section)
        self.assertNotIn("Result[0] := 'arm-linux-gnueabihf-';", section)

    def test_search_libraries_delegates_to_helper(self):
        section = self._section(
            'function TCrossToolchainSearch.SearchLibraries(const ATarget: TCrossTarget): TStringArray;',
            'function TCrossToolchainSearch.DiagnoseTarget(const ATarget: TCrossTarget): TStringArray;',
        )

        self.assertIn('BuildCrossLibraryCandidatesCore(', section)
        self.assertNotIn('Candidates: array of string', section)
        self.assertNotIn('procedure AddCandidate', section)

    def test_diagnose_target_delegates_to_searchdiag_helper(self):
        section = self._section(
            'function TCrossToolchainSearch.DiagnoseTarget(const ATarget: TCrossTarget): TStringArray;',
            'function TCrossToolchainSearch.GetSearchLog: TStringArray;',
        )

        self.assertIn('BuildCrossDiagnoseLinesCore(', section)
        self.assertNotIn('procedure AddLine', section)
        self.assertNotIn("AddLine('Target: ' + ATarget.CPU + '-' + ATarget.OS);", section)

    def test_get_search_log_delegates_to_searchdiag_helper(self):
        section = self._section(
            'function TCrossToolchainSearch.GetSearchLog: TStringArray;',
            'function TCrossToolchainSearch.GetSearchLogCount: Integer;',
        )

        self.assertIn('BuildCrossSearchLogLinesCore(', section)
        self.assertNotIn("StatusStr := 'FOUND'", section)
        self.assertNotIn("StatusStr := 'miss'", section)

    def test_search_binutils_with_config_delegates_to_searchflow(self):
        section = self._section(
            'function TCrossToolchainSearch.SearchBinutilsWithConfig(const ATarget: TCrossTarget;',
            'function TCrossToolchainSearch.SearchLibraries(const ATarget: TCrossTarget): TStringArray;',
        )

        self.assertIn('ExecuteCrossBinutilsSearchCore(', section)
        self.assertNotIn("if ATarget.BinutilsPath <> '' then", section)
        self.assertNotIn('\n  ClearLog;', section)
        self.assertNotIn('Result := SearchLayer1_FPDevManaged(ATarget);', section)
        self.assertNotIn('Result := SearchLayer6_ConfigHints(ATarget, AFpcCfgPath);', section)


if __name__ == '__main__':
    unittest.main()
