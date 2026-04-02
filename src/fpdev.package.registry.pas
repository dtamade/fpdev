unit fpdev.package.registry;

{$mode objfpc}{$H+}

(*
  Package Registry Module

  Provides functionality for managing a local package registry:
  - Initialize registry structure
  - Add/remove packages
  - Query package metadata
  - Search packages
  - Version management

  Registry Structure:
    <data-root>/registry/
    registry/
    +-- index.json          # Package index
    +-- config.json         # Registry configuration
    +-- packages/
        +-- packagename/
            +-- version/
                +-- packagename-version.tar.gz
                +-- packagename-version.tar.gz.sha256
                +-- package.json

  Usage:
    Registry := TPackageRegistry.Create(GetDataRoot + PathDelim + 'registry');
    if Registry.Initialize then
    begin
      Registry.AddPackage('mylib-1.0.0.tar.gz');
      if Registry.HasPackage('mylib') then
        WriteLn('Package found');
    end;
*)

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  { TPackageRegistry }
  TPackageRegistry = class
  private
    FRegistryPath: string;
    FIndex: TJSONObject;
    FLastError: string;

    function LoadIndex: Boolean;
    function SaveIndex: Boolean;
    function GetPackagePath(const AName, AVersion: string): string;
    function ExtractPackageInfo(const AArchivePath: string; out AName, AVersion: string): Boolean;
    function GetIndexPath: string;
    function GetConfigPath: string;
    function GetPackagesPath: string;

  public
    constructor Create(const ARegistryPath: string);
    destructor Destroy; override;

    { Initialize registry structure }
    function Initialize: Boolean;

    { Add package to registry }
    function AddPackage(const AArchivePath: string): Boolean;

    { Remove package from registry }
    function RemovePackage(const AName, AVersion: string): Boolean;

    { Get package metadata }
    function GetPackageMetadata(const AName: string): TJSONObject;

    { Get package versions }
    function GetPackageVersions(const AName: string): TStringList;

    { Check if package exists }
    function HasPackage(const AName: string): Boolean;
    function HasPackageVersion(const AName, AVersion: string): Boolean;

    { Get package archive path }
    function GetPackageArchive(const AName, AVersion: string): string;

    { List all packages }
    function ListPackages: TStringList;

    { Search packages }
    function SearchPackages(const AQuery: string): TStringList;

    { Get last error }
    function GetLastError: string;

    property RegistryPath: string read FRegistryPath;
  end;

implementation

{ TPackageRegistry }

constructor TPackageRegistry.Create(const ARegistryPath: string);
begin
  inherited Create;
  FRegistryPath := ExpandFileName(ARegistryPath);
  FIndex := nil;
  FLastError := '';
end;

destructor TPackageRegistry.Destroy;
begin
  if FIndex <> nil then
    FIndex.Free;
  inherited Destroy;
end;

function TPackageRegistry.GetIndexPath: string;
begin
  Result := FRegistryPath + PathDelim + 'index.json';
end;

function TPackageRegistry.GetConfigPath: string;
begin
  Result := FRegistryPath + PathDelim + 'config.json';
end;

function TPackageRegistry.GetPackagesPath: string;
begin
  Result := FRegistryPath + PathDelim + 'packages';
end;

function TPackageRegistry.GetPackagePath(const AName, AVersion: string): string;
begin
  Result := GetPackagesPath + PathDelim + AName + PathDelim + AVersion;
end;

function TPackageRegistry.LoadIndex: Boolean;
var
  IndexPath: string;
  J: TJSONData;
  FS: TFileStream;
begin
  Result := False;
  FLastError := '';

  IndexPath := GetIndexPath;
  if not FileExists(IndexPath) then
  begin
    FLastError := 'Index file not found: ' + IndexPath;
    Exit;
  end;

  try
    FS := TFileStream.Create(IndexPath, fmOpenRead or fmShareDenyWrite);
    try
      J := GetJSON(FS);
      if J is TJSONObject then
      begin
        if FIndex <> nil then
          FIndex.Free;
        FIndex := TJSONObject(J);
        Result := True;
      end
      else
      begin
        J.Free;
        FLastError := 'Index file is not a valid JSON object';
      end;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to load index: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageRegistry.SaveIndex: Boolean;
var
  IndexPath: string;
  FS: TFileStream;
  JSONStr: string;
begin
  Result := False;
  FLastError := '';

  if FIndex = nil then
  begin
    FLastError := 'Index not initialized';
    Exit;
  end;

  IndexPath := GetIndexPath;

  try
    JSONStr := FIndex.FormatJSON;
    FS := TFileStream.Create(IndexPath, fmCreate);
    try
      FS.WriteBuffer(JSONStr[1], Length(JSONStr));
      Result := True;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to save index: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageRegistry.Initialize: Boolean;
var
  ConfigPath: string;
  F: TextFile;
