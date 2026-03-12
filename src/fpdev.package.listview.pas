unit fpdev.package.listview;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types;

function BuildPackageListLinesCore(
  const APackages: TPackageArray;
  AShowAll: Boolean;
  const AInstalledHeader, AAvailableHeader, AInstalledEmpty, AAvailableEmpty: string
): TStringArray;

implementation

function BuildPackageListLinesCore(
  const APackages: TPackageArray;
  AShowAll: Boolean;
  const AInstalledHeader, AAvailableHeader, AInstalledEmpty, AAvailableEmpty: string
): TStringArray;
var
  Index: Integer;
  Header: string;
  EmptyLine: string;
begin
  Result := nil;
  if AShowAll then
  begin
    Header := AAvailableHeader;
    EmptyLine := '  ' + AAvailableEmpty;
  end
  else
  begin
    Header := AInstalledHeader;
    EmptyLine := '  ' + AInstalledEmpty;
  end;

  if Length(APackages) = 0 then
  begin
    SetLength(Result, 2);
    Result[0] := Header;
    Result[1] := EmptyLine;
    Exit;
  end;

  SetLength(Result, Length(APackages) + 1);
  Result[0] := Header;
  for Index := 0 to High(APackages) do
    Result[Index + 1] := Format('  %-16s  %-10s  %s',
      [APackages[Index].Name, APackages[Index].Version, APackages[Index].Description]);
end;

end.
