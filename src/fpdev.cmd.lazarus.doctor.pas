unit fpdev.cmd.lazarus.doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config.interfaces,
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

uses
  fpdev.command.registry, fpdev.command.utils,
  fpdev.doctor.runtime;

function TLazarusDoctorCommand.Name: string; begin Result := 'doctor'; end;

function TLazarusDoctorCommand.Aliases: TStringArray; begin Result := nil; end;

function TLazarusDoctorCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TLazarusDoctorCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LOut, LErr: string;
  LOk: Boolean;
  LRoot: string;
  LSettings: TFPDevSettings;
  LIssueCount: Integer;
begin
  Result := EXIT_OK;
  LIssueCount := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_LAZARUS_DOCTOR_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_DOCTOR_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  Ctx.Out.WriteLn(_(MSG_CHECKING_LAZARUS_ENV));
  Ctx.Out.WriteLn('');

  // 1) Write permission check (install root)
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  LRoot := LSettings.InstallRoot;
  if LRoot = '' then
    LRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
  LOk := CheckDoctorWriteableDirCore(LRoot, LErr);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_WRITE_OK, [LRoot]))
  else
  begin
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_WRITE_FAIL, [LRoot, LErr]));
    Inc(LIssueCount);
  end;

  // 2) git
  LOk := RunDoctorToolVersionCore('git', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_GIT_OK, [Trim(LOut)]))
  else
    Ctx.Out.WriteLn(_(MSG_DOCTOR_GIT_FAIL));

  // 3) make
  LOk := RunDoctorToolVersionCore('make', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_MAKE_OK, [Copy(Trim(LOut), 1, 80) + '...']))
  else
    Ctx.Out.WriteLn(_(MSG_DOCTOR_MAKE_FAIL));

  // 4) FPC compiler (required for building Lazarus)
  LOk := RunDoctorToolVersionCore('fpc', '-i', LOut);
  if LOk then
    Ctx.Out.WriteLn(_(MSG_DOCTOR_FPC_OK))
  else
  begin
    Ctx.Out.WriteLn(_(MSG_DOCTOR_FPC_FAIL));
    Inc(LIssueCount);
  end;

  // 5) lazbuild (if Lazarus is already installed)
  LOk := RunDoctorToolVersionCore('lazbuild', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(MSG_DOCTOR_LAZBUILD_OK, [Trim(LOut)]))
  else
    Ctx.Out.WriteLn(_(MSG_DOCTOR_LAZBUILD_WARN));

  // 6) Check for X11/GTK on Linux
  {$IFDEF LINUX}
  LOk := RunDoctorToolVersionCore('pkg-config', '--exists gtk+-2.0', LOut);
  if LOk then
    Ctx.Out.WriteLn(_(MSG_DOCTOR_GTK2_OK))
  else
  begin
    LOk := RunDoctorToolVersionCore('pkg-config', '--exists gtk+-3.0', LOut);
    if LOk then
      Ctx.Out.WriteLn(_(MSG_DOCTOR_GTK3_OK))
    else
      Ctx.Out.WriteLn(_(MSG_DOCTOR_GTK_FAIL));
  end;
  {$ENDIF}

  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_DOCTOR_COMPLETE));
  if LIssueCount > 0 then
    Result := EXIT_ERROR;
end;

function LazarusDoctorFactory: ICommand;
begin
  Result := TLazarusDoctorCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','doctor'], @LazarusDoctorFactory, []);

end.
