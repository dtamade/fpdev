unit fpdev.registry.updater;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.output.intf;

type
  TRegistryUpdateResult = (rurSuccess, rurAlreadyUpToDate, rurCloned, rurFailed);

function UpdateRegistry(
  const ARegistryDir: string;
  const APreferredMirror: string;
  const AOut: IOutput
): TRegistryUpdateResult;

function GetRegistryMirrorURL(const AMirrorName: string): string;

implementation

uses
  fpdev.utils.process, fpdev.constants, fpdev.utils.fs;

function GetRegistryMirrorURL(const AMirrorName: string): string;
begin
  if SameText(AMirrorName, 'gitee') then
    Result := FPDEV_REGISTRY_GITEE
  else
    Result := FPDEV_REGISTRY_GITHUB;
end;

function UpdateRegistry(
  const ARegistryDir: string;
  const APreferredMirror: string;
  const AOut: IOutput
): TRegistryUpdateResult;
var
  URL: string;
  Res: TProcessResult;
begin
  Result := rurFailed;
  URL := GetRegistryMirrorURL(APreferredMirror);

  if DirectoryExists(ARegistryDir + PathDelim + '.git') then
  begin
    if AOut <> nil then
      AOut.WriteLn('Updating registry from ' + URL + '...');

    TProcessExecutor.Execute('git', [
      '-C', ARegistryDir, 'remote', 'set-url', 'origin', URL
    ], '');

    Res := TProcessExecutor.Execute('git', [
      '-C', ARegistryDir, 'pull', '--ff-only'
    ], '');

    if Res.Success then
    begin
      if Pos('Already up to date', Res.StdOut) > 0 then
        Result := rurAlreadyUpToDate
      else
        Result := rurSuccess;
    end
    else
    begin
      if AOut <> nil then
        AOut.WriteLn('Warning: git pull failed: ' + Res.ErrorMessage);
    end;
  end
  else
  begin
    if DirectoryExists(ARegistryDir) then
    begin
      if AOut <> nil then
        AOut.WriteLn('Warning: ' + ARegistryDir + ' exists but is not a git repo, removing...');
      DeleteDirRecursive(ARegistryDir);
    end;

    if AOut <> nil then
      AOut.WriteLn('Cloning registry from ' + URL + '...');

    Res := TProcessExecutor.Execute('git', [
      'clone', '--depth=1', URL, ARegistryDir
    ], '');

    if Res.Success then
      Result := rurCloned
    else
    begin
      if AOut <> nil then
        AOut.WriteLn('Error: git clone failed: ' + Res.ErrorMessage);
    end;
  end;
end;

end.
