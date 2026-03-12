unit fpdev.command.utils;

{
================================================================================
  fpdev.command.utils - Command Line Utility Functions
================================================================================

  Provides common utility functions for command-line argument parsing.
  This unit consolidates duplicated functions from various cmd.*.pas files.

  Functions:
  - HasFlag: Check if a flag exists in parameters
  - GetFlagValue: Get value of a --key=value parameter
  - GetPositionalArg: Get positional argument by index

  Usage:
    if HasFlag(Params, 'verbose') then ...
    if GetFlagValue(Params, 'prefix', PrefixValue) then ...

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.intf, fpdev.exitcodes;

{ Check if a flag exists in parameters (--flag or -flag) }
function HasFlag(const Params: array of string; const Flag: string): Boolean;

{ Get value of a --key=value style parameter }
function GetFlagValue(const Params: array of string; const Key: string; out Value: string): Boolean;

{ Get positional argument (non-flag) by index, returns empty if not found }
function GetPositionalArg(const Params: array of string; Index: Integer): string;

{ Count positional arguments (non-flags) }
function CountPositionalArgs(const Params: array of string): Integer;

{ Write missing argument error and return EXIT_USAGE_ERROR }
function MissingArgError(const Ctx: IContext; const ArgName, UsageHelp: string): Integer;

{ Write unknown command error and return EXIT_USAGE_ERROR }
function UnknownCmdError(const Ctx: IContext; const CmdName: string): Integer;

{ Write generic error and return specified exit code }
function CmdError(const Ctx: IContext; const Msg: string; ExitCode: Integer = EXIT_ERROR): Integer;

{ Return True when AParam matches AKnownOption. }
{ AKnownOption may be an exact option (e.g. "--json") or a prefix ending with "=" (e.g. "--depth="). }
function IsKnownOption(const AParam: string; const AKnownOption: string): Boolean;

{ Find first unknown option in Params; returns True and sets UnknownOption when found. }
function FindUnknownOption(const Params: array of string; const KnownOptions: array of string;
  out UnknownOption: string): Boolean;

implementation

uses
  SysUtils, fpdev.i18n, fpdev.i18n.strings;

function HasFlag(const Params: array of string; const Flag: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(Params) to High(Params) do
    if SameText(Params[i], '--' + Flag) or SameText(Params[i], '-' + Flag) then
      Exit(True);
end;

function GetFlagValue(const Params: array of string; const Key: string; out Value: string): Boolean;
var
  i, p: Integer;
  s, k: string;
begin
  Result := False;
  Value := '';
  k := '--' + LowerCase(Key) + '=';
  for i := Low(Params) to High(Params) do
  begin
    s := Params[i];
    // Case-insensitive key matching, preserve original value case
    p := Pos(k, LowerCase(s));
    if p = 1 then
    begin
      Value := Copy(s, Length(k) + 1, MaxInt);
      Exit(True);
    end;
  end;
end;

function GetPositionalArg(const Params: array of string; Index: Integer): string;
var
  i, Count: Integer;
begin
  Result := '';
  Count := 0;
  for i := Low(Params) to High(Params) do
  begin
    if (Length(Params[i]) > 0) and (Params[i][1] <> '-') then
    begin
      if Count = Index then
        Exit(Params[i]);
      Inc(Count);
    end;
  end;
end;

function CountPositionalArgs(const Params: array of string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := Low(Params) to High(Params) do
    if (Length(Params[i]) > 0) and (Params[i][1] <> '-') then
      Inc(Result);
end;

function MissingArgError(const Ctx: IContext; const ArgName, UsageHelp: string): Integer;
begin
  Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, [ArgName]));
  if UsageHelp <> '' then
    Ctx.Err.WriteLn(UsageHelp);
  Result := EXIT_USAGE_ERROR;
end;

function UnknownCmdError(const Ctx: IContext; const CmdName: string): Integer;
begin
  Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [CmdName]));
  Result := EXIT_USAGE_ERROR;
end;

function CmdError(const Ctx: IContext; const Msg: string; ExitCode: Integer): Integer;
begin
  Ctx.Err.WriteLn('Error: ' + Msg);
  Result := ExitCode;
end;

function IsKnownOption(const AParam: string; const AKnownOption: string): Boolean;
var
  Prefix: string;
begin
  Result := False;
  if (AKnownOption = '') or (AParam = '') then
    Exit;

  if AKnownOption[Length(AKnownOption)] = '=' then
  begin
    Prefix := LowerCase(AKnownOption);
    Result := Pos(Prefix, LowerCase(AParam)) = 1;
    Exit;
  end;

  Result := SameText(AParam, AKnownOption);
end;

function FindUnknownOption(const Params: array of string; const KnownOptions: array of string;
  out UnknownOption: string): Boolean;
var
  I, J: Integer;
  IsKnown: Boolean;
begin
  UnknownOption := '';
  Result := False;

  for I := Low(Params) to High(Params) do
  begin
    if (Params[I] = '') or (Params[I][1] <> '-') then
      Continue;

    IsKnown := False;
    for J := Low(KnownOptions) to High(KnownOptions) do
    begin
      if IsKnownOption(Params[I], KnownOptions[J]) then
      begin
        IsKnown := True;
        Break;
      end;
    end;

    if not IsKnown then
    begin
      UnknownOption := Params[I];
      Exit(True);
    end;
  end;
end;

end.
