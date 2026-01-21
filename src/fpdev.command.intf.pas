unit fpdev.command.intf;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.config, fpdev.config.interfaces, fpdev.output.intf, fpdev.logger.intf;

type
  // 新统一的接口命名（推荐使用）

  // 命令上下文接口
  IContext = interface
    ['{7C3B2C0F-0D95-4D8C-9D13-3B8D1E1E6F0E}']
    function Config: IConfigManager;
    function Out: IOutput;
    function Err: IOutput;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

  // Legacy command context interface for backward compatibility
  ICommandContext = interface
    ['{8D4E3F1A-2B6C-4E9D-A7F8-1C5D9E2B4A3F}']
    function Config: TFPDevConfigManager;
    procedure SaveIfModified;
  end;

  // 通用命令接口（支持嵌套子命令）
  ICommand = interface
    ['{B4DCC2C3-8AF7-4C3E-9F31-0B7A4E6A2F2E}']
    function Name: string;
    function Aliases: TStringArray; // 可返回空数组
    function FindSub(const AName: string): ICommand; // 若无子命令可返回 nil
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

  // Legacy command interface for backward compatibility
  IFpdevCommand = interface
    ['{9E5F4D2C-3A7B-4E8D-B6F9-2C8D1E3A5F4D}']
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

end.

