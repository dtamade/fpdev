unit fpdev.fpc.bootstrapflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TFPCManagedBootstrapEnsureFunc = function(
    const ATargetVersion: string
  ): Boolean of object;

  TFPCManagedBootstrapInstallFunc = function(
    const ATargetVersion: string
  ): Boolean of object;

function ExecuteManagedFPCBootstrapEnsureCore(
  const ATargetVersion: string;
  const AOut: IOutput;
  AEnsureBootstrap: TFPCManagedBootstrapEnsureFunc;
  AInstallBinaryFallback: TFPCManagedBootstrapInstallFunc
): Boolean;

implementation

procedure WriteLine(const AOut: IOutput; const AText: string);
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ExecuteManagedFPCBootstrapEnsureCore(
  const ATargetVersion: string;
  const AOut: IOutput;
  AEnsureBootstrap: TFPCManagedBootstrapEnsureFunc;
  AInstallBinaryFallback: TFPCManagedBootstrapInstallFunc
): Boolean;
begin
  Result := Assigned(AEnsureBootstrap) and AEnsureBootstrap(ATargetVersion);
  if Result then
    Exit;

  if not Assigned(AInstallBinaryFallback) then
    Exit(False);

  WriteLine(AOut, 'Attempting binary bootstrap fallback for FPC ' + ATargetVersion + '...');
  if not AInstallBinaryFallback(ATargetVersion) then
    Exit(False);

  WriteLine(AOut, 'Binary bootstrap fallback installed FPC ' + ATargetVersion);
  Result := Assigned(AEnsureBootstrap) and AEnsureBootstrap(ATargetVersion);
end;

end.
