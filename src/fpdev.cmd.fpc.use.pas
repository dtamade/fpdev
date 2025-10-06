unit fpdev.cmd.fpc.use;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils,
  fpdev.utils, fpdev.command.intf, fpdev.config, fpdev.cmd.fpc;

type
  { TFPCUseCommand }
  TFPCUseCommand = class(TInterfacedObject, IFpdevCommand)
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
function TFPCUseCommand.Name: string; begin Result := 'use'; end;
function TFPCUseCommand.Aliases: TStringArray; begin SetLength(Result,1); Result[0] := 'default'; end;
function TFPCUseCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;


function FPCUseFactory: IFpdevCommand;
begin
  Result := TFPCUseCommand.Create;
end;

function GuessInstalled(const AVer: string; const Ctx: ICommandContext): Boolean;
var
  LInfo: TToolchainInfo;
  LRoot, LExe: string;
begin
  if Ctx.Config.GetToolchain('fpc-' + AVer, LInfo) then Exit(True);
  LRoot := Ctx.Config.GetSettings.InstallRoot;
  if LRoot = '' then LRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
  {$IFDEF MSWINDOWS}
  LExe := IncludeTrailingPathDelimiter(LRoot) + 'fpc' + PathDelim + AVer + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  LExe := IncludeTrailingPathDelimiter(LRoot) + 'fpc' + PathDelim + AVer + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
  Result := FileExists(LExe);
end;


procedure TFPCUseCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LVer: string;
  LMgr: TFPCManager;
begin
  if Length(AParams) < 1 then
  begin
  // WriteLn('错误: 需要指定版本号，例如: fpdev fpc use 3.2.2');  // 调试代码已注释
    Exit;
  end;
  LVer := AParams[0];

  if HasFlag(AParams, 'ensure') and (not GuessInstalled(LVer, Ctx)) then
  begin
    LMgr := TFPCManager.Create(Ctx.Config);
    try
  // WriteLn('未安装版本 ', LVer, '，自动安装 (--ensure) ...');  // 调试代码已注释
      if not LMgr.InstallVersion(LVer, True {from source}, '' {prefix}, True {ensure}) then
      begin
  // WriteLn('错误: 自动安装失败，无法切换');  // 调试代码已注释
        Exit;
      end;
    finally
      LMgr.Free;
    end;
  end;

  LMgr := TFPCManager.Create(Ctx.Config);
  try
    if LMgr.SetDefaultVersion(LVer) then
      if Ctx.Config.Modified then Ctx.Config.SaveConfig;
  finally
    LMgr.Free;
  end;
end;


initialization
  GlobalCommandRegistry.RegisterPath(['fpc','use'], @FPCUseFactory, ['default']);

end.

