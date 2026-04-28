program test_package_resource_flow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson,
  fpdev.output.intf,
  fpdev.package.types,
  fpdev.package.managerflow,
  fpdev.pkg.version,
  fpdev.resource.repo.types,
  fpdev.resource.repo.mirror,
  fpdev.resource.repo.mirrorflow;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

  TPackageFlowProbe = class
  public
    PrepareResult: Boolean;
    BuildResult: Boolean;
    MetadataResult: Boolean;
    PrepareCalls: Integer;
    BuildCalls: Integer;
    MetadataCalls: Integer;
    LastPreparedSource: string;
    LastPreparedInstall: string;
    LastBuildPath: string;
    LastMetadataPath: string;
    LastMetadataInfo: TPackageInfo;
    PackageInfo: TPackageInfo;
    function PrepareTree(const ASourcePath, AInstallPath: string): Boolean;
    function BuildSource(const ASourcePath: string): Boolean;
    function WriteMetadata(const AInstallPath: string; const AInfo: TPackageInfo): Boolean;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
  end;

  TMirrorFlowProbe = class
  public
    DetectCalls: Integer;
    function DetectRegion: string;
    function TestLatency(const AURL: string; ATimeoutMS: Integer): Integer;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TPackageFlowProbe.PrepareTree(const ASourcePath, AInstallPath: string): Boolean;
begin
  Inc(PrepareCalls);
  LastPreparedSource := ASourcePath;
  LastPreparedInstall := AInstallPath;
  Result := PrepareResult;
end;

function TPackageFlowProbe.BuildSource(const ASourcePath: string): Boolean;
begin
  Inc(BuildCalls);
  LastBuildPath := ASourcePath;
  Result := BuildResult;
end;

function TPackageFlowProbe.WriteMetadata(const AInstallPath: string; const AInfo: TPackageInfo): Boolean;
begin
  Inc(MetadataCalls);
  LastMetadataPath := AInstallPath;
  LastMetadataInfo := AInfo;
  Result := MetadataResult;
end;

function TPackageFlowProbe.GetPackageInfo(const APackageName: string): TPackageInfo;
begin
  if APackageName = '' then;
  Result := PackageInfo;
end;

function TMirrorFlowProbe.DetectRegion: string;
begin
  Inc(DetectCalls);
  Result := 'china';
end;

function TMirrorFlowProbe.TestLatency(const AURL: string; ATimeoutMS: Integer): Integer;
begin
  if ATimeoutMS < 0 then;
  if Pos('cn.mirror', AURL) > 0 then
    Result := 30
  else if Pos('primary', AURL) > 0 then
    Result := 300
  else
    Result := 120;
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', AName);
    Inc(PassCount);
  end
  else
  begin
    WriteLn('[FAIL] ', AName, ': ', AReason);
    Inc(FailCount);
  end;
end;

function MakePackage(const AName, AVersion: string; const ADependencies: array of string): TPackageInfo;
var
  I: Integer;
begin
  Result := EmptyPackageInfo;
  Result.Name := AName;
  Result.Version := AVersion;
  SetLength(Result.Dependencies, Length(ADependencies));
  for I := 0 to High(ADependencies) do
    Result.Dependencies[I] := ADependencies[I];
end;

procedure TestExecutePackageInstallFromSourceCoreStopsAfterPrepareFailure;
var
  Probe: TPackageFlowProbe;
