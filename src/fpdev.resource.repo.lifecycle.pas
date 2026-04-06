unit fpdev.resource.repo.lifecycle;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson;

type
  TRepoLifecycleBoolFunc = function: Boolean of object;
  TRepoLifecycleStringFunc = function: string of object;
  TRepoLifecycleCloneFunc = function(const AURL: string): Boolean of object;
  TRepoLifecycleLogProc = procedure(const AMsg: string) of object;
  TRepoLifecycleTouchProc = procedure of object;

function ExecuteResourceRepoInitializeCore(
  const ALocalPath, APrimaryURL: string;
  const AMirrors: TStringArray;
  ANeedsUpdate: Boolean;
  AIsGitRepository: TRepoLifecycleBoolFunc;
  AGetLastCommitHash: TRepoLifecycleStringFunc;
  AGitClone: TRepoLifecycleCloneFunc;
  AGitPull, ALoadManifest: TRepoLifecycleBoolFunc;
  ALogLine: TRepoLifecycleLogProc;
  ATouchUpdateCheck: TRepoLifecycleTouchProc
): Boolean;

function ExecuteResourceRepoUpdateCore(
  AForce, ANeedsUpdate: Boolean;
  const ALastUpdateCheck: TDateTime;
  AIsGitRepository, AGitPull, ALoadManifest: TRepoLifecycleBoolFunc;
  ALogLine: TRepoLifecycleLogProc;
  ATouchUpdateCheck: TRepoLifecycleTouchProc
): Boolean;

function LoadResourceRepoManifestCore(
  const AManifestPath: string;
  ALogLine: TRepoLifecycleLogProc;
  out AManifestData: TJSONObject;
  out AManifestLoaded: Boolean
): Boolean;

function EnsureResourceRepoManifestLoadedCore(
  AManifestLoaded: Boolean;
  AManifestData: TJSONObject;
  ALoadManifest: TRepoLifecycleBoolFunc
): Boolean;

implementation

uses
  Classes, jsonparser, fpdev.resource.repo.statusflow;

function ExecuteResourceRepoInitializeCore(
  const ALocalPath, APrimaryURL: string;
  const AMirrors: TStringArray;
  ANeedsUpdate: Boolean;
  AIsGitRepository: TRepoLifecycleBoolFunc;
  AGetLastCommitHash: TRepoLifecycleStringFunc;
  AGitClone: TRepoLifecycleCloneFunc;
  AGitPull, ALoadManifest: TRepoLifecycleBoolFunc;
  ALogLine: TRepoLifecycleLogProc;
  ATouchUpdateCheck: TRepoLifecycleTouchProc
): Boolean;
var
  Index: Integer;
  Success: Boolean;

  procedure LogLine(const AMsg: string);
  begin
    if Assigned(ALogLine) then
      ALogLine(AMsg);
  end;

begin
  Result := False;

  if Assigned(AIsGitRepository) and AIsGitRepository() then
  begin
    LogLine(Format('Resource repository already exists at: %s', [ALocalPath]));
    if Assigned(AGetLastCommitHash) then
      LogLine(Format('Commit: %s', [AGetLastCommitHash()]));

    if ANeedsUpdate then
    begin
      if Assigned(AGitPull) then
        AGitPull();
      if Assigned(ATouchUpdateCheck) then
        ATouchUpdateCheck;
    end;

    Result := True;
  end
  else
  begin
    Success := Assigned(AGitClone) and AGitClone(APrimaryURL);
    if not Success then
    begin
      LogLine('Failed to clone from primary URL, trying mirrors...');
      for Index := 0 to High(AMirrors) do
      begin
        LogLine(Format('Trying mirror %d: %s', [Index + 1, AMirrors[Index]]));
        Success := AGitClone(AMirrors[Index]);
        if Success then
          Break;
      end;
    end;

    if Success then
    begin
      if Assigned(ATouchUpdateCheck) then
        ATouchUpdateCheck;
      Result := True;
    end
    else
    begin
      LogLine('Failed to clone resource repository from any source');
      Result := False;
    end;
  end;

  if Result and Assigned(ALoadManifest) then
    Result := ALoadManifest();
end;

function ExecuteResourceRepoUpdateCore(
  AForce, ANeedsUpdate: Boolean;
  const ALastUpdateCheck: TDateTime;
  AIsGitRepository, AGitPull, ALoadManifest: TRepoLifecycleBoolFunc;
  ALogLine: TRepoLifecycleLogProc;
  ATouchUpdateCheck: TRepoLifecycleTouchProc
): Boolean;

  procedure LogLine(const AMsg: string);
  begin
    if Assigned(ALogLine) then
      ALogLine(AMsg);
  end;

begin
  if (not Assigned(AIsGitRepository)) or (not AIsGitRepository()) then
  begin
    LogLine('Error: Resource repository not initialized');
    Exit(False);
  end;

  if AForce or ANeedsUpdate then
  begin
    Result := Assigned(AGitPull) and AGitPull();
    if Result then
    begin
      if Assigned(ATouchUpdateCheck) then
        ATouchUpdateCheck;
      if Assigned(ALoadManifest) and (not ALoadManifest()) then
        LogLine('Warning: Git pull succeeded but manifest reload failed');
    end;
    Exit;
  end;

  LogLine(Format('Resource repository is up to date (last check: %s)', [
    FormatResourceRepoLastUpdateCheck(ALastUpdateCheck)
  ]));
  Result := True;
end;

function LoadResourceRepoManifestCore(
  const AManifestPath: string;
  ALogLine: TRepoLifecycleLogProc;
  out AManifestData: TJSONObject;
  out AManifestLoaded: Boolean
): Boolean;
var
  Content: string;
  Parser: TJSONParser;
  Parsed: TJSONData;
  Lines: TStringList;

  procedure LogLine(const AMsg: string);
  begin
    if Assigned(ALogLine) then
      ALogLine(AMsg);
  end;

begin
  Result := False;
  AManifestLoaded := False;
  AManifestData := nil;

  if not FileExists(AManifestPath) then
  begin
    LogLine('Warning: manifest.json not found in resource repository');
    Exit(False);
  end;

  try
    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(AManifestPath);
      Content := Lines.Text;
    finally
      Lines.Free;
    end;

    Parser := TJSONParser.Create(Content, []);
    try
      Parsed := Parser.Parse;
      if Parsed is TJSONObject then
      begin
        AManifestData := TJSONObject(Parsed);
        AManifestLoaded := True;
        Result := True;
        LogLine(Format('Manifest loaded (version: %s)', [
          AManifestData.Get('version', 'unknown')
        ]));
      end
      else
      begin
        Parsed.Free;
        LogLine('Warning: Failed to parse manifest.json');
      end;
    finally
      Parser.Free;
    end;
  except
    on E: Exception do
    begin
      if Assigned(AManifestData) then
        FreeAndNil(AManifestData);
      AManifestLoaded := False;
      LogLine(Format('Error loading manifest: %s', [E.Message]));
      Result := False;
    end;
  end;
end;

function EnsureResourceRepoManifestLoadedCore(
  AManifestLoaded: Boolean;
  AManifestData: TJSONObject;
  ALoadManifest: TRepoLifecycleBoolFunc
): Boolean;
begin
  if AManifestLoaded and Assigned(AManifestData) then
    Exit(True);
  Result := Assigned(ALoadManifest) and ALoadManifest();
end;

end.
