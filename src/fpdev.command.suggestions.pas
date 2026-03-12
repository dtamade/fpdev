unit fpdev.command.suggestions;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function FindSimilarCommand(const AInput: string; const ACommands: TStringArray): string;

implementation

function LevenshteinDistance(const S1, S2: string): Integer;
var
  D: array of array of Integer;
  I, J, Cost: Integer;
  Len1, Len2: Integer;
begin
  D := nil;
  Len1 := Length(S1);
  Len2 := Length(S2);

  if Len1 = 0 then
    Exit(Len2);
  if Len2 = 0 then
    Exit(Len1);

  SetLength(D, Len1 + 1, Len2 + 1);

  for I := 0 to Len1 do
    D[I, 0] := I;
  for J := 0 to Len2 do
    D[0, J] := J;

  for I := 1 to Len1 do
    for J := 1 to Len2 do
    begin
      if LowerCase(S1[I]) = LowerCase(S2[J]) then
        Cost := 0
      else
        Cost := 1;

      D[I, J] := D[I - 1, J] + 1;
      if D[I, J - 1] + 1 < D[I, J] then
        D[I, J] := D[I, J - 1] + 1;
      if D[I - 1, J - 1] + Cost < D[I, J] then
        D[I, J] := D[I - 1, J - 1] + Cost;
    end;

  Result := D[Len1, Len2];
end;

function FindSimilarCommand(const AInput: string; const ACommands: TStringArray): string;
var
  I, Dist, MinDist: Integer;
  BestMatch: string;
  MaxDist: Integer;
begin
  Result := '';
  if Length(ACommands) = 0 then
    Exit;

  BestMatch := '';
  MinDist := MaxInt;

  MaxDist := Length(AInput) * 2 div 5;
  if MaxDist < 2 then
    MaxDist := 2;
  if MaxDist > 4 then
    MaxDist := 4;

  for I := 0 to High(ACommands) do
  begin
    Dist := LevenshteinDistance(AInput, ACommands[I]);
    if (Dist < MinDist) and (Dist <= MaxDist) then
    begin
      MinDist := Dist;
      BestMatch := ACommands[I];
    end;
  end;

  Result := BestMatch;
end;

end.
