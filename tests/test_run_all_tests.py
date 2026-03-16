import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / 'scripts' / 'run_all_tests.sh'


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

    def create_stub_tool(self, directory: Path, name: str, content: str) -> Path:
        path = directory / name
        path.write_text(content, encoding='utf-8')
        path.chmod(0o755)
        return path

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
            self.assertEqual('2', fpc_count_file.read_text(encoding='utf-8'))
            self.assertFalse(stale_object.exists(), 'recovery should remove stale linker artifacts before retry')
            self.assertTrue(test_bin.exists())
            self.assertGreater(test_bin.stat().st_size, 0)
            self.assertIn('retrying once', build_log.read_text(encoding='utf-8'))

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


if __name__ == '__main__':
    unittest.main()
