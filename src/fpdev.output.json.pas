unit fpdev.output.json;

{
  JSON output helper for CLI commands

  Provides consistent JSON formatting for --json flag support
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson,
  fpdev.fpc.version;

type
  { TJsonOutputHelper - Helper for consistent JSON output }
  TJsonOutputHelper = class
  public
    { Convert TFPCVersionInfo to JSON object }
    class function VersionInfoToJson(const AInfo: TFPCVersionInfo): TJSONObject;

    { Convert TFPCVersionArray to JSON array }
    class function VersionArrayToJson(const AVersions: TFPCVersionArray): TJSONArray;

    { Create simple key-value JSON object }
    class function SimpleObject(const AKey, AValue: string): TJSONObject;

    { Create error JSON object }
    class function ErrorObject(const AMessage: string; ACode: Integer = 1): TJSONObject;

    { Format JSON for output (pretty print) }
    class function FormatJson(AObj: TJSONData): string;
  end;

implementation

{ TJsonOutputHelper }

class function TJsonOutputHelper.VersionInfoToJson(const AInfo: TFPCVersionInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('version', AInfo.Version);
  Result.Add('release_date', AInfo.ReleaseDate);
  Result.Add('git_tag', AInfo.GitTag);
  Result.Add('branch', AInfo.Branch);
  Result.Add('available', AInfo.Available);
  Result.Add('installed', AInfo.Installed);
end;

class function TJsonOutputHelper.VersionArrayToJson(const AVersions: TFPCVersionArray): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(AVersions) do
    Result.Add(VersionInfoToJson(AVersions[I]));
end;

class function TJsonOutputHelper.SimpleObject(const AKey, AValue: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add(AKey, AValue);
end;

class function TJsonOutputHelper.ErrorObject(const AMessage: string; ACode: Integer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('error', True);
  Result.Add('code', ACode);
  Result.Add('message', AMessage);
end;

class function TJsonOutputHelper.FormatJson(AObj: TJSONData): string;
begin
  Result := AObj.FormatJSON;
end;

end.
