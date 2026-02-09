unit fpdev.cross.opts;

{
  TCrossOptBuilder - CROSSOPT parameter construction

  Builds the CROSSOPT= string for FPC make cross-compilation from
  target definition (CPU, OS, ABI, SubArch, libraries path).

  Examples:
    ARM eabihf:  -CaEABIHF -CfVFPV3 -CpARMV7A -Fl/usr/arm-linux-gnueabihf/lib
    Win64:       (empty - no special options needed)
    MIPS softfp: -CfSOFT
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces;

type
  { TCrossOptBuilder - Construct CROSSOPT string from target definition }
  TCrossOptBuilder = class
  public
    class function Build(const ATarget: TCrossTarget): string;
    class function GetABIOption(const ACPU, AABI: string): string;
    class function GetFPUOption(const ACPU, AABI: string): string;
    class function GetSubArchOption(const ACPU, ASubArch: string): string;
    class function GetLibraryOption(const ALibrariesPath: string): string;
  end;

implementation

class function TCrossOptBuilder.GetABIOption(const ACPU, AABI: string): string;
begin
  Result := '';
  if ACPU = 'arm' then
  begin
    if AABI = 'eabihf' then
      Result := '-CaEABIHF'
    else if AABI = 'eabi' then
      Result := '-CaEABI'
    else if AABI = '' then
      Result := '-CaEABI';
  end
  else if ACPU = 'aarch64' then
  begin
    // aarch64 typically does not need ABI option
  end
  else if ACPU = 'mipsel' then
  begin
    if AABI = 'o32' then
      Result := '-CaO32';
  end;
end;

class function TCrossOptBuilder.GetFPUOption(const ACPU, AABI: string): string;
begin
  Result := '';
  if ACPU = 'arm' then
  begin
    if AABI = 'eabihf' then
      Result := '-CfVFPV3'
    else
      Result := '-CfSOFT';
  end
  else if ACPU = 'mipsel' then
    Result := '-CfSOFT'
  else if ACPU = 'mips' then
    Result := '-CfSOFT';
end;

class function TCrossOptBuilder.GetSubArchOption(const ACPU, ASubArch: string): string;
begin
  Result := '';
  if ACPU <> 'arm' then Exit;
  if ASubArch = '' then Exit;

  if ASubArch = 'armv7' then
    Result := '-CpARMV7A'
  else if ASubArch = 'armv7a' then
    Result := '-CpARMV7A'
  else if ASubArch = 'armv6' then
    Result := '-CpARMV6'
  else if ASubArch = 'armv5' then
    Result := '-CpARMV5TE'
  else if ASubArch = 'armv8' then
    Result := '-CpARMV7A';  // ARMv8 in 32-bit mode uses v7a profile
end;

class function TCrossOptBuilder.GetLibraryOption(const ALibrariesPath: string): string;
begin
  if ALibrariesPath <> '' then
    Result := '-Fl' + ALibrariesPath
  else
    Result := '';
end;

class function TCrossOptBuilder.Build(const ATarget: TCrossTarget): string;
var
  Parts: array[0..4] of string;
  Count, I: Integer;
begin
  Count := 0;

  // If target has explicit CrossOpt, use it directly
  if ATarget.CrossOpt <> '' then
  begin
    Result := ATarget.CrossOpt;
    // Append library path if not already included
    if (ATarget.LibrariesPath <> '') and (Pos('-Fl', ATarget.CrossOpt) = 0) then
      Result := Result + ' ' + GetLibraryOption(ATarget.LibrariesPath);
    Exit;
  end;

  // Build from components
  Parts[Count] := GetABIOption(ATarget.CPU, ATarget.ABI);
  if Parts[Count] <> '' then Inc(Count);

  Parts[Count] := GetFPUOption(ATarget.CPU, ATarget.ABI);
  if Parts[Count] <> '' then Inc(Count);

  Parts[Count] := GetSubArchOption(ATarget.CPU, ATarget.SubArch);
  if Parts[Count] <> '' then Inc(Count);

  Parts[Count] := GetLibraryOption(ATarget.LibrariesPath);
  if Parts[Count] <> '' then Inc(Count);

  // Join with spaces
  Result := '';
  for I := 0 to Count - 1 do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + Parts[I];
  end;
end;

end.
