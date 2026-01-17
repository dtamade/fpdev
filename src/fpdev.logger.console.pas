unit fpdev.logger.console;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.logger.intf, fpdev.output.intf;

type
  TConsoleLogger = class(TInterfacedObject, ILogger)
  private
    FOut: IOutput;
    function LevelToPrefix(const ALevel: TLogLevel): string;
  public
    constructor Create(const AOut: IOutput);
    procedure Log(const ALevel: TLogLevel; const Msg: string);
    procedure Debug(const Msg: string);
    procedure Info(const Msg: string);
    procedure Warn(const Msg: string);
    procedure Error(const Msg: string);
  end;

implementation

constructor TConsoleLogger.Create(const AOut: IOutput);
begin
  inherited Create;
  FOut := AOut;
end;

function TConsoleLogger.LevelToPrefix(const ALevel: TLogLevel): string;
begin
  Result := '';
  case ALevel of
    llDebug: Result := '[DEBUG] ';
    llInfo: Result := '[INFO] ';
    llWarn: Result := '[WARN] ';
    llError: Result := '[ERROR] ';
  end;
end;

procedure TConsoleLogger.Log(const ALevel: TLogLevel; const Msg: string);
begin
  if FOut <> nil then
    FOut.WriteLn(LevelToPrefix(ALevel) + Msg);
end;

procedure TConsoleLogger.Debug(const Msg: string);
begin
  Log(llDebug, Msg);
end;

procedure TConsoleLogger.Info(const Msg: string);
begin
  Log(llInfo, Msg);
end;

procedure TConsoleLogger.Warn(const Msg: string);
begin
  Log(llWarn, Msg);
end;

procedure TConsoleLogger.Error(const Msg: string);
begin
  Log(llError, Msg);
end;

end.
