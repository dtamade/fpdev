unit fpdev.cross.targets;

{
  TCrossTargetRegistry - Cross-compilation target definition registry

  Provides built-in target definitions for common FPC cross-compilation
  targets, plus the ability to register custom targets. Each target
  definition contains CPU/OS/SubArch/ABI/BinutilsPrefix information
  needed by the build engine, search engine, and CROSSOPT builder.

  Built-in targets are defined as Pascal const arrays to avoid external
  file dependencies. Custom targets can be loaded from JSON or registered
  programmatically.
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser;

type
  { TCrossTargetDef - Complete definition for a cross-compilation target }
  TCrossTargetDef = record
    Name: string;              // Short name, e.g. 'arm-linux', 'x86_64-win64'
    DisplayName: string;       // Human-readable, e.g. 'ARM Linux (32-bit hard-float)'
    CPU: string;               // FPC CPU target, e.g. 'arm', 'aarch64'
    OS: string;                // FPC OS target, e.g. 'linux', 'win64'
    SubArch: string;           // Sub-architecture, e.g. 'armv7' (empty if N/A)
    ABI: string;               // ABI, e.g. 'eabihf', 'musl' (empty if N/A)
    BinutilsPrefix: string;    // Default binutils prefix, e.g. 'arm-linux-gnueabihf-'
    DefaultCrossOpt: string;   // Default CROSSOPT, e.g. '-CaEABIHF -CfVFPV3'
    Description: string;       // Brief notes
    Builtin: Boolean;          // True if from built-in array, False if user-defined
  end;

  TCrossTargetDefArray = array of TCrossTargetDef;

  { TCrossTargetRegistry - Registry of known cross-compilation targets }
  TCrossTargetRegistry = class
  private
    FTargets: TCrossTargetDefArray;
    function FindIndex(const AName: string): Integer;
  public
    constructor Create;

    { Load built-in targets into registry }
    procedure LoadBuiltinTargets;

    { Register a custom target (overwrites if same name exists) }
    procedure RegisterTarget(const ADef: TCrossTargetDef);

    { Remove a target by name. Returns True if found and removed. }
    function RemoveTarget(const AName: string): Boolean;

    { Get target by name. Returns True if found. }
    function GetTarget(const AName: string; out ADef: TCrossTargetDef): Boolean;

    { Check if a target exists }
    function HasTarget(const AName: string): Boolean;

    { List all target names }
    function ListTargets: TStringArray;

    { List all target definitions }
    function ListTargetDefs: TCrossTargetDefArray;

    { Get count of registered targets }
    function Count: Integer;

    { Load custom targets from JSON array string }
    procedure LoadFromJSON(const AJSON: string);

    { Load custom targets from JSON file }
    procedure LoadFromFile(const AFilePath: string);

    { Export all targets to JSON array string }
    function ExportToJSON: string;

    { Find targets by CPU }
    function FindByCPU(const ACPU: string): TCrossTargetDefArray;

    { Find targets by OS }
    function FindByOS(const AOS: string): TCrossTargetDefArray;
  end;

{ Create a target definition record }
function MakeTargetDef(const AName, ADisplayName, ACPU, AOS, ASubArch,
  AABI, ABinutilsPrefix, ADefaultCrossOpt, ADescription: string;
  ABuiltin: Boolean = True): TCrossTargetDef;

implementation

{ Built-in target definitions }

const
  BUILTIN_TARGET_COUNT = 21;

  BUILTIN_TARGETS: array[0..BUILTIN_TARGET_COUNT - 1] of TCrossTargetDef = (
    // Windows targets
    (Name: 'i386-win32';     DisplayName: 'Windows 32-bit';
     CPU: 'i386';   OS: 'win32';  SubArch: ''; ABI: '';
     BinutilsPrefix: 'i686-w64-mingw32-'; DefaultCrossOpt: '';
     Description: 'Cross-compile for Windows 32-bit from Linux/macOS';
     Builtin: True),

    (Name: 'x86_64-win64';   DisplayName: 'Windows 64-bit';
     CPU: 'x86_64'; OS: 'win64';  SubArch: ''; ABI: '';
     BinutilsPrefix: 'x86_64-w64-mingw32-'; DefaultCrossOpt: '';
     Description: 'Cross-compile for Windows 64-bit from Linux/macOS';
     Builtin: True),

    // Linux x86 targets
    (Name: 'i386-linux';     DisplayName: 'Linux 32-bit';
     CPU: 'i386';   OS: 'linux';  SubArch: ''; ABI: '';
     BinutilsPrefix: 'i686-linux-gnu-'; DefaultCrossOpt: '';
     Description: 'Cross-compile for Linux 32-bit';
     Builtin: True),

    (Name: 'x86_64-linux';   DisplayName: 'Linux 64-bit';
     CPU: 'x86_64'; OS: 'linux';  SubArch: ''; ABI: '';
     BinutilsPrefix: 'x86_64-linux-gnu-'; DefaultCrossOpt: '';
     Description: 'Cross-compile for Linux 64-bit';
     Builtin: True),

    // ARM Linux targets
    (Name: 'arm-linux';      DisplayName: 'ARM Linux (hard-float)';
     CPU: 'arm';    OS: 'linux';  SubArch: 'armv7'; ABI: 'eabihf';
     BinutilsPrefix: 'arm-linux-gnueabihf-';
     DefaultCrossOpt: '-CaEABIHF -CfVFPV3 -CpARMV7A';
     Description: 'Raspberry Pi 2/3/4, BeagleBone (32-bit)';
     Builtin: True),

    (Name: 'arm-linux-eabi'; DisplayName: 'ARM Linux (soft-float)';
     CPU: 'arm';    OS: 'linux';  SubArch: 'armv6'; ABI: 'eabi';
     BinutilsPrefix: 'arm-linux-gnueabi-';
     DefaultCrossOpt: '-CaEABI -CfSOFT -CpARMV6';
     Description: 'Raspberry Pi Zero/1, ARMv6 devices';
     Builtin: True),

    (Name: 'aarch64-linux';  DisplayName: 'ARM64 Linux';
     CPU: 'aarch64'; OS: 'linux'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'aarch64-linux-gnu-'; DefaultCrossOpt: '';
     Description: 'Raspberry Pi 4/5 (64-bit), ARM servers';
     Builtin: True),

    // macOS / Darwin targets
    (Name: 'x86_64-darwin';  DisplayName: 'macOS Intel';
     CPU: 'x86_64'; OS: 'darwin'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'x86_64-apple-darwin-'; DefaultCrossOpt: '';
     Description: 'macOS on Intel hardware';
     Builtin: True),

    (Name: 'aarch64-darwin'; DisplayName: 'macOS Apple Silicon';
     CPU: 'aarch64'; OS: 'darwin'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'aarch64-apple-darwin-'; DefaultCrossOpt: '';
     Description: 'macOS M1/M2/M3/M4 chips';
     Builtin: True),

    // Android targets
    (Name: 'arm-android';    DisplayName: 'Android ARM 32-bit';
     CPU: 'arm';    OS: 'android'; SubArch: 'armv7'; ABI: 'eabi';
     BinutilsPrefix: 'arm-linux-androideabi-';
     DefaultCrossOpt: '-CaEABI -CpARMV7A';
     Description: 'Android devices (32-bit ARM)';
     Builtin: True),

    (Name: 'aarch64-android'; DisplayName: 'Android ARM 64-bit';
     CPU: 'aarch64'; OS: 'android'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'aarch64-linux-android-'; DefaultCrossOpt: '';
     Description: 'Modern Android devices (64-bit ARM)';
     Builtin: True),

    (Name: 'x86_64-android'; DisplayName: 'Android x86_64';
     CPU: 'x86_64'; OS: 'android'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'x86_64-linux-android-'; DefaultCrossOpt: '';
     Description: 'Android emulator and x86 devices';
     Builtin: True),

    // iOS target
    (Name: 'aarch64-ios';    DisplayName: 'iOS ARM64';
     CPU: 'aarch64'; OS: 'ios'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'aarch64-apple-ios-'; DefaultCrossOpt: '';
     Description: 'iPhone/iPad (requires Xcode SDK)';
     Builtin: True),

    // FreeBSD targets
    (Name: 'x86_64-freebsd'; DisplayName: 'FreeBSD 64-bit';
     CPU: 'x86_64'; OS: 'freebsd'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'x86_64-freebsd-'; DefaultCrossOpt: '';
     Description: 'FreeBSD 64-bit (x86_64)';
     Builtin: True),

    (Name: 'i386-freebsd';  DisplayName: 'FreeBSD 32-bit';
     CPU: 'i386';   OS: 'freebsd'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'i386-freebsd-'; DefaultCrossOpt: '';
     Description: 'FreeBSD 32-bit (i386)';
     Builtin: True),

    // MIPS targets
    (Name: 'mipsel-linux';   DisplayName: 'MIPS Little-Endian Linux';
     CPU: 'mipsel'; OS: 'linux';  SubArch: ''; ABI: '';
     BinutilsPrefix: 'mipsel-linux-gnu-';
     DefaultCrossOpt: '-CfSOFT';
     Description: 'MIPS LE embedded devices, routers';
     Builtin: True),

    (Name: 'mips-linux';     DisplayName: 'MIPS Big-Endian Linux';
     CPU: 'mips';   OS: 'linux';  SubArch: ''; ABI: '';
     BinutilsPrefix: 'mips-linux-gnu-';
     DefaultCrossOpt: '-CfSOFT';
     Description: 'MIPS BE embedded devices';
     Builtin: True),

    // PowerPC targets
    (Name: 'powerpc-linux';  DisplayName: 'PowerPC 32-bit Linux';
     CPU: 'powerpc'; OS: 'linux'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'powerpc-linux-gnu-'; DefaultCrossOpt: '';
     Description: 'PowerPC 32-bit Linux systems';
     Builtin: True),

    (Name: 'powerpc64-linux'; DisplayName: 'PowerPC 64-bit Linux';
     CPU: 'powerpc64'; OS: 'linux'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'powerpc64-linux-gnu-'; DefaultCrossOpt: '';
     Description: 'PowerPC 64-bit Linux (big-endian)';
     Builtin: True),

    // RISC-V targets
    (Name: 'riscv64-linux';  DisplayName: 'RISC-V 64-bit Linux';
     CPU: 'riscv64'; OS: 'linux'; SubArch: ''; ABI: '';
     BinutilsPrefix: 'riscv64-linux-gnu-'; DefaultCrossOpt: '';
     Description: 'RISC-V 64-bit Linux (rv64gc)';
     Builtin: True),

    // SPARC target
    (Name: 'sparc-linux';    DisplayName: 'SPARC 32-bit Linux';
     CPU: 'sparc';  OS: 'linux';  SubArch: ''; ABI: '';
     BinutilsPrefix: 'sparc-linux-gnu-'; DefaultCrossOpt: '';
     Description: 'SPARC 32-bit Linux';
     Builtin: True)
  );

{ Helper function }

function MakeTargetDef(const AName, ADisplayName, ACPU, AOS, ASubArch,
  AABI, ABinutilsPrefix, ADefaultCrossOpt, ADescription: string;
  ABuiltin: Boolean): TCrossTargetDef;
begin
  Result.Name := AName;
  Result.DisplayName := ADisplayName;
  Result.CPU := ACPU;
  Result.OS := AOS;
  Result.SubArch := ASubArch;
  Result.ABI := AABI;
  Result.BinutilsPrefix := ABinutilsPrefix;
  Result.DefaultCrossOpt := ADefaultCrossOpt;
  Result.Description := ADescription;
  Result.Builtin := ABuiltin;
end;

{ TCrossTargetRegistry }

constructor TCrossTargetRegistry.Create;
begin
  inherited Create;
  FTargets := nil;
end;

function TCrossTargetRegistry.FindIndex(const AName: string): Integer;
var
  I: Integer;
  LName: string;
begin
  Result := -1;
  LName := LowerCase(AName);
  for I := 0 to High(FTargets) do
    if LowerCase(FTargets[I].Name) = LName then
      Exit(I);
end;

procedure TCrossTargetRegistry.LoadBuiltinTargets;
var
  I: Integer;
begin
  for I := 0 to BUILTIN_TARGET_COUNT - 1 do
    RegisterTarget(BUILTIN_TARGETS[I]);
end;

procedure TCrossTargetRegistry.RegisterTarget(const ADef: TCrossTargetDef);
var
  Idx: Integer;
begin
  Idx := FindIndex(ADef.Name);
  if Idx >= 0 then
    FTargets[Idx] := ADef
  else
  begin
    SetLength(FTargets, Length(FTargets) + 1);
    FTargets[High(FTargets)] := ADef;
  end;
end;

function TCrossTargetRegistry.RemoveTarget(const AName: string): Boolean;
var
  Idx, I: Integer;
begin
  Idx := FindIndex(AName);
  if Idx < 0 then Exit(False);
  for I := Idx to High(FTargets) - 1 do
    FTargets[I] := FTargets[I + 1];
  SetLength(FTargets, Length(FTargets) - 1);
  Result := True;
end;

function TCrossTargetRegistry.GetTarget(const AName: string; out ADef: TCrossTargetDef): Boolean;
var
  Idx: Integer;
begin
  Idx := FindIndex(AName);
  if Idx < 0 then
  begin
    ADef := Default(TCrossTargetDef);
    Exit(False);
  end;
  ADef := FTargets[Idx];
  Result := True;
end;

function TCrossTargetRegistry.HasTarget(const AName: string): Boolean;
begin
  Result := FindIndex(AName) >= 0;
end;

function TCrossTargetRegistry.ListTargets: TStringArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(FTargets));
  for I := 0 to High(FTargets) do
    Result[I] := FTargets[I].Name;
