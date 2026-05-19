unit fpdev.registry.buildsteps;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, fpdev.output.intf;

type
  TBuildStepAction = (
    bsaMake,
    bsaPatch,
    bsaSymlinkCompiler,
    bsaCreateWrapper,
    bsaGenerateCfg,
    bsaCopy,
    bsaDelete,
    bsaUnknown
  );

  TBuildStep = record
    Action: TBuildStepAction;
    Description: string;
    Targets: array of string;
    Env: TStringList;
    Parallel: Boolean;
    Platforms: array of string;
    Template: string;
    FileName: string;
  end;

  TBuildStepArray = array of TBuildStep;

  TBuildStepContext = record
    InstallPath: string;
    BootstrapCompiler: string;
    BuildDir: string;
    Version: string;
    NativeCompiler: string;
    BinPath: string;
    HostCompiler: string;
    CPU: string;
    OS: string;
    CrossOptions: string;
    ParallelJobs: Integer;
  end;

  TBuildStepExecutor = class
  private
    FOut: IOutput;
    FErr: IOutput;
    FContext: TBuildStepContext;
    function ResolveTemplate(const ATemplate: string): string;
    function GetCurrentPlatformShort: string;
    function PlatformMatches(const APlatforms: array of string): Boolean;
    function ExecuteMake(const AStep: TBuildStep): Boolean;
    function ExecutePatch(const AStep: TBuildStep): Boolean;
    function ExecuteSymlinkCompiler: Boolean;
    function ExecuteCreateWrapper(const AStep: TBuildStep): Boolean;
    function ExecuteGenerateCfg: Boolean;
  public
    constructor Create(const AContext: TBuildStepContext;
      const AOut, AErr: IOutput);
    function Execute(const ASteps: TBuildStepArray): Boolean;
    function ExecuteStep(const AStep: TBuildStep): Boolean;
  end;

function ParseBuildSteps(const AStepsArray: TJSONArray): TBuildStepArray;
function ParseBuildStepsFromFile(const APath: string): TBuildStepArray;
procedure FreeBuildSteps(var ASteps: TBuildStepArray);
function ActionFromString(const AName: string): TBuildStepAction;
function GetNativeCompilerForPlatform: string;

implementation

uses
  fpdev.utils.process, fpdev.utils.fs;

function ActionFromString(const AName: string): TBuildStepAction;
begin
  if SameText(AName, 'make') then Result := bsaMake
  else if SameText(AName, 'patch') then Result := bsaPatch
  else if SameText(AName, 'symlink-compiler') then Result := bsaSymlinkCompiler
  else if SameText(AName, 'create-wrapper') then Result := bsaCreateWrapper
  else if SameText(AName, 'generate-cfg') then Result := bsaGenerateCfg
  else if SameText(AName, 'copy') then Result := bsaCopy
  else if SameText(AName, 'delete') then Result := bsaDelete
  else Result := bsaUnknown;
end;

function GetNativeCompilerForPlatform: string;
begin
  Result := 'ppcx64';
  {$IFDEF CPUX86_64}
  Result := 'ppcx64';
  {$ENDIF}
  {$IFDEF CPUAARCH64}
  Result := 'ppca64';
  {$ENDIF}
  {$IFDEF CPUI386}
  Result := 'ppc386';
  {$ENDIF}
  {$IFDEF CPUARM}
  Result := 'ppcarm';
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function ParseBuildStep(const AObj: TJSONObject): TBuildStep;
var
  EnvObj: TJSONObject;
  TargetsArr, PlatformsArr: TJSONArray;
  I: Integer;
