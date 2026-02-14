unit fpdev.package.lockfile;

{$mode objfpc}{$H+}

(*
  Package Lock File Management

  Provides functionality for managing package lock files (fpdev-lock.json):
  - Generate lock files from resolved dependencies
  - Parse and validate existing lock files
  - Compare lock files for changes
  - Ensure reproducible builds

  Lock File Format (inspired by npm package-lock.json):
  {
    "name": "myproject",
    "version": "1.0.0",
    "lockfileVersion": 1,
    "packages": {
      "": {
        "name": "myproject",
        "version": "1.0.0",
        "dependencies": {
          "libfoo": ">=1.2.0"
        }
      },
      "libfoo": {
        "version": "1.2.3",
        "resolved": "~/.fpdev/registry/packages/libfoo/1.2.3/libfoo-1.2.3.tar.gz",
        "integrity": "sha256-...",
        "dependencies": {
          "libbar": ">=2.0.0"
        }
      },
      "libbar": {
        "version": "2.1.0",
        "resolved": "~/.fpdev/registry/packages/libbar/2.1.0/libbar-2.1.0.tar.gz",
        "integrity": "sha256-..."
      }
    }
  }

  Usage:
    LockFile := TPackageLockFile.Create('fpdev-lock.json');
    try
      if LockFile.Load then
        WriteLn('Lock file loaded successfully')
      else
        WriteLn('Error: ', LockFile.GetLastError);
    finally
      LockFile.Free;
    end;
*)

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

const
  LOCKFILE_VERSION = 1;
  LOCKFILE_NAME = 'fpdev-lock.json';

type
  { TPackageLockEntry - Single package entry in lock file }
  TPackageLockEntry = class
  public
    Name: string;
    Version: string;
    Resolved: string;  // Path to package archive
    Integrity: string; // SHA256 checksum
    Dependencies: TStringList;  // Package name -> version constraint

    constructor Create;
    destructor Destroy; override;
  end;

  { TPackageLockFile - Package lock file manager }
  TPackageLockFile = class
  private
    FLockFilePath: string;
    FProjectName: string;
    FProjectVersion: string;
    FPackages: TStringList;  // Package name -> TPackageLockEntry
    FLastError: string;

    function GetPackageEntry(const AName: string): TPackageLockEntry;
    procedure SetPackageEntry(const AName: string; const AEntry: TPackageLockEntry);
    function SerializeEntry(const AEntry: TPackageLockEntry): TJSONObject;
    function DeserializeEntry(const AObj: TJSONObject): TPackageLockEntry;

  public
    constructor Create(const ALockFilePath: string);
    destructor Destroy; override;

    { Load lock file from disk }
    function Load: Boolean;

    { Save lock file to disk }
    function Save: Boolean;

    { Add package entry to lock file }
    procedure AddPackage(const AName, AVersion, AResolved, AIntegrity: string;
      const ADependencies: TStringList);

    { Get package version from lock file }
    function GetPackageVersion(const AName: string): string;

    { Check if package exists in lock file }
    function HasPackage(const AName: string): Boolean;

    { Get all package names }
    function GetPackageNames: TStringList;

    { Clear all packages }
    procedure Clear;

    { Get last error message }
    function GetLastError: string;

    { Set project metadata }
    procedure SetProjectInfo(const AName, AVersion: string);

    { Get project name }
    property ProjectName: string read FProjectName;

    { Get project version }
    property ProjectVersion: string read FProjectVersion;

    { Get lock file path }
    property LockFilePath: string read FLockFilePath;
  end;

implementation

uses
  fpdev.utils;

{ TPackageLockEntry }

constructor TPackageLockEntry.Create;
begin
  inherited Create;
  Dependencies := TStringList.Create;
end;

destructor TPackageLockEntry.Destroy;
begin
  Dependencies.Free;
  inherited Destroy;
end;

{ TPackageLockFile }

constructor TPackageLockFile.Create(const ALockFilePath: string);
begin
  inherited Create;
  FLockFilePath := ALockFilePath;
  FPackages := TStringList.Create;
  FPackages.Sorted := True;
  FPackages.Duplicates := dupIgnore;
  FProjectName := '';
  FProjectVersion := '';
  FLastError := '';
end;

destructor TPackageLockFile.Destroy;
var
  i: Integer;
begin
  // Free all entries
  for i := 0 to FPackages.Count - 1 do
    FPackages.Objects[i].Free;
  FPackages.Free;
  inherited Destroy;
end;

function TPackageLockFile.GetPackageEntry(const AName: string): TPackageLockEntry;
var
  Index: Integer;
begin
  Result := nil;
  Index := FPackages.IndexOf(AName);
  if Index >= 0 then
    Result := TPackageLockEntry(FPackages.Objects[Index]);
end;

procedure TPackageLockFile.SetPackageEntry(const AName: string; const AEntry: TPackageLockEntry);
var
  Index: Integer;
begin
  Index := FPackages.IndexOf(AName);
  if Index >= 0 then
  begin
    // Free old entry
    FPackages.Objects[Index].Free;
    FPackages.Objects[Index] := AEntry;
  end
  else
    FPackages.AddObject(AName, AEntry);
end;

function TPackageLockFile.SerializeEntry(const AEntry: TPackageLockEntry): TJSONObject;
var
  DepsObj: TJSONObject;
  i: Integer;
begin
  Result := TJSONObject.Create;
  if not Assigned(AEntry) then Exit;

  Result.Add('version', AEntry.Version);
  Result.Add('resolved', AEntry.Resolved);
  Result.Add('integrity', AEntry.Integrity);

  if Assigned(AEntry.Dependencies) and (AEntry.Dependencies.Count > 0) then
  begin
    DepsObj := TJSONObject.Create;
    for i := 0 to AEntry.Dependencies.Count - 1 do
      DepsObj.Add(AEntry.Dependencies.Names[i], AEntry.Dependencies.ValueFromIndex[i]);
    Result.Add('dependencies', DepsObj);
  end;