begin
  Result := False;
  FLastError := '';

  try
    // Create registry directory
    if not DirectoryExists(FRegistryPath) then
      ForceDirectories(FRegistryPath);

    // Create packages directory
    if not DirectoryExists(GetPackagesPath) then
      ForceDirectories(GetPackagesPath);

    // Create or load index
    if FileExists(GetIndexPath) then
    begin
      Result := LoadIndex;
    end
    else
    begin
      // Create new index
      if FIndex <> nil then
        FIndex.Free;
      FIndex := TJSONObject.Create;
      FIndex.Add('version', '1.0');
      FIndex.Add('packages', TJSONObject.Create);
      Result := SaveIndex;
    end;

    // Create config file if it doesn't exist
    ConfigPath := GetConfigPath;
    if not FileExists(ConfigPath) then
    begin
      AssignFile(F, ConfigPath);
      try
        Rewrite(F);
        WriteLn(F, '{');
        WriteLn(F, '  "version": "1.0",');
        WriteLn(F, '  "registry": {');
        WriteLn(F, '    "path": "' + FRegistryPath + '",');
        WriteLn(F, '    "type": "local"');
        WriteLn(F, '  }');
        WriteLn(F, '}');
      finally
        CloseFile(F);
      end;
    end;

  except
    on E: Exception do
    begin
      FLastError := 'Failed to initialize registry: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageRegistry.ExtractPackageInfo(const AArchivePath: string;
  out AName, AVersion: string): Boolean;
var
  FileName: string;
  DotPos, DashPos: Integer;
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
    Exit;

  // Find last dash to separate name and version
  DashPos := 0;
  for DotPos := Length(FileName) downto 1 do
  begin
    if FileName[DotPos] = '-' then
    begin
      DashPos := DotPos;
      Break;
    end;
  end;

  if DashPos = 0 then
    Exit;

  AName := Copy(FileName, 1, DashPos - 1);
  AVersion := Copy(FileName, DashPos + 1, Length(FileName));

  Result := (AName <> '') and (AVersion <> '');
end;

function TPackageRegistry.AddPackage(const AArchivePath: string): Boolean;
var
  Name, Version: string;
  PackagePath, MetadataPath: string;
  Packages: TJSONObject;
  PackageInfo: TJSONObject;
  Versions: TJSONArray;
  MetadataFile: TJSONData;
  FS: TFileStream;
begin
  Result := False;
  FLastError := '';

  // Check if archive exists
  if not FileExists(AArchivePath) then
  begin
    FLastError := 'Archive file not found: ' + AArchivePath;
    Exit;
  end;

  // Extract package name and version from archive filename
  if not ExtractPackageInfo(AArchivePath, Name, Version) then
  begin
    FLastError := 'Failed to extract package info from archive filename';
    Exit;
  end;

  // Check if version already exists
  if HasPackageVersion(Name, Version) then
  begin
    FLastError := 'Package version already exists: ' + Name + ' ' + Version;
    Exit;
  end;

  try
    // Create package directory
    PackagePath := GetPackagePath(Name, Version);
    if not DirectoryExists(PackagePath) then
      ForceDirectories(PackagePath);

    // Load package metadata from archive directory
    MetadataPath := PackagePath + PathDelim + 'package.json';
    if FileExists(MetadataPath) then
    begin
      FS := TFileStream.Create(MetadataPath, fmOpenRead or fmShareDenyWrite);
      try
        MetadataFile := GetJSON(FS);
      finally
        FS.Free;
      end;
    end
    else
    begin
      // Create minimal metadata
      MetadataFile := TJSONObject.Create;
      TJSONObject(MetadataFile).Add('name', Name);
      TJSONObject(MetadataFile).Add('version', Version);
    end;

    try
      // Update index
      Packages := FIndex.Objects['packages'];

      if Packages.Find(Name) = nil then
      begin
        // New package
        PackageInfo := TJSONObject.Create;
        PackageInfo.Add('name', Name);
        PackageInfo.Add('description', TJSONObject(MetadataFile).Get('description', 'No description'));
        PackageInfo.Add('author', TJSONObject(MetadataFile).Get('author', 'Unknown'));
        PackageInfo.Add('license', TJSONObject(MetadataFile).Get('license', 'Unknown'));

        Versions := TJSONArray.Create;
        Versions.Add(Version);
        PackageInfo.Add('versions', Versions);
        PackageInfo.Add('latest', Version);

        Packages.Add(Name, PackageInfo);
      end
      else
      begin
        // Existing package, add version
        PackageInfo := Packages.Objects[Name];
        Versions := PackageInfo.Arrays['versions'];
        Versions.Add(Version);
        PackageInfo.Strings['latest'] := Version;
      end;

      // Save index
      Result := SaveIndex;

    finally
      MetadataFile.Free;
    end;

  except
    on E: Exception do
    begin
      FLastError := 'Failed to add package: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageRegistry.RemovePackage(const AName, AVersion: string): Boolean;