begin
  Initialize(Result);
  Result.Env := TStringList.Create;

  Result.Action := ActionFromString(AObj.Get('action', ''));
  Result.Description := AObj.Get('description', '');
  Result.Parallel := AObj.Get('parallel', False);
  Result.Template := AObj.Get('template', '');
  Result.FileName := AObj.Get('file', '');

  if AObj.Find('targets') <> nil then
  begin
    TargetsArr := AObj.Arrays['targets'];
    SetLength(Result.Targets, TargetsArr.Count);
    for I := 0 to TargetsArr.Count - 1 do
      Result.Targets[I] := TargetsArr.Strings[I];
  end;

  if AObj.Find('env') <> nil then
  begin
    EnvObj := AObj.Objects['env'];
    for I := 0 to EnvObj.Count - 1 do
    begin
      if EnvObj.Items[I].JSONType = jtNull then
        Continue;
      Result.Env.Values[EnvObj.Names[I]] := EnvObj.Items[I].AsString;
    end;
  end;

  if AObj.Find('platforms') <> nil then
  begin
    PlatformsArr := AObj.Arrays['platforms'];
    SetLength(Result.Platforms, PlatformsArr.Count);
    for I := 0 to PlatformsArr.Count - 1 do
      Result.Platforms[I] := PlatformsArr.Strings[I];
  end;
end;

function ParseBuildSteps(const AStepsArray: TJSONArray): TBuildStepArray;
var
  I, Count: Integer;
begin
  SetLength(Result, AStepsArray.Count);
  Count := 0;
  for I := 0 to AStepsArray.Count - 1 do
  begin
    if AStepsArray.Items[I].JSONType <> jtObject then
      Continue;
    Result[Count] := ParseBuildStep(TJSONObject(AStepsArray.Items[I]));
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

function ParseBuildStepsFromFile(const APath: string): TBuildStepArray;
var
  SL: TStringList;
  J: TJSONData;
  Root: TJSONObject;
begin
  SetLength(Result, 0);
  if not FileExists(APath) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    try
      J := GetJSON(SL.Text);
    except
      J := nil;
    end;
  finally
    SL.Free;
  end;

  if (J = nil) or (J.JSONType <> jtObject) then
  begin
    J.Free;
    Exit;
  end;

  Root := TJSONObject(J);
  try
    if Root.Find('steps') <> nil then
      Result := ParseBuildSteps(Root.Arrays['steps']);
  finally
    Root.Free;
  end;
end;

procedure FreeBuildSteps(var ASteps: TBuildStepArray);
var
  I: Integer;
begin
  for I := 0 to High(ASteps) do
    FreeAndNil(ASteps[I].Env);
  SetLength(ASteps, 0);
end;

{ TBuildStepExecutor }

constructor TBuildStepExecutor.Create(const AContext: TBuildStepContext;
  const AOut, AErr: IOutput);
begin
  inherited Create;
  FContext := AContext;
  FOut := AOut;
  FErr := AErr;
end;

function TBuildStepExecutor.ResolveTemplate(const ATemplate: string): string;
begin
  Result := ATemplate;
  Result := StringReplace(Result, '{{install_path}}', FContext.InstallPath, [rfReplaceAll]);
  Result := StringReplace(Result, '{{bootstrap_compiler}}', FContext.BootstrapCompiler, [rfReplaceAll]);
  Result := StringReplace(Result, '{{bootstrap}}', FContext.BootstrapCompiler, [rfReplaceAll]);
  Result := StringReplace(Result, '{{build_dir}}', FContext.BuildDir, [rfReplaceAll]);
  Result := StringReplace(Result, '{{version}}', FContext.Version, [rfReplaceAll]);
  Result := StringReplace(Result, '{{native_compiler}}', FContext.NativeCompiler, [rfReplaceAll]);
  Result := StringReplace(Result, '{{bin_path}}', FContext.BinPath, [rfReplaceAll]);
  Result := StringReplace(Result, '{{host_compiler}}', FContext.HostCompiler, [rfReplaceAll]);
  Result := StringReplace(Result, '{{cpu}}', FContext.CPU, [rfReplaceAll]);
  Result := StringReplace(Result, '{{os}}', FContext.OS, [rfReplaceAll]);
  Result := StringReplace(Result, '{{cross_options}}', FContext.CrossOptions, [rfReplaceAll]);
end;

