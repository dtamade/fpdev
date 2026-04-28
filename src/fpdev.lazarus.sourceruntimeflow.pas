unit fpdev.lazarus.sourceruntimeflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.lazarus.sourceflow;

type
  TLazarusSourceRuntimeStatusProc = procedure(const AText: string) of object;
  TLazarusSourceRuntimeTreeValidator = function(const APath: string): Boolean of object;
  TLazarusSourceRuntimeCommandExecutor = function(const AExecutable: string;
    const AParams: array of string; const AWorkingDir: string): Boolean of object;
  TLazarusSourceRuntimeLauncher = function(const AExecutablePath: string): Boolean of object;

function ConfigureLegacyLazarusCustomFPCIDECore(
  const AVersion, ASourcePath, AFPCPath, AConfigRoot, AHomeDir, AAppDataDir: string;
  AWriteStatus: TLazarusSourceRuntimeStatusProc
): Boolean;

function ListLegacyLazarusLocalVersionsCore(
  const ASourceRoot: string;
  AIsValidSourceDirectory: TLazarusSourceRuntimeTreeValidator
): TStringArray;

function ExecuteLegacyLazarusBuildCore(
  const ASourcePath, AFPCPath: string;
  const AParallelJobs: Integer;
  AIsValidSourceDirectory: TLazarusSourceRuntimeTreeValidator;
  AExecuteCommand: TLazarusSourceRuntimeCommandExecutor;
  AWriteStatus: TLazarusSourceRuntimeStatusProc
): Boolean;

function ExecuteLegacyLazarusLaunchCore(
  const AExecutablePath: string;
  ALaunchExecutable: TLazarusSourceRuntimeLauncher;
  AWriteStatus: TLazarusSourceRuntimeStatusProc
): Boolean;

implementation

uses
  Classes,
  fpdev.constants,
  fpdev.lazarus.commandflow,
  fpdev.lazarus.config;

procedure WriteStatusLine(
  AWriteStatus: TLazarusSourceRuntimeStatusProc;
  const AText: string
);
begin
  if Assigned(AWriteStatus) then
    AWriteStatus(AText);
end;

function ConfigureLegacyLazarusCustomFPCIDECore(
  const AVersion, ASourcePath, AFPCPath, AConfigRoot, AHomeDir, AAppDataDir: string;
  AWriteStatus: TLazarusSourceRuntimeStatusProc
): Boolean;
var
  IDEConfig: TLazarusIDEConfig;
  ConfigDir: string;
begin
  Result := True;

  if Trim(AFPCPath) = '' then
    Exit(True);

  if not FileExists(AFPCPath) then
  begin
    WriteStatusLine(AWriteStatus, 'Error: Configured FPC executable not found: ' + AFPCPath);
    Exit(False);
  end;

  ConfigDir := ResolveLazarusConfigDirCore(
    AVersion,
    AConfigRoot,
    AHomeDir,
    AAppDataDir
  );

  IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
  try
    Result := IDEConfig.SetCompilerPath(AFPCPath);
    Result := IDEConfig.SetLibraryPath(ASourcePath) and Result;
    {$IFDEF MSWINDOWS}
    Result := IDEConfig.SetMakePath('make.exe') and Result;
    {$ELSE}
    Result := IDEConfig.SetMakePath(UNIX_MAKE_PATH) and Result;
    {$ENDIF}
    Result := IDEConfig.ValidateConfig and Result;
  finally
    IDEConfig.Free;
  end;
end;

function ListLegacyLazarusLocalVersionsCore(
  const ASourceRoot: string;
  AIsValidSourceDirectory: TLazarusSourceRuntimeTreeValidator
): TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName: string;
  SourcePath: string;
  Index: Integer;
begin
  Result := nil;
  VersionList := TStringList.Create;
  try
    if FindFirst(ASourceRoot + PathDelim + 'lazarus-*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          DirName := SearchRec.Name;
          if Pos('lazarus-', DirName) = 1 then
          begin
            SourcePath := ASourceRoot + PathDelim + DirName;
            if Assigned(AIsValidSourceDirectory) and
               (not AIsValidSourceDirectory(SourcePath)) then
              Continue;
            VersionList.Add(Copy(DirName, 9, Length(DirName) - 8));
          end;
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;

    SetLength(Result, VersionList.Count);
    for Index := 0 to VersionList.Count - 1 do
      Result[Index] := VersionList[Index];
  finally
    VersionList.Free;
  end;
end;

function ExecuteLegacyLazarusBuildCore(
  const ASourcePath, AFPCPath: string;
  const AParallelJobs: Integer;
  AIsValidSourceDirectory: TLazarusSourceRuntimeTreeValidator;
  AExecuteCommand: TLazarusSourceRuntimeCommandExecutor;
  AWriteStatus: TLazarusSourceRuntimeStatusProc
): Boolean;
var
  MakeParams: TLazarusLegacySourceArgs;
begin
  Result := False;

  if (not Assigned(AIsValidSourceDirectory)) or
     (not Assigned(AExecuteCommand)) then
    Exit(False);

  if not AIsValidSourceDirectory(ASourcePath) then
  begin
    WriteStatusLine(AWriteStatus, 'Error: Invalid Lazarus source directory: ' + ASourcePath);
    WriteStatusLine(AWriteStatus, 'Please clone the source first.');
    Exit(False);
  end;

  WriteStatusLine(AWriteStatus, 'Building Lazarus...');
  WriteStatusLine(AWriteStatus, '  Source path: ' + ASourcePath);
  WriteStatusLine(AWriteStatus, '  Parallel jobs: ' + IntToStr(AParallelJobs));
  if AFPCPath <> '' then
    WriteStatusLine(AWriteStatus, '  FPC path: ' + AFPCPath);
  WriteStatusLine(AWriteStatus, '  Note: Build may take 10-30 minutes');
  WriteStatusLine(AWriteStatus, '');

  MakeParams := BuildLazarusLegacyMakeParamsCore(AParallelJobs, AFPCPath);
  Result := AExecuteCommand('make', MakeParams, ASourcePath);

  if Result then
    WriteStatusLine(AWriteStatus, 'Lazarus build successful.')
  else
    WriteStatusLine(AWriteStatus, 'Error: Lazarus build failed.');
end;

function ExecuteLegacyLazarusLaunchCore(
  const AExecutablePath: string;
  ALaunchExecutable: TLazarusSourceRuntimeLauncher;
  AWriteStatus: TLazarusSourceRuntimeStatusProc
): Boolean;
begin
  Result := False;

  if not FileExists(AExecutablePath) then
  begin
    WriteStatusLine(AWriteStatus, 'Error: Lazarus executable not found: ' + AExecutablePath);
    WriteStatusLine(AWriteStatus, 'Please build Lazarus first using BuildLazarus.');
    Exit(False);
  end;

  WriteStatusLine(AWriteStatus, 'Launching Lazarus: ' + AExecutablePath);

  if Assigned(ALaunchExecutable) then
    Result := ALaunchExecutable(AExecutablePath);

  if Result then
    WriteStatusLine(AWriteStatus, 'Lazarus launched successfully.')
  else
    WriteStatusLine(AWriteStatus, 'Error: Failed to launch Lazarus.');
end;

end.
