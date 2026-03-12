unit fpdev.package.cleanflow;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

type
  TPackageCleanPathChecker = function(const APath: string): Boolean of object;
  TPackageCleanDeleteAction = function(const APath: string): Boolean of object;

function ExecutePackageCleanCore(
  const AScope, ASandboxDir, APackageCacheDir: string;
  APathExists: TPackageCleanPathChecker;
  ADeleteDirAction: TPackageCleanDeleteAction;
  Outp, Errp: IOutput
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function ExecutePackageCleanCore(
  const AScope, ASandboxDir, APackageCacheDir: string;
  APathExists: TPackageCleanPathChecker;
  ADeleteDirAction: TPackageCleanDeleteAction;
  Outp, Errp: IOutput
): Boolean;
var
  Scope: string;

  function CleanSection(const APath: string): Boolean;
  var
    Existed: Boolean;
  begin
    Result := True;
    if not Assigned(APathExists) then
      Exit(False);

    Existed := APathExists(APath);
    if Existed then
    begin
      if Assigned(ADeleteDirAction) then
        Result := ADeleteDirAction(APath)
      else
        Result := False;

      if Result then
      begin
        if Outp <> nil then
          Outp.WriteLn(_Fmt(MSG_CLEANED, [APath]));
      end
      else if Errp <> nil then
        Errp.WriteLn(_Fmt(MSG_CLEAN_FAILED, [APath]));
    end;
  end;

begin
  Result := True;
  Scope := LowerCase(Trim(AScope));

  if (Scope = 'sandbox') or (Scope = 'all') then
    Result := CleanSection(ASandboxDir) and Result;

  if (Scope = 'cache') or (Scope = 'all') then
    Result := CleanSection(APackageCacheDir) and Result;
end;

end.
