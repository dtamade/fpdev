unit fpdev.cmd.perf;

{
================================================================================
  fpdev.cmd.perf - Performance Monitoring Commands
================================================================================

  Provides CLI commands for performance monitoring:
  - fpdev perf report: Show performance report for last operation
  - fpdev perf clear: Clear performance data
  - fpdev perf summary: Show summary of operations

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.output.intf, fpdev.output.console,
  fpdev.perf.monitor;

type
  { TPerfReportCommand - Show performance report }
  TPerfReportCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

  { TPerfSummaryCommand - Show performance summary }
  TPerfSummaryCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

  { TPerfClearCommand - Clear performance data }
  TPerfClearCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

  { TPerfSaveCommand - Save performance report to file }
  TPerfSaveCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

  { TPerfCommand - Root perf command with help }
  TPerfCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const {%H-}AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreatePerfCommand: ICommand;
function CreatePerfReportCommand: ICommand;
function CreatePerfSummaryCommand: ICommand;
function CreatePerfClearCommand: ICommand;
function CreatePerfSaveCommand: ICommand;

implementation

function CreatePerfCommand: ICommand;
begin
  Result := TPerfCommand.Create;
end;

function CreatePerfReportCommand: ICommand;
begin
  Result := TPerfReportCommand.Create;
end;

function CreatePerfSummaryCommand: ICommand;
begin
  Result := TPerfSummaryCommand.Create;
end;

function CreatePerfClearCommand: ICommand;
begin
  Result := TPerfClearCommand.Create;
end;

function CreatePerfSaveCommand: ICommand;
begin
  Result := TPerfSaveCommand.Create;
end;

{ TPerfCommand }

function TPerfCommand.Name: string;
begin
  Result := 'perf';
end;

function TPerfCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPerfCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused hint
end;

function TPerfCommand.Execute(const {%H-}AParams: array of string; const Ctx: IContext): Integer;
var
  LO: IOutput;
begin
  Result := 0;
  LO := Ctx.Out;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  LO.WriteLn('fpdev perf - Performance Monitoring');
  LO.WriteLn('');
  LO.WriteLn('Usage:');
  LO.WriteLn('  fpdev perf report   - Show JSON performance report');
  LO.WriteLn('  fpdev perf summary  - Show human-readable summary');
  LO.WriteLn('  fpdev perf clear    - Clear all performance data');
  LO.WriteLn('  fpdev perf save <file> - Save report to JSON file');
  LO.WriteLn('');
  LO.WriteLn('Performance data is collected during build operations.');
end;

{ TPerfReportCommand }

function TPerfReportCommand.Name: string;
begin
  Result := 'report';
end;

function TPerfReportCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPerfReportCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused hint
end;

function TPerfReportCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LO: IOutput;
  Report: string;
begin
  Result := 0;
  if Length(AParams) > 0 then; // Suppress unused hint

  LO := Ctx.Out;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  Report := PerfMon.GetReport;
  if Report = '[]' then
  begin
    LO.WriteLn('No performance data available.');
    LO.WriteLn('Run a build operation first (e.g., fpdev fpc install).');
  end
  else
    LO.WriteLn(Report);
end;

{ TPerfSummaryCommand }

function TPerfSummaryCommand.Name: string;
begin
  Result := 'summary';
end;

function TPerfSummaryCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPerfSummaryCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused hint
end;

function TPerfSummaryCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LO: IOutput;
  Summary: string;
begin
  Result := 0;
  if Length(AParams) > 0 then; // Suppress unused hint

  LO := Ctx.Out;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  Summary := PerfMon.GetSummary;
  if Pos('Total', Summary) = 0 then
  begin
    LO.WriteLn('No performance data available.');
    LO.WriteLn('Run a build operation first (e.g., fpdev fpc install).');
  end
  else
    LO.WriteLn(Summary);
end;

{ TPerfClearCommand }

function TPerfClearCommand.Name: string;
begin
  Result := 'clear';
end;

function TPerfClearCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPerfClearCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused hint
end;

function TPerfClearCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LO: IOutput;
begin
  Result := 0;
  if Length(AParams) > 0 then; // Suppress unused hint

  LO := Ctx.Out;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;

  PerfMon.Clear;
  LO.WriteLn('Performance data cleared.');
end;

{ TPerfSaveCommand }

function TPerfSaveCommand.Name: string;
begin
  Result := 'save';
end;

function TPerfSaveCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPerfSaveCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused hint
end;

function TPerfSaveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LO, LE: IOutput;
  FileName: string;
begin
  Result := 0;

  LO := Ctx.Out;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Ctx.Err;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if Length(AParams) < 1 then
  begin
    LE.WriteLn('Error: Missing filename');
    LE.WriteLn('Usage: fpdev perf save <filename>');
    Result := 1;
    Exit;
  end;

  FileName := AParams[0];
  try
    PerfMon.SaveReport(FileName);
    LO.WriteLn('Performance report saved to: ' + FileName);
  except
    on E: Exception do
    begin
      LE.WriteLn('Error saving report: ' + E.Message);
      Result := 1;
    end;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['perf'], @CreatePerfCommand, []);
  GlobalCommandRegistry.RegisterPath(['perf', 'report'], @CreatePerfReportCommand, []);
  GlobalCommandRegistry.RegisterPath(['perf', 'summary'], @CreatePerfSummaryCommand, []);
  GlobalCommandRegistry.RegisterPath(['perf', 'clear'], @CreatePerfClearCommand, []);
  GlobalCommandRegistry.RegisterPath(['perf', 'save'], @CreatePerfSaveCommand, []);

end.
