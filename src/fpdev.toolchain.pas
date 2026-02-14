unit fpdev.toolchain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, fpdev.utils, fpdev.utils.process;

type
  TStringDynArray = array of string;

  TToolStatus = record
    Name: string;
    Found: boolean;
    Version: string;
    Path: string;
    Notes: string;
  end;

  TToolStatusArray = array of TToolStatus;

  TToolchainReport = record
    HostOS: string;
    HostCPU: string;
    PathHead: TStringDynArray;
    Tools: TToolStatusArray;
    Issues: TStringDynArray;
    Level: string; // OK|WARN|FAIL
  end;

// 构建一个最小体检报告（HostReady 场景）：fpc/make/lazbuild/git/openssl
function BuildToolchainReportJSON: string;
// 获取当前 fpc 版本（fpc -iV），成功返回 True 并填充版本号
function GetFPCVersion(out AFPCVersion: string): boolean;
// 校验 FPC 版本是否满足给定源码版本（如 'main','3.2.2','3.2.'）的策略
// 返回值：True 表示 >= min（可继续）；AStatus=OK|WARN|FAIL；
//  - OK  : >= rec
//  - WARN: >= min 且 < rec
//  - FAIL: < min 或 fpc 缺失
function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;

implementation

var
  GPolicyLoaded: Boolean = False;
  GPolicyFPC: TStringList = nil; // key -> min\x1Frec

function EnsurePolicyStore: TStringList;
begin
  if GPolicyFPC = nil then
  begin
    GPolicyFPC := TStringList.Create;
    GPolicyFPC.Sorted := False;
    GPolicyFPC.CaseSensitive := False;
    GPolicyFPC.Duplicates := dupIgnore;
  end;
  Result := GPolicyFPC;
end;

function LoadPolicyFromFile(const Path: string): boolean;
var
  SL: TStringList;
  Root: TJSONData;
  Obj: TJSONObject;
  FpcObj: TJSONObject; // map of key->object
  Tmp: TJSONData;
  i: Integer;
  Key: String;
  Item: TJSONObject;
  MinV, RecV: String;
begin
  Result := False;
  if (Path='') or (not FileExists(Path)) then Exit(False);
  // Simplified: tolerate any failures and avoid strict fpjson API dependence
  Result := False;
  if (Path='') or (not FileExists(Path)) then Exit(False);
  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path);
    try
      Root := GetJSON(SL.Text);
    except
      Exit(False);
    end;
    try
      if Root.JSONType <> jtObject then Exit(False);
      Obj := TJSONObject(Root);
      if Obj.Find('fpc', FpcObj) then
      begin
        EnsurePolicyStore;
        for i := 0 to FpcObj.Count-1 do
        begin
          Key := FpcObj.Names[i];
          if FpcObj.Find(Key, Tmp) and (Assigned(Tmp)) and (Tmp.JSONType = jtObject) then
          begin
            Item := TJSONObject(Tmp);
            MinV := Item.Get('min','');
            RecV := Item.Get('rec','');
            if (MinV<>'') and (RecV<>'') then
              EnsurePolicyStore.Values[Key] := MinV + #31 + RecV;
          end;
        end;
        GPolicyLoaded := True;
        Result := True;
      end;
    finally
      Root.Free;
    end;
  finally
    SL.Free;
  end;
end;

function LoadPolicyAuto: boolean;
var P: string;
begin
  Result := False;
  // 环境变量优先
  P := GetEnvironmentVariable('FPDEV_POLICY_FILE');
  if (P<>'') and LoadPolicyFromFile(P) then Exit(True);
  // 常见位置
  if LoadPolicyFromFile('src'+PathDelim+'fpdev.toolchain.policy.json') then Exit(True);
  if LoadPolicyFromFile('plays'+PathDelim+'fpdev.toolchain.policy.json') then Exit(True);
  if LoadPolicyFromFile('fpdev.toolchain.policy.json') then Exit(True);
end;

