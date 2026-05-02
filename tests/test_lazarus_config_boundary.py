import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LAZARUS_CONFIG = REPO_ROOT / 'src' / 'fpdev.lazarus.config.pas'


class LazarusConfigBoundaryTests(unittest.TestCase):
    set_signatures = [
        'function TLazarusIDEConfig.SetCompilerPath(const AFPCPath: string): Boolean;',
        'function TLazarusIDEConfig.SetLibraryPath(const APath: string): Boolean;',
        'function TLazarusIDEConfig.SetFPCSourcePath(const APath: string): Boolean;',
        'function TLazarusIDEConfig.SetMakePath(const APath: string): Boolean;',
        'function TLazarusIDEConfig.SetDebuggerPath(const APath: string): Boolean;',
        'function TLazarusIDEConfig.SetTargetOS(const AOS: string): Boolean;',
        'function TLazarusIDEConfig.SetTargetCPU(const ACPU: string): Boolean;',
    ]
    get_signatures = [
        'function TLazarusIDEConfig.GetCompilerPath: string;',
        'function TLazarusIDEConfig.GetLibraryPath: string;',
        'function TLazarusIDEConfig.GetFPCSourcePath: string;',
        'function TLazarusIDEConfig.GetMakePath: string;',
        'function TLazarusIDEConfig.GetDebuggerPath: string;',
        'function TLazarusIDEConfig.GetTargetOS: string;',
        'function TLazarusIDEConfig.GetTargetCPU: string;',
    ]

    @classmethod
    def setUpClass(cls):
        cls.text = LAZARUS_CONFIG.read_text(encoding='utf-8')
        cls.interface_text, cls.implementation_text = cls.text.split('implementation', 1)

    @classmethod
    def extract_section(cls, signature: str) -> str:
        pattern = re.compile(
            rf"{re.escape(signature)}(.*?)(?=\n(?:function|procedure) TLazarusIDEConfig\.|\nend\.)",
            re.S,
        )
        match = pattern.search(cls.text)
        if not match:
            raise AssertionError(f'Unable to find section for {signature}')
        return match.group(0)

    def test_lazarus_config_implementation_imports_envoptionsflow_only(self):
        self.assertIn('fpdev.lazarus.config.envoptionsflow', self.implementation_text)
        self.assertNotIn('fpdev.lazarus.config.envoptionsflow', self.interface_text)

    def test_envoptions_setters_delegate_to_helper(self):
        for signature in self.set_signatures:
            section = self.extract_section(signature)
            self.assertIn('SetLazarusEnvOptionValueCore(', section, signature)
            self.assertNotIn('FindOrCreateNode(', section, signature)
            self.assertNotIn('LoadXMLDoc(', section, signature)

    def test_envoptions_getters_delegate_to_helper(self):
        for signature in self.get_signatures:
            section = self.extract_section(signature)
            self.assertIn('GetLazarusEnvOptionValueCore(', section, signature)
            self.assertNotIn('GetElementsByTagName(', section, signature)
            self.assertNotIn('LoadXMLDoc(', section, signature)

    def test_inline_xml_helpers_leave_lazarus_config_unit(self):
        self.assertNotIn('function LoadXMLDoc(const APath: string): TXMLDocument;', self.text)
        self.assertNotIn('function SaveXMLDoc(ADoc: TXMLDocument; const APath: string): Boolean;', self.text)
        self.assertNotIn('function FindOrCreateNode(ADoc: TXMLDocument; AParent: TDOMElement;', self.text)
        self.assertNotIn('function GetNodeValue(ANode: TDOMElement; const AAttrName: string): string;', self.text)
        self.assertNotIn('procedure SetNodeValue(ANode: TDOMElement; const AAttrName, AValue: string);', self.text)


if __name__ == '__main__':
    unittest.main()
