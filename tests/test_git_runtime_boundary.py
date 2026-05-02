import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / 'src'
RUNTIME_PATH = SRC / 'fpdev.git.runtime.pas'
RUNTIME_IMPL_PATH = SRC / 'fpdev.git.runtime.impl.pas'
OPERATIONS_PATH = SRC / 'fpdev.git.operations.pas'
OPERATIONS_IMPL_PATH = SRC / 'fpdev.git.operations.impl.pas'
OPERATIONS_IDENTITYFLOW_PATH = SRC / 'fpdev.git.operations.identityflow.pas'
OPERATIONS_TRANSPORTFLOW_PATH = SRC / 'fpdev.git.operations.transportflow.pas'
UTILS_GIT_PATH = SRC / 'fpdev.utils.git.pas'
DOCS = REPO_ROOT / 'docs'
HISTORY_DOCS = DOCS / 'history'
CLAUDE_MD = REPO_ROOT / 'CLAUDE.md'
CHANGELOG = REPO_ROOT / 'CHANGELOG.md'
RELEASE_NOTES = REPO_ROOT / 'RELEASE_NOTES.md'
BREAKING_REMOVAL_PLAN = DOCS / 'plans' / '2026-04-10-git-compat-breaking-removal.md'
GIT_OPERATIONS_MD = DOCS / 'GIT_OPERATIONS.md'
GIT_OPERATIONS_EN_MD = DOCS / 'GIT_OPERATIONS.en.md'


