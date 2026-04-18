unit fpdev.cmd.fpc.verify;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  fpdev.command.intf;

type
  { TFPCVerifyCommand - Verify FPC installation }
  TFPCVerifyCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateFPCVerifyCommand: ICommand;

implementation

uses
  fpdev.command.registry, fpdev.fpc.manager,
  fpdev.fpc.metadata,
  fpdev.fpc.verifycommandflow;

function CreateFPCVerifyCommand: ICommand;
begin
  Result := TFPCVerifyCommand.Create;
end;

{ TFPCVerifyCommand }

function TFPCVerifyCommand.Name: string;
begin
  Result := 'verify';
end;

function TFPCVerifyCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCVerifyCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then; // Suppress unused parameter hint
end;

function TFPCVerifyCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LManager: TFPCManager;
  LPlan: TFPCVerifyCommandPlan;
  LShouldExit: Boolean;
begin
  Result := PrepareFPCVerifyCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LManager := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    Result := ExecuteFPCVerifyCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LManager.VerifyInstallation,
      @LManager.GetVersionInstallPath,
      @HasFPCMetadata
    );
  finally
    LManager.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'verify'], @CreateFPCVerifyCommand, []);

end.