end;

function TPackageLockFile.DeserializeEntry(const AObj: TJSONObject): TPackageLockEntry;
var
  DepsObj: TJSONObject;
  i: Integer;
  Key: string;
begin
  Result := TPackageLockEntry.Create;
  Result.Version := AObj.Get('version', '');
  Result.Resolved := AObj.Get('resolved', '');
  Result.Integrity := AObj.Get('integrity', '');

  if AObj.Find('dependencies', DepsObj) then
  begin
    for i := 0 to DepsObj.Count - 1 do
    begin
      Key := DepsObj.Names[i];
      Result.Dependencies.Add(Key + '=' + DepsObj.Get(Key, ''));
    end;
  end;
end;

function TPackageLockFile.Load: Boolean;
var
  JSONStr: string;
  JSONData: TJSONData;
  RootObj, PackagesObj, PkgObj: TJSONObject;
  i: Integer;
  PkgName: string;
  Entry: TPackageLockEntry;
begin
  Result := False;
  FLastError := '';

  if not FileExists(FLockFilePath) then
  begin
    FLastError := 'Lock file not found: ' + FLockFilePath;
    Exit;
  end;

  try
    // Read JSON file
    with TStringList.Create do
    try
      LoadFromFile(FLockFilePath);
      JSONStr := Text;
    finally
      Free;
    end;

    // Parse JSON
    JSONData := GetJSON(JSONStr);
    try
      if not (JSONData is TJSONObject) then
      begin
        FLastError := 'Invalid lock file format: root must be object';
        Exit;
      end;

      RootObj := TJSONObject(JSONData);

      // Read project metadata
      FProjectName := RootObj.Get('name', '');
      FProjectVersion := RootObj.Get('version', '');

      // Read packages
      if not RootObj.Find('packages', PackagesObj) then
      begin
        FLastError := 'Invalid lock file format: missing packages field';
        Exit;
      end;

      Clear;
      for i := 0 to PackagesObj.Count - 1 do
      begin
        PkgName := PackagesObj.Names[i];
        if PkgName = '' then Continue;  // Skip root entry

        PkgObj := PackagesObj.Objects[PkgName];
        Entry := DeserializeEntry(PkgObj);
        Entry.Name := PkgName;
        SetPackageEntry(PkgName, Entry);
      end;

      Result := True;
    finally
      JSONData.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to load lock file: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TPackageLockFile.Save: Boolean;
var
  RootObj, PackagesObj, RootPkgObj: TJSONObject;
  i: Integer;
  PkgName: string;
  Entry: TPackageLockEntry;
  JSONStr: string;
begin
  Result := False;
  FLastError := '';

  try
    RootObj := TJSONObject.Create;
    try
      // Add project metadata
      RootObj.Add('name', FProjectName);
      RootObj.Add('version', FProjectVersion);
      RootObj.Add('lockfileVersion', LOCKFILE_VERSION);

      // Add packages
      PackagesObj := TJSONObject.Create;

      // Add root package entry
      RootPkgObj := TJSONObject.Create;
      RootPkgObj.Add('name', FProjectName);
      RootPkgObj.Add('version', FProjectVersion);
      PackagesObj.Add('', RootPkgObj);

      // Add all packages
      for i := 0 to FPackages.Count - 1 do
      begin
        PkgName := FPackages[i];
        Entry := GetPackageEntry(PkgName);
        PackagesObj.Add(PkgName, SerializeEntry(Entry));
      end;

      RootObj.Add('packages', PackagesObj);

      // Write to file
      JSONStr := RootObj.FormatJSON;
      with TStringList.Create do
      try
        Text := JSONStr;
        SaveToFile(FLockFilePath);
      finally
        Free;
      end;

      Result := True;
    finally
      RootObj.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to save lock file: ' + E.Message;
      Result := False;
    end;
  end;
end;

procedure TPackageLockFile.AddPackage(const AName, AVersion, AResolved, AIntegrity: string;
  const ADependencies: TStringList);
var
  Entry: TPackageLockEntry;
begin
  Entry := TPackageLockEntry.Create;
  Entry.Name := AName;
  Entry.Version := AVersion;
  Entry.Resolved := AResolved;
  Entry.Integrity := AIntegrity;

  if Assigned(ADependencies) then
    Entry.Dependencies.Assign(ADependencies);

  SetPackageEntry(AName, Entry);
end;

function TPackageLockFile.GetPackageVersion(const AName: string): string;
var
  Entry: TPackageLockEntry;
begin
  Result := '';
  Entry := GetPackageEntry(AName);
  if Assigned(Entry) then
    Result := Entry.Version;
end;

function TPackageLockFile.HasPackage(const AName: string): Boolean;
begin
  Result := FPackages.IndexOf(AName) >= 0;
end;

function TPackageLockFile.GetPackageNames: TStringList;
begin
  Result := TStringList.Create;
  Result.Assign(FPackages);
end;

procedure TPackageLockFile.Clear;
var
  i: Integer;
begin
  // Free all entries
  for i := 0 to FPackages.Count - 1 do
    FPackages.Objects[i].Free;
  FPackages.Clear;
end;

function TPackageLockFile.GetLastError: string;
begin
  Result := FLastError;
end;

procedure TPackageLockFile.SetProjectInfo(const AName, AVersion: string);
begin
  FProjectName := AName;
  FProjectVersion := AVersion;
end;

end.
