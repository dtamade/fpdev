import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CROSS_BUILD_COMMAND = REPO_ROOT / 'src' / 'fpdev.cmd.cross.build.pas'


class CrossBuildBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.command = CROSS_BUILD_COMMAND.read_text(encoding='utf-8')

    def test_cli_build_delegates_parse_and_runtime_to_commandflow(self):
        self.assertIn('fpdev.cross.buildcommandflow', self.command)
        self.assertIn('PrepareCrossBuildCommandPlanCore(', self.command)
        self.assertIn('ExecuteCrossBuildCommandPlanCore(', self.command)

    def test_cli_build_no_longer_inlines_parse_preflight_or_dryrun_messages(self):
        self.assertNotIn('function ParseTargetString(', self.command)
        self.assertNotIn("GetFlagValue(AParams, 'source'", self.command)
        self.assertNotIn("GetFlagValue(AParams, 'sandbox'", self.command)
        self.assertNotIn("GetFlagValue(AParams, 'version'", self.command)
        self.assertNotIn('Build Plan:', self.command)
        self.assertNotIn('FPC source tree not found:', self.command)
        self.assertNotIn('FPC source tree incomplete (missing Makefile):', self.command)
        self.assertNotIn('Cross-compilation completed successfully.', self.command)
        self.assertNotIn("Ctx.Err.WriteLn('Stage: ' +", self.command)


if __name__ == '__main__':
    unittest.main()
