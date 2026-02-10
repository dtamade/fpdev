unit fpdev.index;

{$mode objfpc}{$H+}

{
================================================================================
  fpdev.index - Multi-Repository Index Manager
================================================================================

  Implements the two-level index architecture for fpdev resource management:

  Level 1: Main Index (fpdev-index)
    - index.json contains repository registry and channels
    - Points to sub-repositories for each resource type

  Level 2: Sub-Repository Manifests (fpdev-bootstrap, fpdev-fpc, etc.)
    - manifest.json contains version-specific download information
    - Each repository handles one resource type

  Download Flow:
    1. Fetch index.json from fpdev-index
    2. Determine target sub-repository based on resource type
    3. Fetch manifest.json from sub-repository
    4. Download binary from URL specified in manifest

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, fphttpclient,
  fpdev.constants, fpdev.output.intf, fpdev.utils.fs;

type
  { Repository type enumeration }
  TRepoType = (rtBootstrap, rtFPC, rtLazarus, rtCross);

  { Repository info from index.json }
  TRepoInfo = record
    Name: string;
    RepoType: TRepoType;
    GitHubURL: string;
    GiteeURL: string;
  end;

  { Channel info from index.json }
  TChannelInfo = record
    Name: string;           // stable, edge
    BootstrapRef: string;   // version or branch ref
    FPCRef: string;
    LazarusRef: string;
    CrossRef: string;
  end;

  { Platform download info from manifest.json }
  TDownloadInfo = record
    URL: string;
    Mirrors: array of string;
    Format: string;         // tar.gz, zip
    SHA256: string;
    Size: Int64;
    Layout: record
      Executable: string;   // e.g., bin/ppcx64
    end;
  end;

  { TFPDevIndex - Main index manager }
  TFPDevIndex = class
  private
    FIndexData: TJSONObject;
    FMirrorPreference: string;  // 'github', 'gitee', 'auto'
    FOutput: IOutput;
    FCacheDir: string;

    procedure Log(const AMsg: string);
    procedure LogFmt(const AFormat: string; const AArgs: array of const);

    function FetchJSON(const AURL: string): TJSONObject;
    function GetRawURL(const ARepoURL, ABranch, AFilePath: string): string;
    function RepoTypeToString(AType: TRepoType): string;
    function StringToRepoType(const AStr: string): TRepoType;

  public
    constructor Create(const AMirrorPreference: string = 'auto');
    destructor Destroy; override;

    { Initialize index from remote }
    function Initialize: Boolean;

    { Get repository info by type }
    function GetRepoInfo(AType: TRepoType): TRepoInfo;

    { Get channel info }
    function GetChannelInfo(const AChannel: string): TChannelInfo;

    { Get download info for a specific version and platform }
    function GetBootstrapDownloadInfo(const AVersion, APlatform: string;
      out AInfo: TDownloadInfo): Boolean;
    function GetFPCDownloadInfo(const AVersion, APlatform: string;
      out AInfo: TDownloadInfo): Boolean;
    function GetLazarusDownloadInfo(const AVersion, APlatform: string;
      out AInfo: TDownloadInfo): Boolean;

    { List available versions }
    function ListBootstrapVersions: TStringArray;
    function ListFPCVersions: TStringArray;
    function ListLazarusVersions: TStringArray;

    { Properties }
    property MirrorPreference: string read FMirrorPreference write FMirrorPreference;
    property Output: IOutput read FOutput write FOutput;
  end;

  { Helper function to get current platform identifier }
  function GetPlatformIdentifier: string;

implementation

{ Helper Functions }

function GetPlatformIdentifier: string;
begin
  {$IFDEF LINUX}
    {$IFDEF CPUX86_64}
    Result := 'linux-x86_64';
    {$ENDIF}
    {$IFDEF CPUAARCH64}
    Result := 'linux-aarch64';
    {$ENDIF}
    {$IFDEF CPUI386}
    Result := 'linux-i386';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF MSWINDOWS}
    {$IFDEF CPUX86_64}
    Result := 'windows-x86_64';
    {$ENDIF}
    {$IFDEF CPUI386}
    Result := 'windows-i386';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPUX86_64}
    Result := 'darwin-x86_64';
    {$ENDIF}
    {$IFDEF CPUAARCH64}
    Result := 'darwin-aarch64';
    {$ENDIF}
  {$ENDIF}

  if Result = '' then
    Result := 'unknown';