var
  PackagePath: string;
  Packages: TJSONObject;
  PackageInfo: TJSONObject;
  Versions: TJSONArray;
  I: Integer;

  procedure DeleteDirectory(const ADir: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if FindFirst(ADir + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            FilePath := ADir + PathDelim + SR.Name;
            if (SR.Attr and faDirectory) <> 0 then
              DeleteDirectory(FilePath)
            else
              DeleteFile(FilePath);
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    RemoveDir(ADir);
  end;

begin
  Result := False;
  FLastError := '';

  if not HasPackageVersion(AName, AVersion) then
  begin
    FLastError := 'Package version not found: ' + AName + ' ' + AVersion;
    Exit;
  end;

  try
    // Delete package directory
    PackagePath := GetPackagePath(AName, AVersion);
    if DirectoryExists(PackagePath) then
      DeleteDirectory(PackagePath);

    // Update index
    Packages := FIndex.Objects['packages'];
    PackageInfo := Packages.Objects[AName];
    Versions := PackageInfo.Arrays['versions'];

    // Remove version from array
    for I := 0 to Versions.Count - 1 do
    begin
      if Versions.Strings[I] = AVersion then
      begin
        Versions.Delete(I);
        Break;
      end;
    end;

    // If no versions left, remove package
    if Versions.Count = 0 then
      Packages.Delete(Packages.IndexOfName(AName))
    else
      // Update latest version
      PackageInfo.Strings['latest'] := Versions.Strings[Versions.Count - 1];

    // Save index
    Result := SaveIndex;

  except
    on E: Exception do
    begin
      FLastError := 'Failed to remove package: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageRegistry.GetPackageMetadata(const AName: string): TJSONObject;
var
  Packages: TJSONObject;
begin
  Result := nil;

  if not HasPackage(AName) then
    Exit;

  Packages := FIndex.Objects['packages'];
  Result := TJSONObject(Packages.Objects[AName].Clone);
end;

function TPackageRegistry.GetPackageVersions(const AName: string): TStringList;
var
  Packages: TJSONObject;
  PackageInfo: TJSONObject;
  Versions: TJSONArray;
  I: Integer;
begin
  Result := TStringList.Create;

  if not HasPackage(AName) then
    Exit;

  Packages := FIndex.Objects['packages'];
  PackageInfo := Packages.Objects[AName];
  Versions := PackageInfo.Arrays['versions'];

  for I := 0 to Versions.Count - 1 do
    Result.Add(Versions.Strings[I]);
end;

function TPackageRegistry.HasPackage(const AName: string): Boolean;
var
  Packages: TJSONObject;
begin
  Result := False;

  if FIndex = nil then
    Exit;

  Packages := FIndex.Objects['packages'];
  Result := Packages.Find(AName) <> nil;
end;

function TPackageRegistry.HasPackageVersion(const AName, AVersion: string): Boolean;
var
  Versions: TStringList;
begin
  Result := False;

  Versions := GetPackageVersions(AName);
  try
    Result := Versions.IndexOf(AVersion) >= 0;
  finally
    Versions.Free;
  end;
end;

function TPackageRegistry.GetPackageArchive(const AName, AVersion: string): string;
var
  PackagePath: string;
begin
  Result := '';

  if not HasPackageVersion(AName, AVersion) then
    Exit;

  PackagePath := GetPackagePath(AName, AVersion);
  Result := PackagePath + PathDelim + AName + '-' + AVersion + '.tar.gz';

  if not FileExists(Result) then
    Result := '';
end;

function TPackageRegistry.ListPackages: TStringList;
var
  Packages: TJSONObject;
  I: Integer;
begin
  Result := TStringList.Create;

  if FIndex = nil then
    Exit;

  Packages := FIndex.Objects['packages'];
  for I := 0 to Packages.Count - 1 do
    Result.Add(Packages.Names[I]);
end;

function TPackageRegistry.SearchPackages(const AQuery: string): TStringList;
var
  Packages: TJSONObject;
  PackageInfo: TJSONObject;
  I: Integer;
  Name, Description: string;
  LowerQuery: string;
begin
  Result := TStringList.Create;

  if FIndex = nil then
    Exit;

  LowerQuery := LowerCase(AQuery);
  Packages := FIndex.Objects['packages'];

  for I := 0 to Packages.Count - 1 do
  begin
    Name := Packages.Names[I];
    PackageInfo := Packages.Objects[Name];
    Description := PackageInfo.Get('description', '');

    if (Pos(LowerQuery, LowerCase(Name)) > 0) or
       (Pos(LowerQuery, LowerCase(Description)) > 0) then
      Result.Add(Name);
  end;
end;

function TPackageRegistry.GetLastError: string;
begin
  Result := FLastError;
end;

end.
