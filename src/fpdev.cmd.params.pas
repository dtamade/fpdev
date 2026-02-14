unit fpdev.cmd.params;

{$mode objfpc}{$H+}

{
  Command-line parameter parsing utilities.

  This module provides common functions for parsing command-line arguments
  used across all fpdev subcommands.
}

interface

{ Check if a flag is present in the parameters array.
  @param AParams The array of command-line parameters
  @param AFlag The flag name without prefix (e.g., 'verbose' for --verbose or -verbose)
  @returns True if the flag is found }
function HasFlag(const AParams: array of string; const AFlag: string): Boolean;

{ Get the value of a key=value parameter.
  @param AParams The array of command-line parameters
  @param AKey The key name without prefix (e.g., 'jobs' for --jobs=4)
  @param AValue Output parameter for the value
  @returns True if the key was found and value extracted }
function GetFlagValue(const AParams: array of string; const AKey: string; out AValue: string): Boolean;

{ Get a positional parameter by index.
  @param AParams The array of command-line parameters
  @param AIndex The zero-based index of the positional parameter
  @param AValue Output parameter for the value
  @returns True if the parameter exists at the given index }
function GetPositionalParam(const AParams: array of string; AIndex: Integer; out AValue: string): Boolean;

{ Count the number of positional (non-flag) parameters.
  @param AParams The array of command-line parameters
  @returns The count of positional parameters }
function CountPositionalParams(const AParams: array of string): Integer;

implementation

uses
  SysUtils;

function HasFlag(const AParams: array of string; const AFlag: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(AParams) to High(AParams) do
    if SameText(AParams[i], '--' + AFlag) or SameText(AParams[i], '-' + AFlag) then
      Exit(True);
end;

function GetFlagValue(const AParams: array of string; const AKey: string; out AValue: string): Boolean;
var
  i, p: Integer;
  s, k: string;
begin
  Result := False;
  AValue := '';
  k := '--' + AKey + '=';
  for i := Low(AParams) to High(AParams) do
  begin
    s := AParams[i];
    p := Pos(k, s);
    if p = 1 then
    begin
      AValue := Copy(s, Length(k) + 1, MaxInt);
      Exit(True);
    end;
  end;
end;

function GetPositionalParam(const AParams: array of string; AIndex: Integer; out AValue: string): Boolean;
var
  i, Count: Integer;
begin
  Result := False;
  AValue := '';
  Count := 0;
  for i := Low(AParams) to High(AParams) do
  begin
    // Skip flags (starting with - or --)
    if (Length(AParams[i]) > 0) and (AParams[i][1] = '-') then
      Continue;
    if Count = AIndex then
    begin
      AValue := AParams[i];
      Exit(True);
    end;
    Inc(Count);
  end;
end;

function CountPositionalParams(const AParams: array of string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := Low(AParams) to High(AParams) do
  begin
    // Skip flags (starting with - or --)
    if (Length(AParams[i]) > 0) and (AParams[i][1] = '-') then
      Continue;
    Inc(Result);
  end;
end;

end.
