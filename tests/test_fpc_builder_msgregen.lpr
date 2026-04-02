program test_fpc_builder_msgregen;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.builder,
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

procedure WriteTextFile(const APath, AContent: string);
var
  TextFile: TStringList;
begin
  TextFile := TStringList.Create;
  try
    TextFile.Text := AContent;
    ForceDirectories(ExtractFileDir(APath));
    TextFile.SaveToFile(APath);
  finally
    TextFile.Free;
  end;
end;

function ReadTextFile(const APath: string): string;
var
  TextFile: TStringList;
begin
  Result := '';
  if not FileExists(APath) then
    Exit;

  TextFile := TStringList.Create;
  try
    TextFile.LoadFromFile(APath);
    Result := TextFile.Text;
  finally
    TextFile.Free;
  end;
end;

procedure TestBuilderDropsGeneratedCompilerMessageIncludes;
var
  SourceDir: string;
  MsgDir: string;
  MsgIdxPath: string;
  MsgTxtPath: string;
begin
  SourceDir := CreateUniqueTempDir('test_fpc_builder_msgregen');
  try
    MsgDir := SourceDir + PathDelim + 'compiler' + PathDelim + 'msg';
    MsgIdxPath := SourceDir + PathDelim + 'compiler' + PathDelim + 'msgidx.inc';
    MsgTxtPath := SourceDir + PathDelim + 'compiler' + PathDelim + 'msgtxt.inc';

    WriteTextFile(MsgDir + PathDelim + 'errore.msg', 'dummy=09221_E_Dummy');
    WriteTextFile(MsgIdxPath, 'stale msgidx');
    WriteTextFile(MsgTxtPath, 'stale msgtxt');

    FPCBuilderInvalidateCompilerMessageIncludesCore(SourceDir);

    Check('builder removes stale compiler msgidx.inc', not FileExists(MsgIdxPath),
      'msgidx.inc should be removed');
    Check('builder removes stale compiler msgtxt.inc', not FileExists(MsgTxtPath),
      'msgtxt.inc should be removed');
  finally
    CleanupTempDir(SourceDir);
  end;
end;

procedure TestBuilderAppliesFCLWebJWTSourcePathHotfix;
var
  SourceDir: string;
  FPMakePath: string;
  UnitsDir: string;
  JWTSourceDir: string;
  TextFile: TStringList;
begin
  SourceDir := CreateUniqueTempDir('test_fpc_builder_fclweb_hotfix');
  try
    FPMakePath := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'fpmake.pp';
    UnitsDir := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'units' + PathDelim + 'x86_64-linux';
    JWTSourceDir := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'src' + PathDelim + 'jwt';

    ForceDirectories(JWTSourceDir);
    WriteTextFile(FPMakePath,
      '    P.SourcePath.Add(''src/base'');' + LineEnding +
      '    P.SourcePath.Add(''src/webdata'');' + LineEnding +
      '    P.SourcePath.Add(''src/jwt'');' + LineEnding +
      '    T:=P.Targets.AddUnit(''fpjwt.pp'');' + LineEnding);
    WriteTextFile(UnitsDir + PathDelim + 'fpjwt.ppu', 'stale ppu');
    WriteTextFile(UnitsDir + PathDelim + 'fpjwt.o', 'stale obj');
    WriteTextFile(UnitsDir + PathDelim + 'BuildUnit_fcl_web.pp', 'stale build unit');

    FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(SourceDir);

    TextFile := TStringList.Create;
    try
      TextFile.LoadFromFile(FPMakePath);
      Check('builder puts src/jwt before src/base',
        TextFile.IndexOf('    P.SourcePath.Add(''src/jwt'');') <
        TextFile.IndexOf('    P.SourcePath.Add(''src/base'');'),
        TextFile.Text);
      Check('builder pins fpjwt target to jwt source file',
        TextFile.IndexOf('    T:=P.Targets.AddUnit(''src/jwt/fpjwt.pp'');') >= 0,
        TextFile.Text);
    finally
      TextFile.Free;
    end;

    Check('builder removes stale fcl-web fpjwt ppu',
      not FileExists(UnitsDir + PathDelim + 'fpjwt.ppu'),
      'fpjwt.ppu should be removed');
    Check('builder removes stale fcl-web fpjwt object',
      not FileExists(UnitsDir + PathDelim + 'fpjwt.o'),
      'fpjwt.o should be removed');
    Check('builder removes stale fcl-web build unit file',
      not FileExists(UnitsDir + PathDelim + 'BuildUnit_fcl_web.pp'),
      'BuildUnit_fcl_web.pp should be removed');
  finally
    CleanupTempDir(SourceDir);
  end;
end;

procedure TestBuilderAddsMissingJWTSourcePathWhenJWTTreeExists;
var
  SourceDir: string;
  FPMakePath: string;
  JWTSourceDir: string;
  TextFile: TStringList;