end;

function TCrossTargetRegistry.ListTargetDefs: TCrossTargetDefArray;
begin
  Result := Copy(FTargets, 0, Length(FTargets));
end;

function TCrossTargetRegistry.Count: Integer;
begin
  Result := Length(FTargets);
end;

procedure TCrossTargetRegistry.LoadFromJSON(const AJSON: string);
var
  Data: TJSONData;
  Arr: TJSONArray;
  Obj: TJSONObject;
  Def: TCrossTargetDef;
  I: Integer;
begin
  if AJSON = '' then Exit;
  Data := GetJSON(AJSON);
  try
    if not (Data is TJSONArray) then Exit;
    Arr := TJSONArray(Data);
    for I := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Obj := TJSONObject(Arr.Items[I]);
      Def := Default(TCrossTargetDef);
      Def.Name := Obj.Get('name', '');
      if Def.Name = '' then Continue;
      Def.DisplayName := Obj.Get('displayName', Def.Name);
      Def.CPU := Obj.Get('cpu', '');
      Def.OS := Obj.Get('os', '');
      Def.SubArch := Obj.Get('subArch', '');
      Def.ABI := Obj.Get('abi', '');
      Def.BinutilsPrefix := Obj.Get('binutilsPrefix', '');
      Def.DefaultCrossOpt := Obj.Get('defaultCrossOpt', '');
      Def.Description := Obj.Get('description', '');
      Def.Builtin := False;
      RegisterTarget(Def);
    end;
  finally
    Data.Free;
  end;