function GetExternalPolicy(const ASource: string; out AMin, ARec, AMatchedKey: string): boolean;
var i: Integer; Key, S: string; Val: string; BestLen: Integer; VSep: SizeInt;
begin
  Result := False; AMin := ''; ARec := ''; AMatchedKey := '';
  if not GPolicyLoaded then Exit(False);
  if (GPolicyFPC=nil) or (GPolicyFPC.Count=0) then Exit(False);
  S := LowerCase(Trim(ASource));
  BestLen := -1;
  for i := 0 to GPolicyFPC.Count-1 do
  begin
    Key := LowerCase(Trim(GPolicyFPC.Names[i]));
    if (Key='') then Continue;
    if (Key=S) or ((Copy(Key,Length(Key),1)='.') and (Pos(Key, S)=1)) or
       ((Key='trunk') and ((S='trunk') or (S='main'))) or
       ((Key='main') and ((S='trunk') or (S='main'))) then
    begin
      if Length(Key) > BestLen then
      begin
        BestLen := Length(Key);
        Val := GPolicyFPC.ValueFromIndex[i];
        AMatchedKey := Key;
      end;
    end;
  end;
  if BestLen >= 0 then
  begin
    VSep := Pos(#31, Val);
    if VSep>0 then
    begin
      AMin := Copy(Val,1,VSep-1);
      ARec := Copy(Val,VSep+1,Length(Val));
      Result := (AMin<>'') and (ARec<>'');
    end;
  end;
end;

function SplitPathHead(const APath: string; AMax: Integer): TStringDynArray;
var
  L: TStringList;
  i, N: Integer;
begin
  Result := nil;
  L := TStringList.Create;
  try
    {$IFDEF MSWINDOWS}
    L.Delimiter := ';';
    {$ELSE}
    L.Delimiter := ':';
    {$ENDIF}
    L.StrictDelimiter := True;
    L.DelimitedText := APath;
    N := L.Count; if (AMax>0) and (N>AMax) then N := AMax;
    SetLength(Result, N);
    for i := 0 to N-1 do Result[i] := L[i];
  finally
    L.Free;
  end;
end;

function RunAndCaptureFirstLine(const ACmd: string; const AArgs: array of string; out ALine: string): boolean;
var
  LResult: TProcessResult;
  LPos: SizeInt;
begin
  ALine := '';
  LResult := TProcessExecutor.Execute(ACmd, AArgs, '');
  if LResult.Success and (LResult.StdOut <> '') then
  begin
    // Get first line only
    LPos := Pos(LineEnding, LResult.StdOut);
    if LPos > 0 then
      ALine := Trim(Copy(LResult.StdOut, 1, LPos - 1))
    else
      ALine := Trim(LResult.StdOut);
  end;
  Result := LResult.Success;
end;

function ResolvePathOf(const ACmd: string): string;
begin
  Result := TProcessExecutor.FindExecutable(ACmd);
end;

procedure AddTool(var AArr: TToolStatusArray; const ATool: TToolStatus);
var
  N: Integer;
begin
  N := Length(AArr);
  SetLength(AArr, N+1);
  AArr[N] := ATool;
end;

procedure AddIssue(var AArr: TStringDynArray; const AItem: string);
var N: Integer;
begin
  N := Length(AArr); SetLength(AArr, N+1); AArr[N] := AItem;
end;

function ProbeOne(const AName: string; const AArgs: array of string): TToolStatus;
var
  LLine: string;
begin
  Result.Name := AName;
  Result.Found := RunAndCaptureFirstLine(AName, AArgs, LLine);
  if Result.Found then
  begin
    Result.Version := LLine;
    Result.Path := ResolvePathOf(AName);
  end
  else
  begin
    Result.Version := '';
    Result.Path := '';
  end;
end;

function ProbeFirstAvailable(
  const ANames: array of string;
  const AArgs: array of string;
  out Chosen: string
): TToolStatus;
var i: Integer;
begin
  for i := Low(ANames) to High(ANames) do
  begin
    Result := ProbeOne(ANames[i], AArgs);
    if Result.Found then begin Chosen := ANames[i]; Exit; end;
  end;
  Chosen := '';
end;

function ReportToJSON(const R: TToolchainReport): string;
var
  i,j: Integer;
  Builder: TStringBuilder;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.Append('{');
    Builder.Append('"hostOS":"' + JsonEscape(R.HostOS) + '",');
    Builder.Append('"hostCPU":"' + JsonEscape(R.HostCPU) + '",');
    Builder.Append('"pathHead":[');
    for i := 0 to High(R.PathHead) do
    begin
      if i>0 then Builder.Append(',');
      Builder.Append('"' + JsonEscape(R.PathHead[i]) + '"');
    end;
    Builder.Append('],"tools":[');
    for i := 0 to High(R.Tools) do
    begin
      if i>0 then Builder.Append(',');
      Builder.Append('{"name":"'+JsonEscape(R.Tools[i].Name)+'",'+
                '"found":'+LowerCase(BoolToStr(R.Tools[i].Found, True))+','+
                '"version":"'+JsonEscape(R.Tools[i].Version)+'",'+
                '"path":"'+JsonEscape(R.Tools[i].Path)+'",'+
                '"notes":"'+JsonEscape(R.Tools[i].Notes)+'"}');
    end;
    Builder.Append('],"issues":[');
    for j := 0 to High(R.Issues) do
    begin
      if j>0 then Builder.Append(',');
      Builder.Append('"'+JsonEscape(R.Issues[j])+'"');
    end;
    Builder.Append('],"level":"'+JsonEscape(R.Level)+'"}');
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function GetFPCVersion(out AFPCVersion: string): boolean;
var LLine: string;
begin
  AFPCVersion := '';
  Result := RunAndCaptureFirstLine('fpc', ['-iV'], LLine);
  if Result then AFPCVersion := Trim(LLine);
end;

function NormalizeVersion(const S: string): string;
var i: Integer; ch: Char;
begin
  // 仅保留 0-9 和点号，去除尾随标签
  Result := '';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    if (ch in ['0'..'9','.']) then Result += ch
    else break;
  end;
end;

function CmpVersion(const A, B: string): Integer;
// 返回 -1/0/1：A<B / A=B / A>B
var
  SA, SB: TStringList;
  i, na, nb, va, vb: Integer;
  pa, pb: string;
begin
  SA := TStringList.Create; SB := TStringList.Create;
  try
    SA.Delimiter := '.'; SA.StrictDelimiter := True; SA.DelimitedText := NormalizeVersion(A);
    SB.Delimiter := '.'; SB.StrictDelimiter := True; SB.DelimitedText := NormalizeVersion(B);
    na := SA.Count; nb := SB.Count;
    if na<nb then na := nb; // 对齐长度
    for i := 0 to na-1 do
    begin
      if i < SA.Count then pa := SA[i] else pa := '0';
      if i < SB.Count then pb := SB[i] else pb := '0';
      va := StrToIntDef(pa,0); vb := StrToIntDef(pb,0);
      if va < vb then begin Result := -1; Exit; end
      else if va > vb then begin Result := 1; Exit; end;
    end;
    Result := 0;
  finally
    SA.Free; SB.Free;
  end;
end;

procedure GetPolicyForSource(const ASource: string; out AMin, ARec: string);
var S, MatchedKey: string;
begin
  S := LowerCase(Trim(ASource));
  // 先尝试外部策略（若有加载）
  if GetExternalPolicy(S, AMin, ARec, MatchedKey) then Exit;
  // 内置保守策略
  if (S='trunk') or (S='main') or (Pos('3.3.', S)=1) then
  begin AMin:='3.2.2'; ARec:='3.2.2'; Exit; end;
  if (S='3.2.2') then begin AMin:='3.0.4'; ARec:='3.2.0'; Exit; end;
  if (Pos('3.2.', S)=1) then begin AMin:='3.0.4'; ARec:='3.2.2'; Exit; end;
  if (Pos('3.0.', S)=1) then begin AMin:='2.6.4'; ARec:='3.0.4'; Exit; end;
  AMin := '3.2.2'; ARec := '3.2.2';
end;

function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;
var cmpMin, cmpRec: Integer;
begin
  // 尝试自动加载外部策略（只加载一次）
  if not GPolicyLoaded then LoadPolicyAuto;
  GetPolicyForSource(ASourceVersion, AMin, ARec);
  if not GetFPCVersion(AFPCVersion) then
  begin
    AStatus := 'FAIL';
    AReason := 'fpc not found';
    Exit(False);
  end;
  cmpMin := CmpVersion(AFPCVersion, AMin);
  cmpRec := CmpVersion(AFPCVersion, ARec);
  if cmpMin < 0 then begin AStatus := 'FAIL'; AReason := 'fpc < min'; Exit(False); end
  else if cmpRec < 0 then begin AStatus := 'WARN'; AReason := 'fpc < recommended'; Result := True; Exit; end
  else begin AStatus := 'OK'; AReason := 'fpc >= recommended'; Result := True; Exit; end;
end;

function BuildToolchainReportJSON: string;
var
  R: TToolchainReport;
  T: TToolStatus;
  Chosen: string;
  PathStr: string;
begin
  {$IFDEF MSWINDOWS}
  R.HostOS := 'Windows';
  {$ELSE}
  R.HostOS := 'Unix-like';
  {$ENDIF}
  {$if defined(CPUX86_64)} R.HostCPU := 'x86_64'
  {$elseif defined(CPUX86)} R.HostCPU := 'i386'
  {$elseif defined(CPUAARCH64)} R.HostCPU := 'aarch64'
  {$elseif defined(CPUARM)} R.HostCPU := 'arm'
  {$else} R.HostCPU := 'unknown' {$endif};

  PathStr := GetEnvironmentVariable('PATH');
  R.PathHead := SplitPathHead(PathStr, 5);

  // fpc
  T := ProbeOne('fpc', ['-iV']); if not T.Found then AddIssue(R.Issues, 'missing fpc');
  AddTool(R.Tools, T);

  // make family
  {$IFDEF MSWINDOWS}
  T := ProbeFirstAvailable(['mingw32-make','make','gmake'], ['--version'], Chosen);
  {$ELSE}
  T := ProbeFirstAvailable(['gmake','make'], ['--version'], Chosen);
  {$ENDIF}
  if not T.Found then AddIssue(R.Issues, 'missing make-family');
  AddTool(R.Tools, T);

  // lazbuild（建议）
  T := ProbeOne('lazbuild', ['--version']);
  if not T.Found then T.Notes := 'optional';
  AddTool(R.Tools, T);

  // git（建议）
  T := ProbeOne('git', ['--version']); if not T.Found then T.Notes := 'optional';
  AddTool(R.Tools, T);

  // openssl（建议）
  T := ProbeOne('openssl', ['version']); if not T.Found then T.Notes := 'optional for HTTPS';
  AddTool(R.Tools, T);

  if Length(R.Issues)=0 then R.Level := 'OK'
  else if (Length(R.Issues)>0) and (Pos('missing fpc', LowerCase(Trim(R.Issues[0])))=0) then R.Level := 'WARN'
  else R.Level := 'FAIL';

  Result := ReportToJSON(R);
end;

end.
