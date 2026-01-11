unit fpdev.cmd.fpc.doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config.interfaces,
  fpdev.utils.fs, fpdev.utils.process,
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
begin
  Result := 0;

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

  // 1) Write permission check (install root)
  LSettings := Ctx.Config.GetSettingsManager.GetSettings;
  LRoot := LSettings.InstallRoot;
  if LRoot = '' then
    LRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
  LOk := CheckWriteableDir(LRoot, LErr);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(CMD_FPC_DOCTOR_WRITE_OK, [LRoot]))
  else
    Ctx.Out.WriteLn(_Fmt(CMD_FPC_DOCTOR_WRITE_FAILED, [LRoot, LErr]));

  // 2) git
  LOk := RunToolVersion('git', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(CMD_FPC_DOCTOR_GIT_OK, [Trim(LOut)]))
  else
    Ctx.Out.WriteLn(_(CMD_FPC_DOCTOR_GIT_NOT_FOUND));

  // 3) make
  LOk := RunToolVersion('make', '--version', LOut);
  if LOk then
    Ctx.Out.WriteLn(_Fmt(CMD_FPC_DOCTOR_MAKE_OK, [Copy(Trim(LOut), 1, 80) + '...']))
  else
    Ctx.Out.WriteLn(_(CMD_FPC_DOCTOR_MAKE_NOT_FOUND));

  // 4) bootstrap fpc (optional)
  LOk := RunToolVersion('fpc', '-i', LOut);
  if LOk then
    Ctx.Out.WriteLn(_(CMD_FPC_DOCTOR_FPC_OK))
  else
    Ctx.Out.WriteLn(_(CMD_FPC_DOCTOR_FPC_NOT_FOUND));
end;


function FPCDoctorFactory: ICommand;
begin
  Result := TFPCDoctorCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','doctor'], @FPCDoctorFactory, []);

end.

