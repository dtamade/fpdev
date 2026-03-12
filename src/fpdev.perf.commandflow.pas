unit fpdev.perf.commandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

function ExecutePerfRootCore(const AParams: array of string; const Ctx: IContext): Integer;
function ExecutePerfReportCore(const AParams: array of string; const Ctx: IContext): Integer;
function ExecutePerfSummaryCore(const AParams: array of string; const Ctx: IContext): Integer;
function ExecutePerfClearCore(const AParams: array of string; const Ctx: IContext): Integer;
function ExecutePerfSaveCore(const AParams: array of string; const Ctx: IContext): Integer;

implementation

uses
  fpdev.exitcodes,
  fpdev.help.details.system,
  fpdev.output.console,
  fpdev.output.intf,
  fpdev.perf.monitor;

function ResolvePerfOutputCore(const Ctx: IContext; AUseErr: Boolean): IOutput;
begin
  Result := nil;
  if Ctx <> nil then
  begin
    if AUseErr then
      Result := Ctx.Err
    else
      Result := Ctx.Out;
  end;

  if Result = nil then
    Result := TConsoleOutput.Create(AUseErr) as IOutput;
end;

procedure WritePerfNoDataCore(const Outp: IOutput);
begin
  Outp.WriteLn('No performance data available.');
  Outp.WriteLn('Run a build operation first (e.g., fpdev fpc install).');
end;

function ExecutePerfRootCore(const AParams: array of string; const Ctx: IContext): Integer;
var
  Outp: IOutput;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then;
  Outp := ResolvePerfOutputCore(Ctx, False);
  WriteSystemPerfHelpCore(Outp);
end;

function ExecutePerfReportCore(const AParams: array of string; const Ctx: IContext): Integer;
var
  Outp: IOutput;
  Report: string;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then;

  Outp := ResolvePerfOutputCore(Ctx, False);
  Report := PerfMon.GetReport;
  if Report = '[]' then
    WritePerfNoDataCore(Outp)
  else
    Outp.WriteLn(Report);
end;

function ExecutePerfSummaryCore(const AParams: array of string; const Ctx: IContext): Integer;
var
  Outp: IOutput;
  Summary: string;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then;

  Outp := ResolvePerfOutputCore(Ctx, False);
  Summary := PerfMon.GetSummary;
  if Pos('Total', Summary) = 0 then
    WritePerfNoDataCore(Outp)
  else
    Outp.WriteLn(Summary);
end;

function ExecutePerfClearCore(const AParams: array of string; const Ctx: IContext): Integer;
var
  Outp: IOutput;
begin
  Result := EXIT_OK;
  if Length(AParams) > 0 then;

  Outp := ResolvePerfOutputCore(Ctx, False);
  PerfMon.Clear;
  Outp.WriteLn('Performance data cleared.');
end;

function ExecutePerfSaveCore(const AParams: array of string; const Ctx: IContext): Integer;
var
  Outp: IOutput;
  Errp: IOutput;
  FileName: string;
begin
  Result := EXIT_OK;
  Outp := ResolvePerfOutputCore(Ctx, False);
  Errp := ResolvePerfOutputCore(Ctx, True);

  if Length(AParams) < 1 then
  begin
    Errp.WriteLn('Error: Missing filename');
    Errp.WriteLn('Usage: fpdev system perf save <filename>');
    Exit(EXIT_ERROR);
  end;

  FileName := AParams[0];
  try
    PerfMon.SaveReport(FileName);
    Outp.WriteLn('Performance report saved to: ' + FileName);
  except
    on E: Exception do
    begin
      Errp.WriteLn('Error saving report: ' + E.Message);
      Exit(EXIT_ERROR);
    end;
  end;
end;

end.
