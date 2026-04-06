import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parents[1] / 'scripts' / 'analyze_code_quality.py'


def load_analyzer_module():
    spec = importlib.util.spec_from_file_location('analyze_code_quality', SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AnalyzeCodeQualityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.analyzer = load_analyzer_module()

    def run_debug_analysis(self, source_files):
        with tempfile.TemporaryDirectory(prefix='acq-test-') as tmp:
            tmp_path = Path(tmp)
            src_path = tmp_path / 'src'
            src_path.mkdir(parents=True, exist_ok=True)

            for relative_name, content in source_files.items():
                file_path = src_path / relative_name
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(content, encoding='utf-8')

            prev_cwd = Path.cwd()
            try:
                os.chdir(tmp_path)
                issues = self.analyzer.analyze_temp_files_and_debug_code()
            finally:
                os.chdir(prev_cwd)

            return issues

    def run_hardcoded_analysis(self, source_files):
        with tempfile.TemporaryDirectory(prefix='acq-test-') as tmp:
            tmp_path = Path(tmp)
            src_path = tmp_path / 'src'
            src_path.mkdir(parents=True, exist_ok=True)

            for relative_name, content in source_files.items():
                file_path = src_path / relative_name
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(content, encoding='utf-8')

            prev_cwd = Path.cwd()
            try:
                os.chdir(tmp_path)
                issues = self.analyzer.analyze_hardcoded_constants()
            finally:
                os.chdir(prev_cwd)

            return issues

    def run_style_analysis(self, source_files):
        with tempfile.TemporaryDirectory(prefix='acq-test-') as tmp:
            tmp_path = Path(tmp)
            src_path = tmp_path / 'src'
            src_path.mkdir(parents=True, exist_ok=True)

            for relative_name, content in source_files.items():
                file_path = src_path / relative_name
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(content, encoding='utf-8')

            prev_cwd = Path.cwd()
            try:
                os.chdir(tmp_path)
                issues = self.analyzer.analyze_code_style()
            finally:
                os.chdir(prev_cwd)

            return issues

    def run_repository_hygiene_analysis(self, repo_files, tracked_files=None, gitignore=None):
        tracked_files = tracked_files or []
        with tempfile.TemporaryDirectory(prefix='acq-test-') as tmp:
            tmp_path = Path(tmp)
            (tmp_path / 'src').mkdir(parents=True, exist_ok=True)

            for relative_name, content in repo_files.items():
                file_path = tmp_path / relative_name
                file_path.parent.mkdir(parents=True, exist_ok=True)
                if isinstance(content, bytes):
                    file_path.write_bytes(content)
                else:
                    file_path.write_text(content, encoding='utf-8')

            subprocess.run(['git', 'init', '-q'], cwd=tmp_path, check=True)
            if gitignore is not None:
                (tmp_path / '.gitignore').write_text(gitignore, encoding='utf-8')
            for relative_name in tracked_files:
                subprocess.run(['git', 'add', '-f', relative_name], cwd=tmp_path, check=True)

            prev_cwd = Path.cwd()
            try:
                os.chdir(tmp_path)
                analyzer = getattr(self.analyzer, 'analyze_repository_hygiene', None)
                issues = analyzer() if analyzer is not None else []
            finally:
                os.chdir(prev_cwd)

            return issues

    def run_legacy_backup_analysis(self, source_files):
        with tempfile.TemporaryDirectory(prefix='acq-test-') as tmp:
            tmp_path = Path(tmp)
            src_path = tmp_path / 'src'
            src_path.mkdir(parents=True, exist_ok=True)

            for relative_name, content in source_files.items():
                file_path = src_path / relative_name
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(content, encoding='utf-8')

            prev_cwd = Path.cwd()
            try:
                os.chdir(tmp_path)
                analyzer = getattr(self.analyzer, 'analyze_legacy_source_backups', None)
                issues = analyzer() if analyzer is not None else []
            finally:
                os.chdir(prev_cwd)

            return issues

    @staticmethod
    def debug_flagged_files(issues):
        names = set()
        for issue in issues:
            if issue.get('type') != 'debug_code':
                continue
            for file_info in issue.get('files', []):
                names.add(Path(str(file_info['file'])).name)
        return names

    @staticmethod
    def hardcoded_flagged_files(issues):
        names = set()
        for issue in issues:
            if issue.get('type') != 'hardcoded_constants':
                continue
            for file_info in issue.get('files', []):
                names.add(Path(str(file_info['file'])).name)
        return names

    @staticmethod
    def style_flagged_files(issues):
        names = set()
        for issue in issues:
            if issue.get('type') != 'code_style':
                continue
            for file_info in issue.get('files', []):
                names.add(Path(str(file_info['file'])).name)
        return names

    @staticmethod
    def repository_hygiene_flagged_files(issues):
        names = set()
        for issue in issues:
            if issue.get('type') != 'repository_hygiene':
                continue
            for file_info in issue.get('files', []):
                names.add(Path(str(file_info)).name)
        return names

    @staticmethod
    def legacy_backup_flagged_files(issues):
        names = set()
        for issue in issues:
            if issue.get('type') != 'legacy_source_backup':
                continue
            for file_info in issue.get('files', []):
                names.add(Path(str(file_info)).name)
        return names

    def test_writes_to_textfile_handle_are_not_debug_output(self):
        issues = self.run_debug_analysis({
            'test_writer.pas': """
unit test_writer;
{$mode objfpc}{$H+}
interface
implementation
procedure SaveHello;
var
  Source: Text;
begin
  Assign(Source, 'hello.txt');
  Rewrite(Source);
  Write(Source, 'hello');
  Close(Source);
end;
end.
"""
        })
        self.assertNotIn('test_writer.pas', self.debug_flagged_files(issues))

    def test_output_console_wrapper_is_not_flagged_as_debug(self):
        issues = self.run_debug_analysis({
            'fpdev.output.console.pas': """
unit fpdev.output.console;
{$mode objfpc}{$H+}
interface
implementation
procedure ConsoleOut(const S: string);
begin
  WriteLn(S);
end;
end.
"""
        })
        self.assertNotIn('fpdev.output.console.pas', self.debug_flagged_files(issues))

    def test_ioutput_adapter_methods_are_not_flagged_as_debug(self):
        issues = self.run_debug_analysis({
            'fpdev.cmd.lazarus.run.pas': """
unit fpdev.cmd.lazarus.run;
{$mode objfpc}{$H+}
interface
uses fpdev.output.intf;
type
  TBufferedOutput = class(TInterfacedObject, IOutput)
  public
    procedure Write(const S: string);
    procedure WriteLn(const S: string);
  end;
implementation
procedure TBufferedOutput.Write(const S: string);
begin
  if S <> '' then;
end;

procedure TBufferedOutput.WriteLn(const S: string);
begin
  Write(S);
end;
end.
"""
        })
        self.assertNotIn('fpdev.cmd.lazarus.run.pas', self.debug_flagged_files(issues))

    def test_real_debug_writeln_still_detected(self):
        issues = self.run_debug_analysis({
            'test_debug.pas': """
unit test_debug;
{$mode objfpc}{$H+}
interface
implementation
procedure Run;
begin
  WriteLn('debug marker');
end;
end.
"""
        })
        self.assertIn('test_debug.pas', self.debug_flagged_files(issues))

    def test_allow_directive_suppresses_debug_detection(self):
        issues = self.run_debug_analysis({
            'test_allow_directive.pas': """
unit test_allow_directive;
{$mode objfpc}{$H+}
interface
implementation
procedure ShowProgress;
begin
  WriteLn('Downloading...'); // acq:allow-debug-output
end;
end.
"""
        })
        self.assertNotIn('test_allow_directive.pas', self.debug_flagged_files(issues))

    def test_without_allow_directive_debug_detection_remains(self):
        issues = self.run_debug_analysis({
            'test_without_allow_directive.pas': """
unit test_without_allow_directive;
{$mode objfpc}{$H+}
interface
implementation
procedure ShowProgress;
begin
  WriteLn('Downloading...');
end;
end.
"""
        })
        self.assertIn('test_without_allow_directive.pas', self.debug_flagged_files(issues))

    def test_file_level_allow_directive_suppresses_debug_detection(self):
        issues = self.run_debug_analysis({
            'test_file_allow_directive.pas': """
unit test_file_allow_directive;
{$mode objfpc}{$H+}
// acq:allow-debug-output-file
interface
implementation
procedure ShowProgress;
begin
  WriteLn('step 1');
  WriteLn('step 2');
end;
end.
"""
        })
        self.assertNotIn('test_file_allow_directive.pas', self.debug_flagged_files(issues))

    def test_const_block_literals_are_not_flagged_as_hardcoded(self):
        issues = self.run_hardcoded_analysis({
            'test_consts.pas': """
unit test_consts;
{$mode objfpc}{$H+}
interface
implementation
const
  TOOL_PATH = '/usr/bin';
  MIRROR_URL = 'https://example.com/repo';
  DEFAULT_VERSION = '1.2.3';
end.
"""
        })
        self.assertNotIn('test_consts.pas', self.hardcoded_flagged_files(issues))

    def test_inline_literals_still_flagged_as_hardcoded(self):
        issues = self.run_hardcoded_analysis({
            'test_inline_literals.pas': """
unit test_inline_literals;
{$mode objfpc}{$H+}
interface
implementation
function DefaultPath: string;
begin
  Result := '/usr/local/bin';
end;
end.
"""
        })
        self.assertIn('test_inline_literals.pas', self.hardcoded_flagged_files(issues))

    def test_allow_directive_suppresses_hardcoded_detection(self):
        issues = self.run_hardcoded_analysis({
            'test_hardcoded_allow_line.pas': """
unit test_hardcoded_allow_line;
{$mode objfpc}{$H+}
interface
implementation
function DefaultPath: string;
begin
  Result := '/usr/local/bin'; // acq:allow-hardcoded-constants
end;
end.
"""
        })
        self.assertNotIn('test_hardcoded_allow_line.pas', self.hardcoded_flagged_files(issues))

    def test_file_level_allow_directive_suppresses_hardcoded_detection(self):
        issues = self.run_hardcoded_analysis({
            'test_hardcoded_allow_file.pas': """
unit test_hardcoded_allow_file;
{$mode objfpc}{$H+}
// acq:allow-hardcoded-constants-file
interface
implementation
function DefaultPath: string;
begin
  Result := '/usr/local/bin';
end;
end.
"""
        })
        self.assertNotIn('test_hardcoded_allow_file.pas', self.hardcoded_flagged_files(issues))

    def test_line_comment_literals_are_not_flagged_as_hardcoded(self):
        issues = self.run_hardcoded_analysis({
            'test_hardcoded_comment_line.pas': """
unit test_hardcoded_comment_line;
{$mode objfpc}{$H+}
interface
implementation
// Example path: /usr/local/bin and version 1.2.3
function Name: string;
begin
  Result := 'ok';
end;
end.
"""
        })
        self.assertNotIn('test_hardcoded_comment_line.pas', self.hardcoded_flagged_files(issues))

    def test_single_slash_separator_literals_are_not_flagged_as_hardcoded(self):
        issues = self.run_hardcoded_analysis({
            'test_separator_literal.pas': """
unit test_separator_literal;
{$mode objfpc}{$H+}
interface
implementation
function Normalize(const APath: string): string;
begin
  Result := StringReplace(APath, '/', PathDelim, [rfReplaceAll]);
end;
end.
"""
        })
        self.assertNotIn('test_separator_literal.pas', self.hardcoded_flagged_files(issues))

    def test_block_comment_literals_are_not_flagged_as_hardcoded(self):
        issues = self.run_hardcoded_analysis({
            'test_hardcoded_comment_block.pas': """
unit test_hardcoded_comment_block;
{$mode objfpc}{$H+}
interface
implementation
(*
  Example URL: https://example.com/repo
  Example version: 1.2.3
*)
function Name: string;
begin
  Result := 'ok';
end;
end.
"""
        })
        self.assertNotIn('test_hardcoded_comment_block.pas', self.hardcoded_flagged_files(issues))

    def test_whitespace_only_lines_are_not_flagged_as_trailing_space(self):
        issues = self.run_style_analysis({
            'test_blank_lines.pas': """
unit test_blank_lines;
{$mode objfpc}{$H+}
interface

implementation

end.
"""
        })
        self.assertNotIn('test_blank_lines.pas', self.style_flagged_files(issues))

    def test_non_empty_line_trailing_space_is_still_flagged(self):
        issues = self.run_style_analysis({
            'test_trailing_space.pas': (
                "unit test_trailing_space;\n"
                "{$mode objfpc}{$H+}\n"
                "interface\n"
                "implementation\n"
                "procedure Run;\n"
                "begin\n"
                "end;\n"
                "end. \n"
            )
        })
        self.assertIn('test_trailing_space.pas', self.style_flagged_files(issues))

    def test_style_allow_directive_suppresses_line_checks(self):
        issues = self.run_style_analysis({
            'test_style_allow_line.pas': """
unit test_style_allow_line;
{$mode objfpc}{$H+}
interface
implementation
procedure Run; // acq:allow-style
begin
end;
end.
"""
        })
        self.assertNotIn('test_style_allow_line.pas', self.style_flagged_files(issues))

    def test_style_file_allow_directive_suppresses_file_checks(self):
        issues = self.run_style_analysis({
            'test_style_allow_file.pas': """
unit test_style_allow_file;
{$mode objfpc}{$H+}
// acq:allow-style-file
interface
implementation
procedure Run;
begin
\tWriteLn('ok');
end;
end.
"""
        })
        self.assertNotIn('test_style_allow_file.pas', self.style_flagged_files(issues))

    def test_tracked_python_cache_is_reported(self):
        issues = self.run_repository_hygiene_analysis(
            {'scripts/__pycache__/analyze_code_quality.cpython-313.pyc': b'compiled-bytes'},
            tracked_files=['scripts/__pycache__/analyze_code_quality.cpython-313.pyc']
        )
        self.assertIn(
            'analyze_code_quality.cpython-313.pyc',
            self.repository_hygiene_flagged_files(issues)
        )

    def test_ignored_untracked_python_cache_is_not_reported(self):
        issues = self.run_repository_hygiene_analysis(
            {'tests/__pycache__/test_analyze_code_quality.cpython-313.pyc': b'compiled-bytes'},
            gitignore='__pycache__/\n*.pyc\n'
        )
        self.assertNotIn(
            'test_analyze_code_quality.cpython-313.pyc',
            self.repository_hygiene_flagged_files(issues)
        )


    def test_legacy_source_backup_in_src_is_reported(self):
        issues = self.run_legacy_backup_analysis({
            'fpdev.config.pas.old': 'legacy backup'
        })
        self.assertIn(
            'fpdev.config.pas.old',
            self.legacy_backup_flagged_files(issues)
        )


if __name__ == '__main__':
    unittest.main()