end;

procedure TCrossTargetRegistry.LoadFromFile(const AFilePath: string);
var
  SL: TStringList;
begin
  if not FileExists(AFilePath) then Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(AFilePath);
    LoadFromJSON(SL.Text);
  finally
    SL.Free;
  end;
end;

function TCrossTargetRegistry.ExportToJSON: string;
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  I: Integer;
begin
  Arr := TJSONArray.Create;
  try
    for I := 0 to High(FTargets) do
    begin
      Obj := TJSONObject.Create;
      Obj.Add('name', FTargets[I].Name);
      Obj.Add('displayName', FTargets[I].DisplayName);
      Obj.Add('cpu', FTargets[I].CPU);
      Obj.Add('os', FTargets[I].OS);
      if FTargets[I].SubArch <> '' then
        Obj.Add('subArch', FTargets[I].SubArch);
      if FTargets[I].ABI <> '' then
        Obj.Add('abi', FTargets[I].ABI);
      Obj.Add('binutilsPrefix', FTargets[I].BinutilsPrefix);
      if FTargets[I].DefaultCrossOpt <> '' then
        Obj.Add('defaultCrossOpt', FTargets[I].DefaultCrossOpt);
      if FTargets[I].Description <> '' then
        Obj.Add('description', FTargets[I].Description);
      Obj.Add('builtin', FTargets[I].Builtin);
      Arr.Add(Obj);
    end;
    Result := Arr.FormatJSON;
  finally
    Arr.Free;
  end;
