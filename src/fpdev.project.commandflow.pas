unit fpdev.project.commandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.project.templateflow;

type
  TProjectTemplate = fpdev.project.templateflow.TProjectTemplate;
  TProjectTemplateArray = fpdev.project.templateflow.TProjectTemplateArray;

  TProjectListCommandPlan = record
    JsonOutput: Boolean;
  end;

  TProjectInfoCommandPlan = record
    TemplateName: string;
  end;

  TProjectBuildCommandPlan = record
    ProjectDir: string;
    Target: string;
  end;

  TProjectDirectoryCommandPlan = record
    ProjectDir: string;
  end;

  TProjectNewCommandPlan = record
    TemplateName: string;
    ProjectName: string;
    TargetDir: string;
  end;

  TProjectListTemplatesFunc = function(const Outp: IOutput): Boolean of object;
  TProjectGetTemplateListFunc = function: TProjectTemplateArray of object;
  TProjectShowTemplateInfoFunc = function(
    const Outp, Errp: IOutput;
    const ATemplateName: string
  ): Boolean of object;
  TProjectBuildFunc = function(
    const AProjectDir: string;
    const ATarget: string
  ): Boolean of object;
  TProjectDirectoryActionFunc = function(
    const Outp, Errp: IOutput;
    const AProjectDir: string
  ): Boolean of object;
  TProjectCreateFunc = function(
    const ATemplateName, AProjectName, ATargetDir: string
  ): Boolean of object;

function PrepareProjectListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectListCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectListCommandPlanCore(
  const APlan: TProjectListCommandPlan;
  const AOut, AErr: IOutput;
  AListTemplates: TProjectListTemplatesFunc;
  AGetTemplateList: TProjectGetTemplateListFunc
): Integer;

function PrepareProjectInfoCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectInfoCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectInfoCommandPlanCore(
  const APlan: TProjectInfoCommandPlan;
  const AOut, AErr: IOutput;
  AShowTemplateInfo: TProjectShowTemplateInfoFunc
): Integer;

function PrepareProjectBuildCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectBuildCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectBuildCommandPlanCore(
  const APlan: TProjectBuildCommandPlan;
  const AOut, AErr: IOutput;
  ABuildProject: TProjectBuildFunc
): Integer;

function PrepareProjectTestCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectDirectoryCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectTestCommandPlanCore(
  const APlan: TProjectDirectoryCommandPlan;
  const AOut, AErr: IOutput;
  ATestProject: TProjectDirectoryActionFunc
): Integer;

function PrepareProjectCleanCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectDirectoryCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectCleanCommandPlanCore(
  const APlan: TProjectDirectoryCommandPlan;
  const AOut, AErr: IOutput;
  ACleanProject: TProjectDirectoryActionFunc
): Integer;

function PrepareProjectNewCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectNewCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectNewCommandPlanCore(
  const APlan: TProjectNewCommandPlan;
  const AOut, AErr: IOutput;
  ACreateProject: TProjectCreateFunc
): Integer;

implementation

uses
  SysUtils, fpjson,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.project.generator;

type
  TProjectLeafKind = (
    plkList,
    plkInfo,
    plkBuild,
    plkTest,
    plkClean,
    plkNew
  );

procedure WriteProjectLeafUsage(const AOut: IOutput; const AKind: TProjectLeafKind);
begin
  if AOut = nil then
    Exit;

  case AKind of
    plkList:
      AOut.WriteLn(_(HELP_PROJECT_LIST_USAGE));
    plkInfo:
      AOut.WriteLn(_(HELP_PROJECT_INFO_USAGE));
    plkBuild:
      AOut.WriteLn(_(HELP_PROJECT_BUILD_USAGE));
    plkTest:
      AOut.WriteLn(_(HELP_PROJECT_TEST_USAGE));
    plkClean:
      AOut.WriteLn(_(HELP_PROJECT_CLEAN_USAGE));
    plkNew:
      AOut.WriteLn(_(HELP_PROJECT_NEW_USAGE));
  end;
end;

