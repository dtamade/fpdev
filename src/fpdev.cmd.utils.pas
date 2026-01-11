unit fpdev.cmd.utils;

{
================================================================================
  fpdev.cmd.utils - Command Line Utility Functions
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

const
  { Command exit codes }
  EXIT_SUCCESS      = 0;  // Command executed successfully
  EXIT_INVALID_ARGS = 2;  // Invalid or missing arguments
  EXIT_FAILED       = 3;  // Command execution failed

{ Check if a flag exists in parameters (--flag or -flag) }
function HasFlag(const Params: array of string; const Flag: string): Boolean;

{ Get value of a --key=value style parameter }
function GetFlagValue(const Params: array of string; const Key: string; out Value: string): Boolean;

{ Get positional argument (non-flag) by index, returns empty if not found }
function GetPositionalArg(const Params: array of string; Index: Integer): string;

{ Count positional arguments (non-flags) }
function CountPositionalArgs(const Params: array of string): Integer;

implementation

uses
  SysUtils;

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

end.