end;

{ TFPDevIndex }

constructor TFPDevIndex.Create(const AMirrorPreference: string);
begin
  inherited Create;
  FIndexData := nil;
  FMirrorPreference := AMirrorPreference;
  FOutput := nil;

  {$IFDEF MSWINDOWS}
  FCacheDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
               FPDEV_CONFIG_DIR + PathDelim + 'cache';
  {$ELSE}
  FCacheDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
               FPDEV_CONFIG_DIR + PathDelim + 'cache';
  {$ENDIF}
end;

destructor TFPDevIndex.Destroy;
begin
  if Assigned(FIndexData) then
    FIndexData.Free;
  inherited Destroy;
end;

procedure TFPDevIndex.Log(const AMsg: string);
begin
  if Assigned(FOutput) then
    FOutput.WriteLn(AMsg);
end;

procedure TFPDevIndex.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  if Assigned(FOutput) then
    FOutput.WriteLn(Format(AFormat, AArgs));
end;

function TFPDevIndex.GetRawURL(const ARepoURL, ABranch, AFilePath: string): string;
var
  RepoPath: string;
begin
  // Convert git URL to raw content URL
  // GitHub: https://github.com/user/repo.git -> https://raw.githubusercontent.com/user/repo/branch/file
  // Gitee: https://gitee.com/user/repo.git -> https://gitee.com/user/repo/raw/branch/file

  RepoPath := ARepoURL;
  if Pos('.git', RepoPath) > 0 then
    RepoPath := Copy(RepoPath, 1, Pos('.git', RepoPath) - 1);

  if Pos('github.com', RepoPath) > 0 then
  begin
    RepoPath := StringReplace(RepoPath, 'github.com', 'raw.githubusercontent.com', []);
    Result := RepoPath + '/' + ABranch + '/' + AFilePath;
  end
  else if Pos('gitee.com', RepoPath) > 0 then
  begin
    Result := RepoPath + '/raw/' + ABranch + '/' + AFilePath;
  end
  else
    Result := RepoPath + '/' + ABranch + '/' + AFilePath;
end;

function TFPDevIndex.FetchJSON(const AURL: string): TJSONObject;
var
  HTTPClient: TFPHTTPClient;
  Response: string;
  Parser: TJSONParser;
begin
  Result := nil;

  HTTPClient := TFPHTTPClient.Create(nil);
  try
    HTTPClient.AllowRedirect := True;
    HTTPClient.ConnectTimeout := 10000;
    HTTPClient.IOTimeout := 30000;

    try
      Response := HTTPClient.Get(AURL);

      Parser := TJSONParser.Create(Response, []);
      try
        Result := Parser.Parse as TJSONObject;
      finally
        Parser.Free;
      end;
    except
      on E: Exception do
      begin
        LogFmt('Error fetching %s: %s', [AURL, E.Message]);
        Result := nil;
      end;
    end;
  finally
    HTTPClient.Free;
  end;
end;

function TFPDevIndex.RepoTypeToString(AType: TRepoType): string;
begin
  case AType of
    rtBootstrap: Result := 'bootstrap';
    rtFPC: Result := 'fpc';
    rtLazarus: Result := 'lazarus';
    rtCross: Result := 'cross';
  else
    Result := 'unknown';
  end;
end;

function TFPDevIndex.StringToRepoType(const AStr: string): TRepoType;
var
  LStr: string;
begin
  LStr := LowerCase(AStr);
  if LStr = 'bootstrap' then
    Result := rtBootstrap
  else if LStr = 'fpc' then
    Result := rtFPC
  else if LStr = 'lazarus' then
    Result := rtLazarus
  else if LStr = 'cross' then
    Result := rtCross
  else
    Result := rtFPC;  // Default
end;

function TFPDevIndex.Initialize: Boolean;
var
  IndexURL: string;
