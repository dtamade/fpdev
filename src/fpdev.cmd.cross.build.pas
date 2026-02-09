unit fpdev.cmd.cross.build;

{$mode objfpc}{$H+}

{
  fpdev cross build <target> [--dry-run] [--source=<path>] [--sandbox=<path>]

  Builds a cross-compiler for the specified target using the 7-step
  build process (compiler_cycle -> rtl -> packages -> verify).
}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes;

type
  TCrossBuildCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.cmd.utils,
  fpdev.config.interfaces,
  fpdev.cross.engine,
  fpdev.cross.engine.intf,
  fpdev.build.manager;

function TCrossBuildCommand.Name: string;
begin
  Result := 'build';
end;

function TCrossBuildCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCrossBuildCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function CrossBuildFactory: ICommand;
begin
  Result := TCrossBuildCommand.Create;
end;

function ParseTargetString(const ATarget: string; out ACPU, AOS: string): Boolean;
var
  P: Integer;
begin
  Result := False;
  P := Pos('-', ATarget);
  if P < 2 then Exit;
  ACPU := Copy(ATarget, 1, P - 1);
  AOS := Copy(ATarget, P + 1, Length(ATarget));
  if (ACPU <> '') and (AOS <> '') then
    Result := True;
end;

function TCrossBuildCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  TargetStr, SourceRoot, SandboxRoot, Version: string;
  CPU, OS: string;
  DryRun: Boolean;
  Target: TCrossTarget;
  BM: TBuildManager;
  Engine: TCrossBuildEngine;
  Log: TStringArray;
  I: Integer;
begin
  Result := EXIT_OK;

  // Handle --help (note: dispatcher normalizes --help/-h to 'help' string)
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') or
     ((Length(AParams) > 0) and (LowerCase(AParams[0]) = 'help')) then
  begin
    Ctx.Out.WriteLn('Usage: fpdev cross build <cpu-os> [options]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Build a cross-compiler for the specified target.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Options:');
    Ctx.Out.WriteLn('  --dry-run         Show commands without executing');
    Ctx.Out.WriteLn('  --source=<path>   FPC source root directory');
    Ctx.Out.WriteLn('  --sandbox=<path>  Installation sandbox directory');
    Ctx.Out.WriteLn('  --version=<ver>   FPC version (default: main)');
    Ctx.Out.WriteLn('  --help            Show this help');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Examples:');
    Ctx.Out.WriteLn('  fpdev cross build x86_64-win64 --dry-run');
    Ctx.Out.WriteLn('  fpdev cross build arm-linux --source=sources/fpc/fpc-main');
    Exit(EXIT_OK);
  end;

  // Parse target argument
  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn('Error: target not specified');
    Ctx.Err.WriteLn('Usage: fpdev cross build <cpu-os> [--dry-run]');
    Exit(EXIT_USAGE_ERROR);
  end;

  TargetStr := AParams[0];
  if not ParseTargetString(TargetStr, CPU, OS) then
  begin
    Ctx.Err.WriteLn('Error: invalid target format "' + TargetStr + '"');
    Ctx.Err.WriteLn('Expected format: <cpu>-<os> (e.g. x86_64-win64, arm-linux)');
    Exit(EXIT_USAGE_ERROR);
  end;

  // Parse options
  DryRun := HasFlag(AParams, 'dry-run');
  GetFlagValue(AParams, 'source', SourceRoot);
  if SourceRoot = '' then
    SourceRoot := 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-main';
  GetFlagValue(AParams, 'sandbox', SandboxRoot);
  if SandboxRoot = '' then
    SandboxRoot := 'sandbox';
  GetFlagValue(AParams, 'version', Version);
  if Version = '' then
    Version := 'main';

  // Build target record
  Target := Default(TCrossTarget);
  Target.Enabled := True;
  Target.CPU := CPU;
  Target.OS := OS;

  // Create engine
  BM := TBuildManager.Create(SourceRoot, 4, True);
  Engine := TCrossBuildEngine.Create(BM, True);
  try
    Engine.SetDryRun(DryRun);

    if DryRun then
      Ctx.Out.WriteLn('=== Cross-compile ' + CPU + '-' + OS + ' (dry-run) ===')
    else
      Ctx.Out.WriteLn('=== Cross-compile ' + CPU + '-' + OS + ' ===');

    if Engine.BuildCrossCompiler(Target, SourceRoot, SandboxRoot, Version) then
    begin
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Cross-compilation completed successfully.');
      if DryRun then
      begin
        Ctx.Out.WriteLn('');
        Ctx.Out.WriteLn('Command log:');
        Log := Engine.GetCommandLog;
        for I := 0 to Engine.GetCommandLogCount - 1 do
          Ctx.Out.WriteLn('  ' + Log[I]);
      end;
    end
    else
    begin
      Ctx.Err.WriteLn('Error: ' + Engine.GetLastError);
      Ctx.Err.WriteLn('Stage: ' + CrossBuildStageToString(Engine.GetCurrentStage));
      Result := EXIT_ERROR;
    end;
  finally
    Engine.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','build'], @CrossBuildFactory, []);

end.
