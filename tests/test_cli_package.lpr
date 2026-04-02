program test_cli_package;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_package - CLI tests for all package sub-commands
================================================================================

  Covers: install, uninstall, update, list, search, info, publish, clean,
          install-local, help, deps, why, repo list/add/remove/update

  B196-B198: Package command CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, fpjson, jsonparser,
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  fpdev.i18n, fpdev.i18n.strings,
  fpdev.config.interfaces,
  fpdev.utils,
  fpdev.utils.fs,
  fpdev.paths,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes,
  fpdev.cmd.package.root,
  fpdev.cmd.package.install,
  fpdev.cmd.package.uninstall,
  fpdev.cmd.package.update,
  fpdev.cmd.package.list,
  fpdev.cmd.package.search,
  fpdev.cmd.package.info,
  fpdev.cmd.package.publish,
  fpdev.cmd.package.clean,
  fpdev.cmd.package.install_local,
  fpdev.cmd.package.help,
  fpdev.cmd.package.deps,
  fpdev.cmd.package.why,
  fpdev.cmd.package.repo.root,
  fpdev.cmd.package.repo.list,
  fpdev.cmd.package.repo.add,
  fpdev.cmd.package.repo.remove,
  fpdev.cmd.package.repo.update,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

{$I test_cli_package_core.inc}

{$I test_cli_package_publish.inc}

{$I test_cli_package_local.inc}

{$I test_cli_package_repo.inc}

{$I test_cli_package_registration.inc}

{ ===== Main ===== }
begin
  WriteLn('=== Package Commands CLI Tests (B196-B198) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_pkg');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    WriteLn('--- install ---');
    TestInstallName;
    TestInstallHelp;
    TestInstallMissingPackage;
    TestInstallUnknownPackage;
    TestInstallUnexpectedArg;
    TestInstallUnknownOption;
    TestInstallDryRunOutput;

    WriteLn('');
    WriteLn('--- uninstall ---');
    TestUninstallName;
    TestUninstallHelp;
    TestUninstallMissingPackage;
    TestUninstallEmptyPackage;
    TestUninstallUnknownPackage;
    TestUninstallUnexpectedArg;
    TestUninstallUnknownOption;

    WriteLn('');
    WriteLn('--- update ---');
    TestUpdateName;
    TestUpdateHelp;
    TestUpdateMissingPackage;
    TestUpdateUnknownPackage;
    TestUpdateUnexpectedArg;
    TestUpdateUnknownOption;

    WriteLn('');
    WriteLn('--- list ---');
    TestListName;
    TestListAlias;
    TestListHelp;
    TestListNoArgs;
    TestListAllOutput;
    TestListJsonOutput;
    TestListUnexpectedArg;
    TestListUnknownOption;

    WriteLn('');
    WriteLn('--- search ---');
    TestSearchName;
    TestSearchHelp;
    TestSearchMissingQuery;
    TestSearchBlankQuery;
    TestSearchUnknownOption;
    TestSearchUnexpectedArg;
    TestSearchNoResultsOutput;
    TestSearchJsonUsesFPDEVDataRootRegistry;

    WriteLn('');
    WriteLn('--- info ---');
    TestInfoName;
    TestInfoHelp;
    TestInfoMissingPackage;
    TestInfoUnknownPackage;
    TestInfoUnexpectedArg;
    TestInfoUnknownOption;

    WriteLn('');
    WriteLn('--- publish ---');
    TestPublishName;
    TestPublishHelp;
    TestPublishMissingPackage;
    TestPublishEmptyPackage;
    TestPublishUnknownPackage;
    TestPublishMissingMetadata;
    TestPublishAfterInstallLocalUsesMetadataVersion;
    TestPublishWorksAfterOriginalSourceDeleted;
    TestPublishUsesFPDEVDataRootArchiveRoot;
    TestPublishRejectsInvalidMetadataSourcePath;
    TestPublishRejectsEmptyMetadataSourceFiles;
    TestPublishResolvesRelativeMetadataSourcePath;
    TestPublishReturnsIoErrorWhenMetadataUnreadable;
    TestPublishRejectsInvalidMetadataJson;
    TestPublishReturnsIoErrorWhenTarUnavailable;
    TestPublishUnexpectedArg;
    TestPublishUnknownOption;

    WriteLn('');
    WriteLn('--- clean ---');
    TestCleanName;
    TestCleanHelp;
    TestCleanMissingScope;
    TestCleanUnexpectedArg;
    TestCleanUnknownOption;

    WriteLn('');
    WriteLn('--- install-local ---');
    TestInstallLocalName;
    TestInstallLocalHelp;
    TestInstallLocalMissingPath;
    TestInstallLocalEmptyPath;
    TestInstallLocalPathNotFound;
    TestInstallLocalValidPath;
    TestInstallLocalUsesMetadataName;
    TestInstallLocalUnexpectedArg;
    TestInstallLocalUnknownOption;

    WriteLn('');
    WriteLn('--- help ---');
    TestHelpName;
    TestHelpNoArgs;
    TestHelpUnexpectedArg;

    WriteLn('');
    WriteLn('--- deps ---');
    TestDepsName;
    TestDepsAlias;
    TestDepsHelp;
    TestDepsNoArgs;
    TestDepsWithPackageName;
    TestDepsUnexpectedArg;
    TestDepsUnknownOption;
    TestDepsInvalidDepthOption;

    WriteLn('');
    WriteLn('--- why ---');
    TestWhyName;
    TestWhyHelp;
    TestWhyMissingPackage;
    TestWhyPackageOutput;
    TestWhyUnexpectedArg;
    TestWhyUnknownOption;
    TestPackageCoreRuntimeI18nKeys;

    WriteLn('');
    WriteLn('--- repo list ---');
    TestRepoListName;
    TestRepoListAlias;
    TestRepoListHelp;
    TestRepoListNoArgs;
    TestRepoListUnexpectedArg;
    TestRepoListUnknownOption;

    WriteLn('');
    WriteLn('--- repo add ---');
    TestRepoAddName;
    TestRepoAddHelp;
    TestRepoAddMissingArgs;
    TestRepoAddEmptyArgs;
    TestRepoAddDuplicateRepo;
    TestRepoAddUnexpectedArg;
    TestRepoAddUnknownOption;

    WriteLn('');
    WriteLn('--- repo remove ---');
    TestRepoRemoveName;
    TestRepoRemoveAliases;
    TestRepoRemoveHelp;
    TestRepoRemoveMissingName;
    TestRepoRemoveEmptyName;
    TestRepoRemoveUnknownRepo;
    TestRepoRemoveUnexpectedArg;
    TestRepoRemoveUnknownOption;

    WriteLn('');
    WriteLn('--- repo update ---');
    TestRepoUpdateName;
    TestRepoUpdateHelp;
    TestRepoUpdateNoArgs;
    TestRepoUpdateUnexpectedArg;
    TestRepoUpdateUnknownOption;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestPackageRegistration;
    TestPackageRepoRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
