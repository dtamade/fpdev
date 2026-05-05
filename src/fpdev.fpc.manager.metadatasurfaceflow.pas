unit fpdev.fpc.manager.metadatasurfaceflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf, fpdev.fpc.metadata, fpdev.fpc.types, fpdev.fpc.activation;

type
  { TFPCMetadataSurface - Metadata I/O wrappers with error logging }
  TFPCMetadataSurface = class
  private
    FErr: IOutput;
  public
    constructor Create(const AErr: IOutput);
    function WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
    function ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
  end;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings, fpdev.fpc.metadataflow;

{ TFPCMetadataSurface }

constructor TFPCMetadataSurface.Create(const AErr: IOutput);
begin
  inherited Create;
  FErr := AErr;
end;

function TFPCMetadataSurface.WriteMetadata(const AInstallPath: string; const AMeta: TFPDevMetadata): Boolean;
begin
  Result := WriteFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': WriteMetadata failed');
end;

function TFPCMetadataSurface.ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
begin
  Result := ReadFPCMetadata(AInstallPath, AMeta);
  if not Result then
    FErr.WriteLn(_(MSG_ERROR) + ': ReadMetadata failed');
end;

end.
