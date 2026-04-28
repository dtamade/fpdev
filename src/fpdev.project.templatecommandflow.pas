unit fpdev.project.templatecommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TProjectTemplateListCommandPlan = record
  end;

  TProjectTemplateInstallCommandPlan = record
    TemplatePath: string;
  end;

  TProjectTemplateRemoveCommandPlan = record
    TemplateName: string;
  end;

  TProjectTemplateUpdateCommandPlan = record
  end;

  TProjectTemplateListCommandFunc = function(const Outp: IOutput): Boolean of object;
  TProjectTemplateInstallCommandFunc = function(
    const Outp, Errp: IOutput;
    const ATemplatePath: string
  ): Boolean of object;
  TProjectTemplateRemoveCommandFunc = function(
    const Outp, Errp: IOutput;
    const ATemplateName: string
  ): Boolean of object;
  TProjectTemplateUpdateCommandFunc = function(
    const Outp, Errp: IOutput
  ): Boolean of object;

function PrepareProjectTemplateListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateListCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectTemplateListCommandPlanCore(
  const AOut, AErr: IOutput;
  AListTemplates: TProjectTemplateListCommandFunc
): Integer;

function PrepareProjectTemplateInstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateInstallCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectTemplateInstallCommandPlanCore(
  const APlan: TProjectTemplateInstallCommandPlan;
  const AOut, AErr: IOutput;
  AInstallTemplate: TProjectTemplateInstallCommandFunc
): Integer;

function PrepareProjectTemplateRemoveCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateRemoveCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectTemplateRemoveCommandPlanCore(
  const APlan: TProjectTemplateRemoveCommandPlan;
  const AOut, AErr: IOutput;
  ARemoveTemplate: TProjectTemplateRemoveCommandFunc
): Integer;

function PrepareProjectTemplateUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteProjectTemplateUpdateCommandPlanCore(
  const AOut, AErr: IOutput;
  AUpdateTemplates: TProjectTemplateUpdateCommandFunc
): Integer;

implementation

uses
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

type
  TProjectTemplateLeafKind = (
    ptlkList,
    ptlkInstall,
    ptlkRemove,
    ptlkUpdate
  );

procedure WriteProjectTemplateUsage(
  const AOut: IOutput;
  const AKind: TProjectTemplateLeafKind
);
begin
  if AOut = nil then
    Exit;

  case AKind of
    ptlkList:
      AOut.WriteLn('Usage: fpdev project template list');
    ptlkInstall:
      AOut.WriteLn('Usage: fpdev project template install <path>');
    ptlkRemove:
      AOut.WriteLn('Usage: fpdev project template remove <name>');
    ptlkUpdate:
      AOut.WriteLn('Usage: fpdev project template update');
  end;
end;

procedure WriteProjectTemplateHelp(
  const AOut: IOutput;
  const AKind: TProjectTemplateLeafKind
);
begin
  if AOut = nil then
    Exit;

  case AKind of
    ptlkList:
      begin
        WriteProjectTemplateUsage(AOut, AKind);
        AOut.WriteLn('');
        AOut.WriteLn('List all available project templates (built-in and custom).');
        AOut.WriteLn('');
        AOut.WriteLn('  --help, -h    Show this help message');
      end;
    ptlkInstall:
      begin
        WriteProjectTemplateUsage(AOut, AKind);
        AOut.WriteLn('');
        AOut.WriteLn('Install a custom project template from a directory.');
        AOut.WriteLn('');
        AOut.WriteLn('Arguments:');
        AOut.WriteLn('  <path>        Path to the template directory');
        AOut.WriteLn('');
        AOut.WriteLn('  --help, -h    Show this help message');
      end;
    ptlkRemove:
      begin
        WriteProjectTemplateUsage(AOut, AKind);
        AOut.WriteLn('');
        AOut.WriteLn('Remove a custom project template.');
        AOut.WriteLn('Built-in templates (console, gui, library, etc.) cannot be removed.');
        AOut.WriteLn('');
        AOut.WriteLn('Arguments:');
        AOut.WriteLn('  <name>        Name of the template to remove');
        AOut.WriteLn('');
        AOut.WriteLn('  --help, -h    Show this help message');
      end;
    ptlkUpdate:
      begin
        WriteProjectTemplateUsage(AOut, AKind);
        AOut.WriteLn('');
        AOut.WriteLn('Update project templates from the remote resource repository.');
        AOut.WriteLn('');
        AOut.WriteLn('  --help, -h    Show this help message');
      end;
  end;
end;

function PrepareProjectTemplateListCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateListCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectTemplateListCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectTemplateHelp(AOut, ptlkList);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) or
     (CountPositionalArgs(AParams) > 0) then
  begin
    AShouldExit := True;
    WriteProjectTemplateUsage(AErr, ptlkList);
    Exit(EXIT_USAGE_ERROR);
  end;
end;

function ExecuteProjectTemplateListCommandPlanCore(
  const AOut, AErr: IOutput;
  AListTemplates: TProjectTemplateListCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;
  if not Assigned(AListTemplates) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit;
  end;

  if AListTemplates(AOut) then
    Exit(EXIT_OK);
end;

function PrepareProjectTemplateInstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateInstallCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectTemplateInstallCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectTemplateHelp(AOut, ptlkInstall);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteProjectTemplateUsage(AErr, ptlkInstall);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['path']));
    WriteProjectTemplateUsage(AErr, ptlkInstall);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteProjectTemplateUsage(AErr, ptlkInstall);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.TemplatePath := GetPositionalArg(AParams, 0);
end;

function ExecuteProjectTemplateInstallCommandPlanCore(
  const APlan: TProjectTemplateInstallCommandPlan;
  const AOut, AErr: IOutput;
  AInstallTemplate: TProjectTemplateInstallCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;
  if not Assigned(AInstallTemplate) then
    Exit;

  if AInstallTemplate(AOut, AErr, APlan.TemplatePath) then
    Exit(EXIT_OK);
end;

function PrepareProjectTemplateRemoveCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateRemoveCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectTemplateRemoveCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectTemplateHelp(AOut, ptlkRemove);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteProjectTemplateUsage(AErr, ptlkRemove);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['name']));
    WriteProjectTemplateUsage(AErr, ptlkRemove);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteProjectTemplateUsage(AErr, ptlkRemove);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.TemplateName := GetPositionalArg(AParams, 0);
end;

function ExecuteProjectTemplateRemoveCommandPlanCore(
  const APlan: TProjectTemplateRemoveCommandPlan;
  const AOut, AErr: IOutput;
  ARemoveTemplate: TProjectTemplateRemoveCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;
  if not Assigned(ARemoveTemplate) then
    Exit;

  if ARemoveTemplate(AOut, AErr, APlan.TemplateName) then
    Exit(EXIT_OK);
end;

function PrepareProjectTemplateUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TProjectTemplateUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  APlan := Default(TProjectTemplateUpdateCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteProjectTemplateHelp(AOut, ptlkUpdate);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) or
     (CountPositionalArgs(AParams) > 0) then
  begin
    AShouldExit := True;
    WriteProjectTemplateUsage(AErr, ptlkUpdate);
    Exit(EXIT_USAGE_ERROR);
  end;
end;

function ExecuteProjectTemplateUpdateCommandPlanCore(
  const AOut, AErr: IOutput;
  AUpdateTemplates: TProjectTemplateUpdateCommandFunc
): Integer;
begin
  Result := EXIT_ERROR;
  if not Assigned(AUpdateTemplates) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit;
  end;

  if AUpdateTemplates(AOut, AErr) then
    Exit(EXIT_OK);
end;

end.
