import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INDEX_SOURCE = REPO_ROOT / 'src' / 'fpdev.index.pas'
INDEX_COMMANDFLOW = REPO_ROOT / 'src' / 'fpdev.index.commandflow.pas'


class IndexBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = INDEX_SOURCE.read_text(encoding='utf-8')
        cls.commandflow = INDEX_COMMANDFLOW.read_text(encoding='utf-8')

    @classmethod
    def _section(cls, start: str, end: str) -> str:
        tail = cls.source.split(start, 1)[1]
        return tail.split(end, 1)[0]

    @classmethod
    def _commandflow_section(cls, start: str, end: str) -> str:
        tail = cls.commandflow.split('implementation', 1)[1].split(start, 1)[1]
        return tail.split(end, 1)[0]

    def test_index_imports_serviceflow_and_paths_units(self):
        self.assertIn('fpdev.index.serviceflow', self.source)
        self.assertIn('fpdev.paths', self.source)

    def test_constructor_uses_portable_cache_dir_helper(self):
        section = self._section(
            'constructor TFPDevIndex.Create(const AMirrorPreference: string);',
            'destructor TFPDevIndex.Destroy;',
        )
        self.assertIn('FCacheDir := GetCacheDir;', section)
        self.assertNotIn("GetEnvironmentVariable('HOME')", section)
        self.assertNotIn("GetEnvironmentVariable('APPDATA')", section)

    def test_initialize_delegates_remote_cache_loading_to_serviceflow(self):
        section = self._section(
            'function TFPDevIndex.Initialize: Boolean;',
            'function TFPDevIndex.GetRepoInfo(AType: TRepoType): TRepoInfo;',
        )
        self.assertIn('LoadRemoteJSONWithCacheCore(', section)
        self.assertNotIn('FIndexData := FetchJSON(IndexURL);', section)
        self.assertNotIn("LogFmt('Primary failed, trying fallback: %s', [IndexURL]);", section)

    def test_download_surfaces_delegate_manifest_io_and_parse_to_helper(self):
        for start, end in (
            (
                'function TFPDevIndex.GetBootstrapDownloadInfo(const AVersion, APlatform: string;',
                'function TFPDevIndex.GetFPCDownloadInfo(const AVersion, APlatform: string;',
            ),
            (
                'function TFPDevIndex.GetFPCDownloadInfo(const AVersion, APlatform: string;',
                'function TFPDevIndex.GetLazarusDownloadInfo(const AVersion, APlatform: string;',
            ),
            (
                'function TFPDevIndex.GetLazarusDownloadInfo(const AVersion, APlatform: string;',
                'function TFPDevIndex.ListBootstrapVersions: TStringArray;',
            ),
        ):
            section = self._section(start, end)
            self.assertIn('ResolveRepoDownloadInfo(', section)
            self.assertNotIn('ManifestData := FetchJSON(ManifestURL);', section)
            self.assertNotIn('LayoutObj := PlatformData.Objects[\'layout\'];', section)

    def test_version_list_surfaces_delegate_manifest_loading_to_helper(self):
        for start, end in (
            (
                'function TFPDevIndex.ListBootstrapVersions: TStringArray;',
                'function TFPDevIndex.ListFPCVersions: TStringArray;',
            ),
            (
                'function TFPDevIndex.ListFPCVersions: TStringArray;',
                'function TFPDevIndex.ListLazarusVersions: TStringArray;',
            ),
            (
                'function TFPDevIndex.ListLazarusVersions: TStringArray;',
                'end.',
            ),
        ):
            section = self._section(start, end)
            self.assertIn('ListRepoVersions(', section)
            self.assertNotIn('ManifestData := FetchJSON(ManifestURL);', section)
            self.assertNotIn('SetLength(Result, Releases.Count);', section)

    def test_commandflow_assigns_context_output_before_running_index(self):
        show_section = self._commandflow_section(
            'function RunIndexShowWithFactory(',
            'function RunIndexUpdate(const Ctx: IContext): Integer;',
        )
        update_section = self._commandflow_section(
            'function RunIndexUpdateWithFactory(',
            'end.',
        )
        self.assertIn('Index.Output := Ctx.Out;', show_section)
        self.assertIn('Index.Output := Ctx.Out;', update_section)


if __name__ == '__main__':
    unittest.main()