begin
  Result := False;

  Log('Initializing fpdev index...');

  // Determine which mirror to use
  if (FMirrorPreference = 'gitee') or (FMirrorPreference = 'china') then
    IndexURL := GetRawURL(FPDEV_INDEX_GITEE, 'main', 'index.json')
  else
    IndexURL := GetRawURL(FPDEV_INDEX_GITHUB, 'main', 'index.json');

  LogFmt('Fetching index from: %s', [IndexURL]);

  // Free existing data
  if Assigned(FIndexData) then
  begin
    FIndexData.Free;
    FIndexData := nil;
  end;

  // Fetch index.json
  FIndexData := FetchJSON(IndexURL);

  if not Assigned(FIndexData) then
  begin
    // Try fallback mirror
    if Pos('github', IndexURL) > 0 then
      IndexURL := GetRawURL(FPDEV_INDEX_GITEE, 'main', 'index.json')
    else
      IndexURL := GetRawURL(FPDEV_INDEX_GITHUB, 'main', 'index.json');

    LogFmt('Primary failed, trying fallback: %s', [IndexURL]);
    FIndexData := FetchJSON(IndexURL);
  end;

  Result := Assigned(FIndexData);

  if Result then
    Log('Index initialized successfully')
  else
    Log('Failed to initialize index from any source');
end;

function TFPDevIndex.GetRepoInfo(AType: TRepoType): TRepoInfo;
var
  Repos: TJSONObject;
  RepoData: TJSONObject;
  TypeStr: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Name := '';
  Result.GitHubURL := '';
  Result.GiteeURL := '';
  Result.RepoType := AType;

  if not Assigned(FIndexData) then
    Exit;

  TypeStr := RepoTypeToString(AType);

  try
    Repos := FIndexData.Objects['repositories'];
    if not Assigned(Repos) then
      Exit;

    RepoData := Repos.Objects[TypeStr];
    if not Assigned(RepoData) then
      Exit;

    Result.Name := RepoData.Get('name', '');
    Result.GitHubURL := RepoData.Get('github', '');
    Result.GiteeURL := RepoData.Get('gitee', '');
  except
    // Return empty result on error
  end;
end;

function TFPDevIndex.GetChannelInfo(const AChannel: string): TChannelInfo;
var
  Channels: TJSONObject;
  ChannelData: TJSONObject;
  BootstrapObj, FPCObj, LazarusObj, CrossObj: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Name := AChannel;
  Result.BootstrapRef := '';
  Result.FPCRef := '';
  Result.LazarusRef := '';
  Result.CrossRef := '';

  if not Assigned(FIndexData) then
    Exit;

  try
    Channels := FIndexData.Objects['channels'];
    if not Assigned(Channels) then
      Exit;

    ChannelData := Channels.Objects[AChannel];
    if not Assigned(ChannelData) then
      Exit;

    BootstrapObj := ChannelData.Objects['bootstrap'];
    if Assigned(BootstrapObj) then
      Result.BootstrapRef := BootstrapObj.Get('ref', '');

    FPCObj := ChannelData.Objects['fpc'];
    if Assigned(FPCObj) then
      Result.FPCRef := FPCObj.Get('ref', '');

    LazarusObj := ChannelData.Objects['lazarus'];
    if Assigned(LazarusObj) then
      Result.LazarusRef := LazarusObj.Get('ref', '');

    CrossObj := ChannelData.Objects['cross'];
    if Assigned(CrossObj) then
      Result.CrossRef := CrossObj.Get('ref', '');
  except
    // Return empty result on error
  end;
end;

function TFPDevIndex.GetBootstrapDownloadInfo(const AVersion, APlatform: string;
  out AInfo: TDownloadInfo): Boolean;
var
  RepoInfo: TRepoInfo;
  ManifestURL: string;
  ManifestData: TJSONObject;
  Releases, VersionData, Platforms, PlatformData: TJSONObject;
  LayoutObj: TJSONObject;
  MirrorsArray: TJSONArray;
  i: Integer;
