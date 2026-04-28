unit fpdev.lazarus.versionflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.lazarus.types;

type
  TLazarusVersionInstalledFunc = function(const AVersion: string): Boolean of object;
  TLazarusVersionSetDefaultFunc = function(const AVersion: string): Boolean of object;
  TLazarusVersionConfiguredLookupFunc = function(
    const AVersion: string;
    out AVersionInfo: TLazarusVersionInfo
  ): Boolean of object;
  TLazarusVersionInstallPathFunc = function(const AVersion: string): string of object;
  TLazarusInfoLookupFunc = function(const AVersion: string; out ALazarusInfo: TLazarusInfo): Boolean of object;

function NormalizeDefaultLazarusVersionCore(const ADefaultVersion: string): string;

function WriteManagedLazarusVersionListCore(
  const AVersions: TLazarusVersionArray;
  const ADefaultVersion: string;
  AShowAll: Boolean;
  const AOut: IOutput
): Boolean;

function SetManagedLazarusDefaultVersionCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AIsVersionInstalled: TLazarusVersionInstalledFunc;
  ASetDefaultVersion: TLazarusVersionSetDefaultFunc
): Boolean;

function ShowManagedLazarusVersionInfoCore(
  const AVersion: string;
  const AOut: IOutput;
  const AAvailableVersions: TLazarusVersionArray;
  ALookupConfiguredVersion: TLazarusVersionConfiguredLookupFunc;
  AIsVersionInstalled: TLazarusVersionInstalledFunc;
  AResolveInstallPath: TLazarusVersionInstallPathFunc;
  ALookupLazarusInfo: TLazarusInfoLookupFunc
): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.lazarus.metadataflow;

function NormalizeDefaultLazarusVersionCore(const ADefaultVersion: string): string;
begin
  Result := Trim(ADefaultVersion);
  if Pos('lazarus-', Result) = 1 then
    Result := Copy(Result, 9, Length(Result));
end;

function WriteManagedLazarusVersionListCore(
  const AVersions: TLazarusVersionArray;
  const ADefaultVersion: string;
  AShowAll: Boolean;
  const AOut: IOutput
): Boolean;
var
  I: Integer;
  DefaultVersion: string;
  Line: string;
begin
  Result := False;
  if AOut = nil then
    Exit(False);

  DefaultVersion := NormalizeDefaultLazarusVersionCore(ADefaultVersion);

  if not AShowAll then
  begin
    AOut.WriteLn(_(CMD_LAZARUS_LIST_HEADER));
    if Length(AVersions) = 0 then
      AOut.WriteLn(_(CMD_LAZARUS_LIST_EMPTY));
  end;

  for I := 0 to High(AVersions) do
  begin
    Line := Format('%-8s  ', [AVersions[I].Version]);

    if AVersions[I].Installed then
    begin
      if SameText(AVersions[I].Version, DefaultVersion) then
        Line := Line + 'Installed*  '
      else
        Line := Line + 'Installed   ';
    end
    else
      Line := Line + 'Available   ';

    Line := Line + Format('%-10s  ', [AVersions[I].ReleaseDate]);
    Line := Line + Format('%-7s  ', [AVersions[I].FPCVersion]);
    Line := Line + AVersions[I].Branch;
    AOut.WriteLn(Line);
  end;

  Result := True;
end;

function SetManagedLazarusDefaultVersionCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AIsVersionInstalled: TLazarusVersionInstalledFunc;
  ASetDefaultVersion: TLazarusVersionSetDefaultFunc
): Boolean;
begin
  Result := False;

  if Assigned(AIsVersionInstalled) and (not AIsVersionInstalled(AVersion)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, [AVersion]));
    Exit(False);
  end;

  if not Assigned(ASetDefaultVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_USE_FAILED));
    Exit(False);
  end;

  Result := ASetDefaultVersion(AVersion);
  if Result then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(CMD_LAZARUS_USE_SET, [AVersion]));
  end
  else if Errp <> nil then
    Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_LAZARUS_USE_FAILED));
end;

function ShowManagedLazarusVersionInfoCore(
  const AVersion: string;
  const AOut: IOutput;
  const AAvailableVersions: TLazarusVersionArray;
  ALookupConfiguredVersion: TLazarusVersionConfiguredLookupFunc;
  AIsVersionInstalled: TLazarusVersionInstalledFunc;
  AResolveInstallPath: TLazarusVersionInstallPathFunc;
  ALookupLazarusInfo: TLazarusInfoLookupFunc
): Boolean;
var
  VersionInfo: TLazarusVersionInfo;
  LazarusInfo: TLazarusInfo;
  Found: Boolean;
begin
  Result := False;
  if AOut = nil then
    Exit(False);

  VersionInfo := Default(TLazarusVersionInfo);
  Found := TryFindLazarusVersionInfoCore(AAvailableVersions, AVersion, VersionInfo);
  if (not Found) and Assigned(ALookupConfiguredVersion) then
    Found := ALookupConfiguredVersion(AVersion, VersionInfo);
  if not Found then
    Exit(False);

  AOut.WriteLn(Format('Version:      %s', [VersionInfo.Version]));
  AOut.WriteLn(Format('Release Date: %s', [VersionInfo.ReleaseDate]));
  AOut.WriteLn(Format('Git Tag:      %s', [VersionInfo.GitTag]));
  AOut.WriteLn(Format('Branch:       %s', [VersionInfo.Branch]));
  AOut.WriteLn(Format('FPC Version:  %s', [VersionInfo.FPCVersion]));

  if Assigned(AIsVersionInstalled) and AIsVersionInstalled(AVersion) then
  begin
    AOut.WriteLn(_(MSG_LAZARUS_STATUS_INSTALLED));
    if Assigned(AResolveInstallPath) then
      AOut.WriteLn(Format('Install Path: %s', [AResolveInstallPath(AVersion)]));
    if Assigned(ALookupLazarusInfo) and ALookupLazarusInfo(AVersion, LazarusInfo) then
    begin
      if LazarusInfo.SourceURL <> '' then
        AOut.WriteLn(Format('Source URL:   %s', [LazarusInfo.SourceURL]));
    end;
  end
  else
    AOut.WriteLn(_(MSG_LAZARUS_STATUS_NOT_INSTALLED));

  Result := True;
end;

end.
