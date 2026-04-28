unit fpdev.fpc.installreportflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

procedure WriteFPCOfflineCacheMissReport(const AVersion: string;
  const AErr: IOutput);
procedure WriteFPCOfflineCacheRestoreFailureReport(const AVersion: string;
  const AErr: IOutput);
procedure WriteFPCInstallSuccessReport(const AVersion, AInstallPath: string;
  const AOut: IOutput);

implementation

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

procedure WriteFPCOfflineCacheMissReport(const AVersion: string;
  const AErr: IOutput);
begin
  WriteLine(AErr, '[FAIL] Cache miss for FPC ' + AVersion);
  WriteLine(AErr, '[HINT] Network disabled by --offline flag');
  WriteLine(
    AErr,
    '[HINT] Run without --offline to download, or use ' +
      '''fpdev fpc cache list'' to see available versions'
  );
end;

procedure WriteFPCOfflineCacheRestoreFailureReport(const AVersion: string;
  const AErr: IOutput);
begin
  WriteLine(AErr, '[FAIL] Cache restoration failed in offline mode');
  WriteLine(AErr, '[HINT] The cached artifact may be corrupted. Try:');
  WriteLine(AErr, '[HINT]   fpdev fpc cache clean ' + AVersion);
  WriteLine(AErr, '[HINT]   fpdev fpc install ' + AVersion + '  (without --offline)');
end;

procedure WriteFPCInstallSuccessReport(const AVersion, AInstallPath: string;
  const AOut: IOutput);
begin
  WriteLine(AOut, '===========================================');
  WriteLine(AOut, 'Installation completed!');
  WriteLine(AOut, 'FPC ' + AVersion + ' installed to: ' + AInstallPath);
  WriteLine(AOut);
  WriteLine(AOut, 'To activate this version, run:');
  WriteLine(AOut, '  fpdev fpc use ' + AVersion);
  WriteLine(AOut, '===========================================');
end;

end.
