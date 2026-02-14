import importlib.util
import os
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

    @staticmethod
    def debug_flagged_files(issues):
        names = set()
        for issue in issues:
            if issue.get('type') != 'debug_code':
                continue
            for file_info in issue.get('files', []):
                names.add(Path(str(file_info['file'])).name)
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


if __name__ == '__main__':
    unittest.main()
