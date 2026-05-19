unit fpdev.version.registry.loadflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.constants, fpdev.version.registry;

type
  TVersionRegistryLoadData = record
    SchemaVersion: string;
    UpdatedAt: string;
    FPCReleases: TFPCReleaseArray;
    FPCDefaultVersion: string;
    FPCRepository: string;
    LazarusReleases: TLazarusReleaseArray;
    LazarusDefaultVersion: string;
    LazarusRepository: string;
    BootstrapMap: TStringList;
    BootstrapFallbackChain: TStringList;
  end;

procedure InitVersionRegistryLoadData(out AData: TVersionRegistryLoadData);
procedure DoneVersionRegistryLoadData(var AData: TVersionRegistryLoadData);
function TryLoadVersionRegistryDataCore(
  const AUserDataPath, AExeDir, ADataRoot: string;
  out AResolvedPath: string;
  var AData: TVersionRegistryLoadData
): Boolean;
function TryLoadVersionRegistryDataFromJSONCore(
  const APath: string;
  var AData: TVersionRegistryLoadData
): Boolean;
procedure LoadDefaultVersionRegistryDataCore(var AData: TVersionRegistryLoadData);

implementation

uses
  fpdev.version.registry.fromregistry;

function GetMirrorPreferenceFromConfig(const ADataRoot: string): string;
var
  ConfigPath: string;
  SL: TStringList;
  J: TJSONData;
  Root, Settings: TJSONObject;
begin
  Result := '';
  ConfigPath := IncludeTrailingPathDelimiter(ADataRoot) + 'config.json';
  if not FileExists(ConfigPath) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(ConfigPath);
    try
      J := GetJSON(SL.Text);
    except
      Exit;
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
    if (Root.Find('settings') <> nil) and
       (Root.Find('settings').JSONType = jtObject) then
    begin
      Settings := Root.Objects['settings'];
      Result := Settings.Get('mirror', '');
      if SameText(Result, 'auto') then
        Result := '';
    end;
  finally
    Root.Free;
  end;
end;

procedure ResetVersionRegistryLoadDataCore(var AData: TVersionRegistryLoadData);
begin
  AData.SchemaVersion := '';
  AData.UpdatedAt := '';
  SetLength(AData.FPCReleases, 0);
  AData.FPCDefaultVersion := '';
  AData.FPCRepository := '';
  SetLength(AData.LazarusReleases, 0);
  AData.LazarusDefaultVersion := '';
  AData.LazarusRepository := '';
  if AData.BootstrapMap <> nil then
    AData.BootstrapMap.Clear;
  if AData.BootstrapFallbackChain <> nil then
    AData.BootstrapFallbackChain.Clear;
end;

procedure ParseFPCReleasesCore(AArray: TJSONArray; var AData: TVersionRegistryLoadData);
var
  i: Integer;
  Item: TJSONObject;
begin
  SetLength(AData.FPCReleases, AArray.Count);
  for i := 0 to AArray.Count - 1 do
  begin
    Item := AArray.Objects[i];
    AData.FPCReleases[i].Version := Item.Get('version', '');
    AData.FPCReleases[i].ReleaseDate := Item.Get('release_date', '');
    AData.FPCReleases[i].GitTag := Item.Get('git_tag', '');
    AData.FPCReleases[i].Branch := Item.Get('branch', '');
    AData.FPCReleases[i].Channel := Item.Get('channel', 'stable');
    AData.FPCReleases[i].LTS := Item.Get('lts', False);
  end;
end;

procedure ParseLazarusReleasesCore(AArray: TJSONArray; var AData: TVersionRegistryLoadData);
var
  i, j: Integer;
  Item: TJSONObject;
  CompatArray: TJSONArray;
begin
  SetLength(AData.LazarusReleases, AArray.Count);
  for i := 0 to AArray.Count - 1 do
  begin
    Item := AArray.Objects[i];
    AData.LazarusReleases[i].Version := Item.Get('version', '');
    AData.LazarusReleases[i].ReleaseDate := Item.Get('release_date', '');
    AData.LazarusReleases[i].GitTag := Item.Get('git_tag', '');
    AData.LazarusReleases[i].Branch := Item.Get('branch', '');
    AData.LazarusReleases[i].Channel := Item.Get('channel', 'stable');

    if Item.Find('fpc_compatible') <> nil then
    begin
      CompatArray := Item.Arrays['fpc_compatible'];
      SetLength(AData.LazarusReleases[i].FPCCompatible, CompatArray.Count);
      for j := 0 to CompatArray.Count - 1 do
        AData.LazarusReleases[i].FPCCompatible[j] := CompatArray.Strings[j];
    end;
  end;
end;

procedure ParseBootstrapMapCore(AObj: TJSONObject; var AData: TVersionRegistryLoadData);
var
  MapObj: TJSONObject;
  ChainArray: TJSONArray;
  i: Integer;
