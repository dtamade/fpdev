unit fpdev.cmd.doctor;

{
  fpdev system doctor command

  Diagnose toolchain environment, check common issues and provide fix suggestions
  Similar to rustup doctor and brew doctor

  Usage:
    fpdev system doctor              # Run full diagnostics
    fpdev system doctor --quick      # Quick check (critical items only)
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry, fpdev.exitcodes;

type
  { TDoctorCommand - Diagnose toolchain environment }
  TDoctorCommand = class(TInterfacedObject, ICommand)
  private
    FCtx: IContext;
    FErrorCount: Integer;
    FWarningCount: Integer;
    FPassCount: Integer;
    FJsonMode: Boolean;
    FChecks: TStringList;  // JSON check results

    procedure CheckPass(const AMessage: string);
    procedure CheckWarn(const AMessage: string; const AHint: string = '');
    procedure CheckFail(const AMessage: string; const AHint: string = '');
    procedure CheckInfo(const AMessage: string);
    procedure AddCheckResult(const AStatus, AMessage, AHint: string);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function DoctorCommandFactory: ICommand;

implementation

uses
  Process, StrUtils,
  fpdev.doctor.checks,
  fpdev.doctor.view,
  fpdev.output.intf;

const
  {$IFDEF MSWINDOWS}
  SHELL_EXECUTABLE = 'cmd';
  SHELL_COMMAND_ARG = '/c';
  {$ELSE}
  SHELL_EXECUTABLE = '/bin/sh';
  SHELL_COMMAND_ARG = '-c';
  {$ENDIF}

function DoctorCommandFactory: ICommand;
begin
  Result := TDoctorCommand.Create;
end;

{ TDoctorCommand }

function TDoctorCommand.Name: string;
begin
  Result := 'doctor';
end;

function TDoctorCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TDoctorCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TDoctorCommand.AddCheckResult(const AStatus, AMessage, AHint: string);
begin
  if FJsonMode then
  begin
    if FChecks.Count > 0 then
      FChecks.Add(',');
    FChecks.Add('{"status":"' + AStatus + '","message":"' +
      StringReplace(AMessage, '"', '\"', [rfReplaceAll]) + '"' +
      IfThen(AHint <> '', ',"hint":"' + StringReplace(AHint, '"', '\"', [rfReplaceAll]) + '"', '') + '}');
  end;
end;

procedure TDoctorCommand.CheckPass(const AMessage: string);
begin
  Inc(FPassCount);
  AddCheckResult('pass', AMessage, '');
  if not FJsonMode then
    FCtx.Out.WriteSuccess(AMessage);
end;

procedure TDoctorCommand.CheckWarn(const AMessage: string; const AHint: string);
begin
  Inc(FWarningCount);
  AddCheckResult('warning', AMessage, AHint);
  if not FJsonMode then
  begin
    FCtx.Out.WriteWarning(AMessage);
    if AHint <> '' then
      FCtx.Out.WriteLn('    Hint: ' + AHint);
  end;
end;

procedure TDoctorCommand.CheckFail(const AMessage: string; const AHint: string);
begin
  Inc(FErrorCount);
  AddCheckResult('error', AMessage, AHint);
  if not FJsonMode then
  begin
    FCtx.Out.WriteError(AMessage);
    if AHint <> '' then
      FCtx.Out.WriteLn('    Fix: ' + AHint);
  end;
end;

procedure TDoctorCommand.CheckInfo(const AMessage: string);
begin
  AddCheckResult('info', AMessage, '');
  if not FJsonMode then
    FCtx.Out.WriteInfo(AMessage);
end;

function ExecuteCommand(const ACmd: string; out AOutput: string): Integer;
var
  LProcess: TProcess;
  LStrings: TStringList;
begin
  Result := -1;
  AOutput := '';
  LProcess := TProcess.Create(nil);
  LStrings := TStringList.Create;
  try
    LProcess.Executable := SHELL_EXECUTABLE;
    LProcess.Parameters.Add(SHELL_COMMAND_ARG);
    LProcess.Parameters.Add(ACmd);
    LProcess.Options := [poUsePipes, poWaitOnExit];
    try
      LProcess.Execute;
      LStrings.LoadFromStream(LProcess.Output);
      AOutput := Trim(LStrings.Text);
      Result := LProcess.ExitCode;
    except
      Result := -1;
    end;
  finally
    LStrings.Free;
    LProcess.Free;
  end;
end;

function TDoctorCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  I: Integer;
  LQuick: Boolean;
  LHasHelpFlag: Boolean;
begin
  Result := 0;
  FCtx := Ctx;
  FErrorCount := 0;
  FWarningCount := 0;
  FPassCount := 0;
  FJsonMode := False;
  FChecks := TStringList.Create;

  try
    LHasHelpFlag := False;

    // Check help flag
    for I := 0 to High(AParams) do
    begin
      if (AParams[I] = '-h') or (AParams[I] = '--help') then
        LHasHelpFlag := True;
    end;

    if LHasHelpFlag then
    begin
      if Length(AParams) <> 1 then
      begin
        Ctx.Err.WriteLn(BuildDoctorHelpTextCore);
        Exit(EXIT_USAGE_ERROR);
      end;
      Ctx.Out.WriteLn(BuildDoctorHelpTextCore);
      Exit(EXIT_OK);
    end;

    // Check flags
    LQuick := False;
    for I := 0 to High(AParams) do
    begin
      if AParams[I] = '--quick' then
        LQuick := True
      else if AParams[I] = '--json' then
        FJsonMode := True;
    end;

    if not FJsonMode then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('fpdev system doctor - Diagnosing your toolchain environment...');
    end;

    // Run checks
    ExecuteDoctorFPCChecksCore(FCtx, FJsonMode, @ExecuteCommand, @CheckPass, @CheckWarn, @CheckInfo);
    ExecuteDoctorLazarusChecksCore(FCtx, FJsonMode, @ExecuteCommand, @CheckPass, @CheckInfo);
    ExecuteDoctorConfigChecksCore(FCtx, FJsonMode, @CheckPass, @CheckInfo);
    ExecuteDoctorEnvironmentChecksCore(FCtx, FJsonMode, @CheckPass, @CheckWarn, @CheckFail, @CheckInfo);
    ExecuteDoctorBuildToolChecksCore(FCtx, FJsonMode, @ExecuteCommand, @CheckPass, @CheckWarn);
    ExecuteDoctorGitChecksCore(FCtx, @ExecuteCommand, @CheckPass, @CheckWarn);

    if not LQuick then
    begin
      ExecuteDoctorDebuggerChecksCore(FCtx, FJsonMode, @ExecuteCommand, @CheckPass, @CheckWarn, @CheckInfo);
      ExecuteDoctorDiskSpaceChecksCore(FCtx, FJsonMode, @CheckPass, @CheckInfo);
    end;

    // Output results
    if FJsonMode then
      Ctx.Out.WriteLn(BuildDoctorJSONSummaryCore(FChecks.Text, FPassCount, FWarningCount, FErrorCount))
    else
      WriteDoctorSummaryCore(Ctx.Out, FPassCount, FWarningCount, FErrorCount);

    if FErrorCount > 0 then
      Result := EXIT_ERROR;
  finally
    FChecks.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'doctor'], @DoctorCommandFactory, []);

end.
