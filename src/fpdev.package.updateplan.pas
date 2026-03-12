unit fpdev.package.updateplan;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  fpdev.package.types;

type
  TPackageUpdatePlan = record
    LatestVersion: string;
    UpdateNeeded: Boolean;
  end;

function BuildPackageUpdatePlanCore(const APackageName, AInstalledVersion: string;
  const AAvailablePackages: TPackageArray; out APlan: TPackageUpdatePlan): Boolean;

implementation

uses
  SysUtils,
  fpdev.utils;

function BuildPackageUpdatePlanCore(const APackageName, AInstalledVersion: string;
  const AAvailablePackages: TPackageArray; out APlan: TPackageUpdatePlan): Boolean;
var
  BestIdx, Index: Integer;
begin
  Result := False;
  APlan.LatestVersion := '';
  APlan.UpdateNeeded := False;

  BestIdx := -1;
  for Index := 0 to High(AAvailablePackages) do
  begin
    if SameText(AAvailablePackages[Index].Name, APackageName) then
    begin
      if (BestIdx < 0) or IsVersionHigher(AAvailablePackages[Index].Version, AAvailablePackages[BestIdx].Version) then
        BestIdx := Index;
    end;
  end;

  if BestIdx < 0 then
    Exit;

  APlan.LatestVersion := AAvailablePackages[BestIdx].Version;
  APlan.UpdateNeeded := IsVersionHigher(APlan.LatestVersion, AInstalledVersion);
  Result := True;
end;

end.
