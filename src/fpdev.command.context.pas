unit fpdev.command.context;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config;

type
  { TDefaultCommandContext }
  TDefaultCommandContext = class(TInterfacedObject, ICommandContext)
  private
    FConfig: TFPDevConfigManager;
  public
    constructor Create;
    destructor Destroy; override;
    function Config: TFPDevConfigManager;
    procedure SaveIfModified;
  end;

implementation

{ TDefaultCommandContext }

constructor TDefaultCommandContext.Create;
begin
  inherited Create;
  FConfig := TFPDevConfigManager.Create('');
  FConfig.LoadConfig;
end;

destructor TDefaultCommandContext.Destroy;
begin
  if FConfig.Modified then FConfig.SaveConfig;
  FConfig.Free;
  inherited Destroy;
end;

function TDefaultCommandContext.Config: TFPDevConfigManager;
begin
  Result := FConfig;
end;

procedure TDefaultCommandContext.SaveIfModified;
begin
  if FConfig.Modified then FConfig.SaveConfig;
end;

end.

