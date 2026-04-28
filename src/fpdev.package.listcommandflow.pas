unit fpdev.package.listcommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.package.types;

type
  TPackageListCommandPlan = record
    ShowAll: Boolean;
    JsonOutput: Boolean;
  end;

  TPackageListCommandListPackagesFunc = function(
    const AShowAll: Boolean;
    Outp: IOutput
  ): Boolean of object;
  TPackageListCommandGetPackagesFunc = function: TPackageArray of object;

function PreparePackageListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageListCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageListCommandPlanCore(
  const APlan: TPackageListCommandPlan;
  const AOut, AErr: IOutput;
  AListPackages: TPackageListCommandListPackagesFunc;
  AGetAvailablePackages: TPackageListCommandGetPackagesFunc;
  AGetInstalledPackages: TPackageListCommandGetPackagesFunc
): Integer;

implementation

uses
  SysUtils, fpjson,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteListUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
end;

procedure WriteListHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_LIST_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_LIST_OPTIONS));
  AOut.WriteLn(_(HELP_PACKAGE_LIST_OPT_ALL));
  AOut.WriteLn(_(HELP_PACKAGE_LIST_OPT_JSON));
  AOut.WriteLn(_(HELP_PACKAGE_LIST_OPT_HELP));
end;

function PackageInfoToJson(const AInfo: TPackageInfo): TJSONObject;
var
  LDeps: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.Add('name', AInfo.Name);
  Result.Add('version', AInfo.Version);
  Result.Add('description', AInfo.Description);
  Result.Add('author', AInfo.Author);
  Result.Add('license', AInfo.License);
  Result.Add('homepage', AInfo.Homepage);
  LDeps := TJSONArray.Create;
  for I := 0 to High(AInfo.Dependencies) do
    LDeps.Add(AInfo.Dependencies[I]);
  Result.Add('dependencies', LDeps);
end;

function PreparePackageListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageListCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageListCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteListHelp(AOut);
    Exit(EXIT_OK);
  end;

  APlan.ShowAll := HasFlag(AParams, 'all') or HasFlag(AParams, 'a');
  APlan.JsonOutput := HasFlag(AParams, 'json');

  if FindUnknownOption(AParams, ['--all', '-a', '--json'], UnknownOption) then
  begin
    AShouldExit := True;
    WriteListUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 0 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      AShouldExit := True;
      WriteListUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
end;

function ExecutePackageListCommandPlanCore(
  const APlan: TPackageListCommandPlan;
  const AOut, AErr: IOutput;
  AListPackages: TPackageListCommandListPackagesFunc;
  AGetAvailablePackages: TPackageListCommandGetPackagesFunc;
  AGetInstalledPackages: TPackageListCommandGetPackagesFunc
): Integer;
var
  LPackages: TPackageArray;
  LJson: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  Result := EXIT_ERROR;

  if APlan.JsonOutput then
  begin
    if APlan.ShowAll then
    begin
      if not Assigned(AGetAvailablePackages) then
      begin
        if AErr <> nil then
          AErr.WriteLn(_(MSG_ERROR));
        Exit(EXIT_ERROR);
      end;
      LPackages := AGetAvailablePackages();
    end
    else
    begin
      if not Assigned(AGetInstalledPackages) then
      begin
        if AErr <> nil then
          AErr.WriteLn(_(MSG_ERROR));
        Exit(EXIT_ERROR);
      end;
      LPackages := AGetInstalledPackages();
    end;

    LJson := TJSONObject.Create;
    try
      LArr := TJSONArray.Create;
      for I := 0 to High(LPackages) do
        LArr.Add(PackageInfoToJson(LPackages[I]));
      LJson.Add('packages', LArr);
      LJson.Add('show_all', APlan.ShowAll);
      if AOut <> nil then
        AOut.WriteLn(LJson.FormatJSON);
    finally
      LJson.Free;
    end;
    Exit(EXIT_OK);
  end;

  if not Assigned(AListPackages) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if AListPackages(APlan.ShowAll, AOut) then
    Exit(EXIT_OK);
end;

end.
