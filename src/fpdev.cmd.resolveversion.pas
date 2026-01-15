unit fpdev.cmd.resolveversion;

{
  fpdev resolve-version 命令

  内部命令，供 shell hook 使用
  解析当前目录的有效 FPC 版本（考虑配置优先级）

  用法:
    fpdev resolve-version           # 输出当前有效的 FPC 版本
    fpdev resolve-version --json    # JSON 格式输出完整信息
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry;

type
  { TResolveVersionCommand - 解析当前有效版本 }
  TResolveVersionCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function ResolveVersionCommandFactory: ICommand;

implementation

uses
  fpjson,
  fpdev.config.project;

function ResolveVersionCommandFactory: ICommand;
begin
  Result := TResolveVersionCommand.Create;
end;

{ TResolveVersionCommand }

function TResolveVersionCommand.Name: string;
begin
  Result := 'resolve-version';
end;

function TResolveVersionCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TResolveVersionCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TResolveVersionCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LResolver: TProjectConfigResolver;
  LResolved: TResolvedConfig;
  LGlobalFPC, LGlobalLazarus: string;
  LJsonOutput: Boolean;
  LJson: TJSONObject;
  I: Integer;
begin
  Result := 0;

  // 检查 --json 标志
  LJsonOutput := False;
  for I := 0 to High(AParams) do
  begin
    if AParams[I] = '--json' then
    begin
      LJsonOutput := True;
      Break;
    end;
  end;

  // 获取全局默认值
  LGlobalFPC := '';
  LGlobalLazarus := '';

  if Ctx.Config <> nil then
  begin
    LGlobalFPC := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
    // 移除 'fpc-' 前缀
    if Pos('fpc-', LGlobalFPC) = 1 then
      LGlobalFPC := Copy(LGlobalFPC, 5, Length(LGlobalFPC));

    LGlobalLazarus := Ctx.Config.GetLazarusManager.GetDefaultLazarusVersion;
    // 移除 'lazarus-' 前缀
    if Pos('lazarus-', LGlobalLazarus) = 1 then
      LGlobalLazarus := Copy(LGlobalLazarus, 9, Length(LGlobalLazarus));
  end;

  // 创建解析器
  LResolver := TProjectConfigResolver.Create(LGlobalFPC, LGlobalLazarus);
  try
    LResolved := LResolver.ResolveConfig(GetCurrentDir);

    if LJsonOutput then
    begin
      // JSON 格式输出
      LJson := TJSONObject.Create;
      try
        LJson.Add('fpc_version', LResolved.FPCVersion);
        LJson.Add('fpc_source', ConfigSourceToString(LResolved.FPCSource));
        if LResolved.FPCSourceFile <> '' then
          LJson.Add('fpc_source_file', LResolved.FPCSourceFile);

        LJson.Add('lazarus_version', LResolved.LazarusVersion);
        LJson.Add('lazarus_source', ConfigSourceToString(LResolved.LazarusSource));
        if LResolved.LazarusSourceFile <> '' then
          LJson.Add('lazarus_source_file', LResolved.LazarusSourceFile);

        LJson.Add('mirror', LResolved.Mirror);
        LJson.Add('auto_install', LResolved.AutoInstall);

        Ctx.Out.WriteLn(LJson.FormatJSON);
      finally
        LJson.Free;
      end;
    end
    else
    begin
      // 简单输出：仅版本号（供 shell hook 使用）
      Ctx.Out.WriteLn(LResolved.FPCVersion);
    end;
  finally
    LResolver.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['resolve-version'], @ResolveVersionCommandFactory, []);

end.
