unit fpdev.lazarus.metadataflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.constants,
  fpdev.config.interfaces,
  fpdev.lazarus.types;

function NormalizeConfiguredLazarusFPCVersionCore(
  const AConfiguredFPCVersion, ARecommendedFPCVersion: string
): string;

function BuildConfiguredLazarusVersionInfoCore(
  const AVersion: string;
  const ALazarusInfo: TLazarusInfo;
  const ARecommendedFPCVersion: string;
  AAvailable, AInstalled: Boolean
): TLazarusVersionInfo;

function OverlayConfiguredLazarusVersionInfoCore(
  const ABaseInfo, AConfiguredInfo: TLazarusVersionInfo
): TLazarusVersionInfo;

function MergeConfiguredInstalledLazarusVersionsCore(
  const ABaseVersions: TLazarusVersionArray;
  const AConfiguredInfo: TLazarusVersionInfo
): TLazarusVersionArray;

function FilterInstalledLazarusVersionsCore(
  const AAllVersions: TLazarusVersionArray
): TLazarusVersionArray;

function TryFindLazarusVersionInfoCore(
  const AVersions: TLazarusVersionArray;
  const AVersion: string;
  out AVersionInfo: TLazarusVersionInfo
): Boolean;

implementation

function NormalizeConfiguredLazarusFPCVersionCore(
  const AConfiguredFPCVersion, ARecommendedFPCVersion: string
): string;
begin
  Result := Trim(AConfiguredFPCVersion);
  if SameText(Copy(Result, 1, 4), 'fpc-') then
    Delete(Result, 1, 4);
  if Result = '' then
    Result := Trim(ARecommendedFPCVersion);
  if Result = '' then
    Result := DEFAULT_FPC_VERSION;
end;

function BuildConfiguredLazarusVersionInfoCore(
  const AVersion: string;
  const ALazarusInfo: TLazarusInfo;
  const ARecommendedFPCVersion: string;
  AAvailable, AInstalled: Boolean
): TLazarusVersionInfo;
begin
  Result := Default(TLazarusVersionInfo);
  Result.Version := AVersion;
  Result.ReleaseDate := '';
  Result.GitTag := '';
  Result.Branch := ALazarusInfo.Branch;
  Result.FPCVersion := NormalizeConfiguredLazarusFPCVersionCore(
    ALazarusInfo.FPCVersion,
    ARecommendedFPCVersion
  );
  Result.Available := AAvailable;
  Result.Installed := AInstalled or ALazarusInfo.Installed;
end;

function OverlayConfiguredLazarusVersionInfoCore(
  const ABaseInfo, AConfiguredInfo: TLazarusVersionInfo
): TLazarusVersionInfo;
begin
  Result := ABaseInfo;

  if Trim(AConfiguredInfo.Branch) <> '' then
    Result.Branch := AConfiguredInfo.Branch;
  if Trim(AConfiguredInfo.FPCVersion) <> '' then
    Result.FPCVersion := AConfiguredInfo.FPCVersion;

  Result.Available := ABaseInfo.Available or AConfiguredInfo.Available;
  Result.Installed := ABaseInfo.Installed or AConfiguredInfo.Installed;
end;

function MergeConfiguredInstalledLazarusVersionsCore(
  const ABaseVersions: TLazarusVersionArray;
  const AConfiguredInfo: TLazarusVersionInfo
): TLazarusVersionArray;
var
  I: Integer;
begin
  Result := Copy(ABaseVersions);
  if (Trim(AConfiguredInfo.Version) = '') or (not AConfiguredInfo.Installed) then
    Exit;

  for I := 0 to High(Result) do
  begin
    if SameText(Result[I].Version, AConfiguredInfo.Version) then
    begin
      Result[I] := OverlayConfiguredLazarusVersionInfoCore(Result[I], AConfiguredInfo);
      Exit;
    end;
  end;

  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := AConfiguredInfo;
end;

function FilterInstalledLazarusVersionsCore(
  const AAllVersions: TLazarusVersionArray
): TLazarusVersionArray;
var
  I: Integer;
  Count: Integer;
begin
  Result := nil;
  Count := 0;

  for I := 0 to High(AAllVersions) do
    if AAllVersions[I].Installed then
      Inc(Count);

  SetLength(Result, Count);
  Count := 0;
  for I := 0 to High(AAllVersions) do
  begin
    if not AAllVersions[I].Installed then
      Continue;
    Result[Count] := AAllVersions[I];
    Inc(Count);
  end;
end;

function TryFindLazarusVersionInfoCore(
  const AVersions: TLazarusVersionArray;
  const AVersion: string;
  out AVersionInfo: TLazarusVersionInfo
): Boolean;
var
  I: Integer;
begin
  AVersionInfo := Default(TLazarusVersionInfo);
  Result := False;

  for I := 0 to High(AVersions) do
  begin
    if not SameText(AVersions[I].Version, AVersion) then
      Continue;
    AVersionInfo := AVersions[I];
    Exit(True);
  end;
end;

end.
