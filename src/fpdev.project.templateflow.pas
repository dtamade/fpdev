unit fpdev.project.templateflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.project.generator;

type
  TProjectTemplate = fpdev.project.generator.TProjectTemplate;
  TProjectTemplateArray = array of TProjectTemplate;
  TProjectTemplateRepoInitFunc = function: Boolean of object;
  TProjectTemplateRepoUpdateFunc = function(const AForce: Boolean): Boolean of object;

function FormatProjectTemplateListLineCore(const ATemplate: TProjectTemplate): string;
function ExecuteProjectTemplateListCore(
  const ATemplates: TProjectTemplateArray;
  const Outp: IOutput
): Boolean;
function ExecuteProjectTemplateInfoCore(
  const ATemplateName: string;
  const ATemplate: TProjectTemplate;
  const Outp, Errp: IOutput
): Boolean;
function ExecuteProjectTemplateInstallCore(
  const ATemplatePath, ATemplatesRoot: string;
  const Outp, Errp: IOutput
): Boolean;
function ExecuteProjectTemplateRemoveCore(
  const ATemplateName, ATemplatesRoot: string;
  const ABuiltinTemplates: TProjectTemplateArray;
  const Outp, Errp: IOutput
): Boolean;
function ExecuteProjectTemplateUpdateCore(
  const ARepoLocalPath, ATemplatesRoot: string;
  const Outp: IOutput;
  AInitializeRepo: TProjectTemplateRepoInitFunc;
  AUpdateRepo: TProjectTemplateRepoUpdateFunc
): Boolean;
function SyncProjectTemplatesFromRepositoryCore(
  const ARepoTemplatesDir, ATemplatesRoot: string;
  out AAddedCount, AUpdatedCount: Integer
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.utils.fs;

function ProjectTemplateListTypeLabelCore(AProjectType: TProjectType): string;
begin
  case AProjectType of
    ptConsole: Result := 'Console';
    ptGUI: Result := 'GUI App';
    ptLibrary: Result := 'Library';
    ptPackage: Result := 'Package';
    ptWebApp: Result := 'Web App';
    ptService: Result := 'Service';
    ptGame: Result := 'Game';
  else
    Result := 'Custom';
  end;
end;

function ProjectTemplateInfoTypeLabelCore(AProjectType: TProjectType): string;
begin
  case AProjectType of
    ptConsole: Result := _(CMD_PROJECT_TYPE_CONSOLE);
    ptGUI: Result := _(CMD_PROJECT_TYPE_GUI);
    ptLibrary: Result := _(CMD_PROJECT_TYPE_LIBRARY);
    ptPackage: Result := _(CMD_PROJECT_TYPE_PACKAGE);
    ptWebApp: Result := _(CMD_PROJECT_TYPE_WEBAPP);
    ptService: Result := _(CMD_PROJECT_TYPE_SERVICE);
    ptGame: Result := _(CMD_PROJECT_TYPE_GAME);
  else
    Result := _(CMD_PROJECT_TYPE_CUSTOM);
  end;
end;

function IsBuiltinProjectTemplateCore(
  const ATemplateName: string;
  const ABuiltinTemplates: TProjectTemplateArray
): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ABuiltinTemplates) do
    if SameText(ABuiltinTemplates[I].Name, ATemplateName) then
      Exit(True);
end;

function FormatProjectTemplateListLineCore(const ATemplate: TProjectTemplate): string;
begin
  Result := Format(
    '%-10s  %-12s %s',
    [ATemplate.Name, ProjectTemplateListTypeLabelCore(ATemplate.ProjectType), ATemplate.Description]
  );
end;

function ExecuteProjectTemplateListCore(
  const ATemplates: TProjectTemplateArray;
  const Outp: IOutput
): Boolean;
var
  Template: TProjectTemplate;
begin
  Result := Assigned(Outp);
  if not Result then
    Exit;

  for Template in ATemplates do
    Outp.WriteLn(FormatProjectTemplateListLineCore(Template));
end;

function ExecuteProjectTemplateInfoCore(
  const ATemplateName: string;
  const ATemplate: TProjectTemplate;
  const Outp, Errp: IOutput
): Boolean;
begin
  Result := False;

  if not Assigned(Outp) or not Assigned(Errp) then
    Exit;

  if ATemplate.Name = '' then
  begin
    Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TEMPLATE_NOT_FOUND, [ATemplateName]));
    Exit;
  end;

  Outp.WriteLn(Format('Name:        %s', [ATemplate.Name]));
  Outp.WriteLn(Format('Display:     %s', [ATemplate.DisplayName]));
  Outp.WriteLn(Format('Description: %s', [ATemplate.Description]));
  Outp.WriteLn(Format('Type:        %s', [ProjectTemplateInfoTypeLabelCore(ATemplate.ProjectType)]));
  Result := True;
end;

function ExecuteProjectTemplateInstallCore(
  const ATemplatePath, ATemplatesRoot: string;
  const Outp, Errp: IOutput
): Boolean;
var
  TemplateName: string;
  DestDir: string;