begin
  Probe := TPackageFlowProbe.Create;
  try
    Probe.PrepareResult := False;
    Probe.BuildResult := True;
    Probe.MetadataResult := True;

    Check(
      'package install core returns false when prepare fails',
      not ExecutePackageInstallFromSourceCore(
        'alpha',
        '/tmp/source',
        '/tmp/install',
        @Probe.PrepareTree,
        @Probe.GetPackageInfo,
        @Probe.BuildSource,
        @Probe.WriteMetadata
      ),
      'prepare failure should stop install flow'
    );
    Check('package install core does not build after prepare failure', Probe.BuildCalls = 0,
      'build calls=' + IntToStr(Probe.BuildCalls));
    Check('package install core does not write metadata after prepare failure', Probe.MetadataCalls = 0,
      'metadata calls=' + IntToStr(Probe.MetadataCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestExecutePackageInstallFromSourceCoreBuildsAndWritesMetadata;
var
  Probe: TPackageFlowProbe;
begin
  Probe := TPackageFlowProbe.Create;
  try
    Probe.PrepareResult := True;
    Probe.BuildResult := True;
    Probe.MetadataResult := True;
    Probe.PackageInfo := MakePackage('alpha', '1.2.3', []);

    Check(
      'package install core succeeds on green path',
      ExecutePackageInstallFromSourceCore(
        'alpha',
        '/tmp/source',
        '/tmp/install',
        @Probe.PrepareTree,
        @Probe.GetPackageInfo,
        @Probe.BuildSource,
        @Probe.WriteMetadata
      ),
      'expected install flow success'
    );
    Check('package install core records build path', Probe.LastBuildPath = '/tmp/install',
      'build path=' + Probe.LastBuildPath);
    Check('package install core writes metadata to install path', Probe.LastMetadataPath = '/tmp/install',
      'metadata path=' + Probe.LastMetadataPath);
    Check('package install core preserves package metadata name', Probe.LastMetadataInfo.Name = 'alpha',
      'metadata name=' + Probe.LastMetadataInfo.Name);
  finally
    Probe.Free;
  end;
end;

procedure TestResolvePackageDependenciesCoreAndWriteLines;
var
  Available, Installed: TPackageArray;
  Dependencies: TStringArray;
  OutRef: TStringOutput;
  Outp: IOutput;
begin
  SetLength(Available, 2);
  Available[0] := MakePackage('alpha', '1.0.0', ['beta>=1.0.0']);
  Available[1] := MakePackage('beta', '2.0.0', []);
  SetLength(Installed, 0);

  Dependencies := ResolvePackageDependenciesCore('alpha', Available, Installed, @ExtractPackageName);
  Check('package dependency resolver keeps dependency first', (Length(Dependencies) >= 2) and
    SameText(Dependencies[0], 'beta'), 'first dep=' + Dependencies[0]);
  Check('package dependency resolver keeps root last', (Length(Dependencies) >= 2) and
    SameText(Dependencies[High(Dependencies)], 'alpha'), 'last dep=' + Dependencies[High(Dependencies)]);

  OutRef := TStringOutput.Create;
  Outp := OutRef;
  Check(
    'package dependency writer succeeds',
    WritePackageDependencyLinesCore('alpha', Dependencies, Outp),
    OutRef.Text
  );
  Check('package dependency writer emits package header', OutRef.Contains('Dependencies for alpha'),
    OutRef.Text);
  Check('package dependency writer emits resolved dependency', OutRef.Contains('beta'),
    OutRef.Text);
end;

procedure TestSelectResourceRepoBestMirrorCoreUsesCache;
var
  Selection: TResourceRepoMirrorSelection;
  Probe: TMirrorFlowProbe;
begin
  Probe := TMirrorFlowProbe.Create;
  try
    Selection := SelectResourceRepoBestMirrorCore(
      nil,
      '',
      'https://primary.example/repo.git',
      [],
      'https://cached.example/repo.git',
      EncodeDate(2026, 4, 12) + EncodeTime(12, 0, 0, 0),
      1,
      EncodeDate(2026, 4, 12) + EncodeTime(12, 30, 0, 0),
      @Probe.DetectRegion,
      @Probe.TestLatency
    );

    Check('mirror selection returns cached mirror on cache hit',
      Selection.SelectedMirror = 'https://cached.example/repo.git',
      Selection.SelectedMirror);
    Check('mirror selection marks cache hit', Selection.UsedCache, 'expected cache hit');
    Check('mirror selection skips region detection on cache hit', Probe.DetectCalls = 0,
      'detect calls=' + IntToStr(Probe.DetectCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestSelectResourceRepoBestMirrorCoreBuildsCandidatesAndLatencies;
var
  Manifest, Repo, Mirror: TJSONObject;
  Mirrors: TJSONArray;
  Selection: TResourceRepoMirrorSelection;
  Probe: TMirrorFlowProbe;
begin
  Probe := TMirrorFlowProbe.Create;
  Manifest := TJSONObject.Create;
  try
    Repo := TJSONObject.Create;
    Mirrors := TJSONArray.Create;
    Mirror := TJSONObject.Create;
    Mirror.Add('name', 'CN');
    Mirror.Add('url', 'https://cn.mirror.example/repo.git');
    Mirror.Add('region', 'china');
    Mirror.Add('priority', 10);
    Mirrors.Add(Mirror);
    Repo.Add('mirrors', Mirrors);
    Manifest.Add('repository', Repo);

    Selection := SelectResourceRepoBestMirrorCore(
      Manifest,
      '',
      'https://primary.example/repo.git',
      ['https://config.example/repo.git'],
      '',
      0,
      1,
      EncodeDate(2026, 4, 12) + EncodeTime(14, 0, 0, 0),
      @Probe.DetectRegion,
      @Probe.TestLatency
    );

    Check('mirror selection chooses fastest candidate',
      Selection.SelectedMirror = 'https://cn.mirror.example/repo.git',
      Selection.SelectedMirror);
    Check('mirror selection records used region',
      Selection.UsedRegion = 'china',
      Selection.UsedRegion);
    Check('mirror selection returns candidate latencies',
      Length(Selection.CandidateLatencies) = Length(Selection.CandidateMirrors),
      'latencies=' + IntToStr(Length(Selection.CandidateLatencies)));
  finally
    Manifest.Free;
    Probe.Free;
  end;
end;

procedure TestConvertResourceRepoMirrorsCoreMapsFields;
var
  Parsed: TResourceRepoMirrorInfoArray;
  Mirrors: TMirrorArray;
begin
  SetLength(Parsed, 1);
  Parsed[0].Name := 'Mirror CN';
  Parsed[0].URL := 'https://cn.example/repo.git';
  Parsed[0].Region := 'china';
  Parsed[0].Priority := 10;

  Mirrors := ConvertResourceRepoMirrorsCore(Parsed);
  Check('mirror conversion keeps length', Length(Mirrors) = 1, 'length=' + IntToStr(Length(Mirrors)));
  Check('mirror conversion maps name', Mirrors[0].Name = 'Mirror CN', Mirrors[0].Name);
  Check('mirror conversion maps url', Mirrors[0].URL = 'https://cn.example/repo.git', Mirrors[0].URL);
  Check('mirror conversion maps region', Mirrors[0].Region = 'china', Mirrors[0].Region);
  Check('mirror conversion maps priority', Mirrors[0].Priority = 10, IntToStr(Mirrors[0].Priority));
end;

begin
  TestExecutePackageInstallFromSourceCoreStopsAfterPrepareFailure;
  TestExecutePackageInstallFromSourceCoreBuildsAndWritesMetadata;
  TestResolvePackageDependenciesCoreAndWriteLines;
  TestSelectResourceRepoBestMirrorCoreUsesCache;
  TestSelectResourceRepoBestMirrorCoreBuildsCandidatesAndLatencies;
  TestConvertResourceRepoMirrorsCoreMapsFields;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
