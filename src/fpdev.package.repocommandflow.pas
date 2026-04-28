unit fpdev.package.repocommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TPackageRepoAddCommandPlan = record
    RepoName: string;
    URL: string;
  end;

  TPackageRepoListCommandPlan = record
  end;

  TPackageRepoRemoveCommandPlan = record
    RepoName: string;
  end;

  TPackageRepoUpdateCommandPlan = record
  end;

  TPackageRepoAddCommandFunc = function(
    const AName, AURL: string;
    Outp, Errp: IOutput
  ): Boolean of object;
  TPackageRepoListCommandFunc = function(Outp: IOutput): Boolean of object;
  TPackageRepoRemoveCommandFunc = function(
    const AName: string;
    Outp, Errp: IOutput
  ): Boolean of object;
  TPackageRepoUpdateCommandFunc = function(Outp, Errp: IOutput): Boolean of object;

function PreparePackageRepoAddCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoAddCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageRepoAddCommandPlanCore(
  const APlan: TPackageRepoAddCommandPlan;
  const AOut, AErr: IOutput;
  const ARepositoryExists: Boolean;
  AAddRepository: TPackageRepoAddCommandFunc
): Integer;

function PreparePackageRepoListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoListCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageRepoListCommandPlanCore(
  const AOut: IOutput;
  AListRepositories: TPackageRepoListCommandFunc
): Integer;

function PreparePackageRepoRemoveCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoRemoveCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageRepoRemoveCommandPlanCore(
  const APlan: TPackageRepoRemoveCommandPlan;
  const AOut, AErr: IOutput;
  const ARepositoryExists: Boolean;
  ARemoveRepository: TPackageRepoRemoveCommandFunc
): Integer;

function PreparePackageRepoUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageRepoUpdateCommandPlanCore(
  const AOut, AErr: IOutput;
  AUpdateRepositories: TPackageRepoUpdateCommandFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteRepoAddUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_REPO_ADD_USAGE));
end;

procedure WriteRepoAddHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_REPO_ADD_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_ADD_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_ADD_OPT_HELP));
end;

procedure WriteRepoListUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_REPO_LIST_USAGE));
end;

procedure WriteRepoListHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_REPO_LIST_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_LIST_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_LIST_OPT_HELP));
end;

procedure WriteRepoRemoveUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
end;

procedure WriteRepoRemoveHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_REMOVE_OPT_HELP));
end;

procedure WriteRepoUpdateUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_REPO_UPDATE_USAGE));
end;

procedure WriteRepoUpdateHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_REPO_UPDATE_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_UPDATE_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_REPO_UPDATE_OPT_HELP));
end;

function PreparePackageRepoAddCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoAddCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageRepoAddCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteRepoAddHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteRepoAddUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 2 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name, url']));
    WriteRepoAddUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.RepoName := AParams[0];
  APlan.URL := AParams[1];
  if (Trim(APlan.RepoName) = '') or (Trim(APlan.URL) = '') then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name, url']));
    WriteRepoAddUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 2 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      AShouldExit := True;
      WriteRepoAddUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
end;

function ExecutePackageRepoAddCommandPlanCore(
  const APlan: TPackageRepoAddCommandPlan;
  const AOut, AErr: IOutput;
  const ARepositoryExists: Boolean;
  AAddRepository: TPackageRepoAddCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if ARepositoryExists then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _(MSG_ALREADY_EXISTS) + ': ' + APlan.RepoName);
    Exit(EXIT_ALREADY_EXISTS);
  end;

  if not Assigned(AAddRepository) then
    Exit(EXIT_ERROR);

  if AAddRepository(APlan.RepoName, APlan.URL, AOut, AErr) then
    Exit(EXIT_OK);
end;

function PreparePackageRepoListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoListCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageRepoListCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteRepoListHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteRepoListUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 0 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      AShouldExit := True;
      WriteRepoListUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
end;

function ExecutePackageRepoListCommandPlanCore(
  const AOut: IOutput;
  AListRepositories: TPackageRepoListCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not Assigned(AListRepositories) then
    Exit(EXIT_ERROR);

  if AListRepositories(AOut) then
    Exit(EXIT_OK);
end;

function PreparePackageRepoRemoveCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoRemoveCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageRepoRemoveCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteRepoRemoveHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteRepoRemoveUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name']));
    WriteRepoRemoveUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.RepoName := AParams[0];
  if Trim(APlan.RepoName) = '' then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name']));
    WriteRepoRemoveUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 1 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      AShouldExit := True;
      WriteRepoRemoveUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
end;

function ExecutePackageRepoRemoveCommandPlanCore(
  const APlan: TPackageRepoRemoveCommandPlan;
  const AOut, AErr: IOutput;
  const ARepositoryExists: Boolean;
  ARemoveRepository: TPackageRepoRemoveCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not ARepositoryExists then
  begin
    if AErr <> nil then
      AErr.WriteLn(_Fmt(CMD_REPO_NOT_FOUND, [APlan.RepoName]));
    Exit(EXIT_NOT_FOUND);
  end;

  if not Assigned(ARemoveRepository) then
    Exit(EXIT_ERROR);

  if ARemoveRepository(APlan.RepoName, AOut, AErr) then
    Exit(EXIT_OK);
end;

function PreparePackageRepoUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageRepoUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageRepoUpdateCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteRepoUpdateHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteRepoUpdateUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 0 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      AShouldExit := True;
      WriteRepoUpdateUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
end;

function ExecutePackageRepoUpdateCommandPlanCore(
  const AOut, AErr: IOutput;
  AUpdateRepositories: TPackageRepoUpdateCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not Assigned(AUpdateRepositories) then
    Exit(EXIT_ERROR);

  if AUpdateRepositories(AOut, AErr) then
    Exit(EXIT_OK);
end;

end.
