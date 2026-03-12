program cli_surface_dump;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.command.imports;

procedure SortStrings(var AItems: TStringArray);
var
  I, J: Integer;
  Temp: string;
begin
  for I := Low(AItems) to High(AItems) do
    for J := I + 1 to High(AItems) do
      if CompareText(AItems[I], AItems[J]) > 0 then
      begin
        Temp := AItems[I];
        AItems[I] := AItems[J];
        AItems[J] := Temp;
      end;
end;

function ExtendPath(const APath: array of string; const AChild: string): TStringArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(APath) + 1);
  for I := Low(APath) to High(APath) do
    Result[I] := APath[I];
  Result[High(Result)] := AChild;
end;

procedure WritePath(const APath: array of string);
var
  I: Integer;
begin
  for I := Low(APath) to High(APath) do
  begin
    if I > Low(APath) then
      Write('/');
    Write(APath[I]);
  end;
  WriteLn;
end;

procedure DumpTree(const APath: array of string);
var
  Children: TStringArray;
  I: Integer;
  NextPath: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(APath);
  SortStrings(Children);
  for I := Low(Children) to High(Children) do
  begin
    NextPath := ExtendPath(APath, Children[I]);
    WritePath(NextPath);
    DumpTree(NextPath);
  end;
end;

begin
  DumpTree([]);
end.
