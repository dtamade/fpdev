unit fpdev.package.query.available;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types,
  fpdev.resource.repo.types;

type
  TAvailablePackageRepoLister = function(const ACategory: string): SysUtils.TStringArray of object;
  TAvailablePackageRepoInfoGetter = function(const AName, AVersion: string;
    out AInfo: TRepoPackageInfo): Boolean of object;
  TAvailablePackageInstalledChecker = function(const APackageName: string): Boolean of object;
  TAvailablePackageIndexLoader = function(const AIndexPath: string): TPackageArray of object;

function GetAvailablePackagesCore(const APackageRegistry: string;
  const APackageNamePathSeparator: Char;
  ARepoListPackages: TAvailablePackageRepoLister;
  ARepoGetPackageInfo: TAvailablePackageRepoInfoGetter;
  AIsInstalled: TAvailablePackageInstalledChecker;
  AParseLocalPackageIndex: TAvailablePackageIndexLoader): TPackageArray;

implementation

function GetAvailablePackagesCore(const APackageRegistry: string;
  const APackageNamePathSeparator: Char;
  ARepoListPackages: TAvailablePackageRepoLister;
  ARepoGetPackageInfo: TAvailablePackageRepoInfoGetter;
  AIsInstalled: TAvailablePackageInstalledChecker;
  AParseLocalPackageIndex: TAvailablePackageIndexLoader): TPackageArray;
var
  RepoPackages: SysUtils.TStringArray;
  RepoInfo: TRepoPackageInfo;
  Pkg: TPackageInfo;
  i, Count: Integer;
begin
  Initialize(Result);
  SetLength(Result, 0);

  if Assigned(ARepoListPackages) and Assigned(ARepoGetPackageInfo) then
  begin
    RepoPackages := ARepoListPackages('');
    if Length(RepoPackages) > 0 then
    begin
      SetLength(Result, Length(RepoPackages));
      Count := 0;
      for i := 0 to High(RepoPackages) do
      begin
        if (Length(RepoPackages[i]) > 0) and
           ((RepoPackages[i][Length(RepoPackages[i])] = APackageNamePathSeparator) or
            (RepoPackages[i][Length(RepoPackages[i])] = PathDelim)) then
          Continue;

        Initialize(Pkg);
        if ARepoGetPackageInfo(RepoPackages[i], '', RepoInfo) then
        begin
          Pkg.Name := RepoInfo.Name;
          Pkg.Version := RepoInfo.Version;
          Pkg.Description := RepoInfo.Description;
          if Assigned(AIsInstalled) then
            Pkg.Installed := AIsInstalled(Pkg.Name)
          else
            Pkg.Installed := False;
          Result[Count] := Pkg;
          Inc(Count);
        end;
      end;
      SetLength(Result, Count);
      if Count > 0 then
        Exit;
    end;
  end;

  if Assigned(AParseLocalPackageIndex) then
    Result := AParseLocalPackageIndex(APackageRegistry + PathDelim + 'index.json');
end;

end.