begin
  AData.BootstrapMap.Clear;
  AData.BootstrapFallbackChain.Clear;

  if AObj.Find('version_map') <> nil then
  begin
    MapObj := AObj.Objects['version_map'];
    for i := 0 to MapObj.Count - 1 do
      AData.BootstrapMap.Values[MapObj.Names[i]] := MapObj.Items[i].AsString;
  end;

  if AObj.Find('fallback_chain') <> nil then
  begin
    ChainArray := AObj.Arrays['fallback_chain'];
    for i := 0 to ChainArray.Count - 1 do
      AData.BootstrapFallbackChain.Add(ChainArray.Strings[i]);
  end;
end;

procedure InitVersionRegistryLoadData(out AData: TVersionRegistryLoadData);
begin
  AData.BootstrapMap := TStringList.Create;
  AData.BootstrapMap.Sorted := True;
  AData.BootstrapMap.Duplicates := dupIgnore;
  AData.BootstrapFallbackChain := TStringList.Create;
  ResetVersionRegistryLoadDataCore(AData);
end;

procedure DoneVersionRegistryLoadData(var AData: TVersionRegistryLoadData);
begin
  FreeAndNil(AData.BootstrapMap);
  FreeAndNil(AData.BootstrapFallbackChain);
  SetLength(AData.FPCReleases, 0);
  SetLength(AData.LazarusReleases, 0);
end;

// Fallback data - used only when registry directory is not available.
// Canonical data source is now ~/.fpdev/registry/ (see docs/REGISTRY_DESIGN.md)
procedure LoadDefaultVersionRegistryDataCore(var AData: TVersionRegistryLoadData);
begin
  ResetVersionRegistryLoadDataCore(AData);

  AData.SchemaVersion := '1.0';
  AData.UpdatedAt := 'embedded';

  AData.FPCDefaultVersion := '3.2.2';
  AData.FPCRepository := FPC_OFFICIAL_REPO;
  SetLength(AData.FPCReleases, 5);

  AData.FPCReleases[0].Version := '3.2.2';
  AData.FPCReleases[0].ReleaseDate := '2021-05-19';
  AData.FPCReleases[0].GitTag := 'release_3_2_2';
  AData.FPCReleases[0].Branch := 'fixes_3_2';
  AData.FPCReleases[0].Channel := 'stable';
  AData.FPCReleases[0].LTS := True;

  AData.FPCReleases[1].Version := '3.2.0';
  AData.FPCReleases[1].ReleaseDate := '2020-06-19';
  AData.FPCReleases[1].GitTag := 'release_3_2_0';
  AData.FPCReleases[1].Branch := 'fixes_3_2';
  AData.FPCReleases[1].Channel := 'stable';
  AData.FPCReleases[1].LTS := False;

  AData.FPCReleases[2].Version := '3.0.4';
  AData.FPCReleases[2].ReleaseDate := '2017-11-21';
  AData.FPCReleases[2].GitTag := 'release_3_0_4';
  AData.FPCReleases[2].Branch := 'fixes_3_0';
  AData.FPCReleases[2].Channel := 'legacy';
  AData.FPCReleases[2].LTS := False;

  AData.FPCReleases[3].Version := '3.3.1';
  AData.FPCReleases[3].ReleaseDate := 'rolling';
  AData.FPCReleases[3].GitTag := 'main';
  AData.FPCReleases[3].Branch := 'main';
  AData.FPCReleases[3].Channel := 'development';
  AData.FPCReleases[3].LTS := False;

  AData.FPCReleases[4].Version := 'main';
  AData.FPCReleases[4].ReleaseDate := 'rolling';
  AData.FPCReleases[4].GitTag := 'main';
  AData.FPCReleases[4].Branch := 'main';
  AData.FPCReleases[4].Channel := 'development';
  AData.FPCReleases[4].LTS := False;

  AData.LazarusDefaultVersion := '3.6';
  AData.LazarusRepository := LAZARUS_OFFICIAL_REPO;
  SetLength(AData.LazarusReleases, 2);

  AData.LazarusReleases[0].Version := '3.6';
  AData.LazarusReleases[0].ReleaseDate := '2024-10-14';
  AData.LazarusReleases[0].GitTag := 'lazarus_3_6';
  AData.LazarusReleases[0].Branch := 'lazarus_3_6';
  AData.LazarusReleases[0].Channel := 'stable';
  SetLength(AData.LazarusReleases[0].FPCCompatible, 2);
  AData.LazarusReleases[0].FPCCompatible[0] := '3.2.2';
  AData.LazarusReleases[0].FPCCompatible[1] := '3.2.0';

  AData.LazarusReleases[1].Version := 'main';
  AData.LazarusReleases[1].ReleaseDate := 'rolling';
  AData.LazarusReleases[1].GitTag := 'main';
  AData.LazarusReleases[1].Branch := 'main';
  AData.LazarusReleases[1].Channel := 'development';
  SetLength(AData.LazarusReleases[1].FPCCompatible, 3);
  AData.LazarusReleases[1].FPCCompatible[0] := '3.2.2';
  AData.LazarusReleases[1].FPCCompatible[1] := '3.3.1';
  AData.LazarusReleases[1].FPCCompatible[2] := 'main';

  AData.BootstrapMap.Values['main'] := '3.2.2';
  AData.BootstrapMap.Values['3.3.1'] := '3.2.2';
  AData.BootstrapMap.Values['3.2.2'] := '3.2.0';
  AData.BootstrapMap.Values['3.2.0'] := '3.0.4';
  AData.BootstrapMap.Values['3.0.4'] := '3.0.2';

  AData.BootstrapFallbackChain.Add('3.2.2');
  AData.BootstrapFallbackChain.Add('3.2.0');
  AData.BootstrapFallbackChain.Add('3.0.4');
  AData.BootstrapFallbackChain.Add('3.0.2');
  AData.BootstrapFallbackChain.Add('3.0.0');
  AData.BootstrapFallbackChain.Add('2.6.4');
