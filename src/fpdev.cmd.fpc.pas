unit fpdev.cmd.fpc;

{$mode objfpc}{$H+}

interface

uses
  fpdev.fpc.manager;

type
  TFPCManager = fpdev.fpc.manager.TFPCManager;

procedure FPC_UpdateIndex(const AConfigPath: string = '');

implementation

procedure FPC_UpdateIndex(const AConfigPath: string = '');
begin
  fpdev.fpc.manager.FPC_UpdateIndex(AConfigPath);
end;

end.
