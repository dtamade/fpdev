unit fpdev.cli.flags;

{$mode objfpc}{$H+}

{
  Top-level CLI flag preprocessing helpers.

  This unit owns the remaining pre-dispatch flag prelude handling so
  fpdev.cli.global can stay focused on argument normalization and dispatch
  shaping.
}

interface

uses
  SysUtils;

function LeadingPortablePreludeLength(const AArgs: TStringArray): Integer;
procedure ApplyPortableModeFromArgs(const AArgs: TStringArray);

implementation

uses
  fpdev.paths;

function LeadingPortablePreludeLength(const AArgs: TStringArray): Integer;
begin
  if (Length(AArgs) > 0) and (AArgs[0] = '--portable') then
    Exit(1);

  Result := 0;
end;

procedure ApplyPortableModeFromArgs(const AArgs: TStringArray);
begin
  if LeadingPortablePreludeLength(AArgs) > 0 then
    SetPortableMode(True);
end;

end.
