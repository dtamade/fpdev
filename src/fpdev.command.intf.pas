unit fpdev.command.intf;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.utils, fpdev.config;

type
  // 新统一的接口命名（推荐使用）
  
  // 命令上下文接口
  IContext = interface
    ['{7C3B2C0F-0D95-4D8C-9D13-3B8D1E1E6F0E}']
    function Config: TFPDevConfigManager;
    procedure SaveIfModified;
  end;

  // 通用命令接口（支持嵌套子命令）
  ICommand = interface
    ['{B4DCC2C3-8AF7-4C3E-9F31-0B7A4E6A2F2E}']
    function Name: string;
    function Aliases: TStringArray; // 可返回空数组
    function FindSub(const AName: string): ICommand; // 若无子命令可返回 nil
    procedure Execute(const AParams: array of string; const Ctx: IContext);
  end;

  // 旧接口（向后兼容，已弃用）
  {$IFDEF FPC}
  ICommandContext = IContext deprecated 'Use IContext instead';
  IFpdevCommand = ICommand deprecated 'Use ICommand instead';
  {$ELSE}
  ICommandContext = interface(IContext) end deprecated 'Use IContext instead';
  IFpdevCommand = interface(ICommand) end deprecated 'Use ICommand instead';
  {$ENDIF}

implementation

end.

