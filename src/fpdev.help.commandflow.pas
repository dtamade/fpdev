unit fpdev.help.commandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.help.catalog,
  fpdev.output.intf;

type
  TDomainHelpItemsBuilder = function: THelpListItems;
  TDomainHelpDetailsWriter = function(const ASubcmd: string; const Ctx: IContext): Boolean;

procedure ListChildrenDynamicShellCore(const PathParts: array of string; const Outp: IOutput);
function PrintUsageShellCore(const Parts: array of string; const Outp: IOutput): Boolean;
procedure ExecuteHelpCore(const AParams: array of string; const Outp: IOutput);
procedure WriteDomainHelpOverviewCore(
  const Ctx: IContext;
  const AUsageText, ASubcommandsText, AHelpHintText: string;
  ABuildItems: TDomainHelpItemsBuilder
);
function ExecuteDomainHelpCommandCore(
  const AParams: array of string;
  const Ctx: IContext;
  const AUsageText, ASubcommandsText, AHelpHintText: string;
  ABuildItems: TDomainHelpItemsBuilder;
  AWriteDetails: TDomainHelpDetailsWriter
): Integer;

implementation

uses
  fpdev.exitcodes,
  fpdev.help.routing,
  fpdev.help.rootview,
  fpdev.help.usage,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure ListChildrenDynamicShellCore(const PathParts: array of string; const Outp: IOutput);
begin
  ListChildrenDynamicCore(PathParts, Outp);
end;

function PrintUsageShellCore(const Parts: array of string; const Outp: IOutput): Boolean;
begin
  Result := PrintUsageCore(Parts, Outp);
end;

procedure ExecuteHelpCore(const AParams: array of string; const Outp: IOutput);
begin
  if Length(AParams) > 0 then
  begin
    if PrintUsageShellCore(AParams, Outp) then
      Exit;

    ListChildrenDynamicShellCore(AParams, Outp);
    Exit;
  end;

  WriteRootHelpCore(Outp);
end;

procedure WriteDomainHelpOverviewCore(
  const Ctx: IContext;
  const AUsageText, ASubcommandsText, AHelpHintText: string;
  ABuildItems: TDomainHelpItemsBuilder
);
begin
  Ctx.Out.WriteLn(AUsageText);
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(ASubcommandsText);
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
  if Assigned(ABuildItems) then
    WriteHelpItemsCore(Ctx.Out, ABuildItems());
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(AHelpHintText);
end;

function ExecuteDomainHelpCommandCore(
  const AParams: array of string;
  const Ctx: IContext;
  const AUsageText, ASubcommandsText, AHelpHintText: string;
  ABuildItems: TDomainHelpItemsBuilder;
  AWriteDetails: TDomainHelpDetailsWriter
): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) = 0 then
  begin
    WriteDomainHelpOverviewCore(Ctx, AUsageText, ASubcommandsText, AHelpHintText, ABuildItems);
    Exit;
  end;

  if Length(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(AUsageText);
    Exit(EXIT_USAGE_ERROR);
  end;

  if Assigned(AWriteDetails) and AWriteDetails(AParams[0], Ctx) then
    Exit;

  Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [AParams[0]]));
  Ctx.Out.WriteLn('');
  WriteDomainHelpOverviewCore(Ctx, AUsageText, ASubcommandsText, AHelpHintText, ABuildItems);
  Result := EXIT_USAGE_ERROR;
end;

end.
