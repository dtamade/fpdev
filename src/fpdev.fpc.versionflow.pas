unit fpdev.fpc.versionflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.fpc.types;

type
  TFPCVersionInstalledFunc = function(const AVersion: string): Boolean of object;
  TFPCVersionSetDefaultFunc = function(const AVersion: string): Boolean of object;
  TFPCVersionGetInstallPathFunc = function(const AVersion: string): string of object;
  TFPCVersionActivateFunc = function(
    const AVersion, ABinPath: string
  ): TActivationResult of object;

function NormalizeDefaultFPCVersionCore(const ADefaultToolchain: string): string;

function WriteManagedFPCVersionListCore(
  const AVersions: TFPCVersionArray;
  const ADefaultToolchain: string;
  AShowAll: Boolean;
  const AOut: IOutput
): Boolean;

function SetManagedFPCDefaultVersionCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AIsVersionInstalled: TFPCVersionInstalledFunc;
  ASetDefaultVersion: TFPCVersionSetDefaultFunc
): Boolean;

function ActivateManagedFPCVersionCore(
  const AVersion: string;
  AIsVersionInstalled: TFPCVersionInstalledFunc;
  AGetInstallPath: TFPCVersionGetInstallPathFunc;
  AActivateVersion: TFPCVersionActivateFunc;
  ASetDefaultVersion: TFPCVersionSetDefaultFunc
): TActivationResult;

implementation

uses
  SysUtils,
  fpdev.i18n,
  fpdev.i18n.strings;

function NormalizeDefaultFPCVersionCore(const ADefaultToolchain: string): string;
begin
  Result := Trim(ADefaultToolchain);
  if Pos('fpc-', Result) = 1 then
    Result := Copy(Result, 5, Length(Result));
end;

function WriteManagedFPCVersionListCore(
  const AVersions: TFPCVersionArray;
  const ADefaultToolchain: string;
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

  DefaultVersion := NormalizeDefaultFPCVersionCore(ADefaultToolchain);
  if AShowAll then
    AOut.WriteLn(_(CMD_FPC_LIST_ALL_HEADER))
  else
    AOut.WriteLn(_(CMD_FPC_LIST_HEADER));

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
    Line := Line + AVersions[I].Branch;
    AOut.WriteLn(Line);
  end;

  if DefaultVersion <> '' then
    AOut.WriteLn(_Fmt(CMD_FPC_CURRENT_VERSION, [DefaultVersion]))
  else
    AOut.WriteLn(_(CMD_FPC_CURRENT_NONE));

  Result := True;
end;

function SetManagedFPCDefaultVersionCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AIsVersionInstalled: TFPCVersionInstalledFunc;
  ASetDefaultVersion: TFPCVersionSetDefaultFunc
): Boolean;
begin
  Result := False;
  if Assigned(AIsVersionInstalled) and (not AIsVersionInstalled(AVersion)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_Fmt(CMD_FPC_USE_NOT_FOUND, [AVersion]));
    Exit(False);
  end;

  if not Assigned(ASetDefaultVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_FAILED) + ': set default version');
    Exit(False);
  end;

  Result := ASetDefaultVersion(AVersion);
  if Result then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(CMD_FPC_USE_ACTIVATED, [AVersion]));
  end
  else if Errp <> nil then
    Errp.WriteLn(_(MSG_FAILED) + ': set default version');
end;

function ActivateManagedFPCVersionCore(
  const AVersion: string;
  AIsVersionInstalled: TFPCVersionInstalledFunc;
  AGetInstallPath: TFPCVersionGetInstallPathFunc;
  AActivateVersion: TFPCVersionActivateFunc;
  ASetDefaultVersion: TFPCVersionSetDefaultFunc
): TActivationResult;
var
  InstallPath: string;
begin
  Initialize(Result);
  Result.Success := False;

  if Assigned(AIsVersionInstalled) and (not AIsVersionInstalled(AVersion)) then
  begin
    Result.ErrorMessage := 'FPC version ' + AVersion + ' is not installed';
    Exit;
  end;

  if not Assigned(AGetInstallPath) or not Assigned(AActivateVersion) then
  begin
    Result.ErrorMessage := 'Activation dependencies are incomplete';
    Exit;
  end;

  InstallPath := AGetInstallPath(AVersion);
  Result := AActivateVersion(AVersion, InstallPath + PathDelim + 'bin');
  if not Result.Success then
    Exit;

  if Assigned(ASetDefaultVersion) and ASetDefaultVersion(AVersion) then
    Exit;

  Result.ErrorMessage := 'Failed to set default version';
  Result.Success := False;
end;

end.
