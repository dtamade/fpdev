program test_package_queryflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.package.types,
  fpdev.package.queryflow;

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

  TQueryProbe = class
  public
    AvailablePackages: TPackageArray;
    InstalledPackages: TPackageArray;
    PackageInfo: TPackageInfo;
    function GetAvailablePackages: TPackageArray;
    function GetInstalledPackages: TPackageArray;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
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

function TQueryProbe.GetAvailablePackages: TPackageArray;
begin
  Result := AvailablePackages;
end;

function TQueryProbe.GetInstalledPackages: TPackageArray;
begin
  Result := InstalledPackages;
end;

function TQueryProbe.GetPackageInfo(const APackageName: string): TPackageInfo;
begin
  if APackageName = '' then;
  Result := PackageInfo;
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestExecutePackageListCoreUsesInstalledPackages;
var
  Probe: TQueryProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
begin
  Probe := TQueryProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    SetLength(Probe.InstalledPackages, 1);
    Probe.InstalledPackages[0].Name := 'alpha';
    Probe.InstalledPackages[0].Version := '1.0.0';
    Probe.InstalledPackages[0].Description := 'installed package';

    Check('queryflow list succeeds',
      ExecutePackageListCore(False, @Probe.GetAvailablePackages, @Probe.GetInstalledPackages,
        'Installed:', 'Available:', 'No installed', 'No available', OutRef));
    Check('queryflow list writes installed header', OutBuf.Contains('Installed:'), OutBuf.Text);
    Check('queryflow list writes installed package', OutBuf.Contains('alpha'), OutBuf.Text);
  finally
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecutePackageSearchCoreWritesNoResults;
var
  Probe: TQueryProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
begin
  Probe := TQueryProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    Check('queryflow search succeeds',
      ExecutePackageSearchCore('json', @Probe.GetAvailablePackages,
        'installed', 'available', 'No results', OutRef));
    Check('queryflow search writes no-results line',
      OutBuf.Contains('No results: json'), OutBuf.Text);
  finally
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecutePackageInfoCoreWritesInstallPath;
var
  Probe: TQueryProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
begin
  Probe := TQueryProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    Probe.PackageInfo.Name := 'alpha';
    Probe.PackageInfo.Version := '1.0.0';
    Probe.PackageInfo.Description := 'installed package';
    Probe.PackageInfo.Installed := True;
    Probe.PackageInfo.InstallPath := '/tmp/alpha';

    Check('queryflow info succeeds',
      ExecutePackageInfoCore('alpha', @Probe.GetPackageInfo,
        'Name: %s', 'Version: %s', 'Description: %s', 'Path: %s', OutRef));
    Check('queryflow info writes package name', OutBuf.Contains('Name: alpha'), OutBuf.Text);
    Check('queryflow info writes install path', OutBuf.Contains('Path: /tmp/alpha'), OutBuf.Text);
  finally
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Package Query Flow');
  WriteLn('========================================');
  WriteLn;

  TestExecutePackageListCoreUsesInstalledPackages;
  TestExecutePackageSearchCoreWritesNoResults;
  TestExecutePackageInfoCoreWritesInstallPath;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
