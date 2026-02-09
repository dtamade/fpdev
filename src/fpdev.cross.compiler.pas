unit fpdev.cross.compiler;

{
  TCrossCompilerResolver - Cross-compiler binary resolution

  Locates the ppcross* binary for a given target CPU.
  FPC cross-compilers follow the naming convention:
    ppcross<suffix>[.exe]

  CPU -> suffix mapping:
    x86_64  -> x64
    i386    -> 386
    arm     -> arm
    aarch64 -> a64
    mipsel  -> mipsel
    mips    -> mips
    powerpc -> ppc
    powerpc64 -> ppc64
    sparc   -> sparc
    riscv32 -> rv32
    riscv64 -> rv64
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  { TCrossCompilerResolver - Locate FPC cross-compiler binaries }
  TCrossCompilerResolver = class
  public
    { GetPPCrossName - Get ppcross binary name for a CPU target }
    class function GetPPCrossName(const ACPU: string): string;

    { FindCrossCompiler - Search for cross-compiler in known locations }
    class function FindCrossCompiler(const ACPU, AFPCPrefix: string): string;

    { ValidateCompiler - Check if a compiler binary exists }
    class function ValidateCompiler(const APath: string): Boolean;

    { GetCPUSuffix - Get the FPC internal suffix for a CPU name }
    class function GetCPUSuffix(const ACPU: string): string;
  end;

implementation

class function TCrossCompilerResolver.GetCPUSuffix(const ACPU: string): string;
begin
  if ACPU = 'x86_64' then
    Result := 'x64'
  else if ACPU = 'i386' then
    Result := '386'
  else if ACPU = 'arm' then
    Result := 'arm'
  else if ACPU = 'aarch64' then
    Result := 'a64'
  else if ACPU = 'mipsel' then
    Result := 'mipsel'
  else if ACPU = 'mips' then
    Result := 'mips'
  else if ACPU = 'powerpc' then
    Result := 'ppc'
  else if ACPU = 'powerpc64' then
    Result := 'ppc64'
  else if ACPU = 'sparc' then
    Result := 'sparc'
  else if ACPU = 'riscv32' then
    Result := 'rv32'
  else if ACPU = 'riscv64' then
    Result := 'rv64'
  else
    Result := '';
end;

class function TCrossCompilerResolver.GetPPCrossName(const ACPU: string): string;
var
  Suffix: string;
begin
  Suffix := GetCPUSuffix(ACPU);
  if Suffix <> '' then
    Result := 'ppcross' + Suffix
  else
    Result := '';
end;

class function TCrossCompilerResolver.FindCrossCompiler(const ACPU, AFPCPrefix: string): string;
var
  BinName, Candidate: string;
  SearchDirs: array[0..3] of string;
  I: Integer;
begin
  Result := '';
  BinName := GetPPCrossName(ACPU);
  if BinName = '' then Exit;

  {$IFDEF MSWINDOWS}
  BinName := BinName + '.exe';
  {$ENDIF}

  SearchDirs[0] := AFPCPrefix;
  SearchDirs[1] := AFPCPrefix + PathDelim + 'bin';
  SearchDirs[2] := '/usr/local/bin';
  SearchDirs[3] := '/usr/bin';

  for I := 0 to High(SearchDirs) do
  begin
    if SearchDirs[I] = '' then Continue;
    Candidate := SearchDirs[I] + PathDelim + BinName;
    if FileExists(Candidate) then
    begin
      Result := Candidate;
      Exit;
    end;
  end;
end;

class function TCrossCompilerResolver.ValidateCompiler(const APath: string): Boolean;
begin
  Result := (APath <> '') and FileExists(APath);
end;

end.
