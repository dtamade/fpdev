unit fpdev.fpc.installer.binaryflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TFPCManifestInstallHandler = function(const AVersion,
    AInstallPath: string): Boolean of object;
  TFPCRepoInstallFlowHandler = function(const AVersion,
    APlatform, AInstallPath: string): Boolean of object;
  TFPCSourceForgeInstallHandler = function(const AVersion,
    AInstallPath: string): Boolean of object;

function ExecuteFPCBinaryInstallFlow(const AVersion, APlatform,
  AInstallPath: string; const AOut, AErr: IOutput;
  AInstallFromManifest: TFPCManifestInstallHandler;
  ATryInstallFromRepo: TFPCRepoInstallFlowHandler;
  AInstallFromSourceForge: TFPCSourceForgeInstallHandler): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n, fpdev.i18n.strings;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ExecuteFPCBinaryInstallFlow(const AVersion, APlatform,
  AInstallPath: string; const AOut, AErr: IOutput;
  AInstallFromManifest: TFPCManifestInstallHandler;
  ATryInstallFromRepo: TFPCRepoInstallFlowHandler;
  AInstallFromSourceForge: TFPCSourceForgeInstallHandler): Boolean;
begin
  Result := False;

  try
    WriteLine(AOut, '===========================================');
    WriteLine(AOut, 'FPC Binary Installation: ' + AVersion);
    WriteLine(AOut, '===========================================');
    WriteLine(AOut);
    WriteLine(AOut, 'Target: ' + AInstallPath);
    WriteLine(AOut, 'Platform: ' + APlatform);
    WriteLine(AOut);

    WriteLine(AOut, '[1/4] Attempting manifest-based installation...');
    if Assigned(AInstallFromManifest) and
       AInstallFromManifest(AVersion, AInstallPath) then
    begin
      WriteLine(AOut, '  Manifest-based installation successful');
      Exit(True);
    end;

    WriteLine(AOut, '  Manifest-based installation not available, trying fpdev-repo...');
    WriteLine(AOut);

    if Assigned(ATryInstallFromRepo) and
       ATryInstallFromRepo(AVersion, APlatform, AInstallPath) then
      Exit(True);

    WriteLine(AOut);
    WriteLine(AOut);
    WriteLine(AOut, '[4/4] Attempting SourceForge download (with 30s timeout)...');

    Result := Assigned(AInstallFromSourceForge) and
      AInstallFromSourceForge(AVersion, AInstallPath);

    if Result then
    begin
      WriteLine(AOut);
      WriteLine(AOut, '===========================================');
      WriteLine(AOut, 'Installation Summary');
      WriteLine(AOut, '===========================================');
      WriteLine(AOut, '  Binary package installed from SourceForge');
      WriteLine(AOut);
    end;

  except
    on E: Exception do
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': InstallFromBinary failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
