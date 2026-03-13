unit fpdev.cmd.env;

{
================================================================================
  fpdev.cmd.env - Development Environment Information Command
================================================================================

  Provides commands for displaying development environment information:
  - fpdev system env           - Show environment overview
  - fpdev system env vars      - Show FPC/Lazarus environment variables
  - fpdev system env path      - Show PATH configuration
  - fpdev system env export    - Export environment as shell script
  - fpdev system env hook      - Generate shell integration hook

  Useful for:
  - Debugging toolchain issues
  - Sharing environment configuration
  - Setting up CI/CD pipelines

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.output.intf, fpdev.paths;

type
  { TEnvCommand - Development environment information }
  TEnvCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowOverview(const Ctx: IContext);
    procedure ShowHelp(const Ctx: IContext);
    function GetEnvVar(const AName: string): string;
    function FormatPath(const APath: string): string;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateEnvCommand: ICommand;

implementation

uses
  fpdev.command.namespacehelp,
  fpdev.help.details.system,
  fpdev.system.view;

function CreateEnvCommand: ICommand;
begin
  Result := TEnvCommand.Create;
end;

{ TEnvCommand }

function TEnvCommand.Name: string;
begin
  Result := 'env';
end;

function TEnvCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TEnvCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TEnvCommand.GetEnvVar(const AName: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result = '' then
    Result := '(not set)';
end;

function TEnvCommand.FormatPath(const APath: string): string;
begin
  if DirectoryExists(APath) or FileExists(APath) then
    Result := APath
  else if APath = '' then
    Result := '(empty)'
  else
    Result := APath + ' (missing)';
end;

procedure TEnvCommand.ShowHelp(const Ctx: IContext);
begin
  WriteSystemEnvHelpCore(Ctx);
end;

procedure TEnvCommand.ShowOverview(const Ctx: IContext);
var
  DataRoot, ConfigPath, CacheDir, ToolchainsDir: string;
  Lines: TStringArray;
  Line: string;
  PlatformOS: string;
  Architecture: string;
begin
  {$IFDEF WINDOWS}
  PlatformOS := 'Windows';
  {$ENDIF}
  {$IFDEF LINUX}
  PlatformOS := 'Linux';
  {$ENDIF}
  {$IFDEF DARWIN}
  PlatformOS := 'macOS';
  {$ENDIF}
  {$IFDEF CPUX86_64}
  Architecture := 'x86_64';
  {$ELSE}
  {$IFDEF CPUAARCH64}
  Architecture := 'aarch64';
  {$ELSE}
  {$IFDEF CPU64}
  Architecture := '64-bit';
  {$ELSE}
  {$IFDEF CPUARM}
  Architecture := 'arm';
  {$ELSE}
  Architecture := 'x86';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}

  DataRoot := GetDataRoot;
  ConfigPath := GetConfigPath;
  CacheDir := GetCacheDir;
  ToolchainsDir := GetToolchainsDir;
  if IsPortableMode then
    Lines := BuildSystemEnvOverviewLinesCore(
      PlatformOS,
      Architecture,
      'Portable',
      FormatPath(DataRoot),
      FormatPath(ConfigPath),
      FormatPath(CacheDir),
      FormatPath(ToolchainsDir),
      GetEnvVar('FPCDIR'),
      GetEnvVar('LAZARUSDIR'),
      GetEnvVar('HOME'),
      {$IFDEF WINDOWS}GetEnvVar('USERPROFILE'){$ELSE}''{$ENDIF},
      {$IFDEF WINDOWS}GetEnvVar('APPDATA'){$ELSE}''{$ENDIF}
    )
  else
    Lines := BuildSystemEnvOverviewLinesCore(
      PlatformOS,
      Architecture,
      'Standard',
      FormatPath(DataRoot),
      FormatPath(ConfigPath),
      FormatPath(CacheDir),
      FormatPath(ToolchainsDir),
      GetEnvVar('FPCDIR'),
      GetEnvVar('LAZARUSDIR'),
      GetEnvVar('HOME'),
      {$IFDEF WINDOWS}GetEnvVar('USERPROFILE'){$ELSE}''{$ENDIF},
      {$IFDEF WINDOWS}GetEnvVar('APPDATA'){$ELSE}''{$ENDIF}
    );
  for Line in Lines do
    Ctx.Out.WriteLn(Line);
end;

function TEnvCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteNamespaceRootCommandCore(
    AParams,
    Ctx,
    'Usage: fpdev system env [command]',
    @ShowOverview,
    @ShowHelp
  );
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'env'], @CreateEnvCommand, []);

end.
