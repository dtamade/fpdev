import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / 'src'


class CommandNamespaceHygieneTests(unittest.TestCase):
    def assert_no_token(self, path: Path, token: str):
        text = path.read_text(encoding='utf-8')
        self.assertNotIn(token, text, f'{path} still references {token}')

    def test_package_manager_unit_owns_real_manager_type(self):
        text = (SRC / 'fpdev.package.manager.pas').read_text(encoding='utf-8')
        self.assertIn('TPackageManager = class', text)
        self.assertNotIn('TPackageManager = fpdev.cmd.package.TPackageManager;', text)

    def test_cmd_package_unit_is_compat_shell_for_manager_type(self):
        text = (SRC / 'fpdev.cmd.package.pas').read_text(encoding='utf-8')
        self.assertIn('TPackageManager = fpdev.package.manager.TPackageManager;', text)
        self.assertNotIn('TPackageManager = class', text)

    def test_command_suggestions_unit_owns_fuzzy_helper(self):
        suggestions_path = SRC / 'fpdev.command.suggestions.pas'
        self.assertTrue(suggestions_path.exists(), f'Missing {suggestions_path}')
        text = suggestions_path.read_text(encoding='utf-8')
        self.assertIn('function FindSimilarCommand', text)

    def test_command_registry_has_no_inline_fuzzy_helper(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('function LevenshteinDistance', text)
        self.assertNotIn('function FindSimilarCommand', text)

    def test_command_help_routing_unit_owns_help_rewrite(self):
        helper_path = SRC / 'fpdev.command.helprouting.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function RewriteTrailingHelpFlag', text)

    def test_command_registry_has_no_inline_help_rewrite_block(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('Help flag handling:', text)
        self.assertNotIn('fpc --help         -> fpc help', text)

    def test_command_diagnostics_unit_owns_registry_output_rendering(self):
        helper_path = SRC / 'fpdev.command.diagnostics.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure WriteUnknownCommandSuggestion', text)
        self.assertIn('procedure WriteMissingSubcommandUsage', text)

    def test_command_registry_has_no_inline_diagnostic_rendering(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('Did you mean "', text)
        self.assertNotIn('Run "fpdev help" for available commands.', text)
        self.assertNotIn('Use "fpdev ', text)

    def test_help_routing_unit_owns_leaf_help_context(self):
        helper_path = SRC / 'fpdev.help.routing.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('THelpContext = class', text)
        self.assertIn('function TryDispatchLeafHelp', text)

    def test_cmd_help_unit_removed_after_commandflow_split(self):
        self.assertFalse((SRC / 'fpdev.cmd.help.pas').exists())

    def test_help_usage_unit_owns_dynamic_usage_routing(self):
        helper_path = SRC / 'fpdev.help.usage.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function PrintUsageCore', text)
        self.assertIn('TryDispatchLeafHelp', text)
        self.assertIn('GlobalCommandRegistry.ListChildren', text)
        self.assertNotIn("if cmd = 'fpc' then", text)
        self.assertNotIn("else if cmd = 'system' then", text)
        self.assertNotIn('HELP_FPC_SUBCOMMANDS', text)

    def test_help_commandflow_unit_owns_execute_flow(self):
        helper_path = SRC / 'fpdev.help.commandflow.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure ExecuteHelpCore', text)
        self.assertIn('function PrintUsageShellCore', text)
        self.assertIn('procedure ListChildrenDynamicShellCore', text)
        self.assertIn('WriteRootHelpCore', text)
        self.assertIn('PrintUsageCore', text)
        self.assertIn('ListChildrenDynamicCore', text)

    def test_help_commandflow_unit_owns_domain_help_execute_flow(self):
        helper_path = SRC / 'fpdev.help.commandflow.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure WriteDomainHelpOverviewCore', text)
        self.assertIn('function ExecuteDomainHelpCommandCore', text)
        self.assertIn('WriteHelpItemsCore', text)

    def test_help_catalog_unit_owns_domain_help_lists(self):
        helper_path = SRC / 'fpdev.help.catalog.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('THelpListItem = record', text)
        self.assertIn('procedure WriteHelpItemsCore', text)
        self.assertIn('function BuildFPCHelpItems', text)
        self.assertIn('function BuildPackageHelpItems', text)
        self.assertIn('function BuildProjectHelpItems', text)
        self.assertIn('function BuildCrossHelpItems', text)
        self.assertIn('function BuildLazarusHelpItems', text)
        self.assertIn('function BuildRepoHelpItems', text)

    def test_no_cmd_help_compat_shell_remains(self):
        self.assertFalse((SRC / 'fpdev.cmd.help.pas').exists())

    def test_help_rootview_unit_owns_root_help_rendering(self):
        helper_path = SRC / 'fpdev.help.rootview.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure WriteRootHelpCore', text)
        self.assertNotIn('--check-toolchain', text)
        self.assertNotIn('--self-test', text)

    def test_system_help_is_shell_for_help_commandflow(self):
        text = (SRC / 'fpdev.cmd.system.help.pas').read_text(encoding='utf-8')
        self.assertIn('ExecuteHelpCore', text)
        self.assertNotIn('fpdev.cmd.help.execute', text)

    def test_domain_help_units_use_shared_help_catalog(self):
        expectations = {
            'fpdev.cmd.fpc.help.pas': 'BuildFPCHelpItems',
            'fpdev.cmd.package.help.pas': 'BuildPackageHelpItems',
            'fpdev.cmd.project.help.pas': 'BuildProjectHelpItems',
            'fpdev.cmd.cross.help.pas': 'BuildCrossHelpItems',
            'fpdev.cmd.lazarus.help.pas': 'BuildLazarusHelpItems',
        }
        banned = {
            'fpdev.cmd.fpc.help.pas': "Ctx.Out.WriteLn('  install          ' + _(HELP_FPC_INSTALL_DESC))",
            'fpdev.cmd.package.help.pas': "Ctx.Out.WriteLn('  install          ' + _(HELP_PACKAGE_INSTALL_DESC))",
            'fpdev.cmd.project.help.pas': "Ctx.Out.WriteLn('  new              ' + _(HELP_PROJECT_NEW_DESC))",
            'fpdev.cmd.cross.help.pas': "Ctx.Out.WriteLn('  list             ' + _(HELP_CROSS_LIST_DESC))",
            'fpdev.cmd.lazarus.help.pas': "Ctx.Out.WriteLn('  install            ' + _(HELP_LAZARUS_INSTALL_DESC))",
        }
        for filename, token in expectations.items():
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertIn(token, text, f'{filename} should use shared help catalog')
            self.assertNotIn(banned[filename], text, f'{filename} still has inline root help list rows')

    def test_fpc_help_details_unit_owns_fpc_subcommand_help(self):
        helper_path = SRC / 'fpdev.help.details.fpc.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function WriteFPCHelpDetailsCore', text)
        self.assertIn("Usage: fpdev fpc verify <version>", text)
        self.assertIn("Usage: fpdev fpc cache <subcommand>", text)
        self.assertIn("Usage: fpdev fpc policy <subcommand>", text)

    def test_package_help_details_unit_owns_package_subcommand_help(self):
        helper_path = SRC / 'fpdev.help.details.package.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function WritePackageHelpDetailsCore', text)
        self.assertIn('HELP_PACKAGE_DEPS_USAGE', text)
        self.assertIn('HELP_PACKAGE_WHY_HINT', text)

    def test_project_help_details_unit_owns_project_subcommand_help(self):
        helper_path = SRC / 'fpdev.help.details.project.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function WriteProjectHelpDetailsCore', text)
        self.assertIn('HELP_PROJECT_NEW_USAGE', text)
        self.assertIn('HELP_PROJECT_CLEAN_OPT_HELP', text)
        self.assertIn("Usage: fpdev project template <subcommand>", text)

    def test_cross_help_details_unit_owns_cross_subcommand_help(self):
        helper_path = SRC / 'fpdev.help.details.cross.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function WriteCrossHelpDetailsCore', text)
        self.assertIn('HELP_CROSS_BUILD_USAGE', text)
        self.assertIn('HELP_CROSS_CONFIGURE_OPTIONS', text)

    def test_lazarus_help_details_unit_owns_lazarus_subcommand_help(self):
        helper_path = SRC / 'fpdev.help.details.lazarus.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function WriteLazarusHelpDetailsCore', text)
        self.assertIn('HELP_LAZARUS_INSTALL_USAGE', text)
        self.assertIn('HELP_LAZARUS_CONFIGURE_OPT_HELP', text)

    def test_cmd_fpc_help_has_no_inline_subcommand_details(self):
        text = (SRC / 'fpdev.cmd.fpc.help.pas').read_text(encoding='utf-8')
        self.assertIn('WriteFPCHelpDetailsCore', text)
        self.assertNotIn("Usage: fpdev fpc verify <version>", text)
        self.assertNotIn("Usage: fpdev fpc cache <subcommand>", text)
        self.assertNotIn("Usage: fpdev fpc policy <subcommand>", text)

    def test_cmd_package_help_has_no_inline_subcommand_details(self):
        text = (SRC / 'fpdev.cmd.package.help.pas').read_text(encoding='utf-8')
        self.assertIn('WritePackageHelpDetailsCore', text)
        self.assertNotIn('HELP_PACKAGE_DEPS_USAGE', text)
        self.assertNotIn('HELP_PACKAGE_WHY_HINT', text)

    def test_cmd_project_help_has_no_inline_subcommand_details(self):
        text = (SRC / 'fpdev.cmd.project.help.pas').read_text(encoding='utf-8')
        self.assertIn('WriteProjectHelpDetailsCore', text)
        self.assertNotIn('HELP_PROJECT_NEW_USAGE', text)
        self.assertNotIn('HELP_PROJECT_CLEAN_OPT_HELP', text)
        self.assertNotIn("Usage: fpdev project template <subcommand>", text)

    def test_cmd_cross_help_has_no_inline_subcommand_details(self):
        text = (SRC / 'fpdev.cmd.cross.help.pas').read_text(encoding='utf-8')
        self.assertIn('WriteCrossHelpDetailsCore', text)
        self.assertNotIn('HELP_CROSS_BUILD_USAGE', text)
        self.assertNotIn('HELP_CROSS_CONFIGURE_OPTIONS', text)

    def test_cmd_lazarus_help_has_no_inline_subcommand_details(self):
        text = (SRC / 'fpdev.cmd.lazarus.help.pas').read_text(encoding='utf-8')
        self.assertIn('WriteLazarusHelpDetailsCore', text)
        self.assertNotIn('HELP_LAZARUS_INSTALL_USAGE', text)
        self.assertNotIn('HELP_LAZARUS_CONFIGURE_OPT_HELP', text)

    def test_repo_help_details_unit_owns_repo_subcommand_help(self):
        helper_path = SRC / 'fpdev.help.details.repo.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function WriteRepoHelpDetailsCore', text)
        self.assertIn('HELP_REPO_VERSIONS_USAGE', text)
        self.assertIn('HELP_REPO_DEFAULT_OPT_HELP', text)

    def test_cmd_repo_help_uses_shared_repo_help_helpers(self):
        text = (SRC / 'fpdev.cmd.repo.help.pas').read_text(encoding='utf-8')
        self.assertIn('BuildRepoHelpItems', text)
        self.assertIn('WriteRepoHelpDetailsCore', text)
        self.assertNotIn("Ctx.Out.WriteLn('  add              ' + _(HELP_REPO_ADD_DESC))", text)
        self.assertNotIn('HELP_REPO_VERSIONS_USAGE', text)

    def test_domain_help_units_are_shells_for_shared_help_commandflow(self):
        expectations = {
            'fpdev.cmd.fpc.help.pas': 'ShowFPCHelp',
            'fpdev.cmd.package.help.pas': 'ShowPackageHelp',
            'fpdev.cmd.project.help.pas': 'ShowProjectHelp',
            'fpdev.cmd.cross.help.pas': 'ShowCrossHelp',
            'fpdev.cmd.lazarus.help.pas': 'ShowLazarusHelp',
            'fpdev.cmd.repo.help.pas': 'ShowRepoHelp',
        }
        for filename, banned_token in expectations.items():
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertIn('ExecuteDomainHelpCommandCore', text, f'{filename} should use shared domain help flow')
            self.assertNotIn(banned_token, text, f'{filename} still owns inline overview rendering')
            self.assertNotIn('function ShowSubcommandHelp', text, f'{filename} still owns inline detail dispatch')

    def test_system_help_details_unit_owns_env_and_perf_help(self):
        helper_path = SRC / 'fpdev.help.details.system.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure WriteSystemEnvHelpCore', text)
        self.assertIn('procedure WriteSystemPerfHelpCore', text)
        self.assertIn('procedure WriteSystemConfigHelpCore', text)
        self.assertIn('procedure WriteSystemIndexHelpCore', text)
        self.assertIn('procedure WriteSystemCacheHelpCore', text)
        self.assertIn('Usage: fpdev system env [command]', text)
        self.assertIn('fpdev system perf - Performance Monitoring', text)
        self.assertIn('Usage: fpdev system config <command> [options]', text)
        self.assertIn('Usage: fpdev system index <command>', text)
        self.assertIn('Usage: fpdev system cache <command>', text)

    def test_command_namespace_shell_unit_owns_root_namespace_dispatch(self):
        helper_path = SRC / 'fpdev.command.namespacehelp.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function ExecuteNamespaceRootCommandCore', text)
        self.assertIn('Error: Unknown subcommand:', text)
        self.assertIn("(AParams[0] = 'help')", text)

    def test_cmd_env_uses_system_help_details_helper(self):
        text = (SRC / 'fpdev.cmd.env.pas').read_text(encoding='utf-8')
        self.assertIn('WriteSystemEnvHelpCore', text)
        self.assertNotIn("Ctx.Out.WriteLn('Usage: fpdev system env [command]')", text)

    def test_cmd_env_uses_namespace_shell_helper(self):
        text = (SRC / 'fpdev.cmd.env.pas').read_text(encoding='utf-8')
        self.assertIn('ExecuteNamespaceRootCommandCore', text)
        self.assertNotIn("if (SubCmd = 'help')", text)

    def test_cmd_perf_uses_system_help_details_helper(self):
        text = (SRC / 'fpdev.cmd.perf.pas').read_text(encoding='utf-8')
        self.assertIn('WriteSystemPerfHelpCore', text)
        self.assertNotIn("LO.WriteLn('fpdev system perf - Performance Monitoring')", text)

    def test_perf_commandflow_unit_owns_perf_runtime_execution(self):
        helper_path = SRC / 'fpdev.perf.commandflow.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function ExecutePerfReportCore', text)
        self.assertIn('function ExecutePerfSummaryCore', text)
        self.assertIn('function ExecutePerfClearCore', text)
        self.assertIn('function ExecutePerfSaveCore', text)

    def test_cmd_perf_has_no_inline_perf_runtime_messages(self):
        text = (SRC / 'fpdev.cmd.perf.pas').read_text(encoding='utf-8')
        self.assertIn('ExecutePerfReportCore', text)
        self.assertIn('ExecutePerfSummaryCore', text)
        self.assertIn('ExecutePerfClearCore', text)
        self.assertIn('ExecutePerfSaveCore', text)
        self.assertNotIn("LO.WriteLn('No performance data available.')", text)
        self.assertNotIn("LO.WriteLn('Run a build operation first (e.g., fpdev fpc install).')", text)
        self.assertNotIn("LO.WriteLn('Performance data cleared.')", text)
        self.assertNotIn("LE.WriteLn('Error: Missing filename')", text)
        self.assertNotIn("LO.WriteLn('Performance report saved to: ' + FileName)", text)

    def test_doctor_view_unit_owns_help_and_summary_rendering(self):
        helper_path = SRC / 'fpdev.doctor.view.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function BuildDoctorHelpTextCore', text)
        self.assertIn('procedure WriteDoctorSectionCore', text)
        self.assertIn('procedure WriteDoctorSummaryCore', text)
        self.assertIn('function BuildDoctorJSONSummaryCore', text)

    def test_doctor_checks_unit_owns_doctor_check_orchestration(self):
        helper_path = SRC / 'fpdev.doctor.checks.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure ExecuteDoctorFPCChecksCore', text)
        self.assertIn('procedure ExecuteDoctorLazarusChecksCore', text)
        self.assertIn('procedure ExecuteDoctorConfigChecksCore', text)
        self.assertIn('procedure ExecuteDoctorEnvironmentChecksCore', text)
        self.assertIn('procedure ExecuteDoctorBuildToolChecksCore', text)
        self.assertIn('procedure ExecuteDoctorDebuggerChecksCore', text)
        self.assertIn('procedure ExecuteDoctorDiskSpaceChecksCore', text)

    def test_cmd_doctor_has_no_inline_help_or_summary_rendering(self):
        text = (SRC / 'fpdev.cmd.doctor.pas').read_text(encoding='utf-8')
        self.assertIn('BuildDoctorHelpTextCore', text)
        self.assertIn('WriteDoctorSummaryCore', text)
        self.assertIn('BuildDoctorJSONSummaryCore', text)
        self.assertNotIn("HELP_DOCTOR = 'Usage: fpdev system doctor [options]'", text)
        self.assertNotIn("Ctx.Out.WriteLn('Summary')", text)
        self.assertNotIn('{"checks":[', text)

    def test_cmd_doctor_has_no_inline_check_methods(self):
        text = (SRC / 'fpdev.cmd.doctor.pas').read_text(encoding='utf-8')
        self.assertIn('ExecuteDoctorFPCChecksCore', text)
        self.assertIn('ExecuteDoctorLazarusChecksCore', text)
        self.assertNotIn('function TDoctorCommand.CheckFPCInstallation', text)
        self.assertNotIn('function TDoctorCommand.CheckLazarusInstallation', text)
        self.assertNotIn('function TDoctorCommand.CheckConfigFile', text)
        self.assertNotIn('function TDoctorCommand.CheckEnvironmentVariables', text)
        self.assertNotIn('function TDoctorCommand.CheckMakeAvailable', text)
        self.assertNotIn('function TDoctorCommand.CheckGitAvailable', text)
        self.assertNotIn('function TDoctorCommand.CheckDebuggerAvailable', text)
        self.assertNotIn('function TDoctorCommand.CheckDiskSpace', text)

    def test_doctor_runtime_unit_owns_tool_exec_and_writable_checks(self):
        helper_path = SRC / 'fpdev.doctor.runtime.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function RunDoctorToolVersionCore', text)
        self.assertIn('function CheckDoctorWriteableDirCore', text)

    def test_fpc_doctor_view_unit_owns_help_and_summary(self):
        helper_path = SRC / 'fpdev.fpc.doctor.view.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure WriteFPCDoctorHelpCore', text)
        self.assertIn('procedure WriteFPCDoctorSummaryCore', text)

    def test_fpc_doctor_checks_unit_owns_fpc_doctor_execution(self):
        helper_path = SRC / 'fpdev.fpc.doctor.checks.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function ExecuteFPCDoctorChecksCore', text)

    def test_cross_doctor_view_unit_owns_help_and_summary(self):
        helper_path = SRC / 'fpdev.cross.doctor.view.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure WriteCrossDoctorHelpCore', text)
        self.assertIn('procedure WriteCrossDoctorSummaryCore', text)

    def test_cross_doctor_checks_unit_owns_cross_doctor_execution(self):
        helper_path = SRC / 'fpdev.cross.doctor.checks.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function ExecuteCrossDoctorChecksCore', text)

    def test_cmd_fpc_doctor_uses_shared_helpers(self):
        text = (SRC / 'fpdev.cmd.fpc.doctor.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.doctor.runtime', text)
        self.assertIn('fpdev.fpc.doctor.view', text)
        self.assertIn('fpdev.fpc.doctor.checks', text)
        self.assertIn('WriteFPCDoctorHelpCore', text)
        self.assertIn('WriteFPCDoctorSummaryCore', text)
        self.assertIn('ExecuteFPCDoctorChecksCore', text)
        self.assertNotIn('function RunToolVersion', text)
        self.assertNotIn('function CheckWriteableDir', text)

    def test_cmd_cross_doctor_uses_shared_helpers(self):
        text = (SRC / 'fpdev.cmd.cross.doctor.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.doctor.runtime', text)
        self.assertIn('fpdev.cross.doctor.view', text)
        self.assertIn('fpdev.cross.doctor.checks', text)
        self.assertIn('WriteCrossDoctorHelpCore', text)
        self.assertIn('WriteCrossDoctorSummaryCore', text)
        self.assertIn('ExecuteCrossDoctorChecksCore', text)
        self.assertNotIn('function RunToolVersion', text)
        self.assertNotIn('function CheckWriteableDir', text)

    def test_cmd_lazarus_doctor_uses_shared_runtime(self):
        text = (SRC / 'fpdev.cmd.lazarus.doctor.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.doctor.runtime', text)
        self.assertIn('RunDoctorToolVersionCore', text)
        self.assertIn('CheckDoctorWriteableDirCore', text)
        self.assertNotIn('function RunToolVersion', text)
        self.assertNotIn('function CheckWriteableDir', text)

    def test_config_commandflow_uses_system_help_details_helper(self):
        text = (SRC / 'fpdev.config.commandflow.pas').read_text(encoding='utf-8')
        self.assertIn('WriteSystemConfigHelpCore', text)
        self.assertNotIn("Ctx.Out.WriteLn('Usage: fpdev system config <command> [options]')", text)
        self.assertIn('BuildSystemConfigShowLinesCore', text)
        self.assertNotIn("Ctx.Out.WriteLn('FPDev Configuration')", text)
        self.assertNotIn("Ctx.Out.WriteLn('Mirror Settings:')", text)

    def test_index_commandflow_uses_system_help_details_helper(self):
        text = (SRC / 'fpdev.index.commandflow.pas').read_text(encoding='utf-8')
        self.assertIn('WriteSystemIndexHelpCore', text)
        self.assertNotIn("Ctx.Out.WriteLn('Usage: fpdev system index <command>')", text)

    def test_cache_commandflow_uses_system_help_details_helper(self):
        text = (SRC / 'fpdev.cache.commandflow.pas').read_text(encoding='utf-8')
        self.assertIn('WriteSystemCacheHelpCore', text)
        self.assertNotIn("Ctx.Out.WriteLn('Usage: fpdev system cache <command>')", text)

    def test_system_view_unit_owns_runtime_rendering(self):
        helper_path = SRC / 'fpdev.system.view.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function BuildSystemEnvOverviewLinesCore', text)
        self.assertIn('function BuildSystemConfigShowLinesCore', text)
        self.assertIn('function BuildSystemIndexStatusLinesCore', text)
        self.assertIn('function BuildSystemIndexShowLinesCore', text)
        self.assertIn('function BuildSystemIndexUpdateResultLinesCore', text)
        self.assertIn('function BuildSystemCachePathLinesCore', text)
        self.assertIn('function BuildSystemCacheStatusLinesCore', text)
        self.assertIn('function BuildSystemCacheStatsLinesCore', text)

    def test_cmd_env_has_no_inline_overview_labels(self):
        text = (SRC / 'fpdev.cmd.env.pas').read_text(encoding='utf-8')
        self.assertNotIn("Ctx.Out.WriteLn('FPDev Paths:')", text)
        self.assertNotIn("Ctx.Out.WriteLn('Key Environment Variables:')", text)

    def test_index_commandflow_has_no_inline_status_labels(self):
        text = (SRC / 'fpdev.index.commandflow.pas').read_text(encoding='utf-8')
        self.assertNotIn("Ctx.Out.WriteLn('Index Status')", text)
        self.assertNotIn("Ctx.Out.WriteLn('Index File: ' + IndexFile)", text)
        self.assertNotIn("Ctx.Out.WriteLn('Repositories:')", text)
        self.assertNotIn("Ctx.Out.WriteLn('Updating index...')", text)

    def test_cache_commandflow_has_no_inline_status_or_path_labels(self):
        text = (SRC / 'fpdev.cache.commandflow.pas').read_text(encoding='utf-8')
        self.assertNotIn("Ctx.Out.WriteLn('Cache Status')", text)
        self.assertNotIn("Ctx.Out.WriteLn('Cache Paths')", text)
        self.assertNotIn("Ctx.Out.WriteLn('Cache Statistics')", text)

    def test_cmd_config_uses_namespace_shell_helper(self):
        text = (SRC / 'fpdev.cmd.config.pas').read_text(encoding='utf-8')
        self.assertIn('ExecuteNamespaceRootCommandCore', text)
        self.assertNotIn("if (AParams[0] = 'help')", text)

    def test_cmd_index_uses_namespace_shell_helper(self):
        text = (SRC / 'fpdev.cmd.index.pas').read_text(encoding='utf-8')
        self.assertIn('ExecuteNamespaceRootCommandCore', text)
        self.assertNotIn("if (AParams[0] = 'help')", text)

    def test_cmd_cache_uses_namespace_shell_helper(self):
        text = (SRC / 'fpdev.cmd.cache.pas').read_text(encoding='utf-8')
        self.assertIn('ExecuteNamespaceRootCommandCore', text)
        self.assertNotIn("if (AParams[0] = 'help')", text)

    def test_command_tree_unit_owns_command_node(self):
        helper_path = SRC / 'fpdev.command.tree.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('TCommandNode = class', text)
        self.assertIn('function EnsureChild', text)

    def test_command_registry_has_no_inline_command_node(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('TCommandNode = class', text)
        self.assertNotIn('constructor TCommandNode.Create', text)

    def test_command_registry_has_no_redundant_single_level_register_resolve_api(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('procedure Register(const ACmd: ICommand);', text)
        self.assertNotIn('function Resolve(const AName: string): ICommand;', text)
        self.assertNotIn('procedure TCommandRegistry.Register(const ACmd: ICommand);', text)
        self.assertNotIn('function TCommandRegistry.Resolve(const AName: string): ICommand;', text)

    def test_command_registry_has_no_dispatch_wrapper_api(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('function Dispatch(const AArgs: array of string; const Ctx: IContext): Integer;', text)
        self.assertNotIn('function TCommandRegistry.Dispatch(const AArgs: array of string; const Ctx: IContext): Integer;', text)

    def test_command_lookup_unit_owns_tree_query_helpers(self):
        helper_path = SRC / 'fpdev.command.lookup.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('function HasCommandAtPathCore', text)
        self.assertIn('function ListChildrenAtPathCore', text)
        self.assertIn('function MatchExecutablePrefixCore', text)

    def test_command_registry_has_no_inline_lookup_helpers(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('function HasCommandAtPath(const APath: TStringArray): Boolean;', text)
        self.assertNotIn('function TCommandRegistry.HasCommandAtPath(const APath: TStringArray): Boolean;', text)
        self.assertNotIn('Longest executable prefix matching', text)

    def test_command_registration_unit_owns_registerpath_logic(self):
        helper_path = SRC / 'fpdev.command.registration.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure RegisterCommandPathCore', text)
        self.assertIn('AliasNode := Node.Parent.EnsureChild', text)

    def test_command_registration_unit_owns_singleton_register_logic(self):
        text = (SRC / 'fpdev.command.registration.pas').read_text(encoding='utf-8')
        self.assertIn('procedure RegisterSingletonCommandPathCore', text)
        self.assertIn('Node.Command := ACommand', text)

    def test_command_registry_has_no_inline_registerpath_logic(self):
        text = (SRC / 'fpdev.command.registry.pas').read_text(encoding='utf-8')
        self.assertNotIn('AliasNode := Node.Parent.EnsureChild', text)
        self.assertNotIn('for i := Low(APath) to High(APath) do', text)

    def test_command_import_domain_units_exist(self):
        expected = [
            'fpdev.command.imports.fpc.pas',
            'fpdev.command.imports.lazarus.pas',
            'fpdev.command.imports.cross.pas',
            'fpdev.command.imports.package.pas',
            'fpdev.command.imports.project.pas',
            'fpdev.command.imports.system.pas',
        ]
        missing = [name for name in expected if not (SRC / name).exists()]
        self.assertEqual([], missing, f'Missing domain import aggregators: {missing}')

    def test_project_command_import_aggregator_no_longer_depends_on_legacy_manager_shell(self):
        text = (SRC / 'fpdev.command.imports.project.pas').read_text(encoding='utf-8')
        self.assertNotIn('fpdev.cmd.project,', text)

    def test_lazarus_command_import_aggregator_stays_root_and_action_only(self):
        text = (SRC / 'fpdev.command.imports.lazarus.pas').read_text(encoding='utf-8')
        self.assertNotIn('fpdev.cmd.lazarus,', text)

    def test_project_manager_moves_to_core_module(self):
        manager_path = SRC / 'fpdev.project.manager.pas'
        self.assertTrue(manager_path.exists(), f'Missing {manager_path}')
        shell_text = (SRC / 'fpdev.cmd.project.pas').read_text(encoding='utf-8')
        manager_text = manager_path.read_text(encoding='utf-8')
        self.assertIn('TProjectManager = fpdev.project.manager.TProjectManager;', shell_text)
        self.assertIn('type', manager_text)
        self.assertIn('TProjectManager = class', manager_text)

    def test_lazarus_manager_moves_to_core_module(self):
        manager_path = SRC / 'fpdev.lazarus.manager.pas'
        self.assertTrue(manager_path.exists(), f'Missing {manager_path}')
        shell_text = (SRC / 'fpdev.cmd.lazarus.pas').read_text(encoding='utf-8')
        manager_text = manager_path.read_text(encoding='utf-8')
        self.assertIn('TLazarusManager = fpdev.lazarus.manager.TLazarusManager;', shell_text)
        self.assertIn('type', manager_text)
        self.assertIn('TLazarusManager = class', manager_text)

    def test_command_imports_unit_only_references_domain_aggregators(self):
        text = (SRC / 'fpdev.command.imports.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.command.imports.fpc', text)
        self.assertIn('fpdev.command.imports.lazarus', text)
        self.assertIn('fpdev.command.imports.cross', text)
        self.assertIn('fpdev.command.imports.package', text)
        self.assertIn('fpdev.command.imports.project', text)
        self.assertIn('fpdev.command.imports.system', text)
        self.assertNotIn('fpdev.cmd.fpc.install', text)
        self.assertNotIn('fpdev.cmd.package.install', text)
        self.assertNotIn('fpdev.cmd.env.resolve', text)

    def test_command_imports_has_no_noop_registration_function(self):
        text = (SRC / 'fpdev.command.imports.pas').read_text(encoding='utf-8')
        self.assertNotIn('procedure RegisterImportedCommands', text)

    def test_cli_runner_does_not_call_noop_import_registration(self):
        text = (SRC / 'fpdev.cli.runner.pas').read_text(encoding='utf-8')
        self.assertNotIn('RegisterImportedCommands;', text)

    def test_cli_bootstrap_unit_owns_default_dispatch_bootstrap(self):
        helper_path = SRC / 'fpdev.cli.bootstrap.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('procedure ExecuteRootHelpCore', text)
        self.assertIn('function CreateDefaultContextCore', text)
        self.assertIn('function DispatchArgsWithRegistryCore', text)
        self.assertIn('fpdev.command.imports', text)
        self.assertIn('fpdev.help.rootview', text)
        self.assertIn('TDefaultCommandContext.Create', text)
        self.assertIn('GlobalCommandRegistry.DispatchPath', text)
        self.assertIn('WriteRootHelpCore(AOut)', text)
        self.assertNotIn("Args[0] := 'system';", text)
        self.assertNotIn("Args[1] := 'help';", text)
        self.assertNotIn('DispatchArgsWithRegistryCore(Args, Ctx);', text)

    def test_command_lookup_unit_supports_exact_match_command_nodes(self):
        text = (SRC / 'fpdev.command.lookup.pas').read_text(encoding='utf-8')
        self.assertIn('Assigned(Node.Command)', text)
        self.assertIn('Assigned(AMatch.MatchedNode.Command)', text)

    def test_namespace_root_units_use_singleton_root_shells(self):
        expected = [
            'fpdev.cmd.system.root.pas',
            'fpdev.cmd.repo.root.pas',
            'fpdev.cmd.fpc.root.pas',
            'fpdev.cmd.fpc.cache.pas',
            'fpdev.cmd.fpc.policy.root.pas',
            'fpdev.cmd.cross.root.pas',
            'fpdev.cmd.lazarus.root.pas',
            'fpdev.cmd.package.root.pas',
            'fpdev.cmd.package.repo.root.pas',
            'fpdev.cmd.project.root.pas',
            'fpdev.cmd.project.template.root.pas',
            'fpdev.cmd.system.toolchain.root.pas',
        ]
        for filename in expected:
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertIn('RegisterSingletonPath', text, f'{filename} should register a typed root shell')
            self.assertNotIn('RegisterPath(', text, f'{filename} should stop using nil root registration')
            self.assertNotIn('nil, []', text, f'{filename} should stop using nil registration')

    def test_cli_runner_has_no_inline_default_dispatch_bootstrap(self):
        text = (SRC / 'fpdev.cli.runner.pas').read_text(encoding='utf-8')
        self.assertNotIn('fpdev.command.imports', text)
        self.assertNotIn('TDefaultCommandContext.Create', text)
        self.assertNotIn('GlobalCommandRegistry.DispatchPath', text)
        self.assertNotIn('fpdev.cmd.help.execute', text)
        self.assertNotIn('TryHandleGlobalFlag', text)

    def test_cli_internal_unit_removed_after_internal_commands_join_tree(self):
        self.assertFalse((SRC / 'fpdev.cli.internal.pas').exists())

    def test_debug_symbols_unit_owns_debug_symbol_anchor(self):
        helper_path = SRC / 'fpdev.debug.symbols.pas'
        self.assertTrue(helper_path.exists(), f'Missing {helper_path}')
        text = helper_path.read_text(encoding='utf-8')
        self.assertIn('fpdev.build.cache.types', text)

    def test_fpdev_lpr_has_no_inline_debug_symbol_anchor(self):
        text = (SRC / 'fpdev.lpr').read_text(encoding='utf-8')
        self.assertIn('fpdev.debug.symbols', text)
        self.assertNotIn('fpdev.build.cache.types', text)

    def test_no_old_package_helper_units_remain(self):
        banned = [
            'fpdev.cmd.package.metadata',
            'fpdev.cmd.package.semver',
            'fpdev.cmd.package.depgraph',
            'fpdev.cmd.package.query.available',
            'fpdev.cmd.package.query.info',
            'fpdev.cmd.package.query.installed',
            'fpdev.cmd.package.listview',
            'fpdev.cmd.package.infoview',
            'fpdev.cmd.package.searchview',
            'fpdev.cmd.package.installflow',
            'fpdev.cmd.package.publishflow',
            'fpdev.cmd.package.facadeflow',
            'fpdev.cmd.package.queryflow',
            'fpdev.cmd.package.cleanflow',
            'fpdev.cmd.package.sourceprep',
            'fpdev.cmd.package.sourceinstall',
            'fpdev.cmd.package.updateplan',
            'fpdev.cmd.package.create',
            'fpdev.cmd.package.fetch',
            'fpdev.cmd.package.verify',
            'fpdev.cmd.package.validate',
            'fpdev.cmd.package.lifecycle',
            'fpdev.cmd.package.index',
        ]
        for path in SRC.glob('*.pas'):
            text = path.read_text(encoding='utf-8')
            for token in banned:
                self.assertNotIn(token, text, f'{path} still references {token}')

    def test_no_old_flow_helper_units_remain(self):
        banned = [
            'fpdev.cmd.cache.flow',
            'fpdev.cmd.config.flow',
            'fpdev.cmd.index.flow',
            'fpdev.cmd.lazarus.flow',
            'fpdev.cmd.project.execflow',
            'fpdev.cmd.fpc.runtimeflow',
            'fpdev.cmd.fpc.installversionflow',
            'fpdev.cmd.cross.query',
            'fpdev.cmd.cross.targetflow',
            'fpdev.cmd.utils',
            'fpdev.cmd.imports',
            'fpdev.cli.special',
            'fpdev.cmd.shellhook',
            'fpdev.cmd.resolveversion',
        ]
        for path in SRC.glob('*.pas'):
            text = path.read_text(encoding='utf-8')
            for token in banned:
                self.assertNotIn(token, text, f'{path} still references {token}')


if __name__ == '__main__':
    unittest.main()
