unit fpdev.registry.binary;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.manifest;

function TryLoadBinaryTargetFromRegistry(
  const ARegistryDir, AVersion, APlatform, APreferredMirror: string;
  out ATarget: TManifestTarget;
  out AInstallMethod: string;
  out AError: string
): Boolean;

implementation

uses
  Classes, fpjson, jsonparser;

function TryLoadBinaryTargetFromRegistry(
  const ARegistryDir, AVersion, APlatform, APreferredMirror: string;
  out ATarget: TManifestTarget;
  out AInstallMethod: string;
  out AError: string
): Boolean;
var
  BinaryPath: string;
  SL: TStringList;
  Root, VersionObj, PlatformObj, MirrorsObj, HashObj: TJSONObject;
  J: TJSONData;
  I, K, URLCount: Integer;
  PreferredURL: string;
begin
  Result := False;
  ATarget := Default(TManifestTarget);
  AInstallMethod := '';
  AError := '';

  BinaryPath := IncludeTrailingPathDelimiter(ARegistryDir) +
    'fpc' + PathDelim + 'binary.json';

  if not FileExists(BinaryPath) then
  begin
    AError := 'Registry binary.json not found';
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(BinaryPath);
    try
      J := GetJSON(SL.Text);
    except
      on E: Exception do
      begin
        AError := 'Failed to parse binary.json: ' + E.Message;
        Exit;
      end;
    end;
  finally
    SL.Free;
  end;

  if (J = nil) or (J.JSONType <> jtObject) then
  begin
    J.Free;
    AError := 'Invalid binary.json format';
    Exit;
  end;

  Root := TJSONObject(J);
  try
    if Root.Find(AVersion) = nil then
    begin
      AError := 'Version ' + AVersion + ' not found in binary.json';
      Exit;
    end;
    VersionObj := Root.Objects[AVersion];

    if VersionObj.Find(APlatform) = nil then
    begin
      AError := 'Platform ' + APlatform + ' not available for FPC ' + AVersion;
      Exit;
    end;
    PlatformObj := VersionObj.Objects[APlatform];

    if PlatformObj.Find('mirrors') = nil then
    begin
      AError := 'No mirrors defined for ' + AVersion + '/' + APlatform;
      Exit;
    end;
    MirrorsObj := PlatformObj.Objects['mirrors'];

    PreferredURL := '';
    if (APreferredMirror <> '') and (MirrorsObj.Find(APreferredMirror) <> nil) then
      PreferredURL := MirrorsObj.Get(APreferredMirror, '');

    URLCount := MirrorsObj.Count;
    if PreferredURL <> '' then
    begin
      SetLength(ATarget.URLs, URLCount);
      ATarget.URLs[0] := PreferredURL;
      I := 1;
      for K := 0 to MirrorsObj.Count - 1 do
      begin
        if MirrorsObj.Items[K].AsString <> PreferredURL then
        begin
          ATarget.URLs[I] := MirrorsObj.Items[K].AsString;
          Inc(I);
        end;
      end;
      SetLength(ATarget.URLs, I);
    end
    else
    begin
      SetLength(ATarget.URLs, URLCount);
      for I := 0 to URLCount - 1 do
        ATarget.URLs[I] := MirrorsObj.Items[I].AsString;
    end;

    if PlatformObj.Find('hash') <> nil then
    begin
      HashObj := PlatformObj.Objects['hash'];
      if HashObj.Find('sha256') <> nil then
        ATarget.Hash := 'sha256:' + HashObj.Get('sha256', '');
    end;

    ATarget.Size := PlatformObj.Get('size', Int64(0));
    AInstallMethod := PlatformObj.Get('install_method', 'nested-tar');

    Result := True;
  finally
    Root.Free;
  end;
end;

end.
