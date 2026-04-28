program test_project_templatecommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.project.templatecommandflow;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

  TProjectTemplateCommandProbe = class
  public
    ListResult: Boolean;
    InstallResult: Boolean;
    RemoveResult: Boolean;
    UpdateResult: Boolean;
    ListCalls: Integer;
    InstallCalls: Integer;
    RemoveCalls: Integer;
    UpdateCalls: Integer;
    LastPath: string;
    LastName: string;
    InstallWritesToOut: string;
    InstallWritesToErr: string;
    RemoveWritesToOut: string;
    RemoveWritesToErr: string;
    UpdateWritesToOut: string;
    UpdateWritesToErr: string;
    function ListTemplates(const Outp: IOutput): Boolean;
    function InstallTemplate(const Outp, Errp: IOutput; const APath: string): Boolean;
    function RemoveTemplate(const Outp, Errp: IOutput; const AName: string): Boolean;
    function UpdateTemplates(const Outp, Errp: IOutput): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TStringOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TProjectTemplateCommandProbe.ListTemplates(const Outp: IOutput): Boolean;
begin
  Inc(ListCalls);
  if Outp <> nil then
    Outp.WriteLn('template-list');
  Result := ListResult;
end;

function TProjectTemplateCommandProbe.InstallTemplate(
  const Outp, Errp: IOutput;
  const APath: string
): Boolean;
begin
  Inc(InstallCalls);
  LastPath := APath;
  if (Outp <> nil) and (InstallWritesToOut <> '') then
    Outp.WriteLn(InstallWritesToOut);
  if (Errp <> nil) and (InstallWritesToErr <> '') then
    Errp.WriteLn(InstallWritesToErr);
  Result := InstallResult;
end;

function TProjectTemplateCommandProbe.RemoveTemplate(
  const Outp, Errp: IOutput;
  const AName: string
): Boolean;
begin
  Inc(RemoveCalls);
  LastName := AName;
  if (Outp <> nil) and (RemoveWritesToOut <> '') then
    Outp.WriteLn(RemoveWritesToOut);
  if (Errp <> nil) and (RemoveWritesToErr <> '') then
    Errp.WriteLn(RemoveWritesToErr);
  Result := RemoveResult;
end;

function TProjectTemplateCommandProbe.UpdateTemplates(
  const Outp, Errp: IOutput
): Boolean;
begin
  Inc(UpdateCalls);
  if (Outp <> nil) and (UpdateWritesToOut <> '') then
    Outp.WriteLn(UpdateWritesToOut);
  if (Errp <> nil) and (UpdateWritesToErr <> '') then
    Errp.WriteLn(UpdateWritesToErr);
  Result := UpdateResult;
end;

procedure InitOutputs(
  out AOutObj, AErrObj: TStringOutput;
  out AOut, AErr: IOutput
);
begin
  AOutObj := TStringOutput.Create;
  AErrObj := TStringOutput.Create;
  AOut := AOutObj;
  AErr := AErrObj;
end;

