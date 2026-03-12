unit fpdev.cli.runner;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf,
  fpdev.output.intf;

type
  TRootHelpProc = procedure(const AParams: TStringArray; const AOut: IOutput);
  TNormalizeArgsProc = procedure(const ARawArgs: TStringArray; out APrimary: string; out AParams: TStringArray);
  TBuildDispatchArgsFunc = function(const APrimary: string; const AParams: TStringArray): TStringArray;
  TCreateContextFunc = function(const AOut, AErr: IOutput): IContext;
  TDispatchArgsFunc = function(const AArgs: TStringArray; const Ctx: IContext): Integer;

function RunCLIRootFlowCore(const ARawArgs: TStringArray; const AOut, AErr: IOutput;
  AExecuteRootHelp: TRootHelpProc;
  ANormalizeArgs: TNormalizeArgsProc;
  ABuildDispatchArgs: TBuildDispatchArgsFunc;
  ACreateContext: TCreateContextFunc;
  ADispatchArgs: TDispatchArgsFunc): Integer;

function RunCLI(const ARawArgs: TStringArray; const AOut, AErr: IOutput): Integer;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.cli.bootstrap,
  fpdev.cli.global;

function RunCLIRootFlowCore(const ARawArgs: TStringArray; const AOut, AErr: IOutput;
  AExecuteRootHelp: TRootHelpProc;
  ANormalizeArgs: TNormalizeArgsProc;
  ABuildDispatchArgs: TBuildDispatchArgsFunc;
  ACreateContext: TCreateContextFunc;
  ADispatchArgs: TDispatchArgsFunc): Integer;
var
  LPrimary: string;
  LParams: TStringArray;
  LDispatchArgs: TStringArray;
  LCtx: IContext;
begin
  Result := 0;

  if Length(ARawArgs) = 0 then
  begin
    if Assigned(AExecuteRootHelp) then
      AExecuteRootHelp(nil, AOut);
    Exit;
  end;

  LPrimary := '';
  LParams := nil;
  if Assigned(ANormalizeArgs) then
    ANormalizeArgs(ARawArgs, LPrimary, LParams);

  if LPrimary = '' then
  begin
    if Assigned(AExecuteRootHelp) then
      AExecuteRootHelp(nil, AOut);
    Exit;
  end;

  LDispatchArgs := nil;
  if Assigned(ABuildDispatchArgs) then
    LDispatchArgs := ABuildDispatchArgs(LPrimary, LParams);

  LCtx := nil;
  if Assigned(ACreateContext) then
    LCtx := ACreateContext(AOut, AErr);

  if Assigned(ADispatchArgs) then
    Result := ADispatchArgs(LDispatchArgs, LCtx);
end;

function RunCLI(const ARawArgs: TStringArray; const AOut, AErr: IOutput): Integer;
begin
  try
    ApplyPortableModeFromArgs(ARawArgs);
    Result := RunCLIRootFlowCore(
      ARawArgs,
      AOut,
      AErr,
      @ExecuteRootHelpCore,
      @NormalizePrimaryAndParams,
      @BuildDispatchArgs,
      @CreateDefaultContextCore,
      @DispatchArgsWithRegistryCore
    );
  except
    on E: Exception do
    begin
      if AErr <> nil then
        AErr.WriteLn(_(MSG_ERROR) + ': ' + string(E.ClassName) + ': ' + E.Message);
      Result := 1;
    end;
  end;
end;

end.
