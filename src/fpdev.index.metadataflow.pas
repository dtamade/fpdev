unit fpdev.index.metadataflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson;

function BuildIndexRawURLCore(
  const ARepoURL, ABranch, AFilePath: string
): string;

function SelectIndexPrimaryURLCore(
  const AMirrorPreference, AGitHubURL, AGiteeURL, AFilePath: string
): string;

function SelectIndexFallbackURLCore(
  const AMirrorPreference, AGitHubURL, AGiteeURL, APrimaryURL, AFilePath: string
): string;

function TryGetIndexRepoMetadataCore(
  AIndexData: TJSONObject;
  const ARepoKey: string;
  out AName, AGitHubURL, AGiteeURL: string
): Boolean;

function TryGetIndexChannelMetadataCore(
  AIndexData: TJSONObject;
  const AChannel: string;
  out ABootstrapRef, AFPCRef, ALazarusRef, ACrossRef: string
): Boolean;

implementation

const
  URL_PATH_SEPARATOR = '/';
  GITEE_RAW_SEGMENT = '/raw/';

function BuildIndexRawURLCore(
  const ARepoURL, ABranch, AFilePath: string
): string;
var
  RepoPath: string;
begin
  RepoPath := ARepoURL;
  if Pos('.git', RepoPath) > 0 then
    RepoPath := Copy(RepoPath, 1, Pos('.git', RepoPath) - 1);

  if Pos('github.com', RepoPath) > 0 then
  begin
    RepoPath := StringReplace(
      RepoPath,
      'github.com',
      'raw.githubusercontent.com',
      []
    );
    Result := RepoPath + URL_PATH_SEPARATOR + ABranch +
      URL_PATH_SEPARATOR + AFilePath;
  end
  else if Pos('gitee.com', RepoPath) > 0 then
  begin
    Result := RepoPath + GITEE_RAW_SEGMENT + ABranch +
      URL_PATH_SEPARATOR + AFilePath;
  end
  else
    Result := RepoPath + URL_PATH_SEPARATOR + ABranch +
      URL_PATH_SEPARATOR + AFilePath;
end;

function SelectIndexPrimaryURLCore(
  const AMirrorPreference, AGitHubURL, AGiteeURL, AFilePath: string
): string;
begin
  Result := '';

  if ((AMirrorPreference = 'gitee') or (AMirrorPreference = 'china')) and
     (AGiteeURL <> '') then
    Exit(BuildIndexRawURLCore(AGiteeURL, 'main', AFilePath));

  if AGitHubURL <> '' then
    Exit(BuildIndexRawURLCore(AGitHubURL, 'main', AFilePath));

  if AGiteeURL <> '' then
    Exit(BuildIndexRawURLCore(AGiteeURL, 'main', AFilePath));
end;

function SelectIndexFallbackURLCore(
  const AMirrorPreference, AGitHubURL, AGiteeURL, APrimaryURL, AFilePath: string
): string;
begin
  Result := '';

  if ((AMirrorPreference = 'gitee') or (AMirrorPreference = 'china')) then
  begin
    if AGitHubURL <> '' then
      Result := BuildIndexRawURLCore(AGitHubURL, 'main', AFilePath);
  end
  else if AGiteeURL <> '' then
    Result := BuildIndexRawURLCore(AGiteeURL, 'main', AFilePath);

  if Result = APrimaryURL then
    Result := '';
end;

function TryGetIndexRepoMetadataCore(
  AIndexData: TJSONObject;
  const ARepoKey: string;
  out AName, AGitHubURL, AGiteeURL: string
): Boolean;
var
  Repositories: TJSONObject;
  RepoData: TJSONObject;
begin
  Result := False;
  AName := '';
  AGitHubURL := '';
  AGiteeURL := '';

  if AIndexData = nil then
    Exit(False);

  try
    Repositories := AIndexData.Objects['repositories'];
    if Repositories = nil then
      Exit(False);

    RepoData := Repositories.Objects[ARepoKey];
    if RepoData = nil then
      Exit(False);

    AName := RepoData.Get('name', '');
    AGitHubURL := RepoData.Get('github', '');
    AGiteeURL := RepoData.Get('gitee', '');
    Result := True;
  except
    Result := False;
  end;
end;

function TryGetIndexChannelMetadataCore(
  AIndexData: TJSONObject;
  const AChannel: string;
  out ABootstrapRef, AFPCRef, ALazarusRef, ACrossRef: string
): Boolean;
var
  Channels: TJSONObject;
  ChannelData: TJSONObject;
  BootstrapObj: TJSONObject;
  FPCObj: TJSONObject;
  LazarusObj: TJSONObject;
  CrossObj: TJSONObject;
begin
  Result := False;
  ABootstrapRef := '';
  AFPCRef := '';
  ALazarusRef := '';
  ACrossRef := '';

  if AIndexData = nil then
    Exit(False);

  try
    Channels := AIndexData.Objects['channels'];
    if Channels = nil then
      Exit(False);

    ChannelData := Channels.Objects[AChannel];
    if ChannelData = nil then
      Exit(False);

    BootstrapObj := ChannelData.Objects['bootstrap'];
    if BootstrapObj <> nil then
      ABootstrapRef := BootstrapObj.Get('ref', '');

    FPCObj := ChannelData.Objects['fpc'];
    if FPCObj <> nil then
      AFPCRef := FPCObj.Get('ref', '');

    LazarusObj := ChannelData.Objects['lazarus'];
    if LazarusObj <> nil then
      ALazarusRef := LazarusObj.Get('ref', '');

    CrossObj := ChannelData.Objects['cross'];
    if CrossObj <> nil then
      ACrossRef := CrossObj.Get('ref', '');

    Result := True;
  except
    Result := False;
  end;
end;

end.
