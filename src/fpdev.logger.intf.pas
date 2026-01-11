unit fpdev.logger.intf;

{$mode objfpc}{$H+}

interface

type
  TLogLevel = (llDebug, llInfo, llWarn, llError);

  ILogger = interface
    ['{3B9B8799-6A32-4AA6-9A6C-6FB1EE7BCA2C}']
    procedure Log(const ALevel: TLogLevel; const Msg: string);
    procedure Debug(const Msg: string);
    procedure Info(const Msg: string);
    procedure Warn(const Msg: string);
    procedure Error(const Msg: string);
  end;

implementation

end.
