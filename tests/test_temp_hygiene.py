import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class PascalTempHygieneTests(unittest.TestCase):
    def test_shared_temp_paths_helper_honors_fpdev_test_tmpdir(self):
        source_path = REPO_ROOT / 'tests' / 'test_temp_paths.pas'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn("GetEnvironmentVariable('TMPDIR')", text)
        self.assertIn("GetEnvironmentVariable('TMP')", text)
        self.assertIn("GetEnvironmentVariable('TEMP')", text)
        self.assertIn("GetEnvironmentVariable('FPDEV_TEST_TMPDIR')", text)
        self.assertIn('Result := ResolvePreferredTempEnvRoot;', text)
        self.assertIn('Result := IncludeTrailingPathDelimiter(ResolveTestTempRoot)', text)
        self.assertIn('ExpandFileName(ResolveTestTempRoot)', text)
        self.assertNotIn('IncludeTrailingPathDelimiter(GetTempDir(False))', text)

    def test_fpc_install_cli_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_install_cli.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_install')", text)
        self.assertIn('PathUsesSystemTempRoot(GTempConfigDir)', text)
        self.assertIn('CleanupTempDir(GTempConfigDir);', text)
        self.assertNotIn('function BuildTempConfigDir', text)
        self.assertNotIn("'fpdev_test_install_' + IntToStr(GetTickCount64)", text)

    def test_fpc_builder_bootstrapcompat_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_builder_bootstrapcompat.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-bootstrapcompat')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-custom-prefix-bootstrap')", text)
        self.assertIn('CleanupTempDir(TempRoot);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn("RemoveDir(TempRoot + PathDelim + 'sources')", text)

    def test_fpc_builder_uses_shared_temp_helpers_for_probe_roots(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_builder.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn('Result := CreateUniqueTempDir(APrefix);', text)
        self.assertIn('CleanupTempDir(ProbeRoot);', text)
        self.assertIn('CleanupTempDir(ProbeHome);', text)
        self.assertNotIn('Result := IncludeTrailingPathDelimiter(GetTempDir(False))', text)
        self.assertNotIn('RemoveDir(ProbeRoot);', text)
        self.assertNotIn('RemoveDir(ProbeHome);', text)

    def test_resource_repo_query_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_resource_repo_query.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('test_repo_query')", text)
        self.assertIn('PathUsesSystemTempRoot(TempDir)', text)
        self.assertIn('CleanupTempDir(TempDir);', text)
        self.assertNotIn("IncludeTrailingPathDelimiter(GetTempDir(True)) + 'test_repo_query_'", text)

    def test_resource_repo_package_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_resource_repo_package.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('test_repo_pkg')", text)
        self.assertIn('PathUsesSystemTempRoot(TempDir)', text)
        self.assertIn('CleanupTempDir(TempDir);', text)
        self.assertNotIn("IncludeTrailingPathDelimiter(GetTempDir(True)) +", text)
        self.assertNotIn('Cleanup - best effort', text)

    def test_resource_repo_config_cleans_data_root_probe(self):
        source_path = REPO_ROOT / 'tests' / 'test_resource_repo_config.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-resource-repo-data-root-probe')", text)
        self.assertIn('PathUsesSystemTempRoot(ProbeRoot)', text)
        self.assertIn('CleanupTempDir(ProbeRoot);', text)
        self.assertNotIn("FormatDateTime('yyyymmddhhnnsszzz', Now)", text)

    def test_fpc_install_integration_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_install_integration.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_cache')", text)
        self.assertIn('PathUsesSystemTempRoot(TestCacheDir)', text)
        self.assertIn('CleanupTempDir(TestCacheDir);', text)
        self.assertNotIn('function BuildTempCacheDir', text)
        self.assertNotIn('Halt(0);', text)

    def test_fpc_install_integration_debug_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_install_integration_debug.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_cache')", text)
        self.assertIn('PathUsesSystemTempRoot(TestCacheDir)', text)
        self.assertIn('CleanupTempDir(TestCacheDir);', text)
        self.assertNotIn('function BuildTempCacheDir', text)
        self.assertNotIn('Halt(0);', text)

    def test_cmd_index_cleans_data_root_probe(self):
        source_path = REPO_ROOT / 'tests' / 'test_cmd_index.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-index-status-data-root-probe')", text)
        self.assertIn('PathUsesSystemTempRoot(ProbeRoot)', text)
        self.assertIn('CleanupTempDir(ProbeRoot);', text)
        self.assertNotIn("FormatDateTime('yyyymmddhhnnsszzz', Now)", text)

    def test_cli_fpc_policy_cleans_temp_dir_before_exit(self):
        source_path = REPO_ROOT / 'tests' / 'test_cli_fpc_policy.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_fpc_policy')", text)
        self.assertIn('PathUsesSystemTempRoot(GTempDir)', text)
        self.assertIn('CleanupTempDir(GTempDir);', text)
        self.assertIn('ExitCode := PrintTestSummary;', text)
        self.assertNotIn('Halt(PrintTestSummary);', text)

    def test_fpc_installer_downloadflow_cleans_shared_download_dir(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_installer_downloadflow.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('CleanupTempDir(Plan.TempDir);', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(TempFile));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(Probe.LastTempFile));', text)

    def test_fpc_installer_manifest_plan_cleans_shared_download_dir(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_installer_manifest_plan.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertGreaterEqual(text.count('CleanupTempDir(DownloadDir);'), 2)

    def test_fpc_binary_install_cleans_downloaded_temp_archives(self):
        source_path = REPO_ROOT / 'tests' / 'test_fpc_binary_install.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn("DownloadResult := FPCManager.DownloadBinary('3.2.2', TempFile);", text)
        self.assertIn("if FPCManager.DownloadBinary('3.2.2', TempFile) then", text)
        self.assertGreaterEqual(text.count('if (TempFile <> \'\') and FileExists(TempFile) then'), 2)
        self.assertGreaterEqual(text.count('DeleteFile(TempFile);'), 2)
        self.assertGreaterEqual(text.count('CleanupTempDir(ExtractFileDir(TempFile));'), 2)

    def test_cache_space_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cache_space.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-space-cleanup')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-space-config')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-lru')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-unlimited')", text)
        self.assertGreaterEqual(text.count('PathUsesSystemTempRoot(CacheDir)'), 4)
        self.assertGreaterEqual(text.count('CleanupTempDir(CacheDir);'), 4)
        self.assertNotIn('function MakeTempDir', text)
        self.assertNotIn('procedure AssertPathIsUnderSystemTemp', text)
        self.assertNotIn('procedure CleanupTestDir', text)
        self.assertNotIn('GetTempDir(False)', text)

    def test_build_cache_binarypresence_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_build_cache_binarypresence.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn('Result := IncludeTrailingPathDelimiter(CreateUniqueTempDir(APrefix))', text)
        self.assertIn('PathUsesSystemTempRoot(ExtractFileDir(FirstPath))', text)
        self.assertGreaterEqual(text.count('CleanupTempDir(ExtractFileDir(TempFile));'), 2)
        self.assertIn('CleanupTempDir(ExtractFileDir(FirstPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(SecondPath));', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('GTempPathSequence', text)

    def test_cache_stats_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cache_stats.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-stats-cleanup')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-stats-access')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-stats-persist')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-stats-detailed')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-stats-lru')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-stats-report')", text)
        self.assertGreaterEqual(text.count('PathUsesSystemTempRoot(CacheDir)'), 6)
        self.assertGreaterEqual(text.count('CleanupTempDir(CacheDir);'), 6)
        self.assertNotIn('function MakeTempDir', text)
        self.assertNotIn('procedure AssertPathIsUnderSystemTemp', text)
        self.assertNotIn('procedure CleanupTestDir', text)
        self.assertNotIn('GetTempDir(False)', text)

    def test_cache_metadata_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cache_metadata.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-metadata-cleanup')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-json-write')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-json-read')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-compat')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-migrate')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-roundtrip')", text)
        self.assertGreaterEqual(text.count('PathUsesSystemTempRoot(CacheDir)'), 6)
        self.assertGreaterEqual(text.count('CleanupTempDir(CacheDir);'), 6)
        self.assertNotIn('function MakeTempDir', text)
        self.assertNotIn('procedure AssertPathIsUnderSystemTemp', text)
        self.assertNotIn('procedure CleanupTestDir', text)
        self.assertNotIn('GetTempDir(False)', text)

    def test_build_cache_artifactmeta_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_build_cache_artifactmeta.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-artifactmeta')", text)
        self.assertIn('PathUsesSystemTempRoot(ExtractFileDir(FirstPath))', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(FirstPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(SecondPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(MetaPath));', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('GTempPathSequence', text)

    def test_build_cache_deletefiles_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_build_cache_deletefiles.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn('Result := IncludeTrailingPathDelimiter(CreateUniqueTempDir(APrefix))', text)
        self.assertIn('PathUsesSystemTempRoot(ExtractFileDir(FirstPath))', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(FirstPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(SecondPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(ArchivePath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(MetaPath));', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('GTempPathSequence', text)

    def test_build_cache_cleanupscan_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_build_cache_cleanupscan.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("Result := CreateUniqueTempDir('fpdev-cache-cleanupscan')", text)
        self.assertIn('PathUsesSystemTempRoot(TempDir)', text)
        self.assertIn('CleanupTempDir(TempDir);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(TempDir);', text)

    def test_build_cache_migrationbackup_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_build_cache_migrationbackup.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn('Result := IncludeTrailingPathDelimiter(CreateUniqueTempDir(APrefix))', text)
        self.assertIn('PathUsesSystemTempRoot(ExtractFileDir(FirstPath))', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(FirstPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(SecondPath));', text)
        self.assertGreaterEqual(text.count('CleanupTempDir(ExtractFileDir(OldMetaPath));'), 2)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('GTempPathSequence', text)

    def test_build_cache_binarysave_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_build_cache_binarysave.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn('Result := IncludeTrailingPathDelimiter(CreateUniqueTempDir(APrefix))', text)
        self.assertIn('PathUsesSystemTempRoot(ExtractFileDir(FirstPath))', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(FirstPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(SecondPath));', text)
        self.assertGreaterEqual(text.count('CleanupTempDir(ExtractFileDir(TempFile));'), 2)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('GTempPathSequence', text)

    def test_build_cache_expiredscan_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_build_cache_expiredscan.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("Result := IncludeTrailingPathDelimiter(CreateUniqueTempDir('fpdev-expiredscan'))", text)
        self.assertIn('PathUsesSystemTempRoot(Dir)', text)
        self.assertIn('CleanupTempDir(Dir);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('RemoveDir(Dir);', text)

    def test_cache_ttl_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cache_ttl.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-cleanup')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-ttl')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-ttl-config')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-clean')", text)
        self.assertGreaterEqual(text.count('PathUsesSystemTempRoot(CacheDir)'), 4)
        self.assertGreaterEqual(text.count('CleanupTempDir(CacheDir);'), 4)
        self.assertNotIn('function MakeTempDir', text)
        self.assertNotIn('procedure AssertPathIsUnderSystemTemp', text)
        self.assertNotIn('procedure CleanupTestDir', text)
        self.assertNotIn('GetTempDir(False)', text)

    def test_cache_verification_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cache_verification.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-verification-cleanup')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-sha256')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-verify')", text)
        self.assertIn("CreateUniqueTempDir('fpdev-test-cache-perf')", text)
        self.assertGreaterEqual(text.count('PathUsesSystemTempRoot(CacheDir)'), 4)
        self.assertGreaterEqual(text.count('CleanupTempDir(CacheDir);'), 4)
        self.assertNotIn('function MakeTempDir', text)
        self.assertNotIn('procedure AssertPathIsUnderSystemTemp', text)
        self.assertNotIn('procedure CleanupTestDir', text)
        self.assertNotIn('GetTempDir(False)', text)

    def test_cross_compiler_resolve_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cross_compiler_resolve.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('test_ppcross_validate')", text)
        self.assertIn('PathUsesSystemTempRoot(ExtractFileDir(FirstPath))', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(FirstPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(SecondPath));', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(TmpFile));', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('GTempPathSequence', text)

    def test_cross_search_libs_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cross_search_libs.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_libs')", text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_dedup')", text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_diag')", text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_multi1')", text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_multi2')", text)
        self.assertIn('PathUsesSystemTempRoot(TmpDir)', text)
        self.assertIn('PathUsesSystemTempRoot(TmpDir1)', text)
        self.assertIn('PathUsesSystemTempRoot(TmpDir2)', text)
        self.assertIn('CleanupTempDir(TmpDir);', text)
        self.assertIn('CleanupTempDir(TmpDir1);', text)
        self.assertIn('CleanupTempDir(TmpDir2);', text)
        self.assertNotIn('function MakeTempDir', text)
        self.assertNotIn('procedure AssertUsesSystemTempPath', text)
        self.assertNotIn('procedure CleanupTempDir', text)
        self.assertNotIn('GetTempDir(False)', text)

    def test_cross_query_uses_shared_temp_root_assertion(self):
        source_path = REPO_ROOT / 'tests' / 'test_cross_query.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn('PathUsesSystemTempRoot(ConfigPath)', text)
        self.assertIn('PathUsesSystemTempRoot(GetTestInstallRoot)', text)
        self.assertIn('CleanupTempDir(GTestInstallRoot);', text)
        self.assertNotIn('IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)))', text)

    def test_cross_downloader_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cross_downloader.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_downloader_test')", text)
        self.assertIn('PathUsesSystemTempRoot(FTestOutputDir)', text)
        self.assertIn('CleanupTempDir(FTestOutputDir);', text)
        self.assertGreaterEqual(text.count('CleanupTempDir(TestInstallDir);'), 2)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('procedure CleanupDir(', text)

    def test_cross_cache_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_cross_cache.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_cache_test')", text)
        self.assertIn('PathUsesSystemTempRoot(FTestCacheDir)', text)
        self.assertIn('CleanupTempDir(FTestCacheDir);', text)
        self.assertIn('CleanupTempDir(OtherDir);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(FTestCacheDir);', text)

    def test_package_index_validation_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_index_validation.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-package-index-validation')", text)
        self.assertIn('PathUsesSystemTempRoot(Cfg.ConfigPath)', text)
        self.assertIn('CleanupTempDir(TempRoot);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(TempRoot);', text)

    def test_package_repo_integration_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_repo_integration.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-package-repo-integration')", text)
        self.assertIn('PathUsesSystemTempRoot(Cfg.ConfigPath)', text)
        self.assertIn('CleanupTempDir(TempRoot);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(TempRoot);', text)

    def test_package_index_parser_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_index_parser.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("Result := CreateUniqueTempDir('fpdev-pkg-index-parser')", text)
        self.assertIn('PathUsesSystemTempRoot(TempDir)', text)
        self.assertIn('CleanupTempDir(TempDir);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(TempDir);', text)

    def test_package_installed_query_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_installed_query.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("Result := CreateUniqueTempDir('fpdev-pkg-installed-' + ASuffix);", text)
        self.assertIn('PathUsesSystemTempRoot(Result)', text)
        self.assertIn('CleanupTempDir(TempRoot);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(TempRoot);', text)

    def test_package_metadata_writer_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_metadata_writer.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("Result := CreateUniqueTempDir('fpdev-pkg-metadata-' + ASuffix);", text)
        self.assertIn('PathUsesSystemTempRoot(Result)', text)
        self.assertIn('CleanupTempDir(TempDir);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(TempDir);', text)

    def test_package_verify_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_verify.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev_test_pkg_verify')", text)
        self.assertIn('PathUsesSystemTempRoot(TempRoot)', text)
        self.assertIn('CleanupTempDir(OtherTempRoot);', text)
        self.assertIn('CleanupTempDir(TempRoot);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(TempRoot);', text)

    def test_package_install_flow_helper_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_install_flow_helper.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn('Result := CreateUniqueTempDir(APrefix);', text)
        self.assertIn('PathUsesSystemTempRoot(APath)', text)
        self.assertGreaterEqual(text.count('CleanupTempDir(SandboxDir);'), 2)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(SandboxDir);', text)

    def test_package_resolver_integration_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_resolver_integration.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-package-resolver')", text)
        self.assertIn('PathUsesSystemTempRoot(FTestDataDir)', text)
        self.assertIn('PathUsesSystemTempRoot(FLockFilePath)', text)
        self.assertIn('CleanupTempDir(FTestRootDir);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(FTestRootDir);', text)

    def test_package_properties_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_properties.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("Result := CreateUniqueTempDir('fpdev_test_' + AName);", text)
        self.assertIn('PathUsesSystemTempRoot(Result)', text)
        self.assertIn('CleanupTempDir(TestDir);', text)
        self.assertIn('CleanupTempDir(SourceDir);', text)
        self.assertIn('CleanupTempDir(OutputDir);', text)
        self.assertNotIn('GetTempDir(', text)
        self.assertNotIn('RemoveDirRecursive(', text)

    def test_package_management_uses_shared_temp_root_assertion(self):
        source_path = REPO_ROOT / 'tests' / 'test_package_management.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('test_package_management')", text)
        self.assertIn('PathUsesSystemTempRoot(FTestConfigPath)', text)
        self.assertIn('CleanupTempDir(ExtractFileDir(FTestConfigPath));', text)
        self.assertNotIn('GetTempDir(False)', text)

    def test_config_isolation_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_config_isolation.pas'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir(TestName + '-config') + PathDelim + 'config.json'", text)
        self.assertIn('CleanupTempDir(ConfigDir);', text)
        self.assertNotIn('IncludeTrailingPathDelimiter(GetTempDir(False))', text)
        self.assertNotIn('DeleteDirRecursive(ConfigDir);', text)

    def test_config_management_uses_shared_temp_root_assertion(self):
        source_path = REPO_ROOT / 'tests' / 'test_config_management.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('PathUsesSystemTempRoot(FConfigManager.ConfigPath)', text)
        self.assertNotIn('ExpandFileName(GetTempDir(False))', text)

    def test_config_simple_programs_use_shared_temp_root_assertion(self):
        pas_path = REPO_ROOT / 'tests' / 'test_config_simple.pas'
        pas_text = pas_path.read_text(encoding='utf-8')
        lpr_path = REPO_ROOT / 'tests' / 'test_config_simple.lpr'
        lpr_text = lpr_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', pas_text)
        self.assertIn('PathUsesSystemTempRoot(Config.GetConfigPath)', pas_text)
        self.assertNotIn('GetTempDir(False)', pas_text)

        self.assertIn('test_temp_paths', lpr_text)
        self.assertIn('PathUsesSystemTempRoot(Config.ConfigPath)', lpr_text)
        self.assertNotIn('GetTempDir(False)', lpr_text)

    def test_command_registry_uses_shared_temp_helpers(self):
        source_path = REPO_ROOT / 'tests' / 'test_command_registry.lpr'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn('test_temp_paths', text)
        self.assertIn("CreateUniqueTempDir('fpdev-command-registry')", text)
        self.assertIn('PathUsesSystemTempRoot(EnsureTempConfigRoot)', text)
        self.assertIn('CleanupTempDir(GTempConfigRoot);', text)
        self.assertNotIn('GetTempDir(False)', text)
        self.assertNotIn('DeleteDirRecursive(GTempConfigRoot);', text)

    def test_cli_surface_consistency_uses_env_aware_temp_root(self):
        source_path = REPO_ROOT / 'tests' / 'test_cli_surface_consistency.py'
        text = source_path.read_text(encoding='utf-8')

        self.assertIn("os.environ.get('FPDEV_TEST_TMPDIR', '').strip()", text)
        self.assertIn("os.environ.get('TMPDIR', '').strip()", text)
        self.assertIn("os.environ.get('TMP', '').strip()", text)
        self.assertIn("os.environ.get('TEMP', '').strip()", text)
        self.assertIn("fallback_root = REPO_ROOT / '.tmp-pytest'", text)
        self.assertIn('cls._temp_dir = tempfile.TemporaryDirectory(', text)
        self.assertIn("prefix='fpdev-cli-surface-'", text)
        self.assertIn('dir=resolve_python_test_temp_root(),', text)


if __name__ == '__main__':
    unittest.main()
