unit fpdev.cmd.lazarus.doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config.interfaces,
  fpdev.utils.fs, fpdev.utils.process,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TLazarusDoctorCommand }
  TLazarusDoctorCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TLazarusDoctorCommand.Name: string; begin Result := 'doctor'; end;

function TLazarusDoctorCommand.Aliases: TStringArray; begin Result := nil; end;

function TLazarusDoctorCommand.FindSub(const AName: string): ICommand;
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

function TLazarusDoctorCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
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
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_OPT_HELP));
    Exit(EXIT_OK);
  end;

  Ctx.Out.WriteLn(_(MSG_CHECKING_LAZARUS_ENV));
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

  // 2) git
  LOk := RunToolVersion('git', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_GIT_OK, [Trim(LOut)]))
  else
    Ctx.Out.WriteLn(_(MSG_DOCTOR_GIT_FAIL));

  // 3) make
  LOk := RunToolVersion('make', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_MAKE_OK, [Copy(Trim(LOut), 1, 80) + '...']))
  else
    Ctx.Out.WriteLn(_(MSG_DOCTOR_MAKE_FAIL));

  // 4) FPC compiler (required for building Lazarus)
  LOk := RunToolVersion('fpc', '-i', LOut);
  if LOk then
    Ctx.Out.WriteLn(_(MSG_DOCTOR_FPC_OK))
  else
    Ctx.Out.WriteLn(_(MSG_DOCTOR_FPC_FAIL));

  // 5) lazbuild (if Lazarus is already installed)
  LOk := RunToolVersion('lazbuild', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_LAZBUILD_OK, [Trim(LOut)]))
  else
    Ctx.Out.WriteLn(_(MSG_DOCTOR_LAZBUILD_WARN));

  // 6) Check for X11/GTK on Linux
  {$IFDEF LINUX}
  LOk := RunToolVersion('pkg-config', '--exists gtk+-2.0', LOut);
  if LOk then
    Ctx.Out.WriteLn(_(MSG_DOCTOR_GTK2_OK))
  else
  begin
    LOk := RunToolVersion('pkg-config', '--exists gtk+-3.0', LOut);
    if LOk then
      Ctx.Out.WriteLn(_(MSG_DOCTOR_GTK3_OK))
    else
      Ctx.Out.WriteLn(_(MSG_DOCTOR_GTK_FAIL));
  end;
  {$ENDIF}

  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_DOCTOR_COMPLETE));
end;

function LazarusDoctorFactory: ICommand;
begin
  Result := TLazarusDoctorCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','doctor'], @LazarusDoctorFactory, []);

end.
