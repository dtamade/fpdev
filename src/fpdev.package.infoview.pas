unit fpdev.package.infoview;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types;

function BuildPackageInfoLinesCore(
  const AInfo: TPackageInfo;
  const ANameFmt, AVersionFmt, ADescriptionFmt, AInstallPathFmt: string
): TStringArray;

implementation

function BuildPackageInfoLinesCore(
  const AInfo: TPackageInfo;
  const ANameFmt, AVersionFmt, ADescriptionFmt, AInstallPathFmt: string
): TStringArray;
begin
  Result := nil;
  if AInfo.Installed then
  begin
    SetLength(Result, 4);
    Result[3] := Format(AInstallPathFmt, [AInfo.InstallPath]);
  end
  else
    SetLength(Result, 3);

  Result[0] := Format(ANameFmt, [AInfo.Name]);
  Result[1] := Format(AVersionFmt, [AInfo.Version]);
  Result[2] := Format(ADescriptionFmt, [AInfo.Description]);
end;

end.
