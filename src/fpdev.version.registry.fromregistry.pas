unit fpdev.version.registry.fromregistry;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.version.registry.loadflow;

function TryLoadVersionRegistryFromRegistryDir(
  const ARegistryDir: string;
  var AData: TVersionRegistryLoadData;
  const APreferredMirror: string = ''
): Boolean;

implementation

uses
  Classes, fpjson, jsonparser, fpdev.constants;

function LoadJSONObjectFromFile(const APath: string): TJSONObject;
var
  SL: TStringList;
  J: TJSONData;
begin
  Result := nil;
  if not FileExists(APath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    try
      J := GetJSON(SL.Text);
    except
      Exit;
    end;
    if (J <> nil) and (J.JSONType = jtObject) then
      Result := TJSONObject(J)
    else
      J.Free;
  finally
    SL.Free;
  end;
end;

procedure ParseFPCVersionsFromRegistry(const AVersionsObj: TJSONObject;
  var AData: TVersionRegistryLoadData);
var
  Versions: TJSONObject;
  I, J, Count: Integer;
  Key: string;
  Entry: TJSONObject;
  Bootstrap: TJSONObject;
  KnownGood: TJSONArray;
begin
  AData.FPCDefaultVersion := AVersionsObj.Get('default_version', '3.2.2');

  if AVersionsObj.Find('versions') = nil then
    Exit;
  Versions := AVersionsObj.Objects['versions'];

  Count := Versions.Count;
  SetLength(AData.FPCReleases, Count);

  for I := 0 to Count - 1 do
  begin
    Key := Versions.Names[I];
    Entry := Versions.Objects[Key];

    AData.FPCReleases[I].Version := Key;
    AData.FPCReleases[I].ReleaseDate := Entry.Get('release_date', '');
    AData.FPCReleases[I].GitTag := Entry.Get('ref', '');
    AData.FPCReleases[I].Branch := Entry.Get('branch', '');
    AData.FPCReleases[I].Channel := Entry.Get('channel', 'stable');
    AData.FPCReleases[I].LTS := Entry.Get('lts', False);

    if Entry.Find('bootstrap') <> nil then
    begin
      Bootstrap := Entry.Objects['bootstrap'];

      if Bootstrap.Find('known_good') <> nil then
      begin
        KnownGood := Bootstrap.Arrays['known_good'];
        AData.BootstrapMap.Sorted := False;
        for J := 0 to KnownGood.Count - 1 do
        begin
          if not SameText(KnownGood.Strings[J], Key) then
          begin
            AData.BootstrapMap.Values[Key] := KnownGood.Strings[J];
            Break;
          end;
        end;
        AData.BootstrapMap.Sorted := True;
      end
      else
      begin
        AData.BootstrapMap.Sorted := False;
        AData.BootstrapMap.Values[Key] := Bootstrap.Get('minimum', '');
        AData.BootstrapMap.Sorted := True;
      end;
    end;
  end;
end;

procedure ParseLazarusVersionsFromRegistry(const AVersionsObj: TJSONObject;
  var AData: TVersionRegistryLoadData);
var
  Versions: TJSONObject;
  I, J, Count: Integer;
  Key: string;
  Entry: TJSONObject;
  Compat: TJSONArray;
begin
  AData.LazarusDefaultVersion := AVersionsObj.Get('default_version', '3.6');

  if AVersionsObj.Find('versions') = nil then
    Exit;
  Versions := AVersionsObj.Objects['versions'];

  Count := Versions.Count;
  SetLength(AData.LazarusReleases, Count);

  for I := 0 to Count - 1 do
  begin
    Key := Versions.Names[I];
    Entry := Versions.Objects[Key];

    AData.LazarusReleases[I].Version := Key;
    AData.LazarusReleases[I].ReleaseDate := Entry.Get('release_date', '');
    AData.LazarusReleases[I].GitTag := Entry.Get('ref', '');
    AData.LazarusReleases[I].Branch := Entry.Get('branch', '');
    AData.LazarusReleases[I].Channel := Entry.Get('channel', 'stable');

    if Entry.Find('fpc_compatible') <> nil then
    begin
      Compat := Entry.Arrays['fpc_compatible'];
      SetLength(AData.LazarusReleases[I].FPCCompatible, Compat.Count);
      for J := 0 to Compat.Count - 1 do
        AData.LazarusReleases[I].FPCCompatible[J] := Compat.Strings[J];
    end;
  end;
end;

procedure ParseBootstrapFromRegistry(const ABootstrapObj: TJSONObject;
  var AData: TVersionRegistryLoadData);
var
  FallbackArr: TJSONArray;
  I: Integer;
begin
  if ABootstrapObj.Find('fallback_chain') <> nil then
  begin
    FallbackArr := ABootstrapObj.Arrays['fallback_chain'];
    AData.BootstrapFallbackChain.Clear;
    for I := 0 to FallbackArr.Count - 1 do
      AData.BootstrapFallbackChain.Add(FallbackArr.Strings[I]);
  end;
end;

procedure ParseSourcesFromRegistry(const ASourcesObj: TJSONObject;
  const APreferredMirror: string;
  var AData: TVersionRegistryLoadData);

  function PickMirrorURL(const AObj: TJSONObject; const APref: string): string;
  var
    MObj: TJSONObject;
    K: Integer;
  begin
    Result := '';
    if (APref <> '') and (AObj.Find(APref) <> nil) and
       (AObj.Find(APref).JSONType = jtObject) then
    begin
      MObj := AObj.Objects[APref];
      Result := MObj.Get('url', '');
      if Result <> '' then Exit;
    end;
    for K := 0 to AObj.Count - 1 do
    begin
      if AObj.Items[K].JSONType = jtObject then
      begin
        MObj := TJSONObject(AObj.Items[K]);
        Result := MObj.Get('url', '');
        if Result <> '' then Exit;
      end;
    end;
  end;

var
  FPCObj, LazObj: TJSONObject;
begin
  if ASourcesObj.Find('fpc') <> nil then
  begin
    FPCObj := ASourcesObj.Objects['fpc'];
    AData.FPCRepository := PickMirrorURL(FPCObj, APreferredMirror);
    if AData.FPCRepository = '' then
      AData.FPCRepository := FPC_OFFICIAL_REPO;
  end;

  if ASourcesObj.Find('lazarus') <> nil then
  begin
    LazObj := ASourcesObj.Objects['lazarus'];
    AData.LazarusRepository := PickMirrorURL(LazObj, APreferredMirror);
    if AData.LazarusRepository = '' then
      AData.LazarusRepository := LAZARUS_OFFICIAL_REPO;
  end;
end;

function TryLoadVersionRegistryFromRegistryDir(
  const ARegistryDir: string;
  var AData: TVersionRegistryLoadData;
  const APreferredMirror: string = ''
): Boolean;
var
  Dir: string;
  SourcesObj, FPCObj, LazObj, BootstrapObj: TJSONObject;
begin
  Result := False;
  Dir := IncludeTrailingPathDelimiter(ARegistryDir);

  if not DirectoryExists(ARegistryDir) then
    Exit;

  if not FileExists(Dir + 'index.json') then
    Exit;

  InitVersionRegistryLoadData(AData);
  AData.FPCRepository := FPC_OFFICIAL_REPO;
  AData.LazarusRepository := LAZARUS_OFFICIAL_REPO;

  SourcesObj := LoadJSONObjectFromFile(Dir + 'sources.json');
  if SourcesObj <> nil then
  try
    ParseSourcesFromRegistry(SourcesObj, APreferredMirror, AData);
  finally
    SourcesObj.Free;
  end;

  FPCObj := LoadJSONObjectFromFile(Dir + 'fpc' + PathDelim + 'versions.json');
  if FPCObj <> nil then
  try
    ParseFPCVersionsFromRegistry(FPCObj, AData);
  finally
    FPCObj.Free;
  end;

  LazObj := LoadJSONObjectFromFile(Dir + 'lazarus' + PathDelim + 'versions.json');
  if LazObj <> nil then
  try
    ParseLazarusVersionsFromRegistry(LazObj, AData);
  finally
    LazObj.Free;
  end;

  BootstrapObj := LoadJSONObjectFromFile(Dir + 'bootstrap' + PathDelim + 'compilers.json');
  if BootstrapObj <> nil then
  try
    ParseBootstrapFromRegistry(BootstrapObj, AData);
  finally
    BootstrapObj.Free;
  end;

  AData.SchemaVersion := '2.0';
  AData.UpdatedAt := 'registry';
  Result := True;
end;

end.
