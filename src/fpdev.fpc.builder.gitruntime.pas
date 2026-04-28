unit fpdev.fpc.builder.gitruntime;

{$mode objfpc}{$H+}

interface

uses
  fpdev.fpc.interfaces;

// Builder-specific process-runner clone bridge.
// Keep this helper builder-local unless another non-builder caller needs the adapter.
function CloneRepositoryWithProcessRunner(
  const AProcessRunner: IProcessRunner;
  const AURL, ATargetDir, ABranch: string;
  out AError: string
): Boolean;

implementation

uses
  fpdev.git.operations,
  fpdev.utils.process;

type
  TGitCliRunnerFromProcessRunner = class(TInterfacedObject, IGitCliRunner)
  private
    FProcessRunner: IProcessRunner;
  public
    constructor Create(const AProcessRunner: IProcessRunner);
    function Execute(
      const AParams: array of string;
      const AWorkDir: string = ''
    ): fpdev.utils.process.TProcessResult;
  end;

constructor TGitCliRunnerFromProcessRunner.Create(const AProcessRunner: IProcessRunner);
begin
  inherited Create;
  FProcessRunner := AProcessRunner;
end;

function TGitCliRunnerFromProcessRunner.Execute(
  const AParams: array of string;
  const AWorkDir: string
): fpdev.utils.process.TProcessResult;
var
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
begin
  ProcResult := FProcessRunner.Execute('git', AParams, AWorkDir);
  Result.Success := ProcResult.Success;
  Result.ExitCode := ProcResult.ExitCode;
  Result.StdOut := ProcResult.StdOut;
  Result.StdErr := ProcResult.StdErr;
  Result.ErrorMessage := '';
end;

function CloneRepositoryWithProcessRunner(
  const AProcessRunner: IProcessRunner;
  const AURL, ATargetDir, ABranch: string;
  out AError: string
): Boolean;
var
  GitOps: TGitOperations;
begin
  AError := '';
  GitOps := TGitOperations.Create(TGitCliRunnerFromProcessRunner.Create(AProcessRunner), True);
  try
    Result := GitOps.Clone(AURL, ATargetDir, ABranch);
    if not Result then
      AError := GitOps.LastError;
  finally
    GitOps.Free;
  end;
end;

end.
