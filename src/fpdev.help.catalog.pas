unit fpdev.help.catalog;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

type
  THelpListItem = record
    Name: string;
    Description: string;
  end;

  THelpListItems = array of THelpListItem;

procedure WriteHelpItemsCore(const Outp: IOutput; const AItems: array of THelpListItem);
function BuildFPCHelpItems: THelpListItems;
function BuildPackageHelpItems: THelpListItems;
function BuildProjectHelpItems: THelpListItems;
function BuildCrossHelpItems: THelpListItems;
function BuildLazarusHelpItems: THelpListItems;
function BuildRepoHelpItems: THelpListItems;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function MakeHelpItem(const AName, ADescription: string): THelpListItem;
begin
  Result.Name := AName;
  Result.Description := ADescription;
end;

function PadRight(const S: string; AWidth: Integer): string;
begin
  Result := S;
  while Length(Result) < AWidth do
    Result := Result + ' ';
end;

procedure WriteHelpItemsCore(const Outp: IOutput; const AItems: array of THelpListItem);
var
  Index: Integer;
  Width: Integer;
begin
  if Outp = nil then
    Exit;

  Width := 0;
  for Index := Low(AItems) to High(AItems) do
    if Length(AItems[Index].Name) > Width then
      Width := Length(AItems[Index].Name);

  for Index := Low(AItems) to High(AItems) do
    Outp.WriteLn('  ' + PadRight(AItems[Index].Name, Width) + '  ' + AItems[Index].Description);
end;

function BuildFPCHelpItems: THelpListItems;
begin
  Result := nil;
  SetLength(Result, 16);
  Result[0] := MakeHelpItem('install', _(HELP_FPC_INSTALL_DESC));
  Result[1] := MakeHelpItem('uninstall', _(HELP_FPC_UNINSTALL_DESC));
  Result[2] := MakeHelpItem('list', _(HELP_FPC_LIST_DESC));
  Result[3] := MakeHelpItem('use', _(HELP_FPC_USE_DESC));
  Result[4] := MakeHelpItem('current', _(HELP_FPC_CURRENT_DESC));
  Result[5] := MakeHelpItem('status', _(HELP_FPC_STATUS_DESC));
  Result[6] := MakeHelpItem('show', _(HELP_FPC_SHOW_DESC));
  Result[7] := MakeHelpItem('doctor', _(HELP_FPC_DOCTOR_DESC));
  Result[8] := MakeHelpItem('test', _(HELP_FPC_TEST_DESC));
  Result[9] := MakeHelpItem('verify', 'Verify an installed FPC version');
  Result[10] := MakeHelpItem('auto-install', 'Install toolchain from project config');
  Result[11] := MakeHelpItem('update', _(HELP_FPC_UPDATE_DESC));
  Result[12] := MakeHelpItem('update-manifest', 'Refresh remote FPC manifest cache');
  Result[13] := MakeHelpItem('cache', 'Manage local FPC artifact cache');
  Result[14] := MakeHelpItem('policy', 'Check FPC source-version policy');
  Result[15] := MakeHelpItem('help', _(HELP_SHOW_HELP));
end;

function BuildPackageHelpItems: THelpListItems;
begin
  Result := nil;
  SetLength(Result, 13);
  Result[0] := MakeHelpItem('install', _(HELP_PACKAGE_INSTALL_DESC));
  Result[1] := MakeHelpItem('uninstall', _(HELP_PACKAGE_UNINSTALL_DESC));
  Result[2] := MakeHelpItem('update', _(HELP_PACKAGE_UPDATE_DESC));
  Result[3] := MakeHelpItem('list', _(HELP_PACKAGE_LIST_DESC));
  Result[4] := MakeHelpItem('search', _(HELP_PACKAGE_SEARCH_DESC));
  Result[5] := MakeHelpItem('info', _(HELP_PACKAGE_INFO_DESC));
  Result[6] := MakeHelpItem('publish', _(HELP_PACKAGE_PUBLISH_DESC));
  Result[7] := MakeHelpItem('clean', _(HELP_PACKAGE_CLEAN_DESC));
  Result[8] := MakeHelpItem('install-local', _(HELP_PACKAGE_INSTALL_LOCAL_DESC));
  Result[9] := MakeHelpItem('repo', _(HELP_PACKAGE_REPO_DESC));
  Result[10] := MakeHelpItem('deps', _(HELP_PACKAGE_DEPS_DESC));
  Result[11] := MakeHelpItem('why', _(HELP_PACKAGE_WHY_DESC));
  Result[12] := MakeHelpItem('help', _(HELP_SHOW_HELP));
