unit fpdev.fpc.builder.downloadflow;

{
================================================================================
  fpdev.fpc.builder.downloadflow - FPC source download flow
================================================================================

  Standalone flow for downloading FPC source code via the git runtime.

  Extracted from TFPCSourceBuilder.DownloadSource as part of the
  facade/flow refactoring to reduce god class complexity.

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf, fpdev.git.runtime, fpdev.git.types, fpdev.constants,
  fpdev.utils.fs, fpdev.version.registry;

{ Downloads FPC source code from the official repository.
  AVersion: FPC version tag to download
  ATargetDir: Local directory for the clone/checkout
  AGitTag: Resolved git tag name for the version
  AOut: Normal output sink
  AErr: Error output sink
  Returns: True if download succeeded }
function DownloadFPCSourceWithGitRuntimeCore(
  const AVersion, ATargetDir, AGitTag: string;
  const AOut, AErr: IOutput
): Boolean;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings;

procedure WriteLine(const AOutput: IOutput; const AText: string);
begin
  if Assigned(AOutput) then
    AOutput.WriteLn(AText);
end;

function DownloadFPCSourceWithGitRuntimeCore(
  const AVersion, ATargetDir, AGitTag: string;
  const AOut, AErr: IOutput
): Boolean;
var
  Git: IGitRuntime;
  RepoURL: string;
begin
  Result := False;

  if AGitTag = '' then
  begin
    WriteLine(AErr, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_UNKNOWN_VERSION, [AVersion]));
    Exit;
  end;

  RepoURL := TVersionRegistry.Instance.GetFPCRepository;

  try
    WriteLine(AOut, _Fmt(CMD_FPC_INSTALL_DOWNLOADING, [AVersion]) + ' (tag: ' + AGitTag + ')...');

    if not DirectoryExists(ExtractFileDir(ATargetDir)) then
      EnsureDir(ExtractFileDir(ATargetDir));

    Git := NewGitRuntime;
    try
      if Git.Backend = gbNone then
      begin
        WriteLine(AErr, _(MSG_ERROR) + ': ' + _(CMD_FPC_NO_GIT_BACKEND));
        Exit;
      end;

      WriteLine(AOut, 'Using backend: ' + GitBackendToString(Git.Backend));

      if DirectoryExists(ATargetDir) and
         DirectoryExists(ATargetDir + PathDelim + '.git') then
      begin
        WriteLine(AOut, 'Source repository exists, fetching and checking out: ' + AGitTag);

        if not Git.Fetch(ATargetDir, 'origin') then
        begin
          WriteLine(AErr, _(MSG_ERROR) + ': Git fetch failed: ' + Git.LastError);
          Exit;
        end;

        if not Git.Checkout(ATargetDir, AGitTag, True) then
        begin
          WriteLine(AErr, _(MSG_ERROR) + ': Git checkout failed for tag: ' + AGitTag);
          WriteLine(AErr, '  ' + Git.LastError);
          Exit;
        end;

        WriteLine(AOut, 'Git checkout completed successfully');
        Result := True;
      end
      else
      begin
        if DirectoryExists(ATargetDir) then
        begin
          WriteLine(AOut, 'Directory exists but is not a git repo, removing...');
          DeleteDirRecursive(ATargetDir);
        end;

        WriteLine(AOut, 'Cloning: ' + RepoURL + ' -> ' + ATargetDir);
        Result := Git.Clone(RepoURL, ATargetDir, AGitTag);
        if not Result then
          WriteLine(AErr, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_CLONE_FAILED, [Git.LastError]))
        else
          WriteLine(AOut, 'Git clone completed successfully');
      end;

    finally
      Git := nil;
    end;

  except
    on E: Exception do
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': DownloadSource failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