begin
  Result := False;
  System.Initialize(AInfo);

  RepoInfo := GetRepoInfo(rtBootstrap);
  if RepoInfo.GitHubURL = '' then
    Exit;

  // Fetch manifest from sub-repository
  if (FMirrorPreference = 'gitee') and (RepoInfo.GiteeURL <> '') then
    ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
  else
    ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

  LogFmt('Fetching bootstrap manifest from: %s', [ManifestURL]);

  ManifestData := FetchJSON(ManifestURL);
  if not Assigned(ManifestData) then
  begin
    // Try fallback
    if Pos('github', ManifestURL) > 0 then
      ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
    else
      ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

    ManifestData := FetchJSON(ManifestURL);
  end;

  if not Assigned(ManifestData) then
    Exit;

  try
    Releases := ManifestData.Objects['releases'];
    if not Assigned(Releases) then
      Exit;

    VersionData := Releases.Objects[AVersion];
    if not Assigned(VersionData) then
      Exit;

    Platforms := VersionData.Objects['platforms'];
    if not Assigned(Platforms) then
      Exit;

    PlatformData := Platforms.Objects[APlatform];
    if not Assigned(PlatformData) then
      Exit;

    // Extract download info
    AInfo.URL := PlatformData.Get('url', '');
    AInfo.Format := PlatformData.Get('format', 'tar.gz');
    AInfo.SHA256 := PlatformData.Get('sha256', '');
    AInfo.Size := PlatformData.Get('size', Int64(0));

    // Extract mirrors
    MirrorsArray := PlatformData.Arrays['mirrors'];
    if Assigned(MirrorsArray) then
    begin
      SetLength(AInfo.Mirrors, MirrorsArray.Count);
      for i := 0 to MirrorsArray.Count - 1 do
        AInfo.Mirrors[i] := MirrorsArray.Strings[i];
    end;

    // Extract layout info
    LayoutObj := PlatformData.Objects['layout'];
    if Assigned(LayoutObj) then
      AInfo.Layout.Executable := LayoutObj.Get('executable', '');

    Result := AInfo.URL <> '';
  finally
    ManifestData.Free;
  end;
end;

function TFPDevIndex.GetFPCDownloadInfo(const AVersion, APlatform: string;
  out AInfo: TDownloadInfo): Boolean;
var
  RepoInfo: TRepoInfo;
  ManifestURL: string;
  ManifestData: TJSONObject;
  Releases, VersionData, Platforms, PlatformData: TJSONObject;
  MirrorsArray: TJSONArray;
  i: Integer;
begin
  Result := False;
  System.Initialize(AInfo);

  RepoInfo := GetRepoInfo(rtFPC);
  if RepoInfo.GitHubURL = '' then
    Exit;

  // Fetch manifest from sub-repository
  if (FMirrorPreference = 'gitee') and (RepoInfo.GiteeURL <> '') then
    ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
  else
    ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

  LogFmt('Fetching FPC manifest from: %s', [ManifestURL]);

  ManifestData := FetchJSON(ManifestURL);
  if not Assigned(ManifestData) then
  begin
    // Try fallback
    if Pos('github', ManifestURL) > 0 then
      ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
    else
      ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

    ManifestData := FetchJSON(ManifestURL);
  end;

  if not Assigned(ManifestData) then
    Exit;

  try
    Releases := ManifestData.Objects['releases'];
    if not Assigned(Releases) then
      Exit;

    VersionData := Releases.Objects[AVersion];
    if not Assigned(VersionData) then
      Exit;

    Platforms := VersionData.Objects['platforms'];
    if not Assigned(Platforms) then
      Exit;

    PlatformData := Platforms.Objects[APlatform];
    if not Assigned(PlatformData) then
      Exit;

    // Extract download info
    AInfo.URL := PlatformData.Get('url', '');
    AInfo.Format := PlatformData.Get('format', 'tar.gz');
    AInfo.SHA256 := PlatformData.Get('sha256', '');
    AInfo.Size := PlatformData.Get('size', Int64(0));

    // Extract mirrors
    MirrorsArray := PlatformData.Arrays['mirrors'];
    if Assigned(MirrorsArray) then
    begin
      SetLength(AInfo.Mirrors, MirrorsArray.Count);
      for i := 0 to MirrorsArray.Count - 1 do
        AInfo.Mirrors[i] := MirrorsArray.Strings[i];
    end;

    Result := AInfo.URL <> '';
  finally
    ManifestData.Free;
  end;
end;

function TFPDevIndex.GetLazarusDownloadInfo(const AVersion, APlatform: string;
  out AInfo: TDownloadInfo): Boolean;
var
  RepoInfo: TRepoInfo;
  ManifestURL: string;
  ManifestData: TJSONObject;
  Releases, VersionData, Platforms, PlatformData: TJSONObject;
  MirrorsArray: TJSONArray;
  i: Integer;
