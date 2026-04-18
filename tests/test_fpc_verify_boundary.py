import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


class FPCVerifyBoundaryTests(unittest.TestCase):
    def test_validator_delegates_runtime_verification_to_shared_verifier(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.validator.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.fpc.verify', source)
        self.assertNotIn('function RunSmokeTest', source)
        self.assertNotIn("TProcessExecutor.Execute(FPCExe, ['-iV'], '')", source)

    def test_validator_does_not_redeclare_verification_result_record(self):
        source = (REPO_ROOT / 'src' / 'fpdev.fpc.validator.pas').read_text(encoding='utf-8')
        self.assertNotRegex(source, r'TVerificationResult\s*=\s*record')

    def assert_uses_shared_mock_helper(self, relative_path: str):
        source = (REPO_ROOT / relative_path).read_text(encoding='utf-8')
        self.assertIn('test_fpc_mock_helpers', source, relative_path)
        self.assertNotIn('procedure CompileMockFPC', source, relative_path)
        self.assertNotIn('ParamStr(0)', source, relative_path)
        self.assertIn('CompileMockFPCBinary(', source, relative_path)

    def test_pascal_verify_related_tests_share_mock_helper(self):
        self.assert_uses_shared_mock_helper('tests/test_fpc_verify.lpr')
        self.assert_uses_shared_mock_helper('tests/test_fpc_manager_installmetadata.lpr')
        self.assert_uses_shared_mock_helper('tests/test_cli_fpc_diag.lpr')

    def test_cli_verify_delegates_report_formatting_to_commandflow(self):
        source = (REPO_ROOT / 'src' / 'fpdev.cmd.fpc.verify.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.fpc.verifycommandflow', source)
        self.assertIn('PrepareFPCVerifyCommandPlanCore(', source)
        self.assertIn('ExecuteFPCVerifyCommandPlanCore(', source)
        self.assertNotIn('[1/3] Checking version...', source)
        self.assertNotIn('Verification complete: FPC ', source)
        self.assertNotIn('HasFPCMetadata(', source)
        self.assertNotIn('ResolveInstalledFPCInstallPathCore(', source)


if __name__ == '__main__':
    unittest.main()
