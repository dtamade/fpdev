unit fpdev.fpc.installer.repoflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TFPCRepoInitializeHandler = function: Boolean of object;
  TFPCRepoHasBinaryReleaseHandler = function(const AVersion,
    APlatform: string): Boolean of object;
  TFPCRepoInstallBinaryReleaseHandler = function(const AVersion,
    APlatform, AInstallPath: string): Boolean of object;

function ExecuteFPCRepoInstallFlow(const AVersion, APlatform,
  AInstallPath: string; const AOut, AErr: IOutput;
  AInitializeRepo: TFPCRepoInitializeHandler;
  AHasBinaryRelease: TFPCRepoHasBinaryReleaseHandler;
  AInstallBinaryRelease: TFPCRepoInstallBinaryReleaseHandler): Boolean;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ExecuteFPCRepoInstallFlow(const AVersion, APlatform,
  AInstallPath: string; const AOut, AErr: IOutput;
  AInitializeRepo: TFPCRepoInitializeHandler;
  AHasBinaryRelease: TFPCRepoHasBinaryReleaseHandler;
  AInstallBinaryRelease: TFPCRepoInstallBinaryReleaseHandler): Boolean;
begin
  Result := False;

  WriteLine(AOut, '[2/4] Initializing fpdev-repo...');

  if (not Assigned(AInitializeRepo)) or (not AInitializeRepo()) then
  begin
    WriteLine(AErr, _(MSG_ERROR) + ': Failed to initialize fpdev-repo');
    WriteLine(AErr);
    WriteLine(AErr, 'fpdev-repo is required for binary installation.');
    WriteLine(AErr, 'Please check your network connection and try again.');
    WriteLine(AErr);
    WriteLine(AErr, 'Mirror configuration:');
    WriteLine(AErr, '  China users: fpdev system config set mirror gitee');
    WriteLine(AErr, '  Global users: fpdev system config set mirror github');
    Exit;
  end;

  WriteLine(AOut, '  fpdev-repo initialized');
  WriteLine(AOut);
  WriteLine(AOut, '[3/4] Checking for FPC ' + AVersion + ' binary...');

  if Assigned(AHasBinaryRelease) and AHasBinaryRelease(AVersion, APlatform) then
  begin
    WriteLine(AOut, '  Found FPC ' + AVersion + ' in fpdev-repo');
    WriteLine(AOut);
    WriteLine(AOut, '[4/4] Installing FPC ' + AVersion + ' from fpdev-repo...');

    if Assigned(AInstallBinaryRelease) and
       AInstallBinaryRelease(AVersion, APlatform, AInstallPath) then
    begin
      WriteLine(AOut, '  Binary package installed from fpdev-repo');
      WriteLine(AOut);
      Result := True;
    end
    else
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': Installation from fpdev-repo failed');
      WriteLine(AErr, 'Trying fallback to SourceForge...');
      WriteLine(AOut);
    end;
  end;
end;

end.