begin
  SourceDir := CreateUniqueTempDir('test_fpc_builder_fclweb_jwt_tree');
  try
    FPMakePath := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'fpmake.pp';
    JWTSourceDir := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'src' + PathDelim + 'jwt';

    ForceDirectories(JWTSourceDir);
    WriteTextFile(FPMakePath,
      '    P.SourcePath.Add(''src/base'');' + LineEnding +
      '    P.SourcePath.Add(''src/webdata'');' + LineEnding +
      '    P.SourcePath.Add(''src/jsonrpc'');' + LineEnding +
      '    T:=P.Targets.AddUnit(''fpjwt.pp'');' + LineEnding);

    FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(SourceDir);

    TextFile := TStringList.Create;
    try
      TextFile.LoadFromFile(FPMakePath);
      Check('builder adds missing src/jwt source path',
        TextFile.IndexOf('    P.SourcePath.Add(''src/jwt'');') >= 0,
        TextFile.Text);
      Check('builder inserts src/jwt before src/base on fresh 3.2.2 tree',
        TextFile.IndexOf('    P.SourcePath.Add(''src/jwt'');') <
        TextFile.IndexOf('    P.SourcePath.Add(''src/base'');'),
        TextFile.Text);
      Check('builder still pins fpjwt target on fresh 3.2.2 tree',
        TextFile.IndexOf('    T:=P.Targets.AddUnit(''src/jwt/fpjwt.pp'');') >= 0,
        TextFile.Text);
    finally
      TextFile.Free;
    end;
  finally
    CleanupTempDir(SourceDir);
  end;
end;

procedure TestBuilderMirrorsJWTUnitIntoBaseWhenJWTTreeExists;
var
  SourceDir: string;
  FPMakePath: string;
  BaseJWTPath: string;
  JWTSourcePath: string;
begin
  SourceDir := CreateUniqueTempDir('test_fpc_builder_fclweb_jwt_mirror');
  try
    FPMakePath := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'fpmake.pp';
    BaseJWTPath := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'src' + PathDelim + 'base' + PathDelim + 'fpjwt.pp';
    JWTSourcePath := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'src' + PathDelim + 'jwt' + PathDelim + 'fpjwt.pp';

    WriteTextFile(FPMakePath,
      '    P.SourcePath.Add(''src/base'');' + LineEnding +
      '    T:=P.Targets.AddUnit(''fpjwt.pp'');' + LineEnding);
    WriteTextFile(BaseJWTPath, 'unit fpjwt;' + LineEnding + 'interface' + LineEnding + 'implementation' + LineEnding + 'end.');
    WriteTextFile(JWTSourcePath,
      'unit fpjwt;' + LineEnding +
      'interface' + LineEnding +
      'type' + LineEnding +
      '  TJWTSigner = class end;' + LineEnding +
      'implementation' + LineEnding +
      'end.');

    FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(SourceDir);

    Check('builder mirrors jwt fpjwt into base tree',
      Pos('TJWTSigner', ReadTextFile(BaseJWTPath)) > 0,
      ReadTextFile(BaseJWTPath));
  finally
    CleanupTempDir(SourceDir);
  end;
end;

procedure TestBuilderSkipsJWTSourceHotfixWhenJWTTreeMissing;
var
  SourceDir: string;
  FPMakePath: string;
  TextFile: TStringList;
begin
  SourceDir := CreateUniqueTempDir('test_fpc_builder_fclweb_no_jwt_tree');
  try
    FPMakePath := SourceDir + PathDelim + 'packages' + PathDelim + 'fcl-web' +
      PathDelim + 'fpmake.pp';

    WriteTextFile(FPMakePath,
      '    P.SourcePath.Add(''src/base'');' + LineEnding +
      '    P.SourcePath.Add(''src/webdata'');' + LineEnding +
      '    T:=P.Targets.AddUnit(''fpjwt.pp'');' + LineEnding);

    FPCBuilderApplyFCLWebJWTSourcePathHotfixCore(SourceDir);

    TextFile := TStringList.Create;
    try
      TextFile.LoadFromFile(FPMakePath);
      Check('builder skips src/jwt path when jwt tree missing',
        TextFile.IndexOf('    P.SourcePath.Add(''src/jwt'');') < 0,
        TextFile.Text);
      Check('builder keeps original fpjwt target when jwt tree missing',
        TextFile.IndexOf('    T:=P.Targets.AddUnit(''fpjwt.pp'');') >= 0,
        TextFile.Text);
    finally
      TextFile.Free;
    end;
  finally
    CleanupTempDir(SourceDir);
  end;
end;

begin
  TestBuilderDropsGeneratedCompilerMessageIncludes;
  TestBuilderAppliesFCLWebJWTSourcePathHotfix;
  TestBuilderAddsMissingJWTSourcePathWhenJWTTreeExists;
  TestBuilderMirrorsJWTUnitIntoBaseWhenJWTTreeExists;
  TestBuilderSkipsJWTSourceHotfixWhenJWTTreeMissing;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
