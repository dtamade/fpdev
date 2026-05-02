unit fpdev.lazarus.config;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.utils.fs;

type
  { TLazarusIDEConfig }
  TLazarusIDEConfig = class
  private
    FConfigDir: string;
    FEnvOptionsPath: string;
    FEditorOptionsPath: string;

    function EnsureConfigDir: Boolean;

  public
    constructor Create(const AConfigDir: string);
    destructor Destroy; override;

    // Compiler configuration
    function SetCompilerPath(const AFPCPath: string): Boolean;
    function GetCompilerPath: string;

    // Library paths
    function SetLibraryPath(const APath: string): Boolean;
    function GetLibraryPath: string;
    function AddLibrarySearchPath(const APath: string): Boolean;

    // FPC source path
    function SetFPCSourcePath(const APath: string): Boolean;
    function GetFPCSourcePath: string;

    // Make path
    function SetMakePath(const APath: string): Boolean;
    function GetMakePath: string;

    // Debugger path
    function SetDebuggerPath(const APath: string): Boolean;
    function GetDebuggerPath: string;

    // Target configuration
    function SetTargetOS(const AOS: string): Boolean;
    function SetTargetCPU(const ACPU: string): Boolean;
    function GetTargetOS: string;
    function GetTargetCPU: string;

    // Import/Export
    function ExportConfig(const AExportPath: string): Boolean;
    function ImportConfig(const AImportPath: string): Boolean;

    // Backup/Restore
    function BackupConfig: string;  // Returns backup path or empty on failure
    function RestoreConfig(const ABackupPath: string): Boolean;

    // Utility
    function ValidateConfig: Boolean;
    function GetConfigSummary: string;

    property ConfigDir: string read FConfigDir;
  end;

implementation

uses
  fpdev.lazarus.config.envoptionsflow;

{ TLazarusIDEConfig }

constructor TLazarusIDEConfig.Create(const AConfigDir: string);
begin
  inherited Create;
  FConfigDir := AConfigDir;
  FEnvOptionsPath := FConfigDir + PathDelim + 'environmentoptions.xml';
  FEditorOptionsPath := FConfigDir + PathDelim + 'editoroptions.xml';
end;

destructor TLazarusIDEConfig.Destroy;
begin
  inherited Destroy;
end;

function TLazarusIDEConfig.EnsureConfigDir: Boolean;
begin
  Result := DirectoryExists(FConfigDir);
  if not Result then
    Result := EnsureDir(FConfigDir);
end;

function TLazarusIDEConfig.SetCompilerPath(const AFPCPath: string): Boolean;
begin
  if not EnsureConfigDir then
    Exit(False);

  Result := SetLazarusEnvOptionValueCore(
    FEnvOptionsPath,
    'CompilerFilename',
    AFPCPath
  );
end;

function TLazarusIDEConfig.GetCompilerPath: string;
begin
  Result := GetLazarusEnvOptionValueCore(FEnvOptionsPath, 'CompilerFilename');
end;

function TLazarusIDEConfig.SetLibraryPath(const APath: string): Boolean;
begin
  if not EnsureConfigDir then
    Exit(False);

  Result := SetLazarusEnvOptionValueCore(
    FEnvOptionsPath,
    'LazarusDirectory',
    APath
  );
end;

function TLazarusIDEConfig.GetLibraryPath: string;
begin
  Result := GetLazarusEnvOptionValueCore(FEnvOptionsPath, 'LazarusDirectory');
end;

function TLazarusIDEConfig.AddLibrarySearchPath(const APath: string): Boolean;
var
  CurrentPath: string;
begin
  CurrentPath := GetLibraryPath;
  if CurrentPath <> '' then
    Result := SetLibraryPath(CurrentPath + PathSeparator + APath)
  else
    Result := SetLibraryPath(APath);
end;

function TLazarusIDEConfig.SetFPCSourcePath(const APath: string): Boolean;
begin
  if not EnsureConfigDir then
    Exit(False);

  Result := SetLazarusEnvOptionValueCore(
    FEnvOptionsPath,
    'FPCSourceDirectory',
    APath
  );
end;

function TLazarusIDEConfig.GetFPCSourcePath: string;
begin
  Result := GetLazarusEnvOptionValueCore(FEnvOptionsPath, 'FPCSourceDirectory');
end;

function TLazarusIDEConfig.SetMakePath(const APath: string): Boolean;
begin
  if not EnsureConfigDir then
    Exit(False);

  Result := SetLazarusEnvOptionValueCore(
    FEnvOptionsPath,
    'MakeFilename',
    APath
  );
end;

function TLazarusIDEConfig.GetMakePath: string;
begin
  Result := GetLazarusEnvOptionValueCore(FEnvOptionsPath, 'MakeFilename');
end;

function TLazarusIDEConfig.SetDebuggerPath(const APath: string): Boolean;
begin
  if not EnsureConfigDir then
    Exit(False);

  Result := SetLazarusEnvOptionValueCore(
    FEnvOptionsPath,
    'DebuggerFilename',
    APath
  );
end;

function TLazarusIDEConfig.GetDebuggerPath: string;
begin
  Result := GetLazarusEnvOptionValueCore(FEnvOptionsPath, 'DebuggerFilename');
end;

function TLazarusIDEConfig.SetTargetOS(const AOS: string): Boolean;
begin
  if not EnsureConfigDir then
    Exit(False);

  Result := SetLazarusEnvOptionValueCore(
    FEnvOptionsPath,
    'TargetOS',
    AOS
  );
