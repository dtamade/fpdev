unit fpdev.cmd.cross.doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config.interfaces,
  fpdev.utils.fs, fpdev.utils.process,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TCrossDoctorCommand }
  TCrossDoctorCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TCrossDoctorCommand.Name: string; begin Result := 'doctor'; end;

function TCrossDoctorCommand.Aliases: TStringArray; begin Result := nil; end;

function TCrossDoctorCommand.FindSub(const AName: string): ICommand;
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

function TCrossDoctorCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LOut, LErr: string;
  LOk: Boolean;
  LRoot: string;
  LSettings: TFPDevSettings;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_OPT_HELP));
    Exit(EXIT_OK);
  end;

  Ctx.Out.WriteLn(_(MSG_CHECKING_CROSS_ENV));
  Ctx.Out.WriteLn('');

  // 1) Write permission check (install root)
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  LRoot := LSettings.InstallRoot;
  if LRoot = '' then
    LRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
  LOk := CheckWriteableDir(LRoot, LErr);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_WRITE_OK, [LRoot]))
  else
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_WRITE_FAIL, [LRoot, LErr]));

  // 2) FPC compiler (required for cross-compilation)
  LOk := RunToolVersion('fpc', '-i', LOut);
  if LOk then
    Ctx.Out.WriteLn(_(MSG_DOCTOR_FPC_OK))
  else
    Ctx.Out.WriteLn('[X] FPC compiler not found (cross-compilation requires FPC)');

  // 3) Check for cross-compilation binutils on Linux
  {$IFDEF LINUX}
  // Check for common cross-compilation targets
  LOk := RunToolVersion('x86_64-w64-mingw32-ld', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn('[OK] Windows x64 cross-linker: available')
  else
    Ctx.Out.WriteLn('[!] Windows x64 cross-linker not found (install mingw-w64 for Windows cross-compilation)');

  LOk := RunToolVersion('i686-w64-mingw32-ld', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn('[OK] Windows x86 cross-linker: available')
  else
    Ctx.Out.WriteLn('[!] Windows x86 cross-linker not found (install mingw-w64 for Windows cross-compilation)');

  LOk := RunToolVersion('aarch64-linux-gnu-ld', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn('[OK] Linux ARM64 cross-linker: available')
  else
    Ctx.Out.WriteLn('[!] Linux ARM64 cross-linker not found (install gcc-aarch64-linux-gnu)');
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  // On Windows, check for cross-compilation to Linux
  Ctx.Out.WriteLn('[!] Cross-compilation from Windows requires manual setup of target libraries');
  {$ENDIF}

  // 4) Check cross directory
  LRoot := LSettings.InstallRoot;
  if LRoot = '' then
    LRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
  LRoot := IncludeTrailingPathDelimiter(LRoot) + 'cross';
  if DirectoryExists(LRoot) then
    Ctx.Out.WriteLn('[OK] Cross-compilation directory exists: ' + LRoot)
  else
    Ctx.Out.WriteLn('[!] Cross-compilation directory not found: ' + LRoot);

  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_DOCTOR_COMPLETE));
end;

function CrossDoctorFactory: ICommand;
begin
  Result := TCrossDoctorCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','doctor'], @CrossDoctorFactory, []);

end.
