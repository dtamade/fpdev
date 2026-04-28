unit fpdev.lazarus.pathflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function BuildLazarusVersionInstallPathCore(
  const AInstallRoot, AVersion: string
): string;

function BuildLazarusExecutablePathFromInstallPathCore(
  const AInstallPath: string;
  const AIsWindows: Boolean
): string;

function ResolveLazarusInstallPathCore(
  const ADefaultInstallPath, AConfiguredInstallPath: string;
  const AIsWindows: Boolean
): string;

function IsLazarusVersionInstalledCore(
  const AInstallPath: string;
  const AIsWindows: Boolean
): Boolean;

implementation

function BuildLazarusVersionInstallPathCore(
  const AInstallRoot, AVersion: string
): string;
begin
  Result := AInstallRoot + PathDelim + 'lazarus' + PathDelim + AVersion;
end;

function BuildLazarusExecutablePathFromInstallPathCore(
  const AInstallPath: string;
  const AIsWindows: Boolean
): string;
begin
  if AIsWindows then
    Result := AInstallPath + PathDelim + 'lazarus.exe'
  else
    Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'lazarus-ide';
end;

function ResolveLazarusInstallPathCore(
  const ADefaultInstallPath, AConfiguredInstallPath: string;
  const AIsWindows: Boolean
): string;
begin
  Result := ADefaultInstallPath;

  if (AConfiguredInstallPath <> '') and
     FileExists(BuildLazarusExecutablePathFromInstallPathCore(AConfiguredInstallPath, AIsWindows)) then
    Exit(AConfiguredInstallPath);

  if FileExists(BuildLazarusExecutablePathFromInstallPathCore(Result, AIsWindows)) then
    Exit;

  if AConfiguredInstallPath <> '' then
    Result := AConfiguredInstallPath;
end;

function IsLazarusVersionInstalledCore(
  const AInstallPath: string;
  const AIsWindows: Boolean
): Boolean;
begin
  Result := FileExists(BuildLazarusExecutablePathFromInstallPathCore(AInstallPath, AIsWindows));
end;

end.
