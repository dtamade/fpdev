unit fpdev.package.query.info;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.package.types;

function GetPackageInstallPathCore(const APackageRegistry, APackageName: string): string;
function IsPackageInstalledCore(const APackageRegistry, APackageName: string): Boolean;
function ValidatePackageNameCore(const APackageName, APathSeparator: string): Boolean;
function GetPackageInfoCore(const APackageName, APackageRegistry,
  AFallbackDescription: string): TPackageInfo;

implementation

uses
  Classes, fpjson, jsonparser;

function GetPackageInstallPathCore(const APackageRegistry, APackageName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(APackageRegistry) + APackageName;
end;

function IsPackageInstalledCore(const APackageRegistry, APackageName: string): Boolean;
begin
  Result := DirectoryExists(GetPackageInstallPathCore(APackageRegistry, APackageName));
end;

function ValidatePackageNameCore(const APackageName, APathSeparator: string): Boolean;
begin
  Result := (APackageName <> '') and
            (Pos(' ', APackageName) = 0) and
            (Pos(APathSeparator, APackageName) = 0);
end;

function GetPackageInfoCore(const APackageName, APackageRegistry,
  AFallbackDescription: string): TPackageInfo;
var
  MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
begin
  Initialize(Result);
  Result.Name := APackageName;
  Result.Installed := IsPackageInstalledCore(APackageRegistry, APackageName);

  if Result.Installed then
  begin
    Result.InstallPath := GetPackageInstallPathCore(APackageRegistry, APackageName);
    MetaPath := IncludeTrailingPathDelimiter(Result.InstallPath) + 'package.json';
    if FileExists(MetaPath) then
    begin
      SL := TStringList.Create;
      try
        try
          SL.LoadFromFile(MetaPath);
          J := GetJSON(SL.Text);
          try
            if J.JSONType = jtObject then
            begin
              O := TJSONObject(J);
              Result.Name := O.Get('name', APackageName);
              Result.Version := O.Get('version', '');
              Result.Description := O.Get('description', '');
              Result.Homepage := O.Get('homepage', '');
              Result.License := O.Get('license', '');
              Result.Repository := O.Get('repository', '');
              Result.SourcePath := O.Get('source_path', '');
            end;
          finally
            J.Free;
          end;
        except
          Result.Version := '';
          Result.Description := AFallbackDescription;
        end;
      finally
        SL.Free;
      end;
    end
    else
    begin
      Result.Version := '';
      Result.Description := AFallbackDescription;
    end;
  end;
end;

end.
