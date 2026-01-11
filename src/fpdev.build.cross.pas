unit fpdev.build.cross;

{$mode objfpc}{$H+}

{
  TCrossService - Cross-compilation service

  Extracted from fpdev.build.manager to handle:
  - Cross-compile target detection
  - Binutils prefix management
  - FPC config generation for cross-compilation
}

interface

uses
  SysUtils, Classes;

type
  { TCrossTarget - Cross-compile target definition }
  TCrossTarget = record
    CPU: string;            // arm, aarch64, i386, x86_64
    OS: string;             // linux, win32, win64, darwin, android
    SubArch: string;        // armv6, armv7, armv8
    ABI: string;            // eabi, eabihf, musl
    BinUtilsPrefix: string; // arm-linux-gnueabihf-
    LibPath: string;        // /usr/arm-linux-gnueabihf/lib
    Options: string;        // -CfVFPV3 -CaEABIHF
  end;

  { TCrossService - Cross-compilation service }
  TCrossService = class
  private
    FBinutilsPath: string;
    FBinutilsPrefix: string;
    FLibsPath: string;
  public
    constructor Create;
    destructor Destroy; override;
    // Binutils management
    function GetBinutilsPrefixes(const ACPU, AOS: string): TStringArray;
    function DetectSystemBinutils(const ATarget: TCrossTarget): Boolean;
    function GetBinutilsPath: string;
    // Config generation
    function GenerateFPCConfig(const ATarget: TCrossTarget): string;
    function GetTargetTriple(const ACPU, AOS, AABI: string): string;
    function GetArmOptions(const ATarget: TCrossTarget): string;
    // Target management
    function ListAvailableTargets: TStringArray;
    function TestCrossCompile(const ATarget: TCrossTarget): Boolean;
    // Properties
    property BinutilsPath: string read FBinutilsPath;
    property BinutilsPrefix: string read FBinutilsPrefix;
    property LibsPath: string read FLibsPath;
  end;

implementation

{ TCrossService }

constructor TCrossService.Create;
begin
  inherited Create;
  FBinutilsPath := '';
  FBinutilsPrefix := '';
  FLibsPath := '';
end;

destructor TCrossService.Destroy;
begin
  inherited Destroy;
end;

function TCrossService.GetBinutilsPrefixes(const ACPU, AOS: string): TStringArray;
begin
  Result := nil;
  if ACPU = 'arm' then
  begin
    if AOS = 'linux' then
    begin
      SetLength(Result, 4);
      Result[0] := 'arm-linux-gnueabihf-';
      Result[1] := 'arm-linux-gnueabi-';
      Result[2] := 'arm-none-eabi-';
      Result[3] := 'arm-linux-musleabihf-';
    end
    else if AOS = 'android' then
    begin
      SetLength(Result, 1);
      Result[0] := 'arm-linux-androideabi-';
    end;
  end
  else if ACPU = 'aarch64' then
  begin
    SetLength(Result, 2);
    Result[0] := 'aarch64-linux-gnu-';
    Result[1] := 'aarch64-linux-musl-';
  end
  else if ACPU = 'i386' then
  begin
    SetLength(Result, 2);
    Result[0] := 'i686-linux-gnu-';
    Result[1] := 'i686-w64-mingw32-';
  end
  else if ACPU = 'x86_64' then
  begin
    if (AOS = 'win64') or (AOS = 'win32') then
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-w64-mingw32-';
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-linux-gnu-';
    end;
  end;
  if Length(Result) = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := ACPU + '-' + AOS + '-';
  end;
end;

function TCrossService.DetectSystemBinutils(const ATarget: TCrossTarget): Boolean;
var
  SearchPaths: array[0..3] of string;
  Prefixes: TStringArray;
  i, j: Integer;
  ToolPath: string;
begin
  Result := False;

  SearchPaths[0] := '/usr/bin';
  SearchPaths[1] := '/usr/local/bin';
  SearchPaths[2] := '/opt/cross/bin';
  SearchPaths[3] := GetUserDir + '.fpdev/cross/bin';

  Prefixes := GetBinutilsPrefixes(ATarget.CPU, ATarget.OS);

  for i := 0 to High(SearchPaths) do
  begin
    for j := 0 to High(Prefixes) do
    begin
      ToolPath := SearchPaths[i] + PathDelim + Prefixes[j] + 'as';
      if FileExists(ToolPath) then
      begin
        FBinutilsPath := SearchPaths[i];
        FBinutilsPrefix := Prefixes[j];
        Exit(True);
      end;
    end;
  end;
end;

function TCrossService.GetBinutilsPath: string;
begin
  Result := FBinutilsPath;
end;

function TCrossService.GenerateFPCConfig(const ATarget: TCrossTarget): string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('#IFDEF CPU' + UpperCase(ATarget.CPU));
    SL.Add('#IFDEF ' + UpperCase(ATarget.OS));

    // Binutils path
    if FBinutilsPath <> '' then
      SL.Add('-FD' + FBinutilsPath);
    if ATarget.BinUtilsPrefix <> '' then
      SL.Add('-XP' + ATarget.BinUtilsPrefix);

    // Library path
    if ATarget.LibPath <> '' then
    begin
      SL.Add('-Fl' + ATarget.LibPath);
      SL.Add('-Xd');  // Don't pass parent /lib
    end;

    // Target specific options
    if ATarget.Options <> '' then
      SL.Add(ATarget.Options);

    // ARM specific
    if ATarget.CPU = 'arm' then
    begin
      if ATarget.ABI = 'eabihf' then
      begin
        SL.Add('-CaEABIHF');
        SL.Add('-CfVFPV3');
      end
      else
        SL.Add('-CaEABI');
    end;

    SL.Add('#ENDIF');
    SL.Add('#ENDIF');

    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

function TCrossService.GetTargetTriple(const ACPU, AOS, AABI: string): string;
begin
  if AABI <> '' then
    Result := ACPU + '-' + AOS + '-' + AABI
  else
    Result := ACPU + '-' + AOS;
end;

function TCrossService.GetArmOptions(const ATarget: TCrossTarget): string;
begin
  Result := '';
  if ATarget.CPU <> 'arm' then Exit;

  if ATarget.ABI = 'eabihf' then
    Result := '-CaEABIHF -CfVFPV3'
  else if ATarget.ABI = 'eabi' then
    Result := '-CaEABI'
  else
    Result := '-CaEABI';

  // SubArch specific
  if ATarget.SubArch = 'armv7' then
    Result := Result + ' -CpARMV7A'
  else if ATarget.SubArch = 'armv6' then
    Result := Result + ' -CpARMV6';
end;

function TCrossService.ListAvailableTargets: TStringArray;
begin
  Result := nil;
  SetLength(Result, 6);
  Result[0] := 'arm-linux (Raspberry Pi)';
  Result[1] := 'aarch64-linux (ARM64 Linux)';
  Result[2] := 'x86_64-win64 (Windows 64-bit)';
  Result[3] := 'i386-win32 (Windows 32-bit)';
  Result[4] := 'x86_64-linux (Linux 64-bit)';
  Result[5] := 'aarch64-darwin (macOS ARM64)';
end;

function TCrossService.TestCrossCompile(const ATarget: TCrossTarget): Boolean;
begin
  // Placeholder: actual cross-compile test would need FPC
  Result := (ATarget.CPU <> '') and (ATarget.OS <> '');
end;

end.
