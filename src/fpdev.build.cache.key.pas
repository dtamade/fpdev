unit fpdev.build.cache.key;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function BuildCacheGetCurrentCPU: string;
function BuildCacheGetCurrentOS: string;
function BuildCacheGetArtifactKey(const AVersion: string): string;

implementation

function BuildCacheGetCurrentCPU: string;
begin
  {$IFDEF CPUX86_64}
  Result := 'x86_64';
  {$ELSE}
  {$IFDEF CPUI386}
  Result := 'i386';
  {$ELSE}
  {$IFDEF CPUARM}
  Result := 'arm';
  {$ELSE}
  {$IFDEF CPUAARCH64}
  Result := 'aarch64';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

function BuildCacheGetCurrentOS: string;
begin
  {$IFDEF LINUX}
  Result := 'linux';
  {$ELSE}
  {$IFDEF MSWINDOWS}
  Result := 'win64';
  {$ELSE}
  {$IFDEF DARWIN}
  Result := 'darwin';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

function BuildCacheGetArtifactKey(const AVersion: string): string;
begin
  if (Pos('..', AVersion) > 0) or (Pos(PathDelim, AVersion) > 0) or
     (Pos('/', AVersion) > 0) or (Pos('\', AVersion) > 0) then
    raise Exception.Create('Invalid version string: contains path traversal characters');

  Result := 'fpc-' + AVersion + '-' + BuildCacheGetCurrentCPU + '-' + BuildCacheGetCurrentOS;
end;

end.
