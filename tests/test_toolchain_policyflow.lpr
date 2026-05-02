program test_toolchain_policyflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.toolchain.policyflow,
  fpdev.utils,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

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

procedure WritePolicyJSON(const APath, ABody: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := ABody;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure TestLoadPolicyFromFileCorePrefersExactMatch;
var
  TempRoot: string;
  PolicyPath: string;
  MinVer: string;
  RecVer: string;
  MatchedKey: string;
begin
  TempRoot := CreateUniqueTempDir('test_toolchain_policyflow_exact');
  try
    Check('toolchain policyflow temp root stays under shared temp',
      PathUsesSystemTempRoot(TempRoot),
      TempRoot);
    PolicyPath := TempRoot + PathDelim + 'policy.json';
    WritePolicyJSON(
      PolicyPath,
      '{' + LineEnding +
      '  "fpc": {' + LineEnding +
      '    "3.2.": { "min": "3.0.4", "rec": "3.2.2" },' + LineEnding +
      '    "3.2.2": { "min": "3.1.0", "rec": "3.2.1" }' + LineEnding +
      '  }' + LineEnding +
      '}'
    );

    ResetToolchainPolicyFlowCore;
    Check('toolchain policyflow loads policy file',
      LoadToolchainPolicyFromFileCore(PolicyPath),
      'expected policy file load success');
    Check('toolchain policyflow resolves exact match',
      GetExternalToolchainPolicyCore('3.2.2', MinVer, RecVer, MatchedKey),
      'expected exact match');
    Check('toolchain policyflow prefers exact key over prefix',
      MatchedKey = '3.2.2',
      'matched=' + MatchedKey);
    Check('toolchain policyflow exact match min',
      MinVer = '3.1.0',
      'min=' + MinVer);
    Check('toolchain policyflow exact match rec',
      RecVer = '3.2.1',
      'rec=' + RecVer);
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestLoadPolicyAutoCoreUsesEnvOverrideAndAliasMatch;
var
  TempRoot: string;
  PolicyPath: string;
  SavedPolicyPath: string;
  MinVer: string;
  RecVer: string;
  MatchedKey: string;
begin
  TempRoot := CreateUniqueTempDir('test_toolchain_policyflow_env');
  SavedPolicyPath := get_env('FPDEV_POLICY_FILE');
  try
    Check('toolchain policyflow env temp root stays under shared temp',
      PathUsesSystemTempRoot(TempRoot),
      TempRoot);
    PolicyPath := TempRoot + PathDelim + 'policy.json';
    WritePolicyJSON(
      PolicyPath,
      '{' + LineEnding +
      '  "fpc": {' + LineEnding +
      '    "main": { "min": "3.1.0", "rec": "3.2.1" }' + LineEnding +
      '  }' + LineEnding +
      '}'
    );

    ResetToolchainPolicyFlowCore;
    Check('toolchain policyflow sets env override',
      set_env('FPDEV_POLICY_FILE', PolicyPath),
      'expected env override set success');
    Check('toolchain policyflow auto-loads env override',
      LoadToolchainPolicyAutoCore,
      'expected auto load success');
    Check('toolchain policyflow matches trunk alias to main',
      GetExternalToolchainPolicyCore('trunk', MinVer, RecVer, MatchedKey),
      'expected alias match');
    Check('toolchain policyflow alias match keeps main key',
      MatchedKey = 'main',
      'matched=' + MatchedKey);
    Check('toolchain policyflow alias min',
      MinVer = '3.1.0',
      'min=' + MinVer);
    Check('toolchain policyflow alias rec',
      RecVer = '3.2.1',
      'rec=' + RecVer);
  finally
    RestoreEnv('FPDEV_POLICY_FILE', SavedPolicyPath);
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestCompareToolchainVersionCoreNormalizesSuffixes;
begin
  Check('toolchain policyflow strips suffix when comparing equal versions',
    CompareToolchainVersionCore('3.2.2-rc1', '3.2.2') = 0,
    'compare failed');
  Check('toolchain policyflow compares numeric segments',
    CompareToolchainVersionCore('3.2.10', '3.2.2') = 1,
    'numeric compare failed');
end;

procedure TestEvaluateToolchainFPCVersionPolicyCoreFallsBackToBuiltInWarn;
var
  StatusText: string;
  ReasonText: string;
  MinVer: string;
  RecVer: string;
begin
  ResetToolchainPolicyFlowCore;
  unset_env('FPDEV_POLICY_FILE');
  Check('toolchain policyflow built-in fallback returns warn above min below rec',
    EvaluateToolchainFPCVersionPolicyCore('3.2.2', '3.1.0', StatusText, ReasonText, MinVer, RecVer),
    'expected built-in warn success');
  Check('toolchain policyflow built-in fallback status warn',
    StatusText = 'WARN',
    'status=' + StatusText);
  Check('toolchain policyflow built-in fallback min',
    MinVer = '3.0.4',
    'min=' + MinVer);
  Check('toolchain policyflow built-in fallback rec',
    RecVer = '3.2.0',
    'rec=' + RecVer);
end;

procedure TestEvaluateToolchainFPCVersionPolicyCoreFailsBelowMin;
var
  StatusText: string;
  ReasonText: string;
  MinVer: string;
  RecVer: string;
begin
  ResetToolchainPolicyFlowCore;
  unset_env('FPDEV_POLICY_FILE');
  Check('toolchain policyflow fails below min version',
    not EvaluateToolchainFPCVersionPolicyCore('3.2.2', '3.0.0', StatusText, ReasonText, MinVer, RecVer),
    'expected fail below min');
  Check('toolchain policyflow fail status',
    StatusText = 'FAIL',
    'status=' + StatusText);
  Check('toolchain policyflow fail reason',
    ReasonText = 'fpc < min',
    'reason=' + ReasonText);
end;

begin
  TestLoadPolicyFromFileCorePrefersExactMatch;
  TestLoadPolicyAutoCoreUsesEnvOverrideAndAliasMatch;
  TestCompareToolchainVersionCoreNormalizesSuffixes;
  TestEvaluateToolchainFPCVersionPolicyCoreFallsBackToBuiltInWarn;
  TestEvaluateToolchainFPCVersionPolicyCoreFailsBelowMin;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