procedure ReleaseOutputs(
  var AOut, AErr: IOutput;
  var AOutObj, AErrObj: TStringOutput
);
begin
  AErr := nil;
  AOut := nil;
  AErrObj := nil;
  AOutObj := nil;
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestPrepareListHelp;
var
  Plan: TProjectTemplateListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectTemplateListCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare template list help EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare template list help exits', ShouldExit, 'should exit');
    Check('prepare template list help writes usage', OutpObj.Contains('fpdev project template list'), OutpObj.Text);
    Check('prepare template list help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareListRejectsUnexpectedArg;
var
  Plan: TProjectTemplateListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectTemplateListCommandPlanCore(['extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare template list extra arg usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare template list extra arg exits', ShouldExit, 'should exit');
    Check('prepare template list extra arg writes usage', ErrpObj.Contains('fpdev project template list'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteListMapsSuccessAndFailure;
var
  Probe: TProjectTemplateCommandProbe;
  Plan: TProjectTemplateListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectTemplateCommandProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.ListResult := True;
    Code := ExecuteProjectTemplateListCommandPlanCore(Outp, Errp, @Probe.ListTemplates);
    Check('execute template list success EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute template list calls callback once', Probe.ListCalls = 1, IntToStr(Probe.ListCalls));
    Check('execute template list preserves output', OutpObj.Contains('template-list'), OutpObj.Text);

    Probe.ListResult := False;
    Code := ExecuteProjectTemplateListCommandPlanCore(Outp, Errp, @Probe.ListTemplates);
    Check('execute template list failure EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareInstallRejectsMissingPath;
var
  Plan: TProjectTemplateInstallCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectTemplateInstallCommandPlanCore([], Outp, Errp, Plan, ShouldExit);
    Check('prepare template install missing path usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare template install missing path exits', ShouldExit, 'should exit');
    Check('prepare template install missing path writes missing arg', ErrpObj.Contains('path'), ErrpObj.Text);
    Check('prepare template install missing path writes usage', ErrpObj.Contains('fpdev project template install <path>'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteInstallDelegatesPath;
var
  Probe: TProjectTemplateCommandProbe;
  Plan: TProjectTemplateInstallCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectTemplateCommandProbe.Create;
  Probe.InstallResult := True;
  Probe.InstallWritesToOut := 'installed-template';
  Plan.TemplatePath := '/tmp/template-path';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecuteProjectTemplateInstallCommandPlanCore(Plan, Outp, Errp, @Probe.InstallTemplate);
    Check('execute template install EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute template install passes path', Probe.LastPath = '/tmp/template-path', Probe.LastPath);
    Check('execute template install preserves output', OutpObj.Contains('installed-template'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareRemoveRejectsMissingName;
var
  Plan: TProjectTemplateRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectTemplateRemoveCommandPlanCore([], Outp, Errp, Plan, ShouldExit);
    Check('prepare template remove missing name usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare template remove missing name exits', ShouldExit, 'should exit');
    Check('prepare template remove missing name writes missing arg', ErrpObj.Contains('name'), ErrpObj.Text);
    Check('prepare template remove missing name writes usage', ErrpObj.Contains('fpdev project template remove <name>'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteRemoveDelegatesName;
var
  Probe: TProjectTemplateCommandProbe;
  Plan: TProjectTemplateRemoveCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectTemplateCommandProbe.Create;
  Probe.RemoveResult := True;
  Probe.RemoveWritesToOut := 'removed-template';
  Plan.TemplateName := 'custom-template';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecuteProjectTemplateRemoveCommandPlanCore(Plan, Outp, Errp, @Probe.RemoveTemplate);
    Check('execute template remove EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute template remove passes name', Probe.LastName = 'custom-template', Probe.LastName);
    Check('execute template remove preserves output', OutpObj.Contains('removed-template'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareUpdateRejectsUnexpectedArg;
var
  Plan: TProjectTemplateUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareProjectTemplateUpdateCommandPlanCore(['extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare template update extra arg usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare template update extra arg exits', ShouldExit, 'should exit');
    Check('prepare template update extra arg writes usage', ErrpObj.Contains('fpdev project template update'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteUpdateMapsSuccessAndFailure;
var
  Probe: TProjectTemplateCommandProbe;
  Plan: TProjectTemplateUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Probe := TProjectTemplateCommandProbe.Create;
  Probe.UpdateWritesToOut := 'updated-templates';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.UpdateResult := True;
    Code := ExecuteProjectTemplateUpdateCommandPlanCore(Outp, Errp, @Probe.UpdateTemplates);
    Check('execute template update EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute template update calls callback once', Probe.UpdateCalls = 1, IntToStr(Probe.UpdateCalls));
    Check('execute template update preserves output', OutpObj.Contains('updated-templates'), OutpObj.Text);

    Probe.UpdateResult := False;
    Code := ExecuteProjectTemplateUpdateCommandPlanCore(Outp, Errp, @Probe.UpdateTemplates);
    Check('execute template update failure EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  TestPrepareListHelp;
  TestPrepareListRejectsUnexpectedArg;
  TestExecuteListMapsSuccessAndFailure;
  TestPrepareInstallRejectsMissingPath;
  TestExecuteInstallDelegatesPath;
  TestPrepareRemoveRejectsMissingName;
  TestExecuteRemoveDelegatesName;
  TestPrepareUpdateRejectsUnexpectedArg;
  TestExecuteUpdateMapsSuccessAndFailure;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
