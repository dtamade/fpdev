unit fpdev.fpc.manager.binarysurfaceflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.fpc.installer, fpdev.fpc.types, fpdev.types;

type
  { TFPCBinaryInstallSurface - Delegates binary install methods to TFPCBinaryInstaller }
  TFPCBinaryInstallSurface = class
  private
    FInstaller: TFPCBinaryInstaller;
  public
    constructor Create(AInstaller: TFPCBinaryInstaller);
    function GetBinaryDownloadURL(const AVersion: string): string;
    function DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
    function GetBinaryDownloadURLLegacy(const AVersion: string): string;
    function DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
    function VerifyChecksum(const AFilePath, AVersion: string): Boolean;
    function ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
    function InstallFromBinary(const AVersion: string; const APrefix: string = ''): Boolean;
  end;

implementation

{ TFPCBinaryInstallSurface }

constructor TFPCBinaryInstallSurface.Create(AInstaller: TFPCBinaryInstaller);
begin
  inherited Create;
  FInstaller := AInstaller;
end;

function TFPCBinaryInstallSurface.GetBinaryDownloadURL(const AVersion: string): string;
begin
  Result := FInstaller.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCBinaryInstallSurface.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstaller.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCBinaryInstallSurface.GetBinaryDownloadURLLegacy(const AVersion: string): string;
begin
  Result := FInstaller.GetBinaryDownloadURLLegacy(AVersion);
end;

function TFPCBinaryInstallSurface.DownloadBinaryLegacy(const AVersion: string; out ATempFile: string): Boolean;
begin
  Result := FInstaller.DownloadBinaryLegacy(AVersion, ATempFile);
end;

function TFPCBinaryInstallSurface.VerifyChecksum(const AFilePath, AVersion: string): Boolean;
begin
  Result := FInstaller.VerifyChecksum(AFilePath, AVersion);
end;

function TFPCBinaryInstallSurface.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
begin
  Result := FInstaller.ExtractArchive(AArchivePath, ADestPath);
end;

function TFPCBinaryInstallSurface.InstallFromBinary(const AVersion: string; const APrefix: string): Boolean;
begin
  Result := FInstaller.InstallFromBinary(AVersion, APrefix);
end;

end.
