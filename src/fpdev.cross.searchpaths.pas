unit fpdev.cross.searchpaths;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces;

function GetCrossPrefixCandidatesCore(const ATarget: TCrossTarget): TStringArray;
function BuildCrossLibraryCandidatesCore(
  const ATarget: TCrossTarget;
  const APrefixes: TStringArray
): TStringArray;

implementation

uses
  fpdev.paths;

function GetCrossPrefixCandidatesCore(const ATarget: TCrossTarget): TStringArray;
var
  CPU: string;
  OS: string;
begin
  Result := nil;
  CPU := ATarget.CPU;
  OS := ATarget.OS;

  if ATarget.BinutilsPrefix <> '' then
  begin
    SetLength(Result, 1);
    Result[0] := ATarget.BinutilsPrefix;
    Exit;
  end;

  if CPU = 'arm' then
  begin
    if OS = 'linux' then
    begin
      SetLength(Result, 4);
      Result[0] := 'arm-linux-gnueabihf-';
      Result[1] := 'arm-linux-gnueabi-';
      Result[2] := 'arm-none-eabi-';
      Result[3] := 'arm-linux-musleabihf-';
    end
    else if OS = 'android' then
    begin
      SetLength(Result, 2);
      Result[0] := 'arm-linux-androideabi-';
      Result[1] := 'armv7a-linux-androideabi-';
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := 'arm-' + OS + '-';
    end;
  end
  else if CPU = 'aarch64' then
  begin
    if OS = 'linux' then
    begin
      SetLength(Result, 2);
      Result[0] := 'aarch64-linux-gnu-';
      Result[1] := 'aarch64-linux-musl-';
    end
    else if OS = 'android' then
    begin
      SetLength(Result, 1);
      Result[0] := 'aarch64-linux-android-';
    end
    else if OS = 'darwin' then
    begin
      SetLength(Result, 1);
      Result[0] := 'aarch64-apple-darwin-';
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := 'aarch64-' + OS + '-';
    end;
  end
  else if CPU = 'i386' then
  begin
    if (OS = 'win32') or (OS = 'win64') then
    begin
      SetLength(Result, 1);
      Result[0] := 'i686-w64-mingw32-';
    end
    else
    begin
      SetLength(Result, 2);
      Result[0] := 'i686-linux-gnu-';
      Result[1] := 'i386-linux-gnu-';
    end;
  end
  else if CPU = 'x86_64' then
  begin
    if (OS = 'win64') or (OS = 'win32') then
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-w64-mingw32-';
    end
    else if OS = 'darwin' then
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-apple-darwin-';
    end
    else
    begin
      SetLength(Result, 1);
      Result[0] := 'x86_64-linux-gnu-';
    end;
  end
  else if CPU = 'mipsel' then
  begin
    SetLength(Result, 2);
    Result[0] := 'mipsel-linux-gnu-';
    Result[1] := 'mipsel-linux-musl-';
  end
  else if CPU = 'mips' then
  begin
    SetLength(Result, 2);
    Result[0] := 'mips-linux-gnu-';
    Result[1] := 'mips-linux-musl-';
  end
  else if CPU = 'powerpc' then
  begin
    SetLength(Result, 1);
    Result[0] := 'powerpc-linux-gnu-';
  end
  else if CPU = 'powerpc64' then
  begin
    SetLength(Result, 2);
    Result[0] := 'powerpc64le-linux-gnu-';
    Result[1] := 'powerpc64-linux-gnu-';
  end
  else if CPU = 'riscv64' then
  begin
    SetLength(Result, 1);
    Result[0] := 'riscv64-linux-gnu-';
  end
  else if CPU = 'riscv32' then
  begin
    SetLength(Result, 1);
    Result[0] := 'riscv32-linux-gnu-';
  end
  else if CPU = 'sparc' then
  begin
    SetLength(Result, 1);
    Result[0] := 'sparc64-linux-gnu-';
  end
  else
  begin
    SetLength(Result, 1);
    Result[0] := CPU + '-' + OS + '-';
  end;
end;

function BuildCrossLibraryCandidatesCore(
  const ATarget: TCrossTarget;
  const APrefixes: TStringArray
): TStringArray;
var
  Candidates: array of string;
  CandCount: Integer;
  Index: Integer;
  Prefix: string;

  procedure AddCandidate(const ADir: string);
  var
    ExistingIndex: Integer;
  begin
    if (ADir = '') or (not DirectoryExists(ADir)) then
      Exit;

    for ExistingIndex := 0 to CandCount - 1 do
      if Candidates[ExistingIndex] = ADir then
        Exit;

    if CandCount >= Length(Candidates) then
      SetLength(Candidates, Length(Candidates) + 8);
    Candidates[CandCount] := ADir;
    Inc(CandCount);
  end;

begin
  Result := nil;
  Candidates := nil;
  SetLength(Candidates, 16);
  CandCount := 0;

  if ATarget.LibrariesPath <> '' then
    AddCandidate(ATarget.LibrariesPath);

  AddCandidate(GetDataRoot + PathDelim + 'cross' + PathDelim +
    ATarget.CPU + '-' + ATarget.OS + PathDelim + 'lib');

  {$IFDEF LINUX}
  for Index := 0 to High(APrefixes) do
  begin
    Prefix := Copy(APrefixes[Index], 1, Length(APrefixes[Index]) - 1);
    AddCandidate('/usr/' + Prefix + '/lib');
    AddCandidate('/usr/lib/' + Prefix);
    AddCandidate('/usr/' + Prefix + '/lib32');
    AddCandidate('/usr/' + Prefix + '/lib64');
  end;

  AddCandidate('/usr/' + ATarget.CPU + '-' + ATarget.OS + '/lib');

  if ATarget.OS = 'android' then
  begin
    AddCandidate(GetEnvironmentVariable('ANDROID_NDK_HOME') +
      '/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/' +
      ATarget.CPU + '-linux-android');
    AddCandidate(GetUserDir +
      'Android/Sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/' +
      ATarget.CPU + '-linux-android');
  end;

  if (ATarget.CPU = 'arm') or (ATarget.CPU = 'aarch64') then
  begin
    AddCandidate('/opt/gcc-arm/lib');
    AddCandidate('/opt/gcc-linaro/lib');
  end;

  if (ATarget.OS = 'win64') or (ATarget.OS = 'win32') then
  begin
    for Index := 0 to High(APrefixes) do
    begin
      Prefix := Copy(APrefixes[Index], 1, Length(APrefixes[Index]) - 1);
      AddCandidate('/usr/' + Prefix + '/lib');
    end;
  end;
  {$ENDIF}

  {$IFDEF DARWIN}
  AddCandidate('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib');
  AddCandidate('/opt/homebrew/opt/' + ATarget.CPU + '-' + ATarget.OS + '/lib');
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  if (ATarget.OS = 'linux') or (ATarget.OS = 'darwin') then
    AddCandidate('C:\msys64\usr\lib');
  {$ENDIF}

  SetLength(Result, CandCount);
  for Index := 0 to CandCount - 1 do
    Result[Index] := Candidates[Index];
end;

end.
