import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / 'scripts' / 'run_all_tests.sh'
FOCUSED_SCRIPT_PATH = REPO_ROOT / 'scripts' / 'run_single_test.sh'


class RunAllTestsScriptTests(unittest.TestCase):
    def run_bash(self, script: str, cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        merged_env = os.environ.copy()
        if env:
            merged_env.update(env)
        return subprocess.run(
            ['bash', '-c', script],
            cwd=cwd,
            env=merged_env,
            text=True,
            capture_output=True,
        )

    def read_env_file(self, path: Path) -> dict[str, str]:
        values: dict[str, str] = {}
        for line in path.read_text(encoding='utf-8').splitlines():
            key, value = line.split('=', 1)
            values[key] = value
        return values

    def create_stub_tool(self, directory: Path, name: str, content: str) -> Path:
        path = directory / name
        path.write_text(content, encoding='utf-8')
        path.chmod(0o755)
        return path

    def write_script_copy(self, source: Path, destination: Path) -> Path:
        destination.write_text(source.read_text(encoding='utf-8'), encoding='utf-8')
        destination.chmod(0o755)
        return destination

    def test_create_test_tmp_root_honors_fpdev_test_tmpdir(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            custom_tmp = tmp_path / 'custom-temp-root'
            env = {'FPDEV_TEST_TMPDIR': str(custom_tmp)}

            result = self.run_bash(
                textwrap.dedent(
                    f'''\
                    source "{SCRIPT_PATH}"
                    tmp_root="$(create_test_tmp_root)"
                    printf '%s\\n' "$tmp_root"
                    test -d "$tmp_root"
                    case "$tmp_root" in
                      "{custom_tmp}"/fpdev-tests.*) ;;
                      *) exit 1 ;;
                    esac
                    rm -rf "$tmp_root"
                    '''
                ),
                cwd=tmp_path,
                env=env,
            )

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}',
            )

    def test_run_single_test_uses_dedicated_runtime_roots_per_pascal_binary(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            tool_dir = tmp_path / 'toolbin'
            tests_dir = tmp_path / 'tests'
            tool_dir.mkdir()
            tests_dir.mkdir()

            test_file = tests_dir / 'test_demo.lpr'
            test_file.write_text('program test_demo;\nbegin\nend.\n', encoding='utf-8')
            shared_env_file = tmp_path / 'shared-env.txt'
            build_env_file = tmp_path / 'build-env.txt'
            run_env_file = tmp_path / 'run-env.txt'

            self.create_stub_tool(
                tool_dir,
                'fpc',
                textwrap.dedent(
                    """#!/bin/sh
                    printf 'TMPDIR=%s\nFPDEV_DATA_ROOT=%s\nFPDEV_LAZARUS_CONFIG_ROOT=%s\n' \
                      "$TMPDIR" "$FPDEV_DATA_ROOT" "$FPDEV_LAZARUS_CONFIG_ROOT" > "$FPDEV_STUB_BUILD_ENV_FILE"
                    out_dir=''
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        -FE*)
                          out_dir=${1#-FE}
                          ;;
                      esac
                      shift
                    done
                    mkdir -p "$out_dir"
                    cat > "$out_dir/test_demo" <<'EOF'
                    #!/bin/sh
                    printf 'TMPDIR=%s\nFPDEV_DATA_ROOT=%s\nFPDEV_LAZARUS_CONFIG_ROOT=%s\n' \
                      "$TMPDIR" "$FPDEV_DATA_ROOT" "$FPDEV_LAZARUS_CONFIG_ROOT" > "$FPDEV_STUB_RUN_ENV_FILE"
                    exit 0
                    EOF
                    chmod +x "$out_dir/test_demo"
                    exit 0
                    """
                ),
            )

            env = {
                'PATH': f'{tool_dir}:{os.environ.get("PATH", "")}',
                'FPDEV_STUB_BUILD_ENV_FILE': str(build_env_file),
                'FPDEV_STUB_RUN_ENV_FILE': str(run_env_file),
            }
            result = self.run_bash(
                textwrap.dedent(
                    f'''\
                    source "{SCRIPT_PATH}"
                    init_test_environment
                    printf 'TMPDIR=%s\\nFPDEV_DATA_ROOT=%s\\nFPDEV_LAZARUS_CONFIG_ROOT=%s\\n' \
                      "$TEST_TMP_ROOT" "$TEST_DATA_ROOT" "$TEST_LAZARUS_CONFIG_ROOT" > "{shared_env_file}"
                    run_single_test "tests/test_demo.lpr"
                    '''
                ),
                cwd=tmp_path,
                env=env,
            )

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}',
            )
            shared_env = self.read_env_file(shared_env_file)
            build_env = self.read_env_file(build_env_file)
            self.assertEqual(
                str(Path(shared_env['TMPDIR']) / 'test_demo' / 'tmp'),
                build_env['TMPDIR'],
            )
            self.assertEqual(
                str(Path(shared_env['TMPDIR']) / 'test_demo' / 'fpdev-data'),
                build_env['FPDEV_DATA_ROOT'],
            )
            self.assertEqual(
                str(Path(shared_env['TMPDIR']) / 'test_demo' / 'lazarus-config'),
                build_env['FPDEV_LAZARUS_CONFIG_ROOT'],
            )

    def test_init_test_environment_exports_system_temp_env_to_test_tmp_root(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            custom_tmp = tmp_path / 'custom-temp-root'
            env = {'FPDEV_TEST_TMPDIR': str(custom_tmp)}

            result = self.run_bash(
                textwrap.dedent(
                    f'''\
                    source "{SCRIPT_PATH}"
                    init_test_environment
                    test -n "$TEST_TMP_ROOT"
                    case "$TEST_TMP_ROOT" in
                      "{custom_tmp}"/fpdev-tests.*) ;;
                      *) exit 1 ;;
                    esac
                    test "$TMPDIR" = "$TEST_TMP_ROOT"
                    test "$TMP" = "$TEST_TMP_ROOT"
                    test "$TEMP" = "$TEST_TMP_ROOT"
                    cleanup
                    '''
                ),
                cwd=tmp_path,
                env=env,
            )

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}',
            )

    def test_transient_build_failure_detects_no_space_left_on_device(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            build_log = tmp_path / 'build.log'
            build_log.write_text('Fatal: No space left on device\n', encoding='utf-8')

            result = self.run_bash(
                f'source "{SCRIPT_PATH}" && is_transient_build_failure "{build_log}"',
                cwd=tmp_path,
            )

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}',
            )

    def test_transient_runtime_failure_detects_busy_or_missing_binary_noise(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            busy_log = tmp_path / 'busy.log'
            busy_log.write_text('scripts/run_all_tests.sh: line 121: bin/test_demo: Text file busy\n', encoding='utf-8')
            missing_log = tmp_path / 'missing.log'
            missing_log.write_text('scripts/run_all_tests.sh: line 121: bin/test_demo: No such file or directory\n', encoding='utf-8')

            busy_result = self.run_bash(
                f'source "{SCRIPT_PATH}" && is_transient_runtime_failure "{busy_log}"',
                cwd=tmp_path,
            )
            missing_result = self.run_bash(
                f'source "{SCRIPT_PATH}" && is_transient_runtime_failure "{missing_log}"',
                cwd=tmp_path,
            )

            self.assertEqual(
                0,
                busy_result.returncode,
                msg=f'stdout={busy_result.stdout}\nstderr={busy_result.stderr}',
            )
            self.assertEqual(
                0,
                missing_result.returncode,
                msg=f'stdout={missing_result.stdout}\nstderr={missing_result.stderr}',
            )

    def test_transient_runtime_failure_ignores_regular_test_output(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            run_log = tmp_path / 'run.log'
            run_log.write_text('Error: No such file or directory\n', encoding='utf-8')

            result = self.run_bash(
                f'source "{SCRIPT_PATH}" && is_transient_runtime_failure "{run_log}"',
                cwd=tmp_path,
            )

            self.assertNotEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}',
            )

    def test_run_test_binary_retries_transient_runtime_failures(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            run_count_file = tmp_path / 'run.count'
            run_log = tmp_path / 'run.log'
            test_bin = tmp_path / 'test_demo'

            test_bin.write_text(
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_RUN_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_RUN_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_RUN_COUNT"
                    if [ "$count" -lt 3 ]; then
                      echo "scripts/run_all_tests.sh: line 121: $0: Text file busy" >&2
                      exit 126
                    fi
                    exit 0
                    """
                ),
                encoding='utf-8',
            )
            test_bin.chmod(0o755)

            env = {
                'FPDEV_STUB_RUN_COUNT': str(run_count_file),
                'FPDEV_TEST_RUNTIME_RETRY_DELAY': '0',
            }
            result = self.run_bash(
                textwrap.dedent(
                    f'''\
                    source "{SCRIPT_PATH}"
                    run_test_binary "{test_bin}" "{run_log}"
                    '''
                ),
                cwd=tmp_path,
                env=env,
            )

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}\nlog={run_log.read_text(encoding="utf-8") if run_log.exists() else ""}',
            )
            self.assertEqual('3', run_count_file.read_text(encoding='utf-8'))

    def test_build_with_recovery_retries_zero_byte_binary_after_successful_lazbuild(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            tool_dir = tmp_path / 'toolbin'
            tool_dir.mkdir()

            test_dir = tmp_path / 'tests' / 'demo'
            test_dir.mkdir(parents=True)
            test_lpi = test_dir / 'test_demo.lpi'
            test_lpi.write_text('<CONFIG/>\n', encoding='utf-8')
            test_file = test_dir / 'test_demo.lpr'
            test_file.write_text('program test_demo;\nbegin\nend.\n', encoding='utf-8')
            test_bin = test_dir / 'bin' / 'test_demo'
            test_bin.parent.mkdir(parents=True)
            build_log = tmp_path / 'build.log'
            count_file = tmp_path / 'lazbuild.count'
            fpc_count_file = tmp_path / 'fpc.count'

            self.create_stub_tool(
                tool_dir,
                'lazbuild',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_LAZBUILD_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_LAZBUILD_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_LAZBUILD_COUNT"
                    if [ "$count" -eq 1 ]; then
                      : > "$FPDEV_STUB_TARGET_BIN"
                      exit 0
                    fi
                    cat > "$FPDEV_STUB_TARGET_BIN" <<'EOF'
                    #!/bin/sh
                    exit 0
                    EOF
                    chmod +x "$FPDEV_STUB_TARGET_BIN"
                    exit 0
                    """
                ),
            )
            self.create_stub_tool(
                tool_dir,
                'fpc',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_FPC_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_FPC_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_FPC_COUNT"
                    exit 99
                    """
                ),
            )

            env = {
                'PATH': f'{tool_dir}:{os.environ.get("PATH", "")}',
                'FPDEV_STUB_TARGET_BIN': str(test_bin),
                'FPDEV_STUB_LAZBUILD_COUNT': str(count_file),
                'FPDEV_STUB_FPC_COUNT': str(fpc_count_file),
            }
            command = textwrap.dedent(
                f'''\
                source "{SCRIPT_PATH}"
                build_test_with_recovery \
                  "{test_lpi}" \
                  "{test_file}" \
                  "{test_bin}" \
                  "{test_dir}" \
                  "test_demo" \
                  "{build_log}"
                test -s "{test_bin}"
                '''
            )

            result = self.run_bash(command, cwd=tmp_path, env=env)

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}\nlog={build_log.read_text(encoding="utf-8") if build_log.exists() else ""}',
            )
            self.assertEqual('2', count_file.read_text(encoding='utf-8'))
            self.assertFalse(fpc_count_file.exists(), 'fpc fallback should not run when lazbuild retry recovers the binary')

    def test_build_with_recovery_falls_back_when_successful_lazbuild_produces_no_binary(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            tool_dir = tmp_path / 'toolbin'
            tool_dir.mkdir()

            test_dir = tmp_path / 'tests' / 'demo'
            test_dir.mkdir(parents=True)
            test_lpi = test_dir / 'test_demo.lpi'
            test_lpi.write_text('<CONFIG/>\n', encoding='utf-8')
            test_file = test_dir / 'test_demo.lpr'
            test_file.write_text('program test_demo;\nbegin\nend.\n', encoding='utf-8')
            test_bin = test_dir / 'bin' / 'test_demo'
            test_bin.parent.mkdir(parents=True)
            build_log = tmp_path / 'build.log'
            lazbuild_count_file = tmp_path / 'lazbuild.count'
            fpc_count_file = tmp_path / 'fpc.count'

            self.create_stub_tool(
                tool_dir,
                'lazbuild',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_LAZBUILD_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_LAZBUILD_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_LAZBUILD_COUNT"
                    if [ "$count" -eq 1 ]; then
                      exit 0
                    fi
                    echo 'Fatal: build failed after retry' >&2
                    exit 1
                    """
                ),
            )
            self.create_stub_tool(
                tool_dir,
                'fpc',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_FPC_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_FPC_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_FPC_COUNT"
                    out_dir=''
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        -FE*)
                          out_dir=${1#-FE}
                          ;;
                      esac
                      shift
                    done
                    mkdir -p "$out_dir"
                    cat > "$out_dir/test_demo" <<'EOF'
                    #!/bin/sh
                    exit 0
                    EOF
                    chmod +x "$out_dir/test_demo"
                    exit 0
                    """
                ),
            )

            env = {
                'PATH': f'{tool_dir}:{os.environ.get("PATH", "")}',
                'FPDEV_STUB_LAZBUILD_COUNT': str(lazbuild_count_file),
                'FPDEV_STUB_FPC_COUNT': str(fpc_count_file),
            }
            command = textwrap.dedent(
                f'''\
                source "{SCRIPT_PATH}"
                build_test_with_recovery \
                  "{test_lpi}" \
                  "{test_file}" \
                  "{test_bin}" \
                  "{test_dir}" \
                  "test_demo" \
                  "{build_log}"
                test -s "{test_bin}"
                '''
            )

            result = self.run_bash(command, cwd=tmp_path, env=env)

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}\nlog={build_log.read_text(encoding="utf-8") if build_log.exists() else ""}',
            )
            self.assertEqual('2', lazbuild_count_file.read_text(encoding='utf-8'))
            self.assertEqual('1', fpc_count_file.read_text(encoding='utf-8'))
            self.assertTrue(test_bin.exists())
            self.assertGreater(test_bin.stat().st_size, 0)

    def test_build_with_recovery_retries_after_fpc_linker_artifact_corruption(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            tool_dir = tmp_path / 'toolbin'
            tool_dir.mkdir()
            (tmp_path / 'lib').mkdir()

            stale_object = tmp_path / 'lib' / 'stale-link.o'
            stale_object.write_text('corrupt\n', encoding='utf-8')

            test_dir = tmp_path / 'tests'
            test_dir.mkdir(parents=True)
            test_lpi = test_dir / 'test_demo.lpi'
            test_file = test_dir / 'test_demo.lpr'
            test_file.write_text('program test_demo;\nbegin\nend.\n', encoding='utf-8')
            test_bin = tmp_path / 'bin' / 'test_demo'
            test_bin.parent.mkdir(parents=True)
            build_log = tmp_path / 'build.log'
            fpc_count_file = tmp_path / 'fpc.count'

            self.create_stub_tool(
                tool_dir,
                'fpc',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_FPC_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_FPC_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_FPC_COUNT"
                    out_dir=''
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        -FE*)
                          out_dir=${1#-FE}
                          ;;
                      esac
                      shift
                    done
                    if [ -f "$FPDEV_STUB_STALE_OBJECT" ]; then
                      echo '/usr/bin/ld.bfd: lib/fpdev.lazarus.config.o: bad reloc symbol index (0x735f6b63 >= 0x118)' >&2
                      echo '/usr/bin/ld.bfd: failed to set dynamic section sizes: bad value' >&2
                      exit 1
                    fi
                    mkdir -p "$out_dir"
                    cat > "$out_dir/test_demo" <<'EOF'
                    #!/bin/sh
                    exit 0
                    EOF
                    chmod +x "$out_dir/test_demo"
                    exit 0
                    """
                ),
            )

            env = {
                'PATH': f'{tool_dir}:{os.environ.get("PATH", "")}',
                'FPDEV_STUB_FPC_COUNT': str(fpc_count_file),
                'FPDEV_STUB_STALE_OBJECT': str(stale_object),
            }
            command = textwrap.dedent(
                f'''\
                source "{SCRIPT_PATH}"
                build_test_with_recovery \
                  "{test_lpi}" \
                  "{test_file}" \
                  "{test_bin}" \
                  "{test_dir}" \
                  "test_demo" \
                  "{build_log}"
                test -s "{test_bin}"
                '''
            )

            result = self.run_bash(command, cwd=tmp_path, env=env)

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}\nlog={build_log.read_text(encoding="utf-8") if build_log.exists() else ""}',
            )
            self.assertEqual('1', fpc_count_file.read_text(encoding='utf-8'))
            self.assertFalse(stale_object.exists(), 'pre-build cleanup should remove stale linker artifacts before the first attempt')
            self.assertTrue(test_bin.exists())
            self.assertGreater(test_bin.stat().st_size, 0)

    def test_build_with_recovery_cleans_shared_compiler_artifacts_before_first_build(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            tool_dir = tmp_path / 'toolbin'
            shared_lib_dir = tmp_path / 'lib' / 'x86_64-linux'
            tool_dir.mkdir()
            shared_lib_dir.mkdir(parents=True)

            stale_unit = shared_lib_dir / 'stale.ppu'
            stale_unit.write_text('stale\n', encoding='utf-8')

            test_dir = tmp_path / 'tests'
            test_dir.mkdir(parents=True)
            test_lpi = test_dir / 'test_demo.lpi'
            test_lpi.write_text('<CONFIG/>\n', encoding='utf-8')
            test_file = test_dir / 'test_demo.lpr'
            test_file.write_text('program test_demo;\nbegin\nend.\n', encoding='utf-8')
            test_bin = tmp_path / 'bin' / 'test_demo'
            test_bin.parent.mkdir(parents=True)
            build_log = tmp_path / 'build.log'
            lazbuild_count_file = tmp_path / 'lazbuild.count'
            fpc_count_file = tmp_path / 'fpc.count'

            self.create_stub_tool(
                tool_dir,
                'lazbuild',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_LAZBUILD_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_LAZBUILD_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_LAZBUILD_COUNT"
                    if [ -f "$FPDEV_STUB_STALE_UNIT" ]; then
                      echo 'stale shared unit still present' >&2
                      exit 1
                    fi
                    mkdir -p "$(dirname "$FPDEV_STUB_TARGET_BIN")"
                    cat > "$FPDEV_STUB_TARGET_BIN" <<'EOF'
                    #!/bin/sh
                    exit 0
                    EOF
                    chmod +x "$FPDEV_STUB_TARGET_BIN"
                    exit 0
                    """
                ),
            )
            self.create_stub_tool(
                tool_dir,
                'fpc',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_FPC_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_FPC_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_FPC_COUNT"
                    exit 99
                    """
                ),
            )

            env = {
                'PATH': f'{tool_dir}:{os.environ.get("PATH", "")}',
                'FPDEV_STUB_TARGET_BIN': str(test_bin),
                'FPDEV_STUB_STALE_UNIT': str(stale_unit),
                'FPDEV_STUB_LAZBUILD_COUNT': str(lazbuild_count_file),
                'FPDEV_STUB_FPC_COUNT': str(fpc_count_file),
            }
            command = textwrap.dedent(
                f'''\
                source "{SCRIPT_PATH}"
                build_test_with_recovery \
                  "{test_lpi}" \
                  "{test_file}" \
                  "{test_bin}" \
                  "{test_dir}" \
                  "test_demo" \
                  "{build_log}"
                test -s "{test_bin}"
                '''
            )

            result = self.run_bash(command, cwd=tmp_path, env=env)

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}\nlog={build_log.read_text(encoding="utf-8") if build_log.exists() else ""}',
            )
            self.assertFalse(stale_unit.exists(), 'shared compiler artifacts should be cleared before the first lazbuild attempt')
            self.assertEqual('1', lazbuild_count_file.read_text(encoding='utf-8'))
            self.assertFalse(fpc_count_file.exists(), 'fpc fallback should stay unused when pre-build cleanup lets lazbuild succeed')

    def test_build_with_recovery_uses_isolated_unit_output_for_fpc_fallback(self):
        with tempfile.TemporaryDirectory(prefix='run-all-tests-') as tmp:
            tmp_path = Path(tmp)
            tool_dir = tmp_path / 'toolbin'
            tool_dir.mkdir()

            test_dir = tmp_path / 'tests' / 'demo'
            test_dir.mkdir(parents=True)
            test_lpi = test_dir / 'test_demo.lpi'
            test_lpi.write_text('<CONFIG/>\n', encoding='utf-8')
            test_file = test_dir / 'test_demo.lpr'
            test_file.write_text('program test_demo;\nbegin\nend.\n', encoding='utf-8')
            test_bin = test_dir / 'bin' / 'test_demo'
            test_bin.parent.mkdir(parents=True)
            build_log = tmp_path / 'build.log'
            args_file = tmp_path / 'fpc-args.txt'

            self.create_stub_tool(
                tool_dir,
                'lazbuild',
                textwrap.dedent(
                    """#!/bin/sh
                    echo 'Fatal: build failed after retry' >&2
                    exit 1
                    """
                ),
            )
            self.create_stub_tool(
                tool_dir,
                'fpc',
                textwrap.dedent(
                    """#!/bin/sh
                    printf '%s\n' "$@" > "$FPDEV_STUB_FPC_ARGS"
                    out_dir=''
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        -FE*)
                          out_dir=${1#-FE}
                          ;;
                      esac
                      shift
                    done
                    mkdir -p "$out_dir"
                    cat > "$out_dir/test_demo" <<'EOF'
                    #!/bin/sh
                    exit 0
                    EOF
                    chmod +x "$out_dir/test_demo"
                    exit 0
                    """
                ),
            )

            env = {
                'PATH': f'{tool_dir}:{os.environ.get("PATH", "")}',
                'FPDEV_STUB_FPC_ARGS': str(args_file),
            }
            command = textwrap.dedent(
                f'''\
                source "{SCRIPT_PATH}"
                build_test_with_recovery \
                  "{test_lpi}" \
                  "{test_file}" \
                  "{test_bin}" \
                  "{test_dir}" \
                  "test_demo" \
                  "{build_log}"
                test -s "{test_bin}"
                '''
            )

            result = self.run_bash(command, cwd=tmp_path, env=env)

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}\nlog={build_log.read_text(encoding="utf-8") if build_log.exists() else ""}',
            )
            args = args_file.read_text(encoding='utf-8').splitlines()
            fu_args = [arg for arg in args if arg.startswith('-FU')]
            self.assertEqual(1, len(fu_args), f'expected one -FU arg, got {fu_args!r}')
            self.assertNotEqual('-FUlib', fu_args[0], 'fpc fallback should not write units into the shared lib directory')
            self.assertEqual(
                f'-FU{test_bin.parent / "lib"}',
                fu_args[0],
                'fpc fallback should isolate unit output under the per-test bin directory',
            )

    def test_run_single_test_requires_exact_test_file_path(self):
        with tempfile.TemporaryDirectory(prefix='run-single-test-') as tmp:
            tmp_path = Path(tmp)
            scripts_dir = tmp_path / 'scripts'
            scripts_dir.mkdir()
            focused_script = self.write_script_copy(FOCUSED_SCRIPT_PATH, scripts_dir / 'run_single_test.sh')
            self.write_script_copy(SCRIPT_PATH, scripts_dir / 'run_all_tests.sh')

            result = self.run_bash(f'"{focused_script}"', cwd=tmp_path)

            self.assertEqual(2, result.returncode, msg=f'stdout={result.stdout}\nstderr={result.stderr}')
            self.assertIn('Usage:', result.stderr)

    def test_run_single_test_reuses_build_recovery_for_targeted_pascal_suite(self):
        with tempfile.TemporaryDirectory(prefix='run-single-test-') as tmp:
            tmp_path = Path(tmp)
            scripts_dir = tmp_path / 'scripts'
            tool_dir = tmp_path / 'toolbin'
            tests_dir = tmp_path / 'tests'
            lib_dir = tmp_path / 'lib'
            scripts_dir.mkdir()
            tool_dir.mkdir()
            tests_dir.mkdir()
            lib_dir.mkdir()

            focused_script = self.write_script_copy(FOCUSED_SCRIPT_PATH, scripts_dir / 'run_single_test.sh')
            self.write_script_copy(SCRIPT_PATH, scripts_dir / 'run_all_tests.sh')

            test_file = tests_dir / 'test_demo.lpr'
            test_file.write_text('program test_demo;\nbegin\nend.\n', encoding='utf-8')
            stale_object = lib_dir / 'stale-link.o'
            stale_object.write_text('corrupt\n', encoding='utf-8')
            fpc_count_file = tmp_path / 'fpc.count'

            self.create_stub_tool(
                tool_dir,
                'fpc',
                textwrap.dedent(
                    """#!/bin/sh
                    count=0
                    if [ -f "$FPDEV_STUB_FPC_COUNT" ]; then
                      count=$(cat "$FPDEV_STUB_FPC_COUNT")
                    fi
                    count=$((count + 1))
                    printf '%s' "$count" > "$FPDEV_STUB_FPC_COUNT"
                    out_dir=''
                    while [ "$#" -gt 0 ]; do
                      case "$1" in
                        -FE*)
                          out_dir=${1#-FE}
                          ;;
                      esac
                      shift
                    done
                    if [ -f "lib/stale-link.o" ]; then
                      echo '/usr/bin/ld.bfd: lib/fpdev.lazarus.config.o: bad reloc symbol index (0x735f6b63 >= 0x118)' >&2
                      echo '/usr/bin/ld.bfd: failed to set dynamic section sizes: bad value' >&2
                      exit 1
                    fi
                    mkdir -p "$out_dir"
                    printf '#!/bin/sh\nexit 0\n' > "$out_dir/test_demo"
                    chmod +x "$out_dir/test_demo"
                    exit 0
                    """
                ),
            )

            env = {
                'PATH': f'{tool_dir}:{os.environ.get("PATH", "")}',
                'FPDEV_STUB_FPC_COUNT': str(fpc_count_file),
            }
            result = self.run_bash(f'"{focused_script}" "tests/test_demo.lpr"', cwd=tmp_path, env=env)

            self.assertEqual(
                0,
                result.returncode,
                msg=f'stdout={result.stdout}\nstderr={result.stderr}',
            )
            self.assertEqual('1', fpc_count_file.read_text(encoding='utf-8'))
            self.assertFalse(stale_object.exists(), 'pre-build cleanup should remove stale linker artifacts before the first attempt')
            self.assertTrue((tmp_path / 'bin' / 'test_demo').exists())
            self.assertIn('Testing test_demo...', result.stdout)
            self.assertIn('All tests passed!', result.stdout)


if __name__ == '__main__':
    unittest.main()