end;

function TCrossTargetRegistry.FindByCPU(const ACPU: string): TCrossTargetDefArray;
var
  I, Cnt: Integer;
  LCPU: string;
begin
  Result := nil;
  LCPU := LowerCase(ACPU);
  Cnt := 0;
  for I := 0 to High(FTargets) do
    if LowerCase(FTargets[I].CPU) = LCPU then
      Inc(Cnt);

  SetLength(Result, Cnt);
  Cnt := 0;
  for I := 0 to High(FTargets) do
    if LowerCase(FTargets[I].CPU) = LCPU then
    begin
      Result[Cnt] := FTargets[I];
      Inc(Cnt);
    end;
end;

function TCrossTargetRegistry.FindByOS(const AOS: string): TCrossTargetDefArray;
var
  I, Cnt: Integer;
  LOS: string;
begin
  Result := nil;
  LOS := LowerCase(AOS);
  Cnt := 0;
  for I := 0 to High(FTargets) do
    if LowerCase(FTargets[I].OS) = LOS then
      Inc(Cnt);

  SetLength(Result, Cnt);
  Cnt := 0;
  for I := 0 to High(FTargets) do
    if LowerCase(FTargets[I].OS) = LOS then
    begin
      Result[Cnt] := FTargets[I];
      Inc(Cnt);
    end;
end;

end.
