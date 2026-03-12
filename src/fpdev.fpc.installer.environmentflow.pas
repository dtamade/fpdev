unit fpdev.fpc.installer.environmentflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf, fpdev.config.interfaces;

type
  TFPCAddToolchainHandler = function(const AName: string;
    const AInfo: TToolchainInfo): Boolean of object;

function BuildInstalledFPCToolchainInfo(const AVersion,
  AInstallPath: string; const AInstallDate: TDateTime): TToolchainInfo;
function ExecuteFPCEnvironmentRegistrationFlow(const AVersion,
  AInstallPath: string; const AErr: IOutput;
  AAddToolchain: TFPCAddToolchainHandler): Boolean;

implementation

uses
  SysUtils,
  fpdev.constants, fpdev.i18n, fpdev.i18n.strings;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function BuildInstalledFPCToolchainInfo(const AVersion,
  AInstallPath: string; const AInstallDate: TDateTime): TToolchainInfo;
begin
  Initialize(Result);
  Result.ToolchainType := ttRelease;
  Result.Version := AVersion;
  Result.InstallPath := AInstallPath;
  Result.SourceURL := FPC_OFFICIAL_REPO;
  Result.Installed := True;
  Result.InstallDate := AInstallDate;
end;

function ExecuteFPCEnvironmentRegistrationFlow(const AVersion,
  AInstallPath: string; const AErr: IOutput;
  AAddToolchain: TFPCAddToolchainHandler): Boolean;
var
  ToolchainInfo: TToolchainInfo;
begin
  Result := False;

  if AVersion = '' then
    Exit;

  if (AInstallPath = '') or (not DirectoryExists(AInstallPath)) then
    Exit;

  try
    ToolchainInfo := BuildInstalledFPCToolchainInfo(AVersion, AInstallPath, Now);
    Result := Assigned(AAddToolchain) and
      AAddToolchain('fpc-' + AVersion, ToolchainInfo);
    if not Result then
      WriteLine(AErr, _(MSG_ERROR) + ': Failed to add toolchain to configuration');
  except
    on E: Exception do
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': SetupEnvironment failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
