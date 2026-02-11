unit fpdev.cmd.env;

{
================================================================================
  fpdev.cmd.env - Development Environment Information Command
================================================================================

  Provides commands for displaying development environment information:
  - fpdev env           - Show environment overview
  - fpdev env vars      - Show FPC/Lazarus environment variables
  - fpdev env path      - Show PATH configuration
  - fpdev env export    - Export environment as shell script

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
  fpdev.output.intf, fpdev.paths, fpdev.exitcodes;

type
  { TEnvCommand - Development environment information }
  TEnvCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowOverview(const Ctx: IContext);
    procedure ShowVarsEnv(const Ctx: IContext);
    procedure ShowPathEnv(const Ctx: IContext);
    procedure ExportEnv(const Ctx: IContext; const AShell: string);
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
  Ctx.Out.WriteLn('Usage: fpdev env [command]');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Show development environment information.');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Commands:');
  Ctx.Out.WriteLn('  (none)      Show environment overview');
  Ctx.Out.WriteLn('  vars        Show FPC/Lazarus environment variables');
  Ctx.Out.WriteLn('  path        Show PATH configuration');
  Ctx.Out.WriteLn('  export      Export environment as shell script');
  Ctx.Out.WriteLn('  help        Show this help');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Options for export:');
  Ctx.Out.WriteLn('  --shell <sh|bash|cmd|ps>   Shell type (default: auto-detect)');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('Examples:');
  Ctx.Out.WriteLn('  fpdev env');
  Ctx.Out.WriteLn('  fpdev env vars');
  Ctx.Out.WriteLn('  fpdev env export --shell bash');
end;

procedure TEnvCommand.ShowOverview(const Ctx: IContext);
var
  DataRoot, ConfigPath, CacheDir, ToolchainsDir: string;
begin
  Ctx.Out.WriteLn('Environment Overview');
  Ctx.Out.WriteLn('====================');
  Ctx.Out.WriteLn('');

  // Platform info
  Ctx.Out.WriteLn('Platform:');
  {$IFDEF WINDOWS}
  Ctx.Out.WriteLn('  OS:           Windows');
  {$ENDIF}
  {$IFDEF LINUX}
  Ctx.Out.WriteLn('  OS:           Linux');
  {$ENDIF}
  {$IFDEF DARWIN}
  Ctx.Out.WriteLn('  OS:           macOS');
  {$ENDIF}
  {$IFDEF CPUX86_64}
  Ctx.Out.WriteLn('  Architecture: x86_64');
  {$ELSE}
  {$IFDEF CPUAARCH64}
  Ctx.Out.WriteLn('  Architecture: aarch64');
  {$ELSE}
  {$IFDEF CPU64}
  Ctx.Out.WriteLn('  Architecture: 64-bit');
  {$ELSE}
  {$IFDEF CPUARM}
  Ctx.Out.WriteLn('  Architecture: arm');
  {$ELSE}
  Ctx.Out.WriteLn('  Architecture: x86');
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  Ctx.Out.WriteLn('');

  // fpdev paths
  DataRoot := GetDataRoot;
  ConfigPath := GetConfigPath;
  CacheDir := GetCacheDir;
  ToolchainsDir := GetToolchainsDir;

  Ctx.Out.WriteLn('FPDev Paths:');
  if IsPortableMode then
    Ctx.Out.WriteLn('  Mode:         Portable')
  else
    Ctx.Out.WriteLn('  Mode:         Standard');
  Ctx.Out.WriteLn('  Data Root:    ' + FormatPath(DataRoot));
  Ctx.Out.WriteLn('  Config:       ' + FormatPath(ConfigPath));
  Ctx.Out.WriteLn('  Cache:        ' + FormatPath(CacheDir));
  Ctx.Out.WriteLn('  Toolchains:   ' + FormatPath(ToolchainsDir));
  Ctx.Out.WriteLn('');

  // Key environment variables
  Ctx.Out.WriteLn('Key Environment Variables:');
  Ctx.Out.WriteLn('  FPCDIR:       ' + GetEnvVar('FPCDIR'));
  Ctx.Out.WriteLn('  LAZARUSDIR:   ' + GetEnvVar('LAZARUSDIR'));
  Ctx.Out.WriteLn('  HOME:         ' + GetEnvVar('HOME'));
  {$IFDEF WINDOWS}
  Ctx.Out.WriteLn('  USERPROFILE:  ' + GetEnvVar('USERPROFILE'));
  Ctx.Out.WriteLn('  APPDATA:      ' + GetEnvVar('APPDATA'));
  {$ENDIF}
end;

procedure TEnvCommand.ShowVarsEnv(const Ctx: IContext);
begin
  Ctx.Out.WriteLn('FPC/Lazarus Environment Variables');
  Ctx.Out.WriteLn('==================================');
  Ctx.Out.WriteLn('');

  // FPC variables
  Ctx.Out.WriteLn('FPC Variables:');
  Ctx.Out.WriteLn('  FPCDIR:       ' + GetEnvVar('FPCDIR'));
  Ctx.Out.WriteLn('  FPCSRCDIR:    ' + GetEnvVar('FPCSRCDIR'));
  Ctx.Out.WriteLn('  FPCVER:       ' + GetEnvVar('FPCVER'));
  Ctx.Out.WriteLn('  FPCOPT:       ' + GetEnvVar('FPCOPT'));
  Ctx.Out.WriteLn('  PP:           ' + GetEnvVar('PP'));
  Ctx.Out.WriteLn('  FPCMAKE:      ' + GetEnvVar('FPCMAKE'));
  Ctx.Out.WriteLn('');

  // Lazarus variables
  Ctx.Out.WriteLn('Lazarus Variables:');
  Ctx.Out.WriteLn('  LAZARUSDIR:   ' + GetEnvVar('LAZARUSDIR'));
  Ctx.Out.WriteLn('  LAZBUILD:     ' + GetEnvVar('LAZBUILD'));
  Ctx.Out.WriteLn('  LCL_PLATFORM: ' + GetEnvVar('LCL_PLATFORM'));
  Ctx.Out.WriteLn('');

  // Cross-compilation variables
  Ctx.Out.WriteLn('Cross-Compilation Variables:');
  Ctx.Out.WriteLn('  CPU_TARGET:   ' + GetEnvVar('CPU_TARGET'));
  Ctx.Out.WriteLn('  OS_TARGET:    ' + GetEnvVar('OS_TARGET'));
  Ctx.Out.WriteLn('  CROSSOPT:     ' + GetEnvVar('CROSSOPT'));
  Ctx.Out.WriteLn('  BINUTILSDIR:  ' + GetEnvVar('BINUTILSDIR'));
