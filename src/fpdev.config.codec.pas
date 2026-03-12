unit fpdev.config.codec;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DateUtils, fpjson,
  fpdev.config.interfaces;

function ConfigToolchainTypeToString(AType: TToolchainType): string;
function ConfigStringToToolchainType(const AStr: string): TToolchainType;
function ConfigToolchainInfoToJSON(const AInfo: TToolchainInfo): TJSONObject;
function ConfigJSONToToolchainInfo(AJSON: TJSONObject): TToolchainInfo;
function ConfigLazarusInfoToJSON(const AInfo: TLazarusInfo): TJSONObject;
function ConfigJSONToLazarusInfo(AJSON: TJSONObject): TLazarusInfo;
function ConfigCrossTargetToJSON(const ATarget: TCrossTarget): TJSONObject;
function ConfigJSONToCrossTarget(AJSON: TJSONObject): TCrossTarget;

implementation

function ConfigToolchainTypeToString(AType: TToolchainType): string;
begin
  Result := 'release';
  case AType of
    ttRelease: Result := 'release';
    ttDevelopment: Result := 'development';
    ttCustom: Result := 'custom';
  end;
end;

function ConfigStringToToolchainType(const AStr: string): TToolchainType;
begin
  if SameText(AStr, 'development') then
    Result := ttDevelopment
  else if SameText(AStr, 'custom') then
    Result := ttCustom
  else
    Result := ttRelease;
end;

function ConfigToolchainInfoToJSON(const AInfo: TToolchainInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('type', ConfigToolchainTypeToString(AInfo.ToolchainType));
    Result.Add('version', AInfo.Version);
    Result.Add('install_path', AInfo.InstallPath);
    Result.Add('source_url', AInfo.SourceURL);
    Result.Add('branch', AInfo.Branch);
    Result.Add('installed', AInfo.Installed);
    if AInfo.InstallDate > 0 then
      Result.Add('install_date', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', AInfo.InstallDate));
  except
    Result.Free;
    raise;
  end;
end;

function ConfigJSONToToolchainInfo(AJSON: TJSONObject): TToolchainInfo;
var
  DateStr: string;
begin
  Result := Default(TToolchainInfo);

  Result.ToolchainType := ConfigStringToToolchainType(AJSON.Get('type', 'release'));
  Result.Version := AJSON.Get('version', '');
  Result.InstallPath := AJSON.Get('install_path', '');
  Result.SourceURL := AJSON.Get('source_url', '');
  Result.Branch := AJSON.Get('branch', '');
  Result.Installed := AJSON.Get('installed', False);

  DateStr := AJSON.Get('install_date', '');
  if DateStr <> '' then
  begin
    try
      DateStr := StringReplace(DateStr, 'T', ' ', [rfReplaceAll]);
      DateStr := StringReplace(DateStr, 'Z', '', [rfReplaceAll]);
      Result.InstallDate := ScanDateTime('yyyy-mm-dd hh:nn:ss', DateStr);
    except
      Result.InstallDate := 0;
    end;
  end;
end;

function ConfigLazarusInfoToJSON(const AInfo: TLazarusInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('version', AInfo.Version);
    Result.Add('fpc_version', AInfo.FPCVersion);
    Result.Add('install_path', AInfo.InstallPath);
    Result.Add('source_url', AInfo.SourceURL);
    Result.Add('branch', AInfo.Branch);
    Result.Add('installed', AInfo.Installed);
  except
    Result.Free;
    raise;
  end;
end;

function ConfigJSONToLazarusInfo(AJSON: TJSONObject): TLazarusInfo;
begin
  Result := Default(TLazarusInfo);

  Result.Version := AJSON.Get('version', '');
  Result.FPCVersion := AJSON.Get('fpc_version', '');
  Result.InstallPath := AJSON.Get('install_path', '');
  Result.SourceURL := AJSON.Get('source_url', '');
  Result.Branch := AJSON.Get('branch', '');
  Result.Installed := AJSON.Get('installed', False);
end;

function ConfigCrossTargetToJSON(const ATarget: TCrossTarget): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.Add('enabled', ATarget.Enabled);
    Result.Add('binutils_path', ATarget.BinutilsPath);
    Result.Add('libraries_path', ATarget.LibrariesPath);
    if ATarget.CPU <> '' then
      Result.Add('cpu', ATarget.CPU);
    if ATarget.OS <> '' then
      Result.Add('os', ATarget.OS);
    if ATarget.SubArch <> '' then
      Result.Add('sub_arch', ATarget.SubArch);
    if ATarget.ABI <> '' then
      Result.Add('abi', ATarget.ABI);
    if ATarget.BinutilsPrefix <> '' then
      Result.Add('binutils_prefix', ATarget.BinutilsPrefix);
    if ATarget.CrossOpt <> '' then
      Result.Add('cross_opt', ATarget.CrossOpt);
  except
    Result.Free;
    raise;
  end;
end;

function ConfigJSONToCrossTarget(AJSON: TJSONObject): TCrossTarget;
begin
  Result := Default(TCrossTarget);

  Result.Enabled := AJSON.Get('enabled', False);
  Result.BinutilsPath := AJSON.Get('binutils_path', '');
  Result.LibrariesPath := AJSON.Get('libraries_path', '');
  Result.CPU := AJSON.Get('cpu', '');
  Result.OS := AJSON.Get('os', '');
  Result.SubArch := AJSON.Get('sub_arch', '');
  Result.ABI := AJSON.Get('abi', '');
  Result.BinutilsPrefix := AJSON.Get('binutils_prefix', '');
  Result.CrossOpt := AJSON.Get('cross_opt', '');
end;

end.