begin
  Result := False;
  System.Initialize(AInfo);

  RepoInfo := GetRepoInfo(rtLazarus);
  if RepoInfo.GitHubURL = '' then
    Exit;

  // Fetch manifest from sub-repository
  if (FMirrorPreference = 'gitee') and (RepoInfo.GiteeURL <> '') then
    ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
  else
    ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

  LogFmt('Fetching Lazarus manifest from: %s', [ManifestURL]);

  ManifestData := FetchJSON(ManifestURL);
  if not Assigned(ManifestData) then
  begin
    // Try fallback
    if Pos('github', ManifestURL) > 0 then
      ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
    else
      ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

    ManifestData := FetchJSON(ManifestURL);
  end;

  if not Assigned(ManifestData) then
    Exit;

  try
    Releases := ManifestData.Objects['releases'];
    if not Assigned(Releases) then
      Exit;

    VersionData := Releases.Objects[AVersion];
    if not Assigned(VersionData) then
      Exit;

    Platforms := VersionData.Objects['platforms'];
    if not Assigned(Platforms) then
      Exit;

    PlatformData := Platforms.Objects[APlatform];
    if not Assigned(PlatformData) then
      Exit;

    // Extract download info
    AInfo.URL := PlatformData.Get('url', '');
    AInfo.Format := PlatformData.Get('format', 'tar.gz');
    AInfo.SHA256 := PlatformData.Get('sha256', '');
    AInfo.Size := PlatformData.Get('size', Int64(0));

    // Extract mirrors
    MirrorsArray := PlatformData.Arrays['mirrors'];
    if Assigned(MirrorsArray) then
    begin
      SetLength(AInfo.Mirrors, MirrorsArray.Count);
      for i := 0 to MirrorsArray.Count - 1 do
        AInfo.Mirrors[i] := MirrorsArray.Strings[i];
    end;

    Result := AInfo.URL <> '';
  finally
    ManifestData.Free;
  end;
end;

function TFPDevIndex.ListBootstrapVersions: TStringArray;
var
  RepoInfo: TRepoInfo;
  ManifestURL: string;
  ManifestData: TJSONObject;
  Releases: TJSONObject;
  i: Integer;
begin
  Result := nil;

  RepoInfo := GetRepoInfo(rtBootstrap);
  if RepoInfo.GitHubURL = '' then
    Exit;

  if (FMirrorPreference = 'gitee') and (RepoInfo.GiteeURL <> '') then
    ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
  else
    ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

  ManifestData := FetchJSON(ManifestURL);
  if not Assigned(ManifestData) then
    Exit;

  try
    Releases := ManifestData.Objects['releases'];
    if not Assigned(Releases) then
      Exit;

    SetLength(Result, Releases.Count);
    for i := 0 to Releases.Count - 1 do
      Result[i] := Releases.Names[i];
  finally
    ManifestData.Free;
  end;
end;

function TFPDevIndex.ListFPCVersions: TStringArray;
var
  RepoInfo: TRepoInfo;
  ManifestURL: string;
  ManifestData: TJSONObject;
  Releases: TJSONObject;
  i: Integer;
begin
  Result := nil;

  RepoInfo := GetRepoInfo(rtFPC);
  if RepoInfo.GitHubURL = '' then
    Exit;

  if (FMirrorPreference = 'gitee') and (RepoInfo.GiteeURL <> '') then
    ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
  else
    ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

  ManifestData := FetchJSON(ManifestURL);
  if not Assigned(ManifestData) then
    Exit;

  try
    Releases := ManifestData.Objects['releases'];
    if not Assigned(Releases) then
      Exit;

    SetLength(Result, Releases.Count);
    for i := 0 to Releases.Count - 1 do
      Result[i] := Releases.Names[i];
  finally
    ManifestData.Free;
  end;
end;

function TFPDevIndex.ListLazarusVersions: TStringArray;
var
  RepoInfo: TRepoInfo;
  ManifestURL: string;
  ManifestData: TJSONObject;
  Releases: TJSONObject;
  i: Integer;
begin
  Result := nil;

  RepoInfo := GetRepoInfo(rtLazarus);
  if RepoInfo.GitHubURL = '' then
    Exit;

  if (FMirrorPreference = 'gitee') and (RepoInfo.GiteeURL <> '') then
    ManifestURL := GetRawURL(RepoInfo.GiteeURL, 'main', 'manifest.json')
  else
    ManifestURL := GetRawURL(RepoInfo.GitHubURL, 'main', 'manifest.json');

  ManifestData := FetchJSON(ManifestURL);
  if not Assigned(ManifestData) then
    Exit;

  try
    Releases := ManifestData.Objects['releases'];
    if not Assigned(Releases) then
      Exit;

    SetLength(Result, Releases.Count);
    for i := 0 to Releases.Count - 1 do
      Result[i] := Releases.Names[i];
  finally
    ManifestData.Free;
  end;
end;

end.