end;

function BuildProjectHelpItems: THelpListItems;
begin
  Result := nil;
  SetLength(Result, 9);
  Result[0] := MakeHelpItem('new', _(HELP_PROJECT_NEW_DESC));
  Result[1] := MakeHelpItem('list', _(HELP_PROJECT_LIST_DESC));
  Result[2] := MakeHelpItem('info', _(HELP_PROJECT_INFO_DESC));
  Result[3] := MakeHelpItem('build', _(HELP_PROJECT_BUILD_DESC));
  Result[4] := MakeHelpItem('run', _(HELP_PROJECT_RUN_DESC));
  Result[5] := MakeHelpItem('test', _(HELP_PROJECT_TEST_DESC));
  Result[6] := MakeHelpItem('clean', _(HELP_PROJECT_CLEAN_DESC));
  Result[7] := MakeHelpItem('template', 'Manage project templates');
  Result[8] := MakeHelpItem('help', _(HELP_SHOW_HELP));
end;

function BuildCrossHelpItems: THelpListItems;
begin
  Result := nil;
  SetLength(Result, 13);
  Result[0] := MakeHelpItem('list', _(HELP_CROSS_LIST_DESC));
  Result[1] := MakeHelpItem('install', _(HELP_CROSS_INSTALL_DESC));
  Result[2] := MakeHelpItem('uninstall', _(HELP_CROSS_UNINSTALL_DESC));
  Result[3] := MakeHelpItem('enable', _(HELP_CROSS_ENABLE_DESC));
  Result[4] := MakeHelpItem('disable', _(HELP_CROSS_DISABLE_DESC));
  Result[5] := MakeHelpItem('show', _(HELP_CROSS_SHOW_DESC));
  Result[6] := MakeHelpItem('test', _(HELP_CROSS_TEST_DESC));
  Result[7] := MakeHelpItem('configure', _(HELP_CROSS_CONFIGURE_DESC));
  Result[8] := MakeHelpItem('update', _(HELP_CROSS_UPDATE_DESC));
  Result[9] := MakeHelpItem('clean', _(HELP_CROSS_CLEAN_DESC));
  Result[10] := MakeHelpItem('build', _(HELP_CROSS_BUILD_DESC));
  Result[11] := MakeHelpItem('doctor', _(HELP_CROSS_DOCTOR_DESC));
  Result[12] := MakeHelpItem('help', _(HELP_SHOW_HELP));
end;

function BuildLazarusHelpItems: THelpListItems;
begin
  Result := nil;
  SetLength(Result, 12);
  Result[0] := MakeHelpItem('install', _(HELP_LAZARUS_INSTALL_DESC));
  Result[1] := MakeHelpItem('uninstall', _(HELP_LAZARUS_UNINSTALL_DESC));
  Result[2] := MakeHelpItem('list', _(HELP_LAZARUS_LIST_DESC));
  Result[3] := MakeHelpItem('use', _(HELP_LAZARUS_USE_DESC));
  Result[4] := MakeHelpItem('current', _(HELP_LAZARUS_CURRENT_DESC));
  Result[5] := MakeHelpItem('show', _(HELP_LAZARUS_SHOW_DESC));
  Result[6] := MakeHelpItem('run', _(HELP_LAZARUS_RUN_DESC));
  Result[7] := MakeHelpItem('test', _(HELP_LAZARUS_TEST_DESC));
  Result[8] := MakeHelpItem('doctor', _(HELP_LAZARUS_DOCTOR_DESC));
  Result[9] := MakeHelpItem('update', _(HELP_LAZARUS_UPDATE_DESC));
  Result[10] := MakeHelpItem('configure', _(HELP_LAZARUS_CONFIGURE_DESC));
  Result[11] := MakeHelpItem('help', _(HELP_SHOW_HELP));
end;

function BuildRepoHelpItems: THelpListItems;
begin
  Result := nil;
  SetLength(Result, 7);
  Result[0] := MakeHelpItem('add', _(HELP_REPO_ADD_DESC));
  Result[1] := MakeHelpItem('remove', _(HELP_REPO_REMOVE_DESC));
  Result[2] := MakeHelpItem('list', _(HELP_REPO_LIST_DESC));
  Result[3] := MakeHelpItem('show', _(HELP_REPO_SHOW_DESC));
  Result[4] := MakeHelpItem('versions', _(HELP_REPO_VERSIONS_DESC));
  Result[5] := MakeHelpItem('use', _(HELP_REPO_DEFAULT_DESC));
  Result[6] := MakeHelpItem('help', _(HELP_SHOW_HELP));
end;

end.