begin
  Result := False;

  if not Assigned(Outp) or not Assigned(Errp) then
    Exit;

  if not DirectoryExists(ATemplatePath) then
  begin
    Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TPL_PATH_NOT_EXIST, [ATemplatePath]));
    Exit;
  end;

  TemplateName := ExtractFileName(ExcludeTrailingPathDelimiter(ATemplatePath));
  if TemplateName = '' then
  begin
    Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PROJECT_TPL_INVALID_PATH));
    Exit;
  end;

  DestDir := IncludeTrailingPathDelimiter(ATemplatesRoot) + TemplateName;
  if DirectoryExists(DestDir) then
    Outp.WriteLn(_(MSG_WARNING) + ': ' + _Fmt(CMD_PROJECT_TPL_OVERWRITING, [TemplateName]));

  try
    if not EnsureDir(DestDir) then
      raise Exception.Create('Failed to create template directory: ' + DestDir);
    if not CopyDirRecursive(ATemplatePath, DestDir) then
      raise Exception.Create('Failed to copy template tree: ' + ATemplatePath);

    Outp.WriteLn(_Fmt(CMD_PROJECT_TPL_INSTALLED, [TemplateName]));
    Result := True;
  except
    on E: Exception do
      Errp.WriteLn(_Fmt(CMD_PROJECT_TPL_INSTALL_ERROR, [E.Message]));
  end;
end;

function ExecuteProjectTemplateRemoveCore(
  const ATemplateName, ATemplatesRoot: string;
  const ABuiltinTemplates: TProjectTemplateArray;
  const Outp, Errp: IOutput
): Boolean;
var
  TemplateDir: string;
begin
  Result := False;

  if not Assigned(Outp) or not Assigned(Errp) then
    Exit;

  if ATemplateName = '' then
  begin
    Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PROJECT_TPL_NAME_REQUIRED));
    Exit;
  end;

  if IsBuiltinProjectTemplateCore(ATemplateName, ABuiltinTemplates) then
  begin
    Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TPL_BUILTIN_REMOVE, [ATemplateName]));
    Exit;
  end;

  TemplateDir := IncludeTrailingPathDelimiter(ATemplatesRoot) + ATemplateName;
  if not DirectoryExists(TemplateDir) then
  begin
    Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PROJECT_TPL_NOT_FOUND, [ATemplateName]));
    Exit;
  end;

  try
    if not DeleteDirRecursive(TemplateDir) then
      raise Exception.Create('Failed to remove template directory: ' + TemplateDir);
    Outp.WriteLn(_Fmt(CMD_PROJECT_TPL_REMOVED, [ATemplateName]));
    Result := True;
  except
    on E: Exception do
      Errp.WriteLn(_Fmt(CMD_PROJECT_TPL_REMOVE_ERROR, [E.Message]));
  end;
end;

function ExecuteProjectTemplateUpdateCore(
  const ARepoLocalPath, ATemplatesRoot: string;
  const Outp: IOutput;
  AInitializeRepo: TProjectTemplateRepoInitFunc;
  AUpdateRepo: TProjectTemplateRepoUpdateFunc
): Boolean;
var
  TemplatesDir: string;
  AddedCount: Integer;
  UpdatedCount: Integer;
begin
  Result := False;
  AddedCount := 0;
  UpdatedCount := 0;

  if not Assigned(Outp) or not Assigned(AInitializeRepo) or not Assigned(AUpdateRepo) then
    Exit;

  if not AInitializeRepo() then
  begin
    Outp.WriteLn(_(MSG_INFO) + ': ' + _(CMD_PROJECT_TPL_REPO_UNAVAIL));
    Exit(True);
  end;

  if not AUpdateRepo(True) then
    Outp.WriteLn(_(MSG_WARNING) + ': ' + _(CMD_PROJECT_TPL_UPDATE_FAILED));

  TemplatesDir := ARepoLocalPath + PathDelim + 'templates';
  if not DirectoryExists(TemplatesDir) then
  begin
    Outp.WriteLn(_(MSG_INFO) + ': ' + _(CMD_PROJECT_TPL_NO_TEMPLATES));
    Exit(True);
  end;

  Result := SyncProjectTemplatesFromRepositoryCore(
    TemplatesDir,
    ATemplatesRoot,
    AddedCount,
    UpdatedCount
  );
  if not Result then
    Exit;

  if (AddedCount > 0) or (UpdatedCount > 0) then
    Outp.WriteLn(_Fmt(CMD_PROJECT_TPL_UPDATED, [AddedCount, UpdatedCount]))
  else
    Outp.WriteLn(_(CMD_PROJECT_TPL_UP_TO_DATE));

  Result := True;
end;

function SyncProjectTemplatesFromRepositoryCore(
  const ARepoTemplatesDir, ATemplatesRoot: string;
  out AAddedCount, AUpdatedCount: Integer
): Boolean;
var
  SR: TSearchRec;
  TemplateSrc: string;
  TemplateDest: string;
  MetaPath: string;
begin
  Result := False;
  AAddedCount := 0;
  AUpdatedCount := 0;

  if not DirectoryExists(ARepoTemplatesDir) then
    Exit;

  if not EnsureDir(ATemplatesRoot) then
    raise Exception.Create('Failed to create template root: ' + ATemplatesRoot);

  if FindFirst(IncludeTrailingPathDelimiter(ARepoTemplatesDir) + '*', faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') or ((SR.Attr and faDirectory) = 0) then
          Continue;

        TemplateSrc := IncludeTrailingPathDelimiter(ARepoTemplatesDir) + SR.Name;
        MetaPath := IncludeTrailingPathDelimiter(TemplateSrc) + 'template.json';
        if not FileExists(MetaPath) then
          Continue;

        TemplateDest := IncludeTrailingPathDelimiter(ATemplatesRoot) + SR.Name;
        if DirectoryExists(TemplateDest) then
          Inc(AUpdatedCount)
        else
          Inc(AAddedCount);

        if not CopyDirRecursive(TemplateSrc, TemplateDest) then
          raise Exception.Create('Failed to copy template tree: ' + TemplateSrc);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;

  Result := True;
end;

end.
