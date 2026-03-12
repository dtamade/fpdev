unit fpdev.cli.global;

{$mode objfpc}{$H+}

{
  Global CLI preprocessing helpers.

  Keeps top-level flag handling and leading --portable normalization out of
  fpdev.lpr so the main program can focus on specialized commands and registry
  dispatch.
}

interface

uses
  SysUtils;

function CollectCLIArgs: TStringArray;
procedure ApplyPortableModeFromArgs(const AArgs: TStringArray);
procedure NormalizePrimaryAndParams(const ARawArgs: TStringArray;
  out APrimary: string; out AParams: TStringArray);
function BuildDispatchArgs(const APrimary: string;
  const AParams: TStringArray): TStringArray;
implementation

uses
  fpdev.paths;

function LeadingPortablePreludeLength(const AArgs: TStringArray): Integer;
begin
  if (Length(AArgs) > 0) and (AArgs[0] = '--portable') then
    Exit(1);

  Result := 0;
end;

function CollectCLIArgs: TStringArray;
var
  I: Integer;
begin
  Initialize(Result);
  SetLength(Result, ParamCount);
  for I := 1 to ParamCount do
    Result[I - 1] := ParamStr(I);
end;

procedure ApplyPortableModeFromArgs(const AArgs: TStringArray);
begin
  if LeadingPortablePreludeLength(AArgs) > 0 then
    SetPortableMode(True);
end;

procedure NormalizePrimaryAndParams(const ARawArgs: TStringArray;
  out APrimary: string; out AParams: TStringArray);
var
  StartIndex: Integer;
  I: Integer;
begin
  APrimary := '';
  Initialize(AParams);
  SetLength(AParams, 0);

  if Length(ARawArgs) = 0 then
    Exit;

  StartIndex := LeadingPortablePreludeLength(ARawArgs);
  if StartIndex > 0 then
  begin
    if StartIndex >= Length(ARawArgs) then
      Exit;
  end;

  APrimary := ARawArgs[StartIndex];
  Inc(StartIndex);

  if StartIndex >= Length(ARawArgs) then
    Exit;

  SetLength(AParams, Length(ARawArgs) - StartIndex);
  for I := StartIndex to High(ARawArgs) do
    AParams[I - StartIndex] := ARawArgs[I];
end;

function BuildDispatchArgs(const APrimary: string;
  const AParams: TStringArray): TStringArray;
var
  I: Integer;
begin
  Initialize(Result);
  if APrimary = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, Length(AParams) + 1);
  Result[0] := APrimary;
  for I := 0 to High(AParams) do
    Result[I + 1] := AParams[I];
end;

end.
