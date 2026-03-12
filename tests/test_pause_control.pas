unit test_pause_control;

{$mode objfpc}{$H+}

interface

function ShouldPauseAfterRun: Boolean;
procedure PauseIfRequested(const APrompt: string = '');

implementation

uses
  SysUtils;

function ShouldPauseAfterRun: Boolean;
var
  I: Integer;
begin
  if GetEnvironmentVariable('FPDEV_DEMO_PAUSE') <> '' then
    Exit(True);

  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), '--pause') = 0 then
      Exit(True);

  Result := False;
end;

procedure PauseIfRequested(const APrompt: string);
begin
  if not ShouldPauseAfterRun then
    Exit;

  WriteLn;
  if APrompt <> '' then
    WriteLn(APrompt);
  ReadLn;
end;

end.