function TBuildStepExecutor.GetCurrentPlatformShort: string;
begin
  Result := 'linux';
  {$IFDEF LINUX}Result := 'linux';{$ENDIF}
  {$IFDEF DARWIN}Result := 'darwin';{$ENDIF}
  {$IFDEF MSWINDOWS}Result := 'windows';{$ENDIF}
  {$IFDEF FREEBSD}Result := 'freebsd';{$ENDIF}
end;

function TBuildStepExecutor.PlatformMatches(const APlatforms: array of string): Boolean;
var
  I: Integer;
  Current: string;
begin
  if Length(APlatforms) = 0 then
    Exit(True);

  Current := GetCurrentPlatformShort;
  for I := 0 to High(APlatforms) do
    if SameText(APlatforms[I], Current) then
      Exit(True);

  Result := False;
end;

function TBuildStepExecutor.ExecuteMake(const AStep: TBuildStep): Boolean;
var
  Args: TStringList;
  ArgsArr: array of string;
  I: Integer;
  Res: TProcessResult;
  MakeCmd: string;
begin
  {$IFDEF MSWINDOWS}
  MakeCmd := 'make.exe';
  {$ELSE}
    {$IFDEF LINUX}
    MakeCmd := 'make';
    {$ELSE}
    MakeCmd := 'gmake';
    {$ENDIF}
  {$ENDIF}

  Args := TStringList.Create;
  try
    for I := 0 to High(AStep.Targets) do
      Args.Add(AStep.Targets[I]);

    for I := 0 to AStep.Env.Count - 1 do
      Args.Add(AStep.Env.Names[I] + '=' + ResolveTemplate(AStep.Env.ValueFromIndex[I]));

    if AStep.Parallel and (FContext.ParallelJobs > 1) then
      Args.Add('-j' + IntToStr(FContext.ParallelJobs));

    if FOut <> nil then
      FOut.WriteLn('Executing: ' + MakeCmd + ' ' + Args.DelimitedText);

    SetLength(ArgsArr, Args.Count);
    for I := 0 to Args.Count - 1 do
      ArgsArr[I] := Args[I];

    Res := TProcessExecutor.RunDirect(MakeCmd, ArgsArr, FContext.BuildDir);
    Result := Res.Success;

    if not Result then
    begin
      if FErr <> nil then
        FErr.WriteLn('make failed: ' + Res.ErrorMessage);
    end;
  finally
    Args.Free;
  end;
end;

function TBuildStepExecutor.ExecutePatch(const AStep: TBuildStep): Boolean;
var
  PatchFile: string;
  Res: TProcessResult;
begin
  PatchFile := ResolveTemplate(AStep.FileName);
  if not FileExists(PatchFile) then
  begin
    if FErr <> nil then
      FErr.WriteLn('Patch file not found: ' + PatchFile);
    Exit(False);
  end;

  if FOut <> nil then
    FOut.WriteLn('Applying patch: ' + ExtractFileName(PatchFile));

  Res := TProcessExecutor.Execute('patch', ['-p1', '-i', PatchFile], FContext.BuildDir);
  Result := Res.Success;

  if not Result then
    if FErr <> nil then
      FErr.WriteLn('patch failed: ' + Res.ErrorMessage);
end;

function TBuildStepExecutor.ExecuteSymlinkCompiler: Boolean;
var
  LibPath, BinPath, CompilerName: string;
  Res: TProcessResult;
begin
  CompilerName := FContext.NativeCompiler;
  LibPath := FContext.InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' +
    PathDelim + FContext.Version + PathDelim + CompilerName;
  BinPath := FContext.InstallPath + PathDelim + 'bin' + PathDelim + CompilerName;

  if FOut <> nil then
    FOut.WriteLn('Creating compiler symlink...');

  Res := TProcessExecutor.Execute('ln', ['-sf', LibPath, BinPath], '');
  Result := Res.Success;

  if Result then
  begin
    if FOut <> nil then
      FOut.WriteLn('  ' + CompilerName + ' symlink created');
  end
  else
    if FErr <> nil then
      FErr.WriteLn('symlink failed: ' + Res.ErrorMessage);
end;

function TBuildStepExecutor.ExecuteCreateWrapper(const AStep: TBuildStep): Boolean;
var
  WrapperContent, WrapperPath, BinPath: string;
  SL: TStringList;
  Res: TProcessResult;
