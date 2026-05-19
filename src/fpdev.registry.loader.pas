unit fpdev.registry.loader;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson;

type
  TRegistrySource = (rsRegistry, rsOverrides, rsFallback);

  TRegistryLoader = class
  private
    FRegistryPath: string;
    FOverridesPath: string;
    FActiveSource: TRegistrySource;
    function GetRegistryDir: string;
    function GetOverridesFile: string;
    function LoadJSONFile(const APath: string): TJSONData;
    function MergeObjects(const ABase, AOverride: TJSONObject): TJSONObject;
  public
    constructor Create(const ADataRoot: string);

    function LoadFile(const ARelativePath: string): TJSONData;
    function LoadSources: TJSONObject;
    function LoadFPCVersions: TJSONObject;
    function LoadFPCBinary: TJSONObject;
    function LoadLazarusVersions: TJSONObject;
    function LoadCrossTargets: TJSONObject;
    function LoadBootstrapCompilers: TJSONObject;
    function LoadPackageIndex: TJSONArray;
    function LoadBuildSteps(const AName: string): TJSONObject;

    function RegistryExists: Boolean;
    property ActiveSource: TRegistrySource read FActiveSource;
    property RegistryDir: string read GetRegistryDir;
  end;

implementation

uses
  jsonparser, fpdev.paths;

constructor TRegistryLoader.Create(const ADataRoot: string);
begin
  inherited Create;
  FRegistryPath := IncludeTrailingPathDelimiter(ADataRoot) + 'registry';
  FOverridesPath := IncludeTrailingPathDelimiter(ADataRoot) + 'overrides.json';
  if DirectoryExists(FRegistryPath) then
    FActiveSource := rsRegistry
  else
    FActiveSource := rsFallback;
end;

function TRegistryLoader.GetRegistryDir: string;
begin
  Result := FRegistryPath;
end;

function TRegistryLoader.GetOverridesFile: string;
begin
  Result := FOverridesPath;
end;

function TRegistryLoader.RegistryExists: Boolean;
begin
  Result := DirectoryExists(FRegistryPath);
end;

function TRegistryLoader.LoadJSONFile(const APath: string): TJSONData;
var
  SL: TStringList;
begin
  Result := nil;
  if not FileExists(APath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    try
      Result := GetJSON(SL.Text);
    except
      Result := nil;
    end;
  finally
    SL.Free;
  end;
end;

function TRegistryLoader.MergeObjects(const ABase, AOverride: TJSONObject): TJSONObject;
var
  I: Integer;
  Key: string;
  BaseVal, OverVal: TJSONData;
begin
  Result := ABase.Clone as TJSONObject;

  for I := 0 to AOverride.Count - 1 do
  begin
    Key := AOverride.Names[I];
    OverVal := AOverride.Items[I];

    if OverVal.JSONType = jtNull then
    begin
      Result.Delete(Key);
      Continue;
    end;

    BaseVal := Result.Find(Key);
    if (BaseVal <> nil) and (BaseVal.JSONType = jtObject) and
       (OverVal.JSONType = jtObject) then
      Result.Objects[Key] := MergeObjects(TJSONObject(BaseVal), TJSONObject(OverVal))
    else
    begin
      if BaseVal <> nil then
        Result.Delete(Key);
      Result.Add(Key, OverVal.Clone);
    end;
  end;
end;

function TRegistryLoader.LoadFile(const ARelativePath: string): TJSONData;
var
  FullPath: string;
begin
  FullPath := IncludeTrailingPathDelimiter(FRegistryPath) + ARelativePath;
  Result := LoadJSONFile(FullPath);
  if Result <> nil then
    FActiveSource := rsRegistry;
end;

function TRegistryLoader.LoadSources: TJSONObject;
var
  Data: TJSONData;
begin
  Data := LoadFile('sources.json');
  if (Data <> nil) and (Data.JSONType = jtObject) then
    Result := TJSONObject(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

function TRegistryLoader.LoadFPCVersions: TJSONObject;
var
  Data: TJSONData;
begin
  Data := LoadFile('fpc' + PathDelim + 'versions.json');
  if (Data <> nil) and (Data.JSONType = jtObject) then
    Result := TJSONObject(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

function TRegistryLoader.LoadFPCBinary: TJSONObject;
var
  Data: TJSONData;
begin
  Data := LoadFile('fpc' + PathDelim + 'binary.json');
  if (Data <> nil) and (Data.JSONType = jtObject) then
    Result := TJSONObject(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

function TRegistryLoader.LoadLazarusVersions: TJSONObject;
var
  Data: TJSONData;
begin
  Data := LoadFile('lazarus' + PathDelim + 'versions.json');
  if (Data <> nil) and (Data.JSONType = jtObject) then
    Result := TJSONObject(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

function TRegistryLoader.LoadCrossTargets: TJSONObject;
var
  Data: TJSONData;
begin
  Data := LoadFile('cross' + PathDelim + 'targets.json');
  if (Data <> nil) and (Data.JSONType = jtObject) then
    Result := TJSONObject(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

function TRegistryLoader.LoadBootstrapCompilers: TJSONObject;
var
  Data: TJSONData;
begin
  Data := LoadFile('bootstrap' + PathDelim + 'compilers.json');
  if (Data <> nil) and (Data.JSONType = jtObject) then
    Result := TJSONObject(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

function TRegistryLoader.LoadPackageIndex: TJSONArray;
var
  Data, PkgData: TJSONData;
begin
  Data := LoadFile('packages' + PathDelim + 'index.json');
  if Data = nil then
    Exit(nil);

  if Data.JSONType = jtObject then
  begin
    PkgData := TJSONObject(Data).Find('packages');
    if (PkgData <> nil) and (PkgData.JSONType = jtArray) then
    begin
      Result := TJSONArray(PkgData.Clone);
      Data.Free;
      Exit;
    end;
  end;

  if Data.JSONType = jtArray then
    Result := TJSONArray(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

function TRegistryLoader.LoadBuildSteps(const AName: string): TJSONObject;
var
  Data: TJSONData;
begin
  Data := LoadFile('build-steps' + PathDelim + AName + '.json');
  if (Data <> nil) and (Data.JSONType = jtObject) then
    Result := TJSONObject(Data)
  else
  begin
    Data.Free;
    Result := nil;
  end;
end;

end.
