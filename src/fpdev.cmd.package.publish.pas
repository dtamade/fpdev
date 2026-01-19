unit fpdev.cmd.package.publish;

{$mode objfpc}{$H+}

(*
  Package Publishing Command

  Provides functionality for publishing packages to a registry:
  - Validate package archives
  - Extract and validate metadata
  - Copy archives to registry
  - Update registry index
  - Support dry-run mode
  - Support force overwrite

  Usage:
    Publisher := TPackagePublishCommand.Create('~/.fpdev/registry');
    if Publisher.Publish('mylib-1.0.0.tar.gz') then
      WriteLn('Package published successfully')
    else
      WriteLn('Error: ', Publisher.GetLastError);
*)

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.package,
  fpdev.i18n, fpdev.i18n.strings, fpdev.package.registry, fpdev.utils.fs;

type
  { TPackagePublishCommand - Functional class for package publishing }
  TPackagePublishCommand = class
  private
    FRegistryPath: string;
    FRegistry: TPackageRegistry;
    FLastError: string;
    FDryRun: Boolean;
    FForcePub: Boolean;

    function ValidateArchive(const AArchivePath: string): Boolean;
    function ValidatePackageName(const AName: string): Boolean;
    function ValidateVersion(const AVersion: string): Boolean;
    function ExtractPackageInfo(const AArchivePath: string; out AName, AVersion: string): Boolean;
    function LoadMetadata(const AArchivePath: string): TJSONObject;
    function CopyFilesToRegistry(const AArchivePath, AName, AVersion: string): Boolean;

  public
    constructor Create(const ARegistryPath: string);
    destructor Destroy; override;

    { Publish package to registry }
    function Publish(const AArchivePath: string): Boolean;

    { Get last error message }
    function GetLastError: string;

    { Set dry-run mode (validate only, don't publish) }
    procedure SetDryRun(ADryRun: Boolean);

    { Set force mode (overwrite existing versions) }
    procedure SetForce(AForce: Boolean);

    property RegistryPath: string read FRegistryPath;
  end;

  { TPackagePublishCmd - Command interface implementation }
  TPackagePublishCmd = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

{ TPackagePublishCommand }

constructor TPackagePublishCommand.Create(const ARegistryPath: string);
begin
  inherited Create;
  FRegistryPath := ExpandFileName(ARegistryPath);
  FRegistry := TPackageRegistry.Create(FRegistryPath);
  FLastError := '';
  FDryRun := False;
  FForcePub := False;
end;

destructor TPackagePublishCommand.Destroy;
begin
  FRegistry.Free;
  inherited Destroy;
end;

function TPackagePublishCommand.ValidateArchive(const AArchivePath: string): Boolean;
begin
  Result := False;
  FLastError := '';

  if AArchivePath = '' then
  begin
    FLastError := 'Archive path is empty';
    Exit;
  end;

  if not FileExists(AArchivePath) then
  begin
    FLastError := 'Archive file not found: ' + AArchivePath;
    Exit;
  end;

  Result := True;
end;

function TPackagePublishCommand.ValidatePackageName(const AName: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  FLastError := '';

  if AName = '' then
  begin
    FLastError := 'Package name is empty';
    Exit;
  end;

  // Package name must contain only lowercase letters, numbers, hyphens, and underscores
  // Must not contain spaces
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if not (C in ['a'..'z', '0'..'9', '-', '_']) then
    begin
      FLastError := 'Invalid package name: ' + AName + ' (contains invalid character: ' + C + ')';
      Exit;
    end;
  end;

  Result := True;
end;

function TPackagePublishCommand.ValidateVersion(const AVersion: string): Boolean;
var
  Parts: TStringList;
  I: Integer;
  Num: Integer;
begin
  Result := False;
  FLastError := '';

  if AVersion = '' then
  begin
    FLastError := 'Version is empty';
    Exit;
  end;

  // Basic semantic version validation (major.minor.patch)
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '.';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := AVersion;

    if Parts.Count < 3 then
    begin
      FLastError := 'Invalid version format: ' + AVersion + ' (expected major.minor.patch)';
      Exit;
    end;

    // Check each part is numeric
    for I := 0 to Parts.Count - 1 do
    begin
      if not TryStrToInt(Parts[I], Num) then
      begin
        FLastError := 'Invalid version format: ' + AVersion + ' (non-numeric part: ' + Parts[I] + ')';
        Exit;
      end;
    end;

    Result := True;
  finally
    Parts.Free;
  end;
end;

function TPackagePublishCommand.ExtractPackageInfo(const AArchivePath: string;
  out AName, AVersion: string): Boolean;
var
  FileName: string;
  DashPos: Integer;
begin
  Result := False;
  AName := '';
  AVersion := '';

  // Extract filename from path
  FileName := ExtractFileName(AArchivePath);

  // Remove .tar.gz extension
  if Pos('.tar.gz', FileName) > 0 then
    FileName := Copy(FileName, 1, Pos('.tar.gz', FileName) - 1)
  else
  begin
    FLastError := 'Archive must have .tar.gz extension';
    Exit;
  end;

  // Find last dash to separate name and version
  DashPos := 0;
  for DashPos := Length(FileName) downto 1 do
  begin
    if FileName[DashPos] = '-' then
      Break;
  end;

  if DashPos = 0 then
  begin
    FLastError := 'Archive filename must be in format: name-version.tar.gz';
    Exit;
  end;

  AName := Copy(FileName, 1, DashPos - 1);
  AVersion := Copy(FileName, DashPos + 1, Length(FileName));

  Result := (AName <> '') and (AVersion <> '');
end;

function TPackagePublishCommand.LoadMetadata(const AArchivePath: string): TJSONObject;
var
  MetadataPath: string;
  FS: TFileStream;
  J: TJSONData;
  ArchiveDir: string;
  Name, Version: string;
begin
  Result := nil;
  FLastError := '';

  // Extract package info to find metadata
  if not ExtractPackageInfo(AArchivePath, Name, Version) then
    Exit;

  // Look for metadata in the same directory as archive
  ArchiveDir := ExtractFilePath(AArchivePath);
  MetadataPath := ArchiveDir + Name + PathDelim + 'package.json';

  if not FileExists(MetadataPath) then
  begin
    FLastError := 'Metadata file not found: ' + MetadataPath;
    Exit;
  end;

  try
    FS := TFileStream.Create(MetadataPath, fmOpenRead or fmShareDenyWrite);
    try
      J := GetJSON(FS);
      if J is TJSONObject then
        Result := TJSONObject(J)
      else
      begin
        J.Free;
        FLastError := 'Metadata file is not a valid JSON object';
      end;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to load metadata: ' + E.Message;
      Result := nil;
    end;
  end;
end;

function TPackagePublishCommand.CopyFilesToRegistry(const AArchivePath, AName, AVersion: string): Boolean;
var
  PackagePath: string;
  DestArchive, DestChecksum, DestMetadata: string;
  SrcChecksum, SrcMetadata: string;
  ArchiveDir: string;
begin
  Result := False;
  FLastError := '';

  try
    // Create package directory in registry
    PackagePath := FRegistryPath + PathDelim + 'packages' + PathDelim + AName + PathDelim + AVersion;
    if not DirectoryExists(PackagePath) then
      ForceDirectories(PackagePath);

    // Copy archive file
    DestArchive := PackagePath + PathDelim + AName + '-' + AVersion + '.tar.gz';
    if not CopyFileSafe(AArchivePath, DestArchive) then
    begin
      FLastError := 'Failed to copy archive to registry';
      Exit;
    end;

    // Copy checksum file if exists
    SrcChecksum := AArchivePath + '.sha256';
    if FileExists(SrcChecksum) then
    begin
      DestChecksum := DestArchive + '.sha256';
      if not CopyFileSafe(SrcChecksum, DestChecksum) then
      begin
        FLastError := 'Failed to copy checksum to registry';
        Exit;
      end;
    end;

    // Copy metadata file
    ArchiveDir := ExtractFilePath(AArchivePath);
    SrcMetadata := ArchiveDir + AName + PathDelim + 'package.json';
    if FileExists(SrcMetadata) then
    begin
      DestMetadata := PackagePath + PathDelim + 'package.json';
      if not CopyFileSafe(SrcMetadata, DestMetadata) then
      begin
        FLastError := 'Failed to copy metadata to registry';
        Exit;
      end;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to copy files to registry: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackagePublishCommand.Publish(const AArchivePath: string): Boolean;
var
  Name, Version: string;
  Metadata: TJSONObject;
begin
  Result := False;
  FLastError := '';

  // Validate archive
  if not ValidateArchive(AArchivePath) then
    Exit;

  // Extract package info
  if not ExtractPackageInfo(AArchivePath, Name, Version) then
    Exit;

  // Validate package name
  if not ValidatePackageName(Name) then
    Exit;

  // Validate version
  if not ValidateVersion(Version) then
    Exit;

  // Load and validate metadata
  Metadata := LoadMetadata(AArchivePath);
  if Metadata = nil then
    Exit;

  try
    // Initialize registry if needed
    if not FRegistry.Initialize then
    begin
      FLastError := 'Failed to initialize registry: ' + FRegistry.GetLastError;
      Exit;
    end;

    // Check for duplicate version (unless force mode)
    if not FForcePub and FRegistry.HasPackageVersion(Name, Version) then
    begin
      FLastError := 'Package version already exists: ' + Name + ' ' + Version;
      Exit;
    end;

    // If dry-run mode, stop here
    if FDryRun then
    begin
      Result := True;
      Exit;
    end;

    // If force mode and version exists, remove it first
    if FForcePub and FRegistry.HasPackageVersion(Name, Version) then
    begin
      if not FRegistry.RemovePackage(Name, Version) then
      begin
        FLastError := 'Failed to remove existing version: ' + FRegistry.GetLastError;
        Exit;
      end;
    end;

    // Copy files to registry
    if not CopyFilesToRegistry(AArchivePath, Name, Version) then
      Exit;

    // Add package to registry index
    if not FRegistry.AddPackage(AArchivePath) then
    begin
      FLastError := 'Failed to add package to registry: ' + FRegistry.GetLastError;
      Exit;
    end;

    Result := True;
  finally
    Metadata.Free;
  end;
end;

function TPackagePublishCommand.GetLastError: string;
begin
  Result := FLastError;
end;

procedure TPackagePublishCommand.SetDryRun(ADryRun: Boolean);
begin
  FDryRun := ADryRun;
end;

procedure TPackagePublishCommand.SetForce(AForce: Boolean);
begin
  FForcePub := AForce;
end;

{ TPackagePublishCmd }

function TPackagePublishCmd.Name: string; begin Result := 'publish'; end;
function TPackagePublishCmd.Aliases: TStringArray; begin Result := nil; end;
function TPackagePublishCmd.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackagePublishFactory: ICommand;
begin
  Result := TPackagePublishCmd.Create;
end;

function TPackagePublishCmd.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  Pkg: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    Ctx.Err.WriteLn(_(HELP_PACKAGE_PUBLISH_USAGE));
    Exit(2);
  end;
  Pkg := AParams[0];

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LMgr.PublishPackage(Pkg, Ctx.Out, Ctx.Err) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','publish'], @PackagePublishFactory, []);

end.