begin
  BinPath := FContext.InstallPath + PathDelim + 'bin';
  WrapperPath := BinPath + PathDelim + 'fpc';

  if AStep.Template <> '' then
    WrapperContent := ResolveTemplate(AStep.Template)
  else
    WrapperContent := '#!/bin/sh' + LineEnding +
      BinPath + '/' + FContext.NativeCompiler +
      ' -n @' + BinPath + '/fpc.cfg "$@"';

  if FOut <> nil then
    FOut.WriteLn('Creating fpc wrapper script...');

  if FileExists(WrapperPath) then
  begin
    if not FileExists(BinPath + PathDelim + 'fpc.orig') then
      RenameFile(WrapperPath, BinPath + PathDelim + 'fpc.orig');
  end;

  SL := TStringList.Create;
  try
    SL.Text := WrapperContent;
    SL.SaveToFile(WrapperPath);
  finally
    SL.Free;
  end;

  Res := TProcessExecutor.Execute('chmod', ['+x', WrapperPath], '');
  Result := Res.Success or FileExists(WrapperPath);

  if FOut <> nil then
    FOut.WriteLn('  fpc wrapper created');
end;

function TBuildStepExecutor.ExecuteGenerateCfg: Boolean;
var
  CfgPath, BinPath, LibBase: string;
  SL: TStringList;
begin
  BinPath := FContext.InstallPath + PathDelim + 'bin';
  CfgPath := BinPath + PathDelim + 'fpc.cfg';
  LibBase := FContext.InstallPath + PathDelim + 'lib' + PathDelim + 'fpc' +
    PathDelim + FContext.Version;

  if FOut <> nil then
    FOut.WriteLn('Generating fpc.cfg...');

  SL := TStringList.Create;
  try
    SL.Add('# FPC configuration file generated by fpdev');
    SL.Add('# FPC version: ' + FContext.Version);
    SL.Add('');
    SL.Add('# Compiler binary path');
    SL.Add('-FD' + LibBase);
    SL.Add('');
    SL.Add('# Unit search paths');
    SL.Add('-Fu' + LibBase + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + '*');
    SL.Add('-Fu' + LibBase + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
    SL.Add('');
    SL.Add('# Library search path');
    SL.Add('-Fl' + LibBase + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
    SL.Add('');
    SL.Add('# Include search path');
    SL.Add('-Fi' + LibBase + PathDelim + 'units' + PathDelim + '$fpctarget' + PathDelim + 'rtl');
    SL.SaveToFile(CfgPath);
    Result := True;
  finally
    SL.Free;
  end;

  if FOut <> nil then
    FOut.WriteLn('  fpc.cfg created');
end;

function TBuildStepExecutor.ExecuteStep(const AStep: TBuildStep): Boolean;
begin
  if not PlatformMatches(AStep.Platforms) then
  begin
    if FOut <> nil then
      FOut.WriteLn('  [skip] ' + AStep.Description + ' (platform not applicable)');
    Exit(True);
  end;

  if (AStep.Description <> '') and (FOut <> nil) then
    FOut.WriteLn('  ' + AStep.Description);

  case AStep.Action of
    bsaMake: Result := ExecuteMake(AStep);
    bsaPatch: Result := ExecutePatch(AStep);
    bsaSymlinkCompiler: Result := ExecuteSymlinkCompiler;
    bsaCreateWrapper: Result := ExecuteCreateWrapper(AStep);
    bsaGenerateCfg: Result := ExecuteGenerateCfg;
    else
    begin
      if FErr <> nil then
        FErr.WriteLn('Unknown build step action');
      Result := False;
    end;
  end;
end;

function TBuildStepExecutor.Execute(const ASteps: TBuildStepArray): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to High(ASteps) do
  begin
    if not ExecuteStep(ASteps[I]) then
    begin
      if FErr <> nil then
        FErr.WriteLn('Build step ' + IntToStr(I + 1) + ' failed');
      Exit(False);
    end;
  end;
end;

end.
