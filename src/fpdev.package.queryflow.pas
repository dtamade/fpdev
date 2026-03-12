unit fpdev.package.queryflow;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.package.types;

type
  TPackageQueryArrayProvider = function: TPackageArray of object;
  TPackageQueryInfoProvider = function(const APackageName: string): TPackageInfo of object;

function ExecutePackageListCore(
  AShowAll: Boolean;
  AGetAvailablePackages, AGetInstalledPackages: TPackageQueryArrayProvider;
  const AInstalledHeader, AAvailableHeader, AInstalledEmpty, AAvailableEmpty: string;
  Outp: IOutput
): Boolean;

function ExecutePackageSearchCore(
  const AQuery: string;
  AGetAvailablePackages: TPackageQueryArrayProvider;
  const AInstalledLabel, AAvailableLabel, ANoResultsText: string;
  Outp: IOutput
): Boolean;

function ExecutePackageInfoCore(
  const APackageName: string;
  AGetPackageInfo: TPackageQueryInfoProvider;
  const ANameFmt, AVersionFmt, ADescriptionFmt, AInstallPathFmt: string;
  Outp: IOutput
): Boolean;

implementation

uses
  fpdev.package.listview,
  fpdev.package.searchview,
  fpdev.package.infoview;

function ExecutePackageListCore(
  AShowAll: Boolean;
  AGetAvailablePackages, AGetInstalledPackages: TPackageQueryArrayProvider;
  const AInstalledHeader, AAvailableHeader, AInstalledEmpty, AAvailableEmpty: string;
  Outp: IOutput
): Boolean;
var
  Packages: TPackageArray;
  Lines: TStringArray;
  Index: Integer;
begin
  Result := False;
  if not Assigned(Outp) then
    Exit;

  if AShowAll then
  begin
    if not Assigned(AGetAvailablePackages) then
      Exit;
    Packages := AGetAvailablePackages();
  end
  else
  begin
    if not Assigned(AGetInstalledPackages) then
      Exit;
    Packages := AGetInstalledPackages();
  end;

  Lines := BuildPackageListLinesCore(
    Packages,
    AShowAll,
    AInstalledHeader,
    AAvailableHeader,
    AInstalledEmpty,
    AAvailableEmpty
  );

  for Index := 0 to High(Lines) do
    Outp.WriteLn(Lines[Index]);

  Result := True;
end;

function ExecutePackageSearchCore(
  const AQuery: string;
  AGetAvailablePackages: TPackageQueryArrayProvider;
  const AInstalledLabel, AAvailableLabel, ANoResultsText: string;
  Outp: IOutput
): Boolean;
var
  Packages: TPackageArray;
  Lines: TStringArray;
  Index: Integer;
begin
  Result := False;
  if (Trim(AQuery) = '') or (not Assigned(Outp)) or (not Assigned(AGetAvailablePackages)) then
    Exit;

  Packages := AGetAvailablePackages();
  Lines := BuildPackageSearchLinesCore(
    Packages,
    AQuery,
    AInstalledLabel,
    AAvailableLabel,
    ANoResultsText
  );

  for Index := 0 to High(Lines) do
    Outp.WriteLn(Lines[Index]);

  Result := True;
end;

function ExecutePackageInfoCore(
  const APackageName: string;
  AGetPackageInfo: TPackageQueryInfoProvider;
  const ANameFmt, AVersionFmt, ADescriptionFmt, AInstallPathFmt: string;
  Outp: IOutput
): Boolean;
var
  PackageInfo: TPackageInfo;
  Lines: TStringArray;
  Index: Integer;
begin
  Result := False;
  if (not Assigned(Outp)) or (not Assigned(AGetPackageInfo)) then
    Exit;

  PackageInfo := AGetPackageInfo(APackageName);
  Lines := BuildPackageInfoLinesCore(
    PackageInfo,
    ANameFmt,
    AVersionFmt,
    ADescriptionFmt,
    AInstallPathFmt
  );

  for Index := 0 to High(Lines) do
    Outp.WriteLn(Lines[Index]);

  Result := True;
end;

end.
