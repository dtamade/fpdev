unit fpdev.cmd.fpc.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  fpdev.utils, fpdev.command.intf, fpdev.config, fpdev.cmd.fpc;

type
  { TFPCInstallCommand }
  TFPCInstallCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

uses fpdev.command.registry;

function HasFlag(const Params: array of string; const Flag: string): Boolean;
var i: Integer;
begin
  Result := False;
  for i := Low(Params) to High(Params) do
    if SameText(Params[i], '--' + Flag) or SameText(Params[i], '-' + Flag) then
      Exit(True);
end;

function GetFlagValue(const Params: array of string; const Key: string; out Value: string): Boolean;
var i, p: Integer; s, k: string;
begin
  Result := False;
  Value := '';
  k := '--' + Key + '=';
  for i := Low(Params) to High(Params) do
  begin
    s := Params[i];
    p := Pos(k, s);
    if p = 1 then
    begin
      Value := Copy(s, Length(k) + 1, MaxInt);
      Exit(True);
    end;
  end;
end;

function TFPCInstallCommand.Name: string; begin Result := 'install'; end;
function TFPCInstallCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TFPCInstallCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;

function FPCInstallFactory: IFpdevCommand;
begin
  Result := TFPCInstallCommand.Create;
end;



procedure TFPCInstallCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer, LJobs, LFrom, LPrefix: string;
  LFromSource: Boolean;
  LSettings: TFPDevSettings;
  LOk: Boolean;
  LMgr: TFPCManager;
begin
  if Length(AParams) < 1 then
  begin
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc install 3.2.2');  // 调试代码已注释
    Exit;
  end;
  LVer := AParams[0];

  // flags
  if GetFlagValue(AParams, 'jobs', LJobs) then
  begin
    LSettings := Ctx.Config.GetSettings;
    if TryStrToInt(LJobs, LSettings.ParallelJobs) then
      Ctx.Config.SetSettings(LSettings);
  end;
  LFromSource := HasFlag(AParams, 'from-source') or (GetFlagValue(AParams, 'from', LFrom) and SameText(LFrom, 'source'));
  if not GetFlagValue(AParams, 'prefix', LPrefix) then LPrefix := '';

  LMgr := TFPCManager.Create(Ctx.Config);
  try
    LOk := LMgr.InstallVersion(LVer, LFromSource, LPrefix, False);
    if LOk and Ctx.Config.Modified then Ctx.Config.SaveConfig;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','install'], @FPCInstallFactory, []);

end.