procedure WriteProjectLeafHelp(const AOut: IOutput; const AKind: TProjectLeafKind);
begin
  if AOut = nil then
    Exit;

  case AKind of
    plkList:
      begin
        AOut.WriteLn(_(HELP_PROJECT_LIST_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_LIST_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_LIST_OPT_JSON));
        AOut.WriteLn(_(HELP_PROJECT_LIST_OPT_HELP));
      end;
    plkInfo:
      begin
        AOut.WriteLn(_(HELP_PROJECT_INFO_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_INFO_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_INFO_OPT_HELP));
      end;
    plkBuild:
      begin
        AOut.WriteLn(_(HELP_PROJECT_BUILD_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_BUILD_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_BUILD_OPT_HELP));
      end;
    plkTest:
      begin
        AOut.WriteLn(_(HELP_PROJECT_TEST_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_TEST_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_TEST_OPT_HELP));
      end;
    plkClean:
      begin
        AOut.WriteLn(_(HELP_PROJECT_CLEAN_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_CLEAN_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_CLEAN_OPT_HELP));
      end;
    plkNew:
      begin
        AOut.WriteLn(_(HELP_PROJECT_NEW_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_NEW_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_NEW_EXAMPLE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PROJECT_NEW_OPT_HELP));
      end;
  end;
end;

function ProjectTypeToStringCore(AType: fpdev.project.generator.TProjectType): string;
begin
  case AType of
    ptConsole: Result := 'console';
    ptGUI: Result := 'gui';
    ptLibrary: Result := 'library';
    ptPackage: Result := 'package';
    ptWebApp: Result := 'webapp';
    ptService: Result := 'service';
    ptGame: Result := 'game';
  else
    Result := 'custom';
  end;
end;

function TemplateToJsonCore(const ATemplate: TProjectTemplate): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('name', ATemplate.Name);
  Result.Add('display_name', ATemplate.DisplayName);
  Result.Add('description', ATemplate.Description);
  Result.Add('type', ProjectTypeToStringCore(ATemplate.ProjectType));
  Result.Add('available', ATemplate.Available);
end;

function PrepareProjectDirectoryLeafPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  const AKind: TProjectLeafKind;
  out APlan: TProjectDirectoryCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectDirectoryCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectLeafHelp(AOut, AKind);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 0 then
    APlan.ProjectDir := GetPositionalArg(AParams, 0)
  else
    APlan.ProjectDir := '.';
end;

function PrepareProjectListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectListCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectListCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteProjectLeafUsage(AErr, plkList);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteProjectLeafHelp(AOut, plkList);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, ['--json'], UnknownOption) then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkList);
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 0 then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkList);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.JsonOutput := HasFlag(AParams, 'json');
end;

function ExecuteProjectListCommandPlanCore(
  const APlan: TProjectListCommandPlan;
  const AOut, AErr: IOutput;
  AListTemplates: TProjectListTemplatesFunc;
  AGetTemplateList: TProjectGetTemplateListFunc
): Integer;
var
  LTemplates: TProjectTemplateArray;
  LJson: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  Result := EXIT_ERROR;

  if APlan.JsonOutput then
  begin
    if not Assigned(AGetTemplateList) then
    begin
      if AErr <> nil then
        AErr.WriteLn(_(MSG_ERROR));
      Exit(EXIT_ERROR);
    end;

    LTemplates := AGetTemplateList();
    LJson := TJSONObject.Create;
    try
      LArr := TJSONArray.Create;
      for I := 0 to High(LTemplates) do
        LArr.Add(TemplateToJsonCore(LTemplates[I]));
      LJson.Add('templates', LArr);
      if AOut <> nil then
        AOut.WriteLn(LJson.FormatJSON);
    finally
      LJson.Free;
    end;
    Exit(EXIT_OK);
  end;

  if not Assigned(AListTemplates) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if AListTemplates(AOut) then
    Exit(EXIT_OK);
end;

function PrepareProjectInfoCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectInfoCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectInfoCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectLeafHelp(AOut, plkInfo);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkInfo);
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['template']));
    WriteProjectLeafUsage(AErr, plkInfo);
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkInfo);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.TemplateName := AParams[0];
end;

function ExecuteProjectInfoCommandPlanCore(
  const APlan: TProjectInfoCommandPlan;
  const AOut, AErr: IOutput;
  AShowTemplateInfo: TProjectShowTemplateInfoFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not Assigned(AShowTemplateInfo) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if AShowTemplateInfo(AOut, AErr, APlan.TemplateName) then
    Exit(EXIT_OK);
end;

function PrepareProjectBuildCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectBuildCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectBuildCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectLeafHelp(AOut, plkBuild);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkBuild);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount > 2 then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkBuild);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 0 then
    APlan.ProjectDir := GetPositionalArg(AParams, 0)
  else
    APlan.ProjectDir := '.';

  if PositionalCount > 1 then
    APlan.Target := GetPositionalArg(AParams, 1)
  else
    APlan.Target := '';
end;

function ExecuteProjectBuildCommandPlanCore(
  const APlan: TProjectBuildCommandPlan;
  const AOut, AErr: IOutput;
  ABuildProject: TProjectBuildFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not Assigned(ABuildProject) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if ABuildProject(APlan.ProjectDir, APlan.Target) then
  begin
    if AOut <> nil then
      AOut.WriteLn(_(CMD_PROJECT_BUILD_DONE));
    Exit(EXIT_OK);
  end;

  if AErr <> nil then
    AErr.WriteLn(_(CMD_PROJECT_BUILD_FAILED));
end;

function PrepareProjectTestCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectDirectoryCommandPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := PrepareProjectDirectoryLeafPlanCore(
    AParams,
    AOut,
    AErr,
    plkTest,
    APlan,
    AShouldExit
  );
end;

function ExecuteProjectTestCommandPlanCore(
  const APlan: TProjectDirectoryCommandPlan;
  const AOut, AErr: IOutput;
  ATestProject: TProjectDirectoryActionFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not Assigned(ATestProject) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if ATestProject(AOut, AErr, APlan.ProjectDir) then
    Exit(EXIT_OK);
end;

function PrepareProjectCleanCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectDirectoryCommandPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := PrepareProjectDirectoryLeafPlanCore(
    AParams,
    AOut,
    AErr,
    plkClean,
    APlan,
    AShouldExit
  );
end;

function ExecuteProjectCleanCommandPlanCore(
  const APlan: TProjectDirectoryCommandPlan;
  const AOut, AErr: IOutput;
  ACleanProject: TProjectDirectoryActionFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not Assigned(ACleanProject) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if ACleanProject(AOut, AErr, APlan.ProjectDir) then
    Exit(EXIT_OK);
end;

function PrepareProjectNewCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectNewCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectNewCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectLeafHelp(AOut, plkNew);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkNew);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount < 2 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['template, name']));
    WriteProjectLeafUsage(AErr, plkNew);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 3 then
  begin
    AShouldExit := True;
    WriteProjectLeafUsage(AErr, plkNew);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.TemplateName := GetPositionalArg(AParams, 0);
  APlan.ProjectName := GetPositionalArg(AParams, 1);
  if PositionalCount > 2 then
    APlan.TargetDir := GetPositionalArg(AParams, 2) + PathDelim + APlan.ProjectName
  else
    APlan.TargetDir := '.' + PathDelim + APlan.ProjectName;
end;

function ExecuteProjectNewCommandPlanCore(
  const APlan: TProjectNewCommandPlan;
  const AOut, AErr: IOutput;
  ACreateProject: TProjectCreateFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not Assigned(ACreateProject) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if ACreateProject(APlan.TemplateName, APlan.ProjectName, APlan.TargetDir) then
  begin
    if AOut <> nil then
      AOut.WriteLn(_Fmt(CMD_PROJECT_NEW_DONE, [APlan.ProjectName]));
    Exit(EXIT_OK);
  end;

  if AErr <> nil then
    AErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PROJECT_NEW_FAILED));
end;

end.
