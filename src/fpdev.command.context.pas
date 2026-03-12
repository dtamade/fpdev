unit fpdev.command.context;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.config.interfaces, fpdev.config.managers,
  fpdev.output.intf, fpdev.output.console, fpdev.logger.intf, fpdev.logger.console;

type
  { TDefaultCommandContext }
  TDefaultCommandContext = class(TInterfacedObject, IContext)
  private
    FConfig: IConfigManager;
    FOut: IOutput;
    FErr: IOutput;
    FLogger: ILogger;
  public
    constructor Create(
      const AConfigPath: string = '';
      const AOut: IOutput = nil;
      const AErr: IOutput = nil
    );
    destructor Destroy; override;
    function Config: IConfigManager;
    function Out: IOutput;
    function Err: IOutput;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

implementation

{ TDefaultCommandContext }

constructor TDefaultCommandContext.Create(
  const AConfigPath: string;
  const AOut: IOutput;
  const AErr: IOutput
);
begin
  inherited Create;
  FConfig := TConfigManager.Create(AConfigPath) as IConfigManager;
  FConfig.LoadConfig;

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  FLogger := TConsoleLogger.Create(FErr) as ILogger;
end;

destructor TDefaultCommandContext.Destroy;
begin
  FLogger := nil;
  FErr := nil;
  FOut := nil;
  FConfig := nil;
  inherited Destroy;
end;

function TDefaultCommandContext.Config: IConfigManager;
begin
  Result := FConfig;
end;

function TDefaultCommandContext.Out: IOutput;
begin
  Result := FOut;
end;

function TDefaultCommandContext.Err: IOutput;
begin
  Result := FErr;
end;

function TDefaultCommandContext.Logger: ILogger;
begin
  Result := FLogger;
end;

procedure TDefaultCommandContext.SaveIfModified;
begin
  if FConfig.IsModified then FConfig.SaveConfig;
end;

end.
