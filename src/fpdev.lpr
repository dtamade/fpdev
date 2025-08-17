program fpdev;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Classes,
  fpdev.utils,

  fpdev.cmd,
  fpdev.cmd.help,
  fpdev.cmd.version,
  fpdev.cmd.fpc,
  fpdev.cmd.lazarus,
  fpdev.cmd.package,
  fpdev.cmd.cross,
  fpdev.cmd.project,

  // 强引用：FPC/Lazarus 子命令对象（确保 initialization 注册生效）
  fpdev.cmd.fpc.install,
  fpdev.cmd.fpc.list,
  fpdev.cmd.fpc.use,
  fpdev.cmd.fpc.doctor,
  fpdev.cmd.fpc.current,
  fpdev.cmd.fpc.show,
  fpdev.cmd.fpc.test,
  fpdev.cmd.fpc.update,
  fpdev.cmd.fpc.root2,

  fpdev.cmd.lazarus.root,
  fpdev.cmd.lazarus.list,
  fpdev.cmd.lazarus.current,
  fpdev.cmd.lazarus.use,
  fpdev.cmd.lazarus.run,

  // 新的命令注册表与上下文
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.command.context,

  // 版本管理模块
  fpdev.fpc.source,
  fpdev.lazarus.source;

// 内部版本管理支持函数 (供现有命令模块使用)
function GetFPCSourceManager: TFPCSourceManager;
begin
  Result := TFPCSourceManager.Create;
end;

function GetLazarusSourceManager: TLazarusSourceManager;
begin
  Result := TLazarusSourceManager.Create;
end;

function make_params:TStringArray;
var
  LCount :Integer;
  i: integer;
begin
  Initialize(Result);
  LCount := ParamCount;
  if LCount >1 then
  begin
    SetLength(Result,LCount-1);
    for i := 2 to LCount do
      Result[i-2] := ParamStr(i);
  end
  else
    SetLength(Result,0);
end;

var
  LParam: string;
  LParams: TStringArray;
  LArgs: TStringArray;
  LCtx: TDefaultCommandContext;
  LI: Integer;
begin
  try
    if ParamCount = 0 then
    begin
      fpdev.cmd.help.execute([]);
    end
    else
    begin
      LParam  := ParamStr(1);
      LParams := make_params;

      // 纯注册表分发
      LCtx := TDefaultCommandContext.Create;
      try
        // 拼接 LParam + LParams => LArgs
        SetLength(LArgs, Length(LParams)+1);
        LArgs[0] := LParam;
        for LI := 0 to High(LParams) do LArgs[LI+1] := LParams[LI];
        if GlobalCommandRegistry.Dispatch(LArgs, LCtx) <> 0 then
        begin
          WriteLn('错误: 未知的命令: ', LParam);
          WriteLn('使用 "fpdev help" 查看帮助信息');
        end;
      finally
        LCtx.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      WriteLn('错误: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.










































































