end;

procedure TEnvCommand.ShowPathEnv(const Ctx: IContext);
var
  PathEnv: string;
  Paths: TStringList;
  I: Integer;
  P: string;
begin
  Ctx.Out.WriteLn('PATH Configuration');
  Ctx.Out.WriteLn('==================');
  Ctx.Out.WriteLn('');

  PathEnv := GetEnvironmentVariable('PATH');
  if PathEnv = '' then
  begin
    Ctx.Out.WriteLn('PATH is empty');
    Exit;
  end;

  Paths := TStringList.Create;
  try
    {$IFDEF WINDOWS}
    Paths.Delimiter := ';';
    {$ELSE}
    Paths.Delimiter := ':';
    {$ENDIF}
    Paths.StrictDelimiter := True;
    Paths.DelimitedText := PathEnv;

    Ctx.Out.WriteLnFmt('Total entries: %d', [Paths.Count]);
    Ctx.Out.WriteLn('');

    for I := 0 to Paths.Count - 1 do
    begin
      P := Paths[I];
      if DirectoryExists(P) then
        Ctx.Out.WriteLnFmt('  [%3d] %s', [I + 1, P])
      else
        Ctx.Out.WriteLnFmt('  [%3d] %s (missing)', [I + 1, P]);
    end;
  finally
    Paths.Free;
  end;
end;

procedure TEnvCommand.ExportEnv(const Ctx: IContext; const AShell: string);
var
  Shell: string;
  DataRoot, ToolchainsDir: string;
begin
  // Auto-detect shell if not specified
  Shell := LowerCase(AShell);
  if Shell = '' then
  begin
    {$IFDEF WINDOWS}
    Shell := 'cmd';
    {$ELSE}
    Shell := 'bash';
    {$ENDIF}
  end;

  DataRoot := GetDataRoot;
  ToolchainsDir := GetToolchainsDir;

  Ctx.Out.WriteLn('# FPDev Environment Export');
  Ctx.Out.WriteLn('# Generated: ' + DateTimeToStr(Now));
  Ctx.Out.WriteLn('');

  if (Shell = 'cmd') then
  begin
    // Windows CMD format
    Ctx.Out.WriteLn('set FPDEV_ROOT=' + DataRoot);
    Ctx.Out.WriteLn('set FPDEV_TOOLCHAINS=' + ToolchainsDir);
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('rem Add FPC to PATH (adjust version as needed)');
    Ctx.Out.WriteLn('rem set PATH=%FPDEV_TOOLCHAINS%\fpc\3.2.2\bin;%PATH%');
  end
  else if (Shell = 'ps') or (Shell = 'powershell') then
  begin
    // PowerShell format
    Ctx.Out.WriteLn('$env:FPDEV_ROOT="' + DataRoot + '"');
    Ctx.Out.WriteLn('$env:FPDEV_TOOLCHAINS="' + ToolchainsDir + '"');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('# Add FPC to PATH (adjust version as needed)');
    Ctx.Out.WriteLn('# $env:PATH="$env:FPDEV_TOOLCHAINS\fpc\3.2.2\bin;$env:PATH"');
  end
  else
  begin
    // sh/bash format (default)
    Ctx.Out.WriteLn('export FPDEV_ROOT="' + DataRoot + '"');
    Ctx.Out.WriteLn('export FPDEV_TOOLCHAINS="' + ToolchainsDir + '"');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('# Add FPC to PATH (adjust version as needed)');
    Ctx.Out.WriteLn('# export PATH="$FPDEV_TOOLCHAINS/fpc/3.2.2/bin:$PATH"');
  end;
end;

function TEnvCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  SubCmd: string;
  Shell: string;
  I: Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) = 0 then
  begin
    ShowOverview(Ctx);
    Exit;
  end;

  SubCmd := LowerCase(AParams[0]);

  if (SubCmd = 'help') or (SubCmd = '--help') or (SubCmd = '-h') then
    ShowHelp(Ctx)
  else if SubCmd = 'vars' then
    ShowVarsEnv(Ctx)
  else if SubCmd = 'path' then
    ShowPathEnv(Ctx)
  else if SubCmd = 'export' then
  begin
    // Parse --shell option
    Shell := '';
    for I := 1 to High(AParams) do
    begin
      if (AParams[I] = '--shell') and (I + 1 <= High(AParams)) then
      begin
        Shell := AParams[I + 1];
        Break;
      end;
    end;
    ExportEnv(Ctx, Shell);
  end
  else
  begin
    Ctx.Err.WriteLn('Error: Unknown subcommand: ' + SubCmd);
    ShowHelp(Ctx);
    Result := EXIT_USAGE_ERROR;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['env'], @CreateEnvCommand, []);

end.