end;

function TLazarusIDEConfig.SetTargetCPU(const ACPU: string): Boolean;
begin
  if not EnsureConfigDir then
    Exit(False);

  Result := SetLazarusEnvOptionValueCore(
    FEnvOptionsPath,
    'TargetCPU',
    ACPU
  );
end;

function TLazarusIDEConfig.GetTargetOS: string;
begin
  Result := GetLazarusEnvOptionValueCore(FEnvOptionsPath, 'TargetOS');
end;

function TLazarusIDEConfig.GetTargetCPU: string;
begin
  Result := GetLazarusEnvOptionValueCore(FEnvOptionsPath, 'TargetCPU');
end;

function TLazarusIDEConfig.ExportConfig(const AExportPath: string): Boolean;
var
  SrcFiles: array[0..1] of string;
  DstFiles: array[0..1] of string;
  i: Integer;
  SrcStream, DstStream: TFileStream;
begin
  Result := False;

  SrcFiles[0] := FEnvOptionsPath;
  SrcFiles[1] := FEditorOptionsPath;
  DstFiles[0] := AExportPath + PathDelim + 'environmentoptions.xml';
  DstFiles[1] := AExportPath + PathDelim + 'editoroptions.xml';

  if not DirectoryExists(AExportPath) then
    if not EnsureDir(AExportPath) then
      Exit;

  try
    for i := 0 to High(SrcFiles) do
    begin
      if FileExists(SrcFiles[i]) then
      begin
        SrcStream := TFileStream.Create(SrcFiles[i], fmOpenRead or fmShareDenyWrite);
        try
          DstStream := TFileStream.Create(DstFiles[i], fmCreate);
          try
            DstStream.CopyFrom(SrcStream, SrcStream.Size);
          finally
            DstStream.Free;
          end;
        finally
          SrcStream.Free;
        end;
      end;
    end;
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TLazarusIDEConfig.ImportConfig(const AImportPath: string): Boolean;
var
  SrcFiles: array[0..1] of string;
  DstFiles: array[0..1] of string;
  i: Integer;
  SrcStream, DstStream: TFileStream;
begin
  Result := False;

  if not EnsureConfigDir then
    Exit;

  SrcFiles[0] := AImportPath + PathDelim + 'environmentoptions.xml';
  SrcFiles[1] := AImportPath + PathDelim + 'editoroptions.xml';
  DstFiles[0] := FEnvOptionsPath;
  DstFiles[1] := FEditorOptionsPath;

  try
    for i := 0 to High(SrcFiles) do
    begin
      if FileExists(SrcFiles[i]) then
      begin
        SrcStream := TFileStream.Create(SrcFiles[i], fmOpenRead or fmShareDenyWrite);
        try
          DstStream := TFileStream.Create(DstFiles[i], fmCreate);
          try
            DstStream.CopyFrom(SrcStream, SrcStream.Size);
          finally
            DstStream.Free;
          end;
        finally
          SrcStream.Free;
        end;
      end;
    end;
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TLazarusIDEConfig.BackupConfig: string;
var
  BackupDir: string;
  Timestamp: string;
begin
  Result := '';

  // Only backup if config file exists
  if not FileExists(FEnvOptionsPath) then
    Exit;

  try
    // Create backup directory
    BackupDir := FConfigDir + PathDelim + 'backups';
    if not DirectoryExists(BackupDir) then
      if not EnsureDir(BackupDir) then
        Exit;

    // Generate timestamp-based backup name
    Timestamp := FormatDateTime('yyyymmdd_hhnnss', Now);

    // Copy config file to backup
    if ExportConfig(BackupDir + PathDelim + Timestamp) then
      Result := BackupDir + PathDelim + Timestamp;

  except
    on E: Exception do
      Result := '';
  end;
end;

function TLazarusIDEConfig.RestoreConfig(const ABackupPath: string): Boolean;
begin
  Result := False;

  if not DirectoryExists(ABackupPath) then
    Exit;

  Result := ImportConfig(ABackupPath);
end;

function TLazarusIDEConfig.ValidateConfig: Boolean;
var
  CompilerPath, LazarusPath: string;
begin
  Result := False;

  // Check if config file exists
  if not FileExists(FEnvOptionsPath) then
    Exit;

  // Check if compiler path is set and exists
  CompilerPath := GetCompilerPath;
  if (CompilerPath = '') or (not FileExists(CompilerPath)) then
    Exit;

  // Check if Lazarus directory is set and exists
  LazarusPath := GetLibraryPath;
  if (LazarusPath = '') or (not DirectoryExists(LazarusPath)) then
    Exit;

  Result := True;
end;

function TLazarusIDEConfig.GetConfigSummary: string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('Lazarus IDE Configuration');
    SL.Add('------------------------');
    SL.Add('Config directory: ' + FConfigDir);
    SL.Add('Compiler path: ' + GetCompilerPath);
    SL.Add('Lazarus directory: ' + GetLibraryPath);
    SL.Add('FPC source path: ' + GetFPCSourcePath);
    SL.Add('Make path: ' + GetMakePath);
    SL.Add('Debugger path: ' + GetDebuggerPath);
    SL.Add('Target OS: ' + GetTargetOS);
    SL.Add('Target CPU: ' + GetTargetCPU);
    SL.Add('');
    if ValidateConfig then
      SL.Add('Status: Valid')
    else
      SL.Add('Status: Invalid or incomplete');
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

end.