end;

function TryLoadVersionRegistryDataFromJSONCore(
  const APath: string;
  var AData: TVersionRegistryLoadData
): Boolean;
var
  JSONText: string;
  Parser: TJSONParser;
  Root: TJSONObject;
  FPCObj, LazObj, BootstrapObj: TJSONObject;
  F: TStringList;
begin
  Result := False;
  LoadDefaultVersionRegistryDataCore(AData);

  F := TStringList.Create;
  try
    F.LoadFromFile(APath);
    JSONText := F.Text;
  finally
    F.Free;
  end;

  try
    Parser := TJSONParser.Create(JSONText, []);
    try
      Root := Parser.Parse as TJSONObject;
      try
        AData.SchemaVersion := Root.Get('schema_version', AData.SchemaVersion);
        AData.UpdatedAt := Root.Get('updated_at', AData.UpdatedAt);

        if Root.Find('fpc') <> nil then
        begin
          FPCObj := Root.Objects['fpc'];
          AData.FPCDefaultVersion := FPCObj.Get('default_version', AData.FPCDefaultVersion);
          AData.FPCRepository := FPCObj.Get('repository', AData.FPCRepository);
          if FPCObj.Find('releases') <> nil then
            ParseFPCReleasesCore(FPCObj.Arrays['releases'], AData);
        end;

        if Root.Find('lazarus') <> nil then
        begin
          LazObj := Root.Objects['lazarus'];
          AData.LazarusDefaultVersion := LazObj.Get('default_version', AData.LazarusDefaultVersion);
          AData.LazarusRepository := LazObj.Get('repository', AData.LazarusRepository);
          if LazObj.Find('releases') <> nil then
            ParseLazarusReleasesCore(LazObj.Arrays['releases'], AData);
        end;

        if Root.Find('bootstrap') <> nil then
        begin
          BootstrapObj := Root.Objects['bootstrap'];
          ParseBootstrapMapCore(BootstrapObj, AData);
        end;

        Result := True;
      finally
        Root.Free;
      end;
    finally
      Parser.Free;
    end;
  except
    Result := False;
  end;
end;

function TryLoadVersionRegistryDataCore(
  const AUserDataPath, AExeDir, ADataRoot: string;
  out AResolvedPath: string;
  var AData: TVersionRegistryLoadData
): Boolean;
var
  SearchPaths: array[0..3] of string;
  RegistryDir: string;
  MirrorPref: string;
  i: Integer;
begin
  AResolvedPath := '';

  RegistryDir := IncludeTrailingPathDelimiter(ADataRoot) + 'registry';
  if DirectoryExists(RegistryDir) and
     FileExists(IncludeTrailingPathDelimiter(RegistryDir) + 'index.json') then
  begin
    MirrorPref := GetMirrorPreferenceFromConfig(ADataRoot);
    if TryLoadVersionRegistryFromRegistryDir(RegistryDir, AData, MirrorPref) then
    begin
      AResolvedPath := RegistryDir;
      Exit(True);
    end;
  end;

  SearchPaths[0] := AUserDataPath;
  SearchPaths[1] := IncludeTrailingPathDelimiter(AExeDir) + 'data' + PathDelim + 'versions.json';
  SearchPaths[2] := IncludeTrailingPathDelimiter(ADataRoot) + 'versions.json';
  SearchPaths[3] := IncludeTrailingPathDelimiter(AExeDir) + '..' + PathDelim + 'data' + PathDelim + 'versions.json';

  for i := 0 to High(SearchPaths) do
  begin
    if (SearchPaths[i] <> '') and FileExists(SearchPaths[i]) then
    begin
      if TryLoadVersionRegistryDataFromJSONCore(SearchPaths[i], AData) then
      begin
        AResolvedPath := SearchPaths[i];
        Exit(True);
      end;
    end;
  end;

  LoadDefaultVersionRegistryDataCore(AData);
  Result := True;
end;

end.
