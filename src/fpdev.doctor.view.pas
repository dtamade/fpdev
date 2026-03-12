unit fpdev.doctor.view;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

function BuildDoctorHelpTextCore: string;
procedure WriteDoctorSectionCore(const AOut: IOutput; const ATitle: string; AEnabled: Boolean = True);
procedure WriteDoctorSummaryCore(const AOut: IOutput; APassed, AWarnings, AErrors: Integer);
function BuildDoctorJSONSummaryCore(const AChecksText: string; APassed, AWarnings, AErrors: Integer): string;

implementation

function BuildDoctorHelpTextCore: string;
begin
  Result :=
    'Usage: fpdev system doctor [options]' + LineEnding +
    '' + LineEnding +
    'Diagnose toolchain environment and check for common issues.' + LineEnding +
    '' + LineEnding +
    'Options:' + LineEnding +
    '  --quick       Run quick checks only (skip slow operations)' + LineEnding +
    '  --json        Output results in JSON format' + LineEnding +
    '  -h, --help    Show this help message' + LineEnding +
    '' + LineEnding +
    'Checks performed:' + LineEnding +
    '  - FPC installation and version' + LineEnding +
    '  - Lazarus installation (if any)' + LineEnding +
    '  - Configuration file validity' + LineEnding +
    '  - Environment variables (PATH, FPCDIR, etc.)' + LineEnding +
    '  - Build tools (make, git)' + LineEnding +
    '  - Debugger availability (gdb/lldb)' + LineEnding +
    '  - Disk space';
end;

procedure WriteDoctorSectionCore(const AOut: IOutput; const ATitle: string; AEnabled: Boolean);
begin
  if (not AEnabled) or (AOut = nil) then
    Exit;

  AOut.WriteLn('');
  AOut.WriteLn(ATitle);
  AOut.WriteLn(StringOfChar('-', Length(ATitle)));
end;

procedure WriteDoctorSummaryCore(const AOut: IOutput; APassed, AWarnings, AErrors: Integer);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn('');
  AOut.WriteLn('Summary');
  AOut.WriteLn('-------');
  AOut.WriteLn('  Passed:   ' + IntToStr(APassed));
  AOut.WriteLn('  Warnings: ' + IntToStr(AWarnings));
  AOut.WriteLn('  Errors:   ' + IntToStr(AErrors));
  AOut.WriteLn('');

  if AErrors > 0 then
    AOut.WriteError('Some checks failed. Please fix the issues above.')
  else if AWarnings > 0 then
    AOut.WriteWarning('Some warnings found. Consider addressing them.')
  else
    AOut.WriteSuccess('All checks passed! Your environment is ready.');

  AOut.WriteLn('');
end;

function BuildDoctorJSONSummaryCore(const AChecksText: string; APassed, AWarnings, AErrors: Integer): string;
begin
  Result := '{"checks":[' + AChecksText + '],"summary":{"passed":' +
    IntToStr(APassed) + ',"warnings":' + IntToStr(AWarnings) +
    ',"errors":' + IntToStr(AErrors) + '}}';
end;

end.
