unit fpdev.fpc.mirrors;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.platform;

type
  TStringArray = array of string;

  { TMirrorManager - Manages FPC binary download mirrors }
  TMirrorManager = class
  private
    FMirrors: TStringList;
    function BuildURL(const AMirror, AVersion, APlatform: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    { Mirror management }
    procedure AddMirror(const AURL: string);
    procedure ClearMirrors;
    procedure LoadDefaultMirrors;
    function GetMirrors: TStringArray;

    { URL generation }
    function GetDownloadURL(const AVersion, APlatform: string): string;
  end;

implementation

{ TMirrorManager }

constructor TMirrorManager.Create;
begin
  inherited Create;
  FMirrors := TStringList.Create;
  FMirrors.Duplicates := dupIgnore;
  LoadDefaultMirrors;
end;

destructor TMirrorManager.Destroy;
begin
  FMirrors.Free;
  inherited Destroy;
end;

procedure TMirrorManager.AddMirror(const AURL: string);
begin
  if AURL <> '' then
    FMirrors.Add(AURL);
end;

procedure TMirrorManager.ClearMirrors;
begin
  FMirrors.Clear;
end;

procedure TMirrorManager.LoadDefaultMirrors;
begin
  FMirrors.Clear;

  // Official FPC SourceForge mirror
  FMirrors.Add('https://sourceforge.net/projects/freepascal/files');

  // GitHub releases (backup)
  FMirrors.Add('https://github.com/fpc/FPCBuild/releases');

  // Gitee mirror (for users in China)
  FMirrors.Add('https://gitee.com/freepascal/fpc/releases');
end;

function TMirrorManager.GetMirrors: TStringArray;
var
  I: Integer;
begin
  SetLength(Result, FMirrors.Count);
  for I := 0 to FMirrors.Count - 1 do
    Result[I] := FMirrors[I];
end;

function TMirrorManager.BuildURL(const AMirror, AVersion, APlatform: string): string;
var
  Info: TPlatformInfo;
  OSStr, CPUStr: string;
begin
  // Parse platform string
  Info := StringToPlatform(APlatform);

  // Convert to URL-friendly strings
  case Info.OS of
    posWindows: OSStr := 'windows';
    posLinux: OSStr := 'linux';
    posDarwin: OSStr := 'darwin';
    posFreeBSD: OSStr := 'freebsd';
    else OSStr := 'unknown';
  end;

  case Info.CPU of
    pcX86_64: CPUStr := 'x86_64';
    pcI386: CPUStr := 'i386';
    pcAArch64: CPUStr := 'aarch64';
    pcARM: CPUStr := 'arm';
    else CPUStr := 'unknown';
  end;

  // Build URL based on mirror type
  if Pos('sourceforge', AMirror) > 0 then
    Result := Format('%s/%s/fpc-%s.%s-%s.tar.gz', [AMirror, AVersion, AVersion, OSStr, CPUStr])
  else if Pos('github', AMirror) > 0 then
    Result := Format('%s/download/v%s/fpc-%s-%s-%s.tar.gz', [AMirror, AVersion, AVersion, OSStr, CPUStr])
  else if Pos('gitee', AMirror) > 0 then
    Result := Format('%s/download/v%s/fpc-%s-%s-%s.tar.gz', [AMirror, AVersion, AVersion, OSStr, CPUStr])
  else
    Result := Format('%s/fpc-%s-%s-%s.tar.gz', [AMirror, AVersion, OSStr, CPUStr]);
end;

function TMirrorManager.GetDownloadURL(const AVersion, APlatform: string): string;
begin
  // Use first mirror by default
  if FMirrors.Count > 0 then
    Result := BuildURL(FMirrors[0], AVersion, APlatform)
  else
    Result := '';
end;

end.
