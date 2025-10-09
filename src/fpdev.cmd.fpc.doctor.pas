unit fpdev.cmd.fpc.doctor;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, fpdev.command.intf, fpdev.config;

type
  { TFPCDoctorCommand }
  TFPCDoctorCommand = class(TInterfacedObject, IFpdevCommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): IFpdevCommand;
    procedure Execute(const AParams: array of string; const Ctx: ICommandContext);
  end;

implementation

uses fpdev.command.registry;

function TFPCDoctorCommand.Name: string; begin Result := 'doctor'; end;

function TFPCDoctorCommand.Aliases: TStringArray; begin SetLength(Result,0); end;
function TFPCDoctorCommand.FindSub(const AName: string): IFpdevCommand; begin Result := nil; end;


function RunToolVersion(const AExe: string; const AArg: string; out AOut: string): Boolean;
var
  LProc: TProcess;
  LOut: TStringList;
begin
  Result := False;
  AOut := '';
  LProc := TProcess.Create(nil);
  LOut := TStringList.Create;
  try
    LProc.Executable := AExe;
    if AArg <> '' then LProc.Parameters.Add(AArg);
    LProc.Options := [poUsePipes, poWaitOnExit];
    try
      LProc.Execute;
      if LProc.ExitStatus = 0 then
      begin
        LOut.LoadFromStream(LProc.Output);
        AOut := Trim(LOut.Text);
        Exit(True);
      end;
    except
      on E: Exception do
      begin
        AOut := E.Message;
        Exit(False);
      end;
    end;
  finally
    LOut.Free;
    LProc.Free;
  end;
end;

function CheckWriteableDir(const ADir: string; out AErr: string): Boolean;
var
  LPath, LTest: string;
  LSL: TStringList;
begin
  Result := False;
  AErr := '';
  LPath := IncludeTrailingPathDelimiter(ADir);
  try
    if not DirectoryExists(LPath) then ForceDirectories(LPath);
    if not DirectoryExists(LPath) then
    begin
      AErr := 'Cannot create directory';
      Exit(False);
    end;
    LTest := LPath + '.fpdev_write_test.tmp';
    LSL := TStringList.Create;
    try
      LSL.Text := 'ok';
      LSL.SaveToFile(LTest);
      Result := FileExists(LTest);
      DeleteFile(LTest);
    finally
      LSL.Free;
    end;
  except
    on E: Exception do
    begin
      AErr := E.Message;
      Result := False;
    end;
  end;
end;

procedure TFPCDoctorCommand.Execute(const AParams: array of string; const Ctx: ICommandContext);
var
  LOut, LErr: string;
  LOk: Boolean;
  LRoot: string;
  LSettings: TFPDevSettings;
begin
  // WriteLn('fpdev fpc doctor');  // 调试代码已注释
  // WriteLn('');  // 调试代码已注释

  // 1) 写权限检查（安装根）
  LSettings := Ctx.Config.GetSettings;
  LRoot := LSettings.InstallRoot;
  if LRoot = '' then
    LRoot := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'data';
  LOk := CheckWriteableDir(LRoot, LErr);
  if LOk then
    WriteLn('[OK] Write permission OK: ', LRoot)
  else
    WriteLn('[X] Write permission failed: ', LRoot, ' (', LErr, ')');

  // 2) git
  LOk := RunToolVersion('git', '--version', LOut);
  if LOk then WriteLn('[OK] git: ', LOut) else WriteLn('[X] git not ready (Please install Git and add it to PATH)');

  // 3) make
  LOk := RunToolVersion('make', '--version', LOut);
  if LOk then WriteLn('[OK] make: ', Copy(LOut,1,80), '...') else WriteLn('[X] make not ready (Windows: install MSYS2/MinGW and add make to PATH)');

  // 4) bootstrap fpc (optional)
  LOk := RunToolVersion('fpc', '-i', LOut);
  if LOk then WriteLn('[OK] bootstrap fpc: available') else WriteLn('[!] bootstrap fpc not available (building from source requires an existing fpc)');

  // WriteLn('');  // 调试代码已注释
  // WriteLn('建议:');  // 调试代码已注释
  {$IFDEF MSWINDOWS}
  // WriteLn('- Windows: 安装 Git；安装 MSYS2/MinGW 并确保 make 可用；可从 FreePascal 官网上安装一个稳定版 FPC 用作引导');  // 调试代码已注释
  {$ELSE}
  // WriteLn('- Linux/macOS: 使用包管理器安装 git/make/fpc；确保当前用户对安装根目录有写权限');  // 调试代码已注释
  {$ENDIF}
end;


function FPCDoctorFactory: IFpdevCommand;
begin
  Result := TFPCDoctorCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','doctor'], @FPCDoctorFactory, []);

end.

