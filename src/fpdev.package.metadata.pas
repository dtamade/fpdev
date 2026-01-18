unit fpdev.package.metadata;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, fgl;

type
  { TDependencyMap - Map of package name to version constraint }
  TDependencyMap = specialize TFPGMap<string, string>;

  { TPackageMetadata - Package metadata structure }
  TPackageMetadata = class
  private
    FName: string;
    FVersion: string;
    FDescription: string;
    FAuthor: string;
    FLicense: string;
    FDependencies: TDependencyMap;
    FOptionalDependencies: TDependencyMap;
    FFPCMinVersion: string;
    FFPCMaxVersion: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property Description: string read FDescription write FDescription;
    property Author: string read FAuthor write FAuthor;
    property License: string read FLicense write FLicense;
    property Dependencies: TDependencyMap read FDependencies;
    property OptionalDependencies: TDependencyMap read FOptionalDependencies;
    property FPCMinVersion: string read FFPCMinVersion write FFPCMinVersion;
    property FPCMaxVersion: string read FFPCMaxVersion write FFPCMaxVersion;
  end;

  { Package metadata functions }
  function LoadMetadata(const AFilePath: string): TPackageMetadata;
  function ValidateMetadata(const AMeta: TPackageMetadata): Boolean;
  procedure ParseDependencies(const AJson: TJSONObject; ADeps: TDependencyMap);

implementation

{ TPackageMetadata }

constructor TPackageMetadata.Create;
begin
  inherited Create;
  FDependencies := TDependencyMap.Create;
  FOptionalDependencies := TDependencyMap.Create;
  FName := '';
  FVersion := '';
  FDescription := '';
  FAuthor := '';
  FLicense := '';
  FFPCMinVersion := '';
  FFPCMaxVersion := '';
end;

destructor TPackageMetadata.Destroy;
begin
  FDependencies.Free;
  FOptionalDependencies.Free;
  inherited Destroy;
end;

{ ParseDependencies - Parse dependencies from JSON object }
procedure ParseDependencies(const AJson: TJSONObject; ADeps: TDependencyMap);
var
  I: Integer;
  Key: string;
  Value: TJSONData;
begin
  if AJson = nil then
    Exit;

  ADeps.Clear;

  for I := 0 to AJson.Count - 1 do
  begin
    Key := AJson.Names[I];
    Value := AJson.Items[I];

    if Value.JSONType = jtString then
      ADeps.Add(Key, Value.AsString);
  end;
end;

{ LoadMetadata - Load package metadata from JSON file }
function LoadMetadata(const AFilePath: string): TPackageMetadata;
var
  JSONData: TJSONData;
  JSONObj: TJSONObject;
  DepsObj: TJSONObject;
  OptDepsObj: TJSONObject;
  FPCObj: TJSONObject;
  FileContent: string;
  SL: TStringList;
begin
  Result := TPackageMetadata.Create;

  try
    // Read file content
    if not FileExists(AFilePath) then
      raise Exception.CreateFmt('Package metadata file not found: %s', [AFilePath]);

    // Use TStringList for efficient file reading
    SL := TStringList.Create;
    try
      SL.LoadFromFile(AFilePath);
      FileContent := SL.Text;
    finally
      SL.Free;
    end;

    // Parse JSON
    try
      JSONData := GetJSON(FileContent);
    except
      on E: Exception do
        raise Exception.CreateFmt('Invalid JSON in package metadata: %s', [E.Message]);
    end;

    try
      if JSONData.JSONType <> jtObject then
        raise Exception.Create('Package metadata must be a JSON object');

      JSONObj := TJSONObject(JSONData);

      // Parse basic fields
      if JSONObj.IndexOfName('name') >= 0 then
        Result.Name := JSONObj.Get('name', '');

      if JSONObj.IndexOfName('version') >= 0 then
        Result.Version := JSONObj.Get('version', '');

      if JSONObj.IndexOfName('description') >= 0 then
        Result.Description := JSONObj.Get('description', '');

      if JSONObj.IndexOfName('author') >= 0 then
        Result.Author := JSONObj.Get('author', '');

      if JSONObj.IndexOfName('license') >= 0 then
        Result.License := JSONObj.Get('license', '');

      // Parse dependencies
      if JSONObj.IndexOfName('dependencies') >= 0 then
      begin
        DepsObj := JSONObj.Objects['dependencies'];
        if DepsObj <> nil then
          ParseDependencies(DepsObj, Result.Dependencies);
      end;

      // Parse optional dependencies
      if JSONObj.IndexOfName('optionalDependencies') >= 0 then
      begin
        OptDepsObj := JSONObj.Objects['optionalDependencies'];
        if OptDepsObj <> nil then
          ParseDependencies(OptDepsObj, Result.OptionalDependencies);
      end;

      // Parse FPC version constraints
      if JSONObj.IndexOfName('fpc') >= 0 then
      begin
        FPCObj := JSONObj.Objects['fpc'];
        if FPCObj <> nil then
        begin
          if FPCObj.IndexOfName('minVersion') >= 0 then
            Result.FPCMinVersion := FPCObj.Get('minVersion', '');

          if FPCObj.IndexOfName('maxVersion') >= 0 then
            Result.FPCMaxVersion := FPCObj.Get('maxVersion', '');
        end;
      end;

    finally
      JSONData.Free;
    end;

  except
    on E: Exception do
    begin
      Result.Free;
      raise;
    end;
  end;
end;

{ ValidateMetadata - Validate package metadata }
function ValidateMetadata(const AMeta: TPackageMetadata): Boolean;
begin
  Result := False;

  // Check required fields
  if AMeta.Name = '' then
    raise Exception.Create('Package name is required');

  if AMeta.Version = '' then
    raise Exception.Create('Package version is required');

  Result := True;
end;

end.