class GitRuntimeBoundaryTests(unittest.TestCase):
    def _iter_pascal_repo_files(self):
        yield from SRC.glob('*.pas')
        yield from (REPO_ROOT / 'tests').glob('*.pas')
        yield from (REPO_ROOT / 'tests').glob('*.lpr')

    def test_git_runtime_adapter_exists(self):
        self.assertTrue(RUNTIME_PATH.exists(), f'Missing {RUNTIME_PATH}')
        self.assertTrue(RUNTIME_IMPL_PATH.exists(), f'Missing {RUNTIME_IMPL_PATH}')
        self.assertTrue(OPERATIONS_PATH.exists(), f'Missing {OPERATIONS_PATH}')
        self.assertTrue(OPERATIONS_IMPL_PATH.exists(), f'Missing {OPERATIONS_IMPL_PATH}')
        self.assertFalse(UTILS_GIT_PATH.exists(), f'{UTILS_GIT_PATH} should be removed in the breaking window')
        text = RUNTIME_PATH.read_text(encoding='utf-8')
        impl_text = RUNTIME_IMPL_PATH.read_text(encoding='utf-8')
        operations_text = OPERATIONS_PATH.read_text(encoding='utf-8')
        operations_impl_text = OPERATIONS_IMPL_PATH.read_text(encoding='utf-8')
        self.assertIn('IGitRuntime', text)
        self.assertIn('NewGitRuntime', text)
        self.assertNotIn('TGitRuntime = class', text)
        self.assertNotIn('TGitOperations', text)
        self.assertIn('TGitRuntime = class', impl_text)
        self.assertIn('TGitOperations', impl_text)
        self.assertIn('TGitOperations = fpdev.git.operations.impl.TGitOperations', operations_text)
        self.assertIn('IGitCliRunner = fpdev.git.operations.impl.IGitCliRunner', operations_text)
        self.assertNotIn('fpdev.utils.git', operations_text)
        self.assertIn('TGitOperations = class', operations_impl_text)

    def test_git_runtime_imports_lightweight_backend_types(self):
        text = RUNTIME_PATH.read_text(encoding='utf-8')
        self.assertIn('fpdev.git.types', text, 'fpdev.git.runtime should import backend enum symbols from the lightweight types unit')

    def test_git_runtime_interface_stops_leaking_utils_git_contracts(self):
        text = RUNTIME_PATH.read_text(encoding='utf-8')
        interface_text = text.split('implementation', 1)[0]
        self.assertNotIn('fpdev.utils.git', interface_text, 'fpdev.git.runtime interface should not depend on fpdev.utils.git')
        self.assertNotIn('TGitOperations', interface_text, 'fpdev.git.runtime interface should not expose TGitOperations')
        self.assertNotIn('IGitCliRunner', interface_text, 'fpdev.git.runtime interface should not expose IGitCliRunner')

    def test_git_runtime_stops_mentioning_igitclirunner(self):
        text = RUNTIME_PATH.read_text(encoding='utf-8')
        self.assertNotIn('IGitCliRunner', text, 'fpdev.git.runtime should no longer mention IGitCliRunner after sealing runtime construction')

    def test_git_runtime_contract_uses_impl_unit_for_factory(self):
        text = RUNTIME_PATH.read_text(encoding='utf-8')
        impl_text = RUNTIME_IMPL_PATH.read_text(encoding='utf-8')
        self.assertIn(
            'fpdev.git.runtime.impl',
            text,
            'fpdev.git.runtime should delegate construction to a dedicated impl unit',
        )
        self.assertIn(
            'fpdev.git.runtime',
            impl_text,
            'fpdev.git.runtime.impl should implement the IGitRuntime contract from fpdev.git.runtime',
        )
        self.assertIn(
            'fpdev.git.operations',
            impl_text,
            'fpdev.git.runtime.impl should consume git operations from the default operations unit',
        )
        self.assertNotIn(
            'fpdev.utils.git',
            impl_text,
            'fpdev.git.runtime.impl should not depend on fpdev.utils.git directly once operations facade exists',
        )

    def test_operations_impl_reuses_shared_pull_failure_type(self):
        text = OPERATIONS_IMPL_PATH.read_text(encoding='utf-8')
        helper_text = OPERATIONS_TRANSPORTFLOW_PATH.read_text(encoding='utf-8') if OPERATIONS_TRANSPORTFLOW_PATH.exists() else ''
        self.assertGreaterEqual(
            text.count('fpdev.git.errors.ClassifyGitPullFailure('),
            1,
            'fpdev.git.operations.impl should use the shared git error helper in internal logic after compat wrapper removal',
        )
        self.assertGreaterEqual(
            helper_text.count('fpdev.git.env.ResolveGitCredentialEnv('),
            1,
            'transportflow helper should use the shared git env helper in internal credential loading after compat wrapper removal',
        )

    def test_operations_impl_delegates_identity_signature_setup_to_internal_identityflow(self):
        self.assertTrue(
            OPERATIONS_IDENTITYFLOW_PATH.exists(),
            f'Missing {OPERATIONS_IDENTITYFLOW_PATH}',
        )
        helper_text = OPERATIONS_IDENTITYFLOW_PATH.read_text(encoding='utf-8')
        impl_text = OPERATIONS_IMPL_PATH.read_text(encoding='utf-8')
        facade_text = OPERATIONS_PATH.read_text(encoding='utf-8')
        self.assertIn(
            'function TryResolveGitOperationIdentity(',
            helper_text,
            'identityflow helper should own author/committer identity resolution',
        )
        self.assertIn(
            'function TryCreateGitOperationSignatures(',
            helper_text,
            'identityflow helper should own libgit2 signature creation helpers',
        )
        self.assertIn(
            'fpdev.git.env.ResolveGitIdentityEnv(',
            helper_text,
            'identityflow helper should be the place that consumes the shared identity env helper',
        )
        self.assertIn(
            'git_signature_now(',
            helper_text,
            'identityflow helper should be the place that creates libgit2 signatures',
        )
        self.assertIn(
            'fpdev.git.operations.identityflow',
            impl_text,
            'fpdev.git.operations.impl should import the internal identityflow helper',
        )
        self.assertGreaterEqual(
            impl_text.count('TryResolveGitOperationIdentity('),
            2,
            'CommitWithLibgit2 and PullWithLibgit2 should both delegate identity resolution to identityflow',
        )
        self.assertGreaterEqual(
            impl_text.count('TryCreateGitOperationSignatures('),
            2,
            'CommitWithLibgit2 and PullWithLibgit2 should both delegate signature creation to identityflow',
        )
        self.assertNotIn(
            'fpdev.git.env.ResolveGitIdentityEnv(',
            impl_text,
            'fpdev.git.operations.impl should stop loading identity env inline once identityflow exists',
        )
        self.assertNotIn(
            'git_signature_now(',
            impl_text,
            'fpdev.git.operations.impl should stop creating libgit2 signatures inline once identityflow exists',
        )
        self.assertNotIn(
            'fpdev.git.operations.identityflow',
            facade_text,
            'fpdev.git.operations must remain the only public facade; identityflow should stay internal',
        )

    def test_operations_impl_delegates_transport_credential_setup_to_internal_transportflow(self):
        self.assertTrue(
            OPERATIONS_TRANSPORTFLOW_PATH.exists(),
            f'Missing {OPERATIONS_TRANSPORTFLOW_PATH}',
        )
        helper_text = OPERATIONS_TRANSPORTFLOW_PATH.read_text(encoding='utf-8')
        impl_text = OPERATIONS_IMPL_PATH.read_text(encoding='utf-8')
        facade_text = OPERATIONS_PATH.read_text(encoding='utf-8')
        self.assertIn(
            'procedure LoadGitTransportCredentialPayload(',
            helper_text,
            'transportflow helper should own credential payload loading',
        )
        self.assertIn(
            'function GitTransportCredentialAcquireCb(',
            helper_text,
            'transportflow helper should own the libgit2 credential callback',
        )
        self.assertIn(
            'function TryInitGitCloneTransportOptions(',
            helper_text,
            'transportflow helper should own clone transport option wiring',
        )
        self.assertIn(
            'function TryInitGitFetchTransportOptions(',
            helper_text,
            'transportflow helper should own fetch transport option wiring',
        )
        self.assertIn(
            'function TryInitGitPushTransportOptions(',
            helper_text,
            'transportflow helper should own push transport option wiring',
        )
        self.assertIn(
            'fpdev.git.env.ResolveGitCredentialEnv(',
            helper_text,
            'transportflow helper should be the place that consumes the shared credential env helper',
        )
        self.assertIn(
            'git_credential_userpass_plaintext_new(',
            helper_text,
            'transportflow helper should own plaintext credential fallback',
        )
        self.assertIn(
            'git_credential_username_new(',
            helper_text,
            'transportflow helper should own username-only credential fallback',
        )
        self.assertIn(
            'fpdev.git.operations.transportflow',
            impl_text,
            'fpdev.git.operations.impl should import the internal transportflow helper',
        )
        self.assertIn(
            'TryInitGitCloneTransportOptions(',
            impl_text,
            'CloneWithLibgit2 should delegate transport setup to transportflow',
        )
        self.assertGreaterEqual(
            impl_text.count('TryInitGitFetchTransportOptions('),
            2,
            'FetchWithLibgit2 and PullWithLibgit2 should both delegate fetch transport setup to transportflow',
        )
        self.assertIn(
            'TryInitGitPushTransportOptions(',
            impl_text,
            'PushWithLibgit2 should delegate transport setup to transportflow',
        )
        self.assertNotIn(
            'LoadCredentialPayloadFromEnv(',
            impl_text,
            'fpdev.git.operations.impl should stop loading transport credential payload inline once transportflow exists',
        )
        self.assertNotIn(
            'CredentialAcquireCb(',
            impl_text,
            'fpdev.git.operations.impl should stop owning the credential callback inline once transportflow exists',
        )
        self.assertNotIn(
            'fpdev.git.operations.transportflow',
            facade_text,
            'fpdev.git.operations must remain the only public facade; transportflow should stay internal',
        )

    def test_utils_git_shim_is_removed(self):
        self.assertFalse(
            UTILS_GIT_PATH.exists(),
            'the final fpdev.utils.git compatibility shim should be deleted in the breaking window',
        )

    def test_utils_git_removed_compat_helpers_have_no_repo_pascal_consumers(self):
        scanned_files = list(self._iter_pascal_repo_files())
        forbidden_patterns = {
            'fpdev.utils.git.GitBackendToString(': set(),
            'fpdev.utils.git.ClassifyGitPullFailure(': set(),
            'fpdev.utils.git.ResolveGitCredentialEnv(': set(),
            'fpdev.utils.git.ResolveGitIdentityEnv(': set(),
        }

        for path in scanned_files:
            rel_path = str(path.relative_to(REPO_ROOT))
            text = path.read_text(encoding='utf-8')
            for pattern, allowed in forbidden_patterns.items():
                if rel_path not in allowed:
                    self.assertNotIn(pattern, text, f'{rel_path} should not consume legacy compat helper {pattern}')

    def test_utils_git_removed_compat_aliases_have_no_repo_pascal_consumers(self):
        scanned_files = list(self._iter_pascal_repo_files())
        forbidden_patterns = {
            'fpdev.utils.git.TGitBackend': set(),
            'fpdev.utils.git.TGitPullFailureKind': set(),
            'fpdev.utils.git.gpfkUnknown': set(),
            'fpdev.utils.git.gpfkDirtyWorktree': set(),
            'fpdev.utils.git.gpfkDetachedHead': set(),
            'fpdev.utils.git.gpfkDivergedHistory': set(),
        }

        for path in scanned_files:
            rel_path = str(path.relative_to(REPO_ROOT))
            text = path.read_text(encoding='utf-8')
            for pattern, allowed in forbidden_patterns.items():
                if rel_path not in allowed:
                    self.assertNotIn(pattern, text, f'{rel_path} should not consume legacy compat alias {pattern}')

    def test_utils_git_direct_imports_are_fully_removed(self):
        direct_imports = set()

        for path in self._iter_pascal_repo_files():
            text = path.read_text(encoding='utf-8')
            if 'fpdev.utils.git' in text:
                direct_imports.add(str(path.relative_to(REPO_ROOT)))

        self.assertEqual(
            set(),
            direct_imports,
            'fpdev.utils.git direct imports should be fully removed after the breaking deletion',
        )

    def test_business_modules_stop_constructing_tgitoperations_directly(self):
        forbidden = [
            'fpdev.fpc.manager.pas',
            'fpdev.resource.repo.pas',
            'fpdev.lazarus.source.pas',
            'fpdev.source.repo.pas',
            'fpdev.fpc.builder.pas',
        ]
        for filename in forbidden:
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertNotIn('TGitOperations.Create', text, f'{filename} should use git runtime injection instead')

    def test_business_modules_stop_constructing_tgitruntime_directly(self):
        migrated = [
            'fpdev.fpc.manager.pas',
            'fpdev.resource.repo.pas',
            'fpdev.lazarus.source.pas',
            'fpdev.source.repo.pas',
            'fpdev.fpc.builder.pas',
            'fpdev.lazarus.manager.pas',
        ]
        for filename in migrated:
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertNotIn('TGitRuntime.Create', text, f'{filename} should use a git runtime factory instead of constructing TGitRuntime directly')

    def test_business_modules_stop_importing_utils_git_for_backend_types(self):
        migrated = [
            'fpdev.resource.repo.pas',
            'fpdev.lazarus.source.pas',
            'fpdev.lazarus.manager.pas',
            'fpdev.fpc.builder.pas',
        ]
        for filename in migrated:
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertNotIn('fpdev.utils.git', text, f'{filename} should consume git backend types from a lighter unit')

    def test_git_operations_default_entrypoint_moves_to_operations_unit(self):
        operations_text = OPERATIONS_PATH.read_text(encoding='utf-8')
        self.assertIn('fpdev.git.operations.impl', operations_text, 'fpdev.git.operations should bridge to the dedicated implementation unit')
        self.assertNotIn('fpdev.utils.git', operations_text, 'fpdev.git.operations should not route through fpdev.utils.git anymore')
        self.assertIn(
            'Default entrypoint for TGitOperations and IGitCliRunner.',
            operations_text,
            'fpdev.git.operations should declare itself as the default entrypoint for operations consumers',
        )
        self.assertNotIn("deprecated 'Use fpdev.git.operations instead'", operations_text)

        operations_impl_text = OPERATIONS_IMPL_PATH.read_text(encoding='utf-8')
        self.assertIn('TGitOperations = class', operations_impl_text)

        runtime_impl_text = RUNTIME_IMPL_PATH.read_text(encoding='utf-8')
        self.assertIn('fpdev.git.operations', runtime_impl_text)
        self.assertNotIn('fpdev.utils.git', runtime_impl_text)

        builder_bridge_text = (SRC / 'fpdev.fpc.builder.gitruntime.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.git.operations', builder_bridge_text)
        self.assertNotIn('fpdev.utils.git', builder_bridge_text)

        operations_test_text = (REPO_ROOT / 'tests' / 'test_git_operations.lpr').read_text(encoding='utf-8')
        self.assertIn('fpdev.git.operations', operations_test_text)
        self.assertNotIn('fpdev.utils.git', operations_test_text)

    def test_git_env_focused_tests_use_lightweight_env_unit(self):
        credentials_text = (REPO_ROOT / 'tests' / 'test_git_env_credentials.lpr').read_text(encoding='utf-8')
        self.assertIn(
            'fpdev.git.env',
            credentials_text,
            'test_git_env_credentials.lpr should use the lightweight git env helper unit',
        )
        self.assertIn(
            'fpdev.git.env.ResolveGitCredentialEnv(',
            credentials_text,
            'test_git_env_credentials.lpr should use the shared credential helper by default',
        )
        self.assertNotIn(
            'fpdev.utils.git.ResolveGitCredentialEnv(',
            credentials_text,
            'test_git_env_credentials.lpr should no longer keep compat-wrapper coverage inline',
        )

        identity_text = (REPO_ROOT / 'tests' / 'test_git_env_identity.lpr').read_text(encoding='utf-8')
        self.assertIn(
            'fpdev.git.env',
            identity_text,
            'test_git_env_identity.lpr should use the lightweight git env helper unit',
        )
        self.assertIn(
            'fpdev.git.env.ResolveGitIdentityEnv(',
            identity_text,
            'test_git_env_identity.lpr should use the shared identity helper by default',
        )
        self.assertNotIn(
            'fpdev.utils.git.ResolveGitIdentityEnv(',
            identity_text,
            'test_git_env_identity.lpr should no longer keep compat-wrapper coverage inline',
        )

    def test_git_operations_test_imports_lightweight_backend_types(self):
        text = (REPO_ROOT / 'tests' / 'test_git_operations.lpr').read_text(encoding='utf-8')
        self.assertIn('fpdev.git.types', text, 'test_git_operations should import backend enum symbols from the lightweight types unit')
        self.assertIn(
            'fpdev.git.types.GitBackendToString(',
            text,
            'test_git_operations should use the shared backend helper by default',
        )
        self.assertNotIn(
            'fpdev.utils.git.GitBackendToString(',
            text,
            'test_git_operations should no longer keep compat backend-wrapper coverage inline',
        )
        self.assertNotIn(
            'fpdev.utils.git.ClassifyGitPullFailure(',
            text,
            'test_git_operations should no longer keep compat pull-failure coverage inline',
        )

    def test_git_compat_migration_doc_exists(self):
        text = (DOCS / 'GIT_COMPAT_MIGRATION.md').read_text(encoding='utf-8')
        self.assertIn('fpdev.utils.git', text)
        self.assertIn('fpdev.git.types', text)
        self.assertIn('fpdev.git.errors', text)
        self.assertIn('fpdev.git.env', text)
        self.assertIn('legacy compatibility layer', text)
        self.assertIn('Breaking removal completed', text)
        self.assertIn('removed from the `fpdev.utils.git` public surface', text)
        self.assertIn('TGitBackend', text)
        self.assertIn('TGitPullFailureKind', text)
        self.assertIn('gpfkUnknown', text)
        self.assertNotIn('tests/test_git_compat_legacy.lpr', text)
        self.assertIn('src/fpdev.fpc.builder.gitruntime.pas', text)
        self.assertIn('tests/test_git_operations.lpr', text)
        self.assertIn('TGitOperations', text)
        self.assertIn('IGitCliRunner', text)
        self.assertIn('src/fpdev.git.operations.pas', text)
        self.assertIn('src/fpdev.git.operations.impl.pas', text)
        self.assertIn('The compatibility shim unit has been deleted.', text)
        self.assertIn('External callers must switch to `fpdev.git.operations`.', text)
        self.assertNotIn('compatibility shim over `fpdev.git.operations`', text)
        self.assertNotIn('soft-deprecated', text)

    def test_git_compat_migration_doc_defines_final_removal_gates_and_reference_buckets(self):
        text = (DOCS / 'GIT_COMPAT_MIGRATION.md').read_text(encoding='utf-8')
        self.assertIn('Final removal gates', text)
        self.assertIn('Current text-reference buckets', text)
        self.assertIn('Active docs may mention `fpdev.utils.git` only when explaining migration or compatibility scope.', text)
        self.assertIn('Repository code and focused tests no longer import `fpdev.utils.git` directly.', text)
        self.assertIn('The shim unit has been deleted; external callers must switch to `fpdev.git.operations`.', text)
        self.assertIn('The breaking release note explicitly lists `TGitOperations` and `IGitCliRunner` removal.', text)
        self.assertNotIn('Remaining external consumers have been given at least one soft-deprecation window.', text)
        self.assertIn('docs/plans/2026-04-10-git-compat-breaking-removal.md', text)

    def test_git_compat_breaking_removal_plan_exists_with_release_note_template(self):
        self.assertTrue(BREAKING_REMOVAL_PLAN.exists(), f'Missing {BREAKING_REMOVAL_PLAN}')
        text = BREAKING_REMOVAL_PLAN.read_text(encoding='utf-8')
        self.assertIn('Git Compat Breaking Removal Implementation Plan', text)
        self.assertIn('src/fpdev.utils.git.pas', text)
        self.assertIn('Release-note template', text)
        self.assertIn('Breaking impact summary', text)
        self.assertIn('Delete: `src/fpdev.utils.git.pas`', text)
        self.assertIn('tests.test_git_runtime_boundary', text)
        self.assertIn('tests.test_contributor_docs_contract', text)
        self.assertIn('tests.test_run_prettier_sh', text)
        self.assertIn('Use `fpdev.git.operations` instead.', text)

    def test_historical_roadmaps_point_git_work_at_operations_units(self):
        for path in [
            HISTORY_DOCS / 'DEVELOPMENT_ROADMAP.md',
            HISTORY_DOCS / 'DEVELOPMENT_ROADMAP.en.md',
        ]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('fpdev.git.operations', text)
            self.assertIn('fpdev.git.operations.impl', text)
            self.assertNotIn('DownloadSource calls `TGitOperations.Clone`', text)
            self.assertNotIn('- `src/fpdev.utils.git.pas` - Backend detection', text)

    def test_historical_deprecated_cleanup_doc_marks_utils_git_as_superseded(self):
        text = (HISTORY_DOCS / 'B166-deprecated-cleanup.md').read_text(encoding='utf-8')
        self.assertIn('compatibility shim has since been removed', text)
        self.assertIn('fpdev.git.operations', text)
        self.assertNotIn('保留 SharedGitManager 作为内部单例', text)

    def test_claude_md_points_new_code_to_git_operations_units(self):
        text = CLAUDE_MD.read_text(encoding='utf-8')
        self.assertIn('src/fpdev.git.operations.pas', text)
        self.assertIn('src/fpdev.git.operations.impl.pas', text)
        self.assertIn('src/fpdev.utils.git.pas', text)
        self.assertIn('removed compatibility shim', text)

    def test_changelog_marks_utils_git_as_legacy_path(self):
        text = CHANGELOG.read_text(encoding='utf-8')
        self.assertIn('fpdev.git.operations', text)
        self.assertIn('fpdev.git.operations.impl', text)
        self.assertIn('Breaking impact summary', text)
        self.assertIn('Removed `src/fpdev.utils.git.pas`', text)
        self.assertIn('External callers must switch to `fpdev.git.operations`', text)
        self.assertNotIn('soft-deprecated compatibility shim', text)
        self.assertNotIn('- fpdev.utils.git.pas: Git utilities', text)

    def test_release_notes_publish_breaking_impact_summary(self):
        text = RELEASE_NOTES.read_text(encoding='utf-8')
        self.assertIn('Breaking impact summary', text)
        self.assertIn('Removed `src/fpdev.utils.git.pas`', text)
        self.assertIn('Removed the last compatibility aliases for `TGitOperations` and `IGitCliRunner`', text)
        self.assertIn('External callers must switch to `fpdev.git.operations`', text)
        self.assertIn('Migration path: Use `fpdev.git.operations` instead.', text)

    def test_historical_deprecated_code_audit_marks_utils_git_as_superseded(self):
        text = (HISTORY_DOCS / 'DEPRECATED_CODE_AUDIT.md').read_text(encoding='utf-8')
        self.assertIn('fpdev.git.operations', text)
        self.assertIn('compatibility shim has since been removed', text)
        self.assertNotIn('No action needed', text)

    def test_git2_usage_guides_point_system_git_facade_at_operations_units(self):
        for path in [
            DOCS / 'GIT2_USAGE.md',
            DOCS / 'GIT2_USAGE.en.md',
        ]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('fpdev.git.operations', text)
            self.assertIn('fpdev.utils.git', text)
            self.assertIn('removed compatibility shim', text)

    def test_git_operations_summary_docs_exist_and_capture_current_surfaces(self):
        expectations = {
            GIT_OPERATIONS_MD: (
                'fpdev.git.operations',
                'src/fpdev.git.operations.impl.pas',
                'git2.api + git2.impl',
                'fpdev.git2',
                'src/fpdev.git.operations.transportflow.pas',
                'tests/test_git_operations.lpr',
                'tests/test_git_operations_transportflow.lpr',
                'tests/fpdev.git2.modern/',
            ),
            GIT_OPERATIONS_EN_MD: (
                'fpdev.git.operations',
                'src/fpdev.git.operations.impl.pas',
                'git2.api + git2.impl',
                'fpdev.git2',
                'src/fpdev.git.operations.transportflow.pas',
                'tests/test_git_operations.lpr',
                'tests/test_git_operations_transportflow.lpr',
                'tests/fpdev.git2.modern/',
            ),
        }
        for path, required in expectations.items():
            self.assertTrue(path.exists(), f'Missing {path}')
            text = path.read_text(encoding='utf-8')
            for needle in required:
                self.assertIn(needle, text, f'{path} should contain {needle!r}')

    def test_architecture_guides_point_system_git_facade_at_operations_units(self):
        for path in [
            DOCS / 'ARCHITECTURE.md',
            DOCS / 'ARCHITECTURE.en.md',
        ]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('fpdev.git.operations', text)
            self.assertIn('fpdev.git.operations.impl', text)
            self.assertIn('fpdev.utils.git', text)
            self.assertIn('removed compatibility shim', text)

    def test_libgit2_integration_guides_clarify_system_git_facade_scope(self):
        for path in [
            DOCS / 'LIBGIT2_INTEGRATION.md',
            DOCS / 'LIBGIT2_INTEGRATION.en.md',
        ]:
            text = path.read_text(encoding='utf-8')
            self.assertIn('system-git facade', text)
            self.assertIn('fpdev.git.operations', text)
            self.assertIn('fpdev.git.operations.impl', text)
            self.assertIn('fpdev.utils.git', text)
            self.assertIn('removed compatibility shim', text)

    def test_active_docs_limit_utils_git_mentions_to_whitelisted_scope_guides(self):
        expected = {
            'docs/ARCHITECTURE.en.md',
            'docs/ARCHITECTURE.md',
            'docs/GIT2_USAGE.en.md',
            'docs/GIT2_USAGE.md',
            'docs/GIT_COMPAT_MIGRATION.md',
            'docs/LIBGIT2_INTEGRATION.en.md',
            'docs/LIBGIT2_INTEGRATION.md',
        }
        found = set()
        active_docs = []
        for path in [REPO_ROOT / 'README.md', REPO_ROOT / 'README.en.md']:
            if path.exists():
                active_docs.append(path)
        active_docs.extend(sorted(DOCS.glob('*.md')))

        for path in active_docs:
            text = path.read_text(encoding='utf-8')
            if 'fpdev.utils.git' in text:
                found.add(str(path.relative_to(REPO_ROOT)))

        self.assertEqual(
            expected,
            found,
            'Active docs should mention fpdev.utils.git only in migration or compat-scope guides',
        )

    def test_git_compat_legacy_suite_is_removed(self):
        self.assertFalse(
            (REPO_ROOT / 'tests' / 'test_git_compat_legacy.lpr').exists(),
            'dedicated legacy compat suite should be removed once the compat public surface is deleted',
        )

    def test_builder_gitruntime_stays_builder_specific_bridge(self):
        helper_text = (SRC / 'fpdev.fpc.builder.gitruntime.pas').read_text(encoding='utf-8')
        self.assertIn(
            'Builder-specific process-runner clone bridge.',
            helper_text,
            'fpdev.fpc.builder.gitruntime should declare its builder-specific bridge role',
        )
        self.assertIn(
            'Keep this helper builder-local unless another non-builder caller needs the adapter.',
            helper_text,
            'fpdev.fpc.builder.gitruntime should document why the helper stays builder-specific for now',
        )

        consumers = set()
        for path in self._iter_pascal_repo_files():
            if path.name == 'fpdev.fpc.builder.gitruntime.pas':
                continue
            text = path.read_text(encoding='utf-8')
            if 'fpdev.fpc.builder.gitruntime' in text:
                consumers.add(str(path.relative_to(REPO_ROOT)))

        self.assertEqual(
            {'src/fpdev.fpc.builder.di.pas'},
            consumers,
            'fpdev.fpc.builder.gitruntime should remain a builder-only helper until another concrete caller exists',
        )

    def test_git_operations_suite_stays_focused_on_default_operations_facade(self):
        text = (REPO_ROOT / 'tests' / 'test_git_operations.lpr').read_text(encoding='utf-8')
        self.assertIn(
            'Focused contract tests for the default operations facade.',
            text,
            'test_git_operations should describe itself as the focused contract suite for fpdev.git.operations',
        )
        self.assertIn(
            'legacy compatibility layer.',
            text,
            'test_git_operations should explicitly avoid presenting itself as a compat-layer test',
        )
        self.assertIn('fpdev.git.operations', text)
        self.assertNotIn('fpdev.utils.git;', text)

    def test_git_compat_facade_stops_binding_to_utils_git(self):
        text = (SRC / 'fpdev.git.pas').read_text(encoding='utf-8')
        self.assertIn('fpdev.git.runtime', text, 'fpdev.git facade should use the runtime adapter')
        self.assertNotIn('fpdev.utils.git', text, 'fpdev.git facade should depend on git runtime instead of fpdev.utils.git')
        self.assertNotIn('TGitOperations', text, 'fpdev.git facade should not expose or hold TGitOperations directly')
        self.assertNotIn('TGitOperations.Create', text, 'fpdev.git facade should construct the runtime adapter instead of TGitOperations directly')

    def test_fpc_builder_di_stops_binding_to_utils_git_contracts(self):
        text = (SRC / 'fpdev.fpc.builder.di.pas').read_text(encoding='utf-8')
        self.assertIn(
            'fpdev.fpc.builder.gitruntime',
            text,
            'fpdev.fpc.builder.di should use a builder-specific git runtime helper',
        )
        self.assertNotIn('fpdev.utils.git', text, 'fpdev.fpc.builder.di should not depend on fpdev.utils.git directly')
        self.assertNotIn('IGitCliRunner', text, 'fpdev.fpc.builder.di should not know about IGitCliRunner directly')
        self.assertNotIn('TGitOperations.Create', text, 'fpdev.fpc.builder.di should not construct TGitOperations directly')

    def test_business_modules_stop_describing_tgitoperations_directly(self):
        migrated = [
            'fpdev.resource.repo.pas',
            'fpdev.fpc.builder.pas',
            'fpdev.lazarus.source.pas',
        ]
        for filename in migrated:
            text = (SRC / filename).read_text(encoding='utf-8')
            self.assertNotIn(
                'TGitOperations',
                text,
                f'{filename} should describe the git runtime/backend, not the legacy concrete type',
            )


if __name__ == '__main__':
    unittest.main()
