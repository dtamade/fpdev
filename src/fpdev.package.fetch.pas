unit fpdev.package.fetch;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types,
  fpdev.toolchain.fetcher;

type
  TPackageDownloadRunner = function(
    const AURLs: array of string;
    const DestFile: string;
    const Opt: TFetchOptions;
    out AErr: string
  ): Boolean;

  TPackageDownloadPlan = record
    PackageInfo: TPackageInfo;
    ZipPath: string;
    URLs: TStringArray;
    FetchOptions: TFetchOptions;
  end;

function BuildPackageDownloadPlanCore(const APackageName, AVersion, ACacheDir: string;
  const AAvailablePackages: TPackageArray; out APlan: TPackageDownloadPlan): Boolean;
function DownloadPackageCore(const APackageName, AVersion, ACacheDir: string;
  const AAvailablePackages: TPackageArray; ADownloadRunner: TPackageDownloadRunner): Boolean;

implementation

uses
  fpdev.utils,
  fpdev.utils.fs;

function BuildPackageDownloadPlanCore(const APackageName, AVersion, ACacheDir: string;
  const AAvailablePackages: TPackageArray; out APlan: TPackageDownloadPlan): Boolean;
var
  i, BestIdx: Integer;
begin
  Result := False;
  Initialize(APlan.PackageInfo);
  APlan.ZipPath := '';
  APlan.URLs := nil;
  APlan.FetchOptions := Default(TFetchOptions);

  if APackageName = '' then
    Exit;

  BestIdx := -1;
  for i := 0 to High(AAvailablePackages) do
  begin
    if SameText(AAvailablePackages[i].Name, APackageName) then
    begin
      if AVersion = '' then
      begin
        if (BestIdx < 0) or IsVersionHigher(AAvailablePackages[i].Version, AAvailablePackages[BestIdx].Version) then
          BestIdx := i;
      end
      else if SameText(AAvailablePackages[i].Version, AVersion) then
        BestIdx := i;
    end;
  end;

  if BestIdx < 0 then
    Exit;
  if Length(AAvailablePackages[BestIdx].URLs) = 0 then
    Exit;

  APlan.PackageInfo := AAvailablePackages[BestIdx];
  APlan.ZipPath := IncludeTrailingPathDelimiter(ACacheDir) + 'packages' + PathDelim +
    APackageName + '-' + APlan.PackageInfo.Version + '.zip';
  EnsureDir(ExtractFileDir(APlan.ZipPath));

  SetLength(APlan.URLs, Length(AAvailablePackages[BestIdx].URLs));
  for i := 0 to High(APlan.URLs) do
    APlan.URLs[i] := AAvailablePackages[BestIdx].URLs[i];

  APlan.FetchOptions.DestDir := ExtractFileDir(APlan.ZipPath);
  APlan.FetchOptions.Hash := AAvailablePackages[BestIdx].Sha256;
  APlan.FetchOptions.HashAlgorithm := haSHA256;
  APlan.FetchOptions.HashDigest := AAvailablePackages[BestIdx].Sha256;
  APlan.FetchOptions.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;
  APlan.FetchOptions.ExpectedSize := 0;
  Result := True;
end;

function DownloadPackageCore(const APackageName, AVersion, ACacheDir: string;
  const AAvailablePackages: TPackageArray; ADownloadRunner: TPackageDownloadRunner): Boolean;
var
  Plan: TPackageDownloadPlan;
  Err: string;
begin
  Result := BuildPackageDownloadPlanCore(APackageName, AVersion, ACacheDir, AAvailablePackages, Plan)
    and Assigned(ADownloadRunner)
    and ADownloadRunner(Plan.URLs, Plan.ZipPath, Plan.FetchOptions, Err);
end;

end.
