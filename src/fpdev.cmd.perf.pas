unit fpdev.cmd.perf;

{
================================================================================
  fpdev.cmd.perf - Performance Monitoring Commands
================================================================================

  Provides CLI commands for performance monitoring:
  - fpdev system perf report: Show performance report for last operation
  - fpdev system perf clear: Clear performance data
  - fpdev system perf summary: Show summary of operations

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.output.intf, fpdev.output.console;

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
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreatePerfCommand: ICommand;
function CreatePerfReportCommand: ICommand;
function CreatePerfSummaryCommand: ICommand;
function CreatePerfClearCommand: ICommand;
function CreatePerfSaveCommand: ICommand;

implementation

uses
  fpdev.help.details.system,
  fpdev.perf.commandflow;

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

function TPerfCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Outp: IOutput;
begin
  Result := 0;
  if Length(AParams) > 0 then;
  Outp := Ctx.Out;
  if Outp = nil then
    Outp := TConsoleOutput.Create(False) as IOutput;
  WriteSystemPerfHelpCore(Outp);
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
begin
  Result := ExecutePerfReportCore(AParams, Ctx);
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
begin
  Result := ExecutePerfSummaryCore(AParams, Ctx);
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
begin
  Result := ExecutePerfClearCore(AParams, Ctx);
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
begin
  Result := ExecutePerfSaveCore(AParams, Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'perf'], @CreatePerfCommand, []);
  GlobalCommandRegistry.RegisterPath(['system', 'perf', 'report'], @CreatePerfReportCommand, []);
  GlobalCommandRegistry.RegisterPath(['system', 'perf', 'summary'], @CreatePerfSummaryCommand, []);
  GlobalCommandRegistry.RegisterPath(['system', 'perf', 'clear'], @CreatePerfClearCommand, []);
  GlobalCommandRegistry.RegisterPath(['system', 'perf', 'save'], @CreatePerfSaveCommand, []);

end.
