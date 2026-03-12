unit fpdev.package.searchview;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types;

function BuildPackageSearchLinesCore(
  const APackages: TPackageArray;
  const AQuery, AInstalledLabel, AAvailableLabel, ANoResultsText: string
): TStringArray;

implementation

function BuildPackageSearchLinesCore(
  const APackages: TPackageArray;
  const AQuery, AInstalledLabel, AAvailableLabel, ANoResultsText: string
): TStringArray;
var
  Index, MatchCount: Integer;
  LowerQuery: string;
  StatusLabel: string;
begin
  Result := nil;
  MatchCount := 0;
  LowerQuery := LowerCase(Trim(AQuery));

  for Index := 0 to High(APackages) do
  begin
    if (Pos(LowerQuery, LowerCase(APackages[Index].Name)) > 0) or
       (Pos(LowerQuery, LowerCase(APackages[Index].Description)) > 0) then
    begin
      SetLength(Result, MatchCount + 1);
      if APackages[Index].Installed then
        StatusLabel := AInstalledLabel
      else
        StatusLabel := AAvailableLabel;
      Result[MatchCount] := Format('%-16s  %-10s  %-10s  %s',
        [APackages[Index].Name, APackages[Index].Version, StatusLabel, APackages[Index].Description]);
      Inc(MatchCount);
    end;
  end;

  if MatchCount = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := ANoResultsText + ': ' + AQuery;
  end;
end;

end.
