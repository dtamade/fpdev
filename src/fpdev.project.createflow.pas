unit fpdev.project.createflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.project.generator;

type
  TProjectTemplateLookupFunc = function(
    const ATemplateName: string
  ): TProjectTemplate of object;

  TProjectTemplateGeneratorFunc = function(
    const ATemplate: TProjectTemplate;
    const AProjectName, ATargetDir: string
  ): Boolean of object;

  TProjectNameValidatorFunc = function(
    const AProjectName: string
  ): Boolean of object;

  TProjectCreateFromTemplateFunc = function(
    const ATemplateName, AProjectName, ATargetDir: string
  ): Boolean of object;

  TProjectSetupEnvironmentFunc = function(
    const AProjectDir: string
  ): Boolean of object;

function ExecuteProjectCreateFromTemplateCore(
  const ATemplateName, AProjectName, ATargetDir: string;
  AGetTemplateInfo: TProjectTemplateLookupFunc;
  AGenerateProjectFiles: TProjectTemplateGeneratorFunc
): Boolean;

function ExecuteProjectCreateCore(
  const ATemplateName, AProjectName, ATargetDir: string;
  const Outp: IOutput;
  AValidateProjectName: TProjectNameValidatorFunc;
  ACreateFromTemplate: TProjectCreateFromTemplateFunc;
  ASetupProjectEnvironment: TProjectSetupEnvironmentFunc
): Boolean;

implementation

uses
  SysUtils,
  fpdev.utils.fs;

const
  PROJECT_SETUP_WARNING_PREFIX = 'Warning: Project environment setup incomplete for: ';

function ExecuteProjectCreateFromTemplateCore(
  const ATemplateName, AProjectName, ATargetDir: string;
  AGetTemplateInfo: TProjectTemplateLookupFunc;
  AGenerateProjectFiles: TProjectTemplateGeneratorFunc
): Boolean;
var
  Template: TProjectTemplate;
begin
  Result := False;
  Template := Default(TProjectTemplate);

  if (not Assigned(AGetTemplateInfo)) or (not Assigned(AGenerateProjectFiles)) then
    Exit;

  Template := AGetTemplateInfo(ATemplateName);
  if Template.Name = '' then
    Exit;

  try
    if (not DirectoryExists(ATargetDir)) and (not EnsureDir(ATargetDir)) then
      Exit;

    Result := AGenerateProjectFiles(Template, AProjectName, ATargetDir);
  except
    on E: Exception do
      Result := False;
  end;
end;

function ExecuteProjectCreateCore(
  const ATemplateName, AProjectName, ATargetDir: string;
  const Outp: IOutput;
  AValidateProjectName: TProjectNameValidatorFunc;
  ACreateFromTemplate: TProjectCreateFromTemplateFunc;
  ASetupProjectEnvironment: TProjectSetupEnvironmentFunc
): Boolean;
begin
  Result := False;

  if Assigned(AValidateProjectName) and (not AValidateProjectName(AProjectName)) then
    Exit;

  if (not Assigned(ACreateFromTemplate)) or
     (not ACreateFromTemplate(ATemplateName, AProjectName, ATargetDir)) then
    Exit;

  if Assigned(ASetupProjectEnvironment) and (not ASetupProjectEnvironment(ATargetDir)) then
    if Assigned(Outp) then
      Outp.WriteLn(PROJECT_SETUP_WARNING_PREFIX + ATargetDir);

  Result := True;
end;

end.
