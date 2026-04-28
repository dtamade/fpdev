unit fpdev.cross.searchflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.config.interfaces;

type
  TCrossSearchResult = record
    Found: Boolean;
    BinutilsPath: string;
    BinutilsPrefix: string;
    LibrariesPath: string;
    Layer: Integer;
    LayerName: string;
  end;

  TCrossSearchLayerFunc = function(
    const ATarget: TCrossTarget
  ): TCrossSearchResult of object;

  TCrossSearchConfigLayerFunc = function(
    const ATarget: TCrossTarget;
    const AFpcCfgPath: string
  ): TCrossSearchResult of object;

  TCrossSearchCheckToolFunc = function(
    const ADir, APrefix, ATool: string
  ): Boolean of object;

  TCrossSearchLogProc = procedure(
    ALayer: Integer;
    const ALayerName, APath, APrefix: string;
    AFound: Boolean
  ) of object;

  TCrossSearchClearLogProc = procedure of object;

  TCrossSearchCallbacks = record
    ClearLog: TCrossSearchClearLogProc;
    CheckTool: TCrossSearchCheckToolFunc;
    AddLog: TCrossSearchLogProc;
    SearchLayer1: TCrossSearchLayerFunc;
    SearchLayer2: TCrossSearchLayerFunc;
    SearchLayer3: TCrossSearchLayerFunc;
    SearchLayer4: TCrossSearchLayerFunc;
    SearchLayer5: TCrossSearchLayerFunc;
    SearchLayer6: TCrossSearchConfigLayerFunc;
  end;

function ExecuteCrossBinutilsSearchCore(
  const ATarget: TCrossTarget;
  const AFpcCfgPath, ATool: string;
  const ACallbacks: TCrossSearchCallbacks
): TCrossSearchResult;

implementation

function ExecuteCrossBinutilsSearchCore(
  const ATarget: TCrossTarget;
  const AFpcCfgPath, ATool: string;
  const ACallbacks: TCrossSearchCallbacks
): TCrossSearchResult;
begin
  Result := Default(TCrossSearchResult);

  if Assigned(ACallbacks.ClearLog) then
    ACallbacks.ClearLog;

  if ATarget.BinutilsPath <> '' then
  begin
    if Assigned(ACallbacks.CheckTool) and
       ACallbacks.CheckTool(ATarget.BinutilsPath, ATarget.BinutilsPrefix, ATool) then
    begin
      Result.Found := True;
      Result.BinutilsPath := ATarget.BinutilsPath;
      Result.BinutilsPrefix := ATarget.BinutilsPrefix;
      Result.Layer := 0;
      Result.LayerName := 'configured';
      if Assigned(ACallbacks.AddLog) then
        ACallbacks.AddLog(0, 'configured', ATarget.BinutilsPath,
          ATarget.BinutilsPrefix, True);
      Exit;
    end;

    if Assigned(ACallbacks.AddLog) then
      ACallbacks.AddLog(0, 'configured', ATarget.BinutilsPath,
        ATarget.BinutilsPrefix, False);
  end;

  if Assigned(ACallbacks.SearchLayer1) then
  begin
    Result := ACallbacks.SearchLayer1(ATarget);
    if Result.Found then
      Exit;
  end;

  if Assigned(ACallbacks.SearchLayer2) then
  begin
    Result := ACallbacks.SearchLayer2(ATarget);
    if Result.Found then
      Exit;
  end;

  if Assigned(ACallbacks.SearchLayer3) then
  begin
    Result := ACallbacks.SearchLayer3(ATarget);
    if Result.Found then
      Exit;
  end;

  if Assigned(ACallbacks.SearchLayer4) then
  begin
    Result := ACallbacks.SearchLayer4(ATarget);
    if Result.Found then
      Exit;
  end;

  if Assigned(ACallbacks.SearchLayer5) then
  begin
    Result := ACallbacks.SearchLayer5(ATarget);
    if Result.Found then
      Exit;
  end;

  if Assigned(ACallbacks.SearchLayer6) then
    Result := ACallbacks.SearchLayer6(ATarget, AFpcCfgPath);
end;

end.
