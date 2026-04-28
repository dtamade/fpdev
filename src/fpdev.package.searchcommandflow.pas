unit fpdev.package.searchcommandflow;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  fpdev.output.intf;

type
  TPackageSearchCommandPlan = record
    Query: string;
    JsonOutput: Boolean;
  end;

  TPackageSearchCommandTextSearchFunc = function(
    const AQuery: string;
    Outp: IOutput
  ): Boolean of object;
  TPackageSearchCommandJSONSearchFunc = function(const AQuery: string): TStringList of object;

function PreparePackageSearchCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageSearchCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageSearchCommandPlanCore(
  const APlan: TPackageSearchCommandPlan;
  const AOut, AErr: IOutput;
  ATextSearch: TPackageSearchCommandTextSearchFunc;
  AJSONSearch: TPackageSearchCommandJSONSearchFunc
): Integer;

implementation

uses
  SysUtils, fpjson,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteSearchUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
end;

procedure WriteSearchHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_SEARCH_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_SEARCH_EXAMPLE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_SEARCH_OPT_JSON));
  AOut.WriteLn(_(HELP_PACKAGE_SEARCH_OPT_HELP));
end;

function PreparePackageSearchCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageSearchCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageSearchCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteSearchHelp(AOut);
    Exit(EXIT_OK);
  end;

  APlan.JsonOutput := HasFlag(AParams, 'json');

  if FindUnknownOption(AParams, ['--json'], UnknownOption) then
  begin
    AShouldExit := True;
    WriteSearchUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteSearchUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.Query := Trim(GetPositionalArg(AParams, 0));
  if APlan.Query = '' then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['query']));
    WriteSearchUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;
end;

function ExecutePackageSearchCommandPlanCore(
  const APlan: TPackageSearchCommandPlan;
  const AOut, AErr: IOutput;
  ATextSearch: TPackageSearchCommandTextSearchFunc;
  AJSONSearch: TPackageSearchCommandJSONSearchFunc
): Integer;
var
  Results: TStringList;
  I: Integer;
  JsonObject: TJSONObject;
  JsonArray: TJSONArray;
begin
  Result := EXIT_ERROR;

  if APlan.JsonOutput then
  begin
    if not Assigned(AJSONSearch) then
    begin
      if AErr <> nil then
        AErr.WriteLn(_(MSG_ERROR));
      Exit(EXIT_ERROR);
    end;

    Results := AJSONSearch(APlan.Query);
    try
      JsonObject := TJSONObject.Create;
      try
        JsonArray := TJSONArray.Create;
        for I := 0 to Results.Count - 1 do
          JsonArray.Add(Results[I]);
        JsonObject.Add('query', APlan.Query);
        JsonObject.Add('results', JsonArray);
        JsonObject.Add('count', Results.Count);
        if AOut <> nil then
          AOut.WriteLn(JsonObject.FormatJSON);
      finally
        JsonObject.Free;
      end;
    finally
      Results.Free;
    end;
    Exit(EXIT_OK);
  end;

  if not Assigned(ATextSearch) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR));
    Exit(EXIT_ERROR);
  end;

  if ATextSearch(APlan.Query, AOut) then
    Exit(EXIT_OK);
end;

end.
