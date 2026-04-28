unit fpdev.fpc.indexflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.version.registry;

function BuildFPCIndexJSONCore(const AReleases: TFPCReleaseArray;
  const AUpdatedAt: TDateTime): string;

function ExecuteFPCUpdateIndexCore(const AConfigPath: string): string;

implementation

uses
  Classes,
  fpdev.config,
  fpdev.fpc.types,
  fpdev.utils.fs;

function BuildFPCIndexJSONCore(const AReleases: TFPCReleaseArray;
  const AUpdatedAt: TDateTime): string;
var
  Lines: TStringList;
  NowIso: string;
  I: Integer;
begin
  NowIso := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"Z"', AUpdatedAt);
  Lines := TStringList.Create;
  try
    Lines.Add('{');
    Lines.Add('  "version": "1",');
    Lines.Add('  "updated_at": "' + NowIso + '",');
    Lines.Add('  "items": [');
    for I := 0 to High(AReleases) do
    begin
      Lines.Add('    {');
      Lines.Add('      "version": "' + AReleases[I].Version + '",');
      Lines.Add('      "tag": "' + AReleases[I].GitTag + '",');
      Lines.Add('      "branch": "' + AReleases[I].Branch + '",');
      Lines.Add('      "channel": "' + AReleases[I].Channel + '"');
      if I < High(AReleases) then
        Lines.Add('    },')
      else
        Lines.Add('    }');
    end;
    Lines.Add('  ]');
    Lines.Add('}');
    Result := Trim(Lines.Text);
  finally
    Lines.Free;
  end;
end;

function ExecuteFPCUpdateIndexCore(const AConfigPath: string): string;
var
  Cfg: TFPDevConfigManager;
  CacheDir: string;
  Releases: TFPCReleaseArray;
begin
  Result := '';
  Cfg := TFPDevConfigManager.Create(AConfigPath);
  try
    Cfg.LoadConfig;
    CacheDir := Cfg.GetSettings.InstallRoot + PathDelim + 'cache' + PathDelim + 'fpc';
    EnsureDir(CacheDir);
    Result := CacheDir + PathDelim + 'index.json';
    Releases := TVersionRegistry.Instance.GetFPCReleases;
    SafeWriteAllText(Result, BuildFPCIndexJSONCore(Releases, Now));
  finally
    Cfg.Free;
  end;
end;

end.
