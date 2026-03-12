unit fpdev.command.helprouting;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.tree;

function RewriteTrailingHelpFlag(
  const AArgs: TStringArray;
  const ARoot: TCommandNode
): TStringArray;

implementation

uses
  fpdev.command.lookup;

function RewriteTrailingHelpFlag(
  const AArgs: TStringArray;
  const ARoot: TCommandNode
): TStringArray;
var
  BaseLen: Integer;
  PrefixLen: Integer;
  I: Integer;
  HelpPath: TStringArray;
  NewArgs: TStringArray;
  ExactNode: TCommandNode;
begin
  Result := Copy(AArgs);

  if (Length(Result) < 2) or
     ((Result[High(Result)] <> '--help') and (Result[High(Result)] <> '-h')) then
    Exit;

  BaseLen := Length(Result) - 1;
  SetLength(HelpPath, BaseLen);
  for I := 0 to BaseLen - 1 do
    HelpPath[I] := Result[I];

  ExactNode := FindNodeAtPathCore(ARoot, HelpPath);
  if (ExactNode <> nil) and Assigned(ExactNode.Factory) then
    Exit;
  if (ExactNode <> nil) and Assigned(ExactNode.Command) and (ExactNode.Children.Count = 0) then
    Exit;

  for PrefixLen := BaseLen downto 1 do
  begin
    SetLength(HelpPath, PrefixLen + 1);
    for I := 0 to PrefixLen - 1 do
      HelpPath[I] := Result[I];
    HelpPath[PrefixLen] := 'help';

    if HasCommandAtPathCore(ARoot, HelpPath) then
    begin
      SetLength(NewArgs, BaseLen + 1);
      for I := 0 to PrefixLen - 1 do
        NewArgs[I] := Result[I];
      NewArgs[PrefixLen] := 'help';
      for I := PrefixLen to BaseLen - 1 do
        NewArgs[I + 1] := Result[I];
      Result := NewArgs;
      Exit;
    end;
  end;
end;

end.
