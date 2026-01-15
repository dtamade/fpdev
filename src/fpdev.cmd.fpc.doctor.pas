unit fpdev.cmd.fpc.doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config.interfaces,
  fpdev.utils.fs, fpdev.utils.process, fpdev.paths,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TFPCDoctorCommand }
  TFPCDoctorCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TFPCDoctorCommand.Name: string; begin Result := 'doctor'; end;

function TFPCDoctorCommand.Aliases: TStringArray; begin Result := nil; end;
function TFPCDoctorCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;


function RunToolVersion(const AExe: string; const AArg: string; out AOut: string): Boolean;
var
  LResult: TProcessResult;
begin
  AOut := '';
  if AArg <> '' then
    LResult := TProcessExecutor.Execute(AExe, [AArg], '')
  else
    LResult := TProcessExecutor.Execute(AExe, [], '');

  if LResult.Success then
  begin
    AOut := LResult.StdOut;
    Result := True;
  end
  else
  begin
    AOut := LResult.ErrorMessage;
    Result := False;
  end;
end;

function CheckWriteableDir(const ADir: string; out AErr: string): Boolean;
var
  LPath, LTest: string;
  LSL: TStringList;
begin
  Result := False;
  AErr := '';
  LPath := IncludeTrailingPathDelimiter(ADir);
  try
    if not DirectoryExists(LPath) then EnsureDir(LPath);
    if not DirectoryExists(LPath) then
    begin
      AErr := 'Cannot create directory';
      Exit(False);
    end;
    LTest := LPath + '.fpdev_write_test.tmp';
    LSL := TStringList.Create;
    try
      LSL.Text := 'ok';
      LSL.SaveToFile(LTest);
      Result := FileExists(LTest);
      DeleteFile(LTest);
    finally
      LSL.Free;
    end;
  except
    on E: Exception do
    begin
      AErr := E.Message;
      Result := False;
    end;
  end;
end;

function TFPCDoctorCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LOut, LErr: string;
  LOk: Boolean;
  LRoot: string;
  LSettings: TFPDevSettings;
  LToolchains: TStringArray;
  LInfo: TToolchainInfo;
  LActivateScript: string;
  LDefaultToolchain: string;
  LIssueCount: Integer;
  I: Integer;
  LFPCPath: string;
begin
  Result := 0;
  LIssueCount := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_OPT_HELP));
    Exit(0);
  end;

  Ctx.Out.WriteLn('FPC Doctor - Checking your FPC environment...');
  Ctx.Out.WriteLn('');

  // 1) Write permission check (install root)
  Ctx.Out.WriteLn('[1/7] Checking write permissions...');
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  LRoot := GetToolchainsDir;
  LOk := CheckWriteableDir(LRoot, LErr);
  if LOk then
    Ctx.Out.WriteLn('  OK: ' + LRoot + ' is writable')
  else
  begin
    Ctx.Out.WriteLn('  ERROR: ' + LRoot + ' - ' + LErr);
    Inc(LIssueCount);
  end;

  // 2) git
  Ctx.Out.WriteLn('[2/7] Checking git...');
  LOk := RunToolVersion('git', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn('  OK: ' + Trim(LOut))
  else
  begin
    Ctx.Out.WriteLn('  WARNING: git not found');
    Ctx.Out.WriteLn('    Hint: Install git for source builds');
  end;

  // 3) make
  Ctx.Out.WriteLn('[3/7] Checking make...');
  LOk := RunToolVersion('make', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn('  OK: ' + Copy(Trim(LOut), 1, 50))
  else
  begin
    Ctx.Out.WriteLn('  WARNING: make not found');
    Ctx.Out.WriteLn('    Hint: Install make for source builds');
  end;

  // 4) bootstrap fpc (system)
  Ctx.Out.WriteLn('[4/7] Checking system FPC...');
  LOk := RunToolVersion('fpc', '-iV', LOut);
  if LOk then
    Ctx.Out.WriteLn('  OK: System FPC version ' + Trim(LOut))
  else
    Ctx.Out.WriteLn('  INFO: No system FPC found (will use fpdev-managed versions)');

  // 5) Installed toolchains
  Ctx.Out.WriteLn('[5/7] Checking installed toolchains...');
  LToolchains := Ctx.Config.GetToolchainManager.ListToolchains;
  if Length(LToolchains) = 0 then
    Ctx.Out.WriteLn('  INFO: No FPC toolchains installed via fpdev')
  else
  begin
    Ctx.Out.WriteLn('  Found ' + IntToStr(Length(LToolchains)) + ' toolchain(s):');
    for I := 0 to High(LToolchains) do
    begin
      if Ctx.Config.GetToolchainManager.GetToolchain(LToolchains[I], LInfo) then
      begin
        // Check if toolchain directory exists
        if DirectoryExists(LInfo.InstallPath) then
        begin
          // Check if fpc binary exists
          {$IFDEF MSWINDOWS}
          LFPCPath := LInfo.InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
          {$ELSE}
          LFPCPath := LInfo.InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
          {$ENDIF}
          if FileExists(LFPCPath) then
            Ctx.Out.WriteLn('    - ' + LToolchains[I] + ' [OK]')
          else
          begin
            Ctx.Out.WriteLn('    - ' + LToolchains[I] + ' [BROKEN: fpc binary missing]');
            Inc(LIssueCount);
          end;
        end
        else
        begin
          Ctx.Out.WriteLn('    - ' + LToolchains[I] + ' [BROKEN: directory missing]');
          Inc(LIssueCount);
        end;
      end;
    end;
  end;

  // 6) Default toolchain
  Ctx.Out.WriteLn('[6/7] Checking default toolchain...');
  LDefaultToolchain := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
  if LDefaultToolchain <> '' then
  begin
    Ctx.Out.WriteLn('  Default: ' + LDefaultToolchain);
    // Verify it exists
    if not Ctx.Config.GetToolchainManager.GetToolchain(LDefaultToolchain, LInfo) then
    begin
      Ctx.Out.WriteLn('  ERROR: Default toolchain not found in config');
      Ctx.Out.WriteLn('    Hint: Run "fpdev fpc use <version>" to set a valid default');
      Inc(LIssueCount);
    end;
  end
  else
    Ctx.Out.WriteLn('  INFO: No default toolchain set');

  // 7) Activation script
  Ctx.Out.WriteLn('[7/7] Checking activation script...');
  LActivateScript := GetDataRoot + PathDelim + 'env' + PathDelim + 'activate.sh';
  if FileExists(LActivateScript) then
    Ctx.Out.WriteLn('  OK: ' + LActivateScript)
  else
    Ctx.Out.WriteLn('  INFO: No activation script (run "fpdev fpc use <version>" to create)');

  // Summary
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('===========================================');
  if LIssueCount = 0 then
  begin
    Ctx.Out.WriteLn('All checks passed! Your FPC environment is healthy.');
    Result := 0;
  end
  else
  begin
    Ctx.Out.WriteLn('Found ' + IntToStr(LIssueCount) + ' issue(s) that need attention.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Suggested fixes:');
    Ctx.Out.WriteLn('  - Reinstall broken toolchains: fpdev fpc install <version>');
    Ctx.Out.WriteLn('  - Set default toolchain: fpdev fpc use <version>');
    Result := 1;
  end;
  Ctx.Out.WriteLn('===========================================');
end;


function FPCDoctorFactory: ICommand;
begin
  Result := TFPCDoctorCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','doctor'], @FPCDoctorFactory, []);

end.

