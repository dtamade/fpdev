unit fpdev.cross.searchdiag;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TCrossSearchLogLine = record
    Layer: Integer;
    LayerName: string;
    Path: string;
    Prefix: string;
    Found: Boolean;
  end;

  TCrossSearchLogLineArray = array of TCrossSearchLogLine;

function BuildCrossSearchLogLinesCore(
  const AEntries: TCrossSearchLogLineArray
): TStringArray;

function BuildCrossDiagnoseLinesCore(
  const ATargetCPU, ATargetOS: string;
  const ABinFound: Boolean;
  const ABinLayer: Integer;
  const ABinLayerName, ABinutilsPath, ABinutilsPrefix: string;
  const ALibraries, ALogLines: TStringArray
): TStringArray;

implementation

procedure AppendLine(var ALines: TStringArray; const ALine: string);
begin
  SetLength(ALines, Length(ALines) + 1);
  ALines[High(ALines)] := ALine;
end;

function BuildCrossSearchLogLinesCore(
  const AEntries: TCrossSearchLogLineArray
): TStringArray;
var
  I: Integer;
  StatusStr: string;
begin
  Result := nil;
  SetLength(Result, Length(AEntries));
  for I := 0 to High(AEntries) do
  begin
    if AEntries[I].Found then
      StatusStr := 'FOUND'
    else
      StatusStr := 'miss';
    Result[I] := Format('[L%d:%s] %s prefix=%s => %s',
      [AEntries[I].Layer, AEntries[I].LayerName, AEntries[I].Path,
       AEntries[I].Prefix, StatusStr]);
  end;
end;

function BuildCrossDiagnoseLinesCore(
  const ATargetCPU, ATargetOS: string;
  const ABinFound: Boolean;
  const ABinLayer: Integer;
  const ABinLayerName, ABinutilsPath, ABinutilsPrefix: string;
  const ALibraries, ALogLines: TStringArray
): TStringArray;
var
  I: Integer;
begin
  Result := nil;

  AppendLine(Result, 'Target: ' + ATargetCPU + '-' + ATargetOS);

  if ABinFound then
  begin
    AppendLine(Result, '[OK] Binutils found (layer ' + IntToStr(ABinLayer) +
      ': ' + ABinLayerName + ')');
    AppendLine(Result, '     Path: ' + ABinutilsPath);
    if ABinutilsPrefix <> '' then
      AppendLine(Result, '     Prefix: ' + ABinutilsPrefix);
  end
  else
    AppendLine(Result, '[X] Binutils not found');

  if Length(ALibraries) > 0 then
  begin
    AppendLine(Result, '[OK] Libraries found (' + IntToStr(Length(ALibraries)) +
      ' path(s))');
    for I := 0 to High(ALibraries) do
      AppendLine(Result, '     ' + ALibraries[I]);
  end
  else
    AppendLine(Result, '[!] No library paths found');

  AppendLine(Result, 'Search log (' + IntToStr(Length(ALogLines)) + ' entries):');
  for I := 0 to High(ALogLines) do
    AppendLine(Result, '  ' + ALogLines[I]);
end;

end.
