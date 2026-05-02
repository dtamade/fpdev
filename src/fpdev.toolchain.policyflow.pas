unit fpdev.toolchain.policyflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

procedure ResetToolchainPolicyFlowCore;
function LoadToolchainPolicyFromFileCore(const APath: string): Boolean;
function LoadToolchainPolicyAutoCore: Boolean;
function GetExternalToolchainPolicyCore(
  const ASource: string;
  out AMin, ARec, AMatchedKey: string
): Boolean;
function NormalizeToolchainVersionCore(const S: string): string;
function CompareToolchainVersionCore(const A, B: string): Integer;
procedure GetToolchainPolicyForSourceCore(const ASource: string; out AMin, ARec: string);
function EvaluateToolchainFPCVersionPolicyCore(
  const ASourceVersion, AFPCVersion: string;
  out AStatus, AReason, AMin, ARec: string
): Boolean;

implementation

uses
  fpjson, jsonparser,
  fpdev.utils;

const
  TOOLCHAIN_POLICY_MAINLINE_VERSION = '3.2.2';
  TOOLCHAIN_POLICY_VERSION_320 = '3.2.0';
  TOOLCHAIN_POLICY_VERSION_304 = '3.0.4';
  TOOLCHAIN_POLICY_VERSION_264 = '2.6.4';

var
  GToolchainPolicyLoaded: Boolean = False;
  GToolchainPolicyFPC: TStringList = nil;

function EnsureToolchainPolicyStoreCore: TStringList;
begin
  if GToolchainPolicyFPC = nil then
  begin
    GToolchainPolicyFPC := TStringList.Create;
    GToolchainPolicyFPC.Sorted := False;
    GToolchainPolicyFPC.CaseSensitive := False;
    GToolchainPolicyFPC.Duplicates := dupIgnore;
  end;
  Result := GToolchainPolicyFPC;
end;

procedure ResetToolchainPolicyFlowCore;
begin
  GToolchainPolicyLoaded := False;
  if GToolchainPolicyFPC <> nil then
    FreeAndNil(GToolchainPolicyFPC);
end;

function LoadToolchainPolicyFromFileCore(const APath: string): Boolean;
var
  Lines: TStringList;
  Root: TJSONData;
  Obj: TJSONObject;
  FPCObj: TJSONObject;
  Tmp: TJSONData;
  I: Integer;
  Key: string;
  Item: TJSONObject;
  MinV: string;
  RecV: string;
begin
  Result := False;
  if (APath = '') or (not FileExists(APath)) then
    Exit(False);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(APath);
    try
      Root := GetJSON(Lines.Text);
    except
      Exit(False);
    end;
    try
      if Root.JSONType <> jtObject then
        Exit(False);

      Obj := TJSONObject(Root);
      if not Obj.Find('fpc', FPCObj) then
        Exit(False);

      EnsureToolchainPolicyStoreCore.Clear;
      for I := 0 to FPCObj.Count - 1 do
      begin
        Key := FPCObj.Names[I];
        if FPCObj.Find(Key, Tmp) and Assigned(Tmp) and (Tmp.JSONType = jtObject) then
        begin
          Item := TJSONObject(Tmp);
          MinV := Item.Get('min', '');
          RecV := Item.Get('rec', '');
          if (MinV <> '') and (RecV <> '') then
            EnsureToolchainPolicyStoreCore.Values[Key] := MinV + #31 + RecV;
        end;
      end;

      GToolchainPolicyLoaded := True;
      Result := True;
    finally
      Root.Free;
    end;
  finally
    Lines.Free;
  end;
end;

function LoadToolchainPolicyAutoCore: Boolean;
var
  PolicyPath: string;
begin
  Result := False;
  PolicyPath := get_env('FPDEV_POLICY_FILE');
  if (PolicyPath <> '') and LoadToolchainPolicyFromFileCore(PolicyPath) then
    Exit(True);

  if LoadToolchainPolicyFromFileCore('src' + PathDelim + 'fpdev.toolchain.policy.json') then
    Exit(True);
  if LoadToolchainPolicyFromFileCore('plays' + PathDelim + 'fpdev.toolchain.policy.json') then
    Exit(True);
  if LoadToolchainPolicyFromFileCore('fpdev.toolchain.policy.json') then
    Exit(True);
end;

function GetExternalToolchainPolicyCore(
  const ASource: string;
  out AMin, ARec, AMatchedKey: string
): Boolean;
var
  I: Integer;
  Key: string;
  SourceKey: string;
  PolicyValue: string;
  BestLen: Integer;
  SepPos: SizeInt;
begin
  Result := False;
  AMin := '';
  ARec := '';
  AMatchedKey := '';

  if not GToolchainPolicyLoaded then
    Exit(False);
  if (GToolchainPolicyFPC = nil) or (GToolchainPolicyFPC.Count = 0) then
    Exit(False);

  SourceKey := LowerCase(Trim(ASource));
  BestLen := -1;
  PolicyValue := '';
  for I := 0 to GToolchainPolicyFPC.Count - 1 do
  begin
    Key := LowerCase(Trim(GToolchainPolicyFPC.Names[I]));
    if Key = '' then
      Continue;

    if (Key = SourceKey) or
       ((Copy(Key, Length(Key), 1) = '.') and (Pos(Key, SourceKey) = 1)) or
       ((Key = 'trunk') and ((SourceKey = 'trunk') or (SourceKey = 'main'))) or
       ((Key = 'main') and ((SourceKey = 'trunk') or (SourceKey = 'main'))) then
    begin
      if Length(Key) > BestLen then
      begin
        BestLen := Length(Key);
        PolicyValue := GToolchainPolicyFPC.ValueFromIndex[I];
        AMatchedKey := Key;
      end;
    end;
  end;

  if BestLen < 0 then
    Exit(False);

  SepPos := Pos(#31, PolicyValue);
  if SepPos <= 0 then
    Exit(False);

  AMin := Copy(PolicyValue, 1, SepPos - 1);
  ARec := Copy(PolicyValue, SepPos + 1, Length(PolicyValue));
  Result := (AMin <> '') and (ARec <> '');
end;

function NormalizeToolchainVersionCore(const S: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    if Ch in ['0'..'9', '.'] then
      Result := Result + Ch
    else
      Break;
  end;
end;

function CompareToolchainVersionCore(const A, B: string): Integer;
var
  SA: TStringList;
  SB: TStringList;
  I: Integer;
  MaxCount: Integer;
  VA: Integer;
  VB: Integer;
  PartA: string;
  PartB: string;
begin
  SA := TStringList.Create;
  SB := TStringList.Create;
  try
    SA.Delimiter := '.';
    SA.StrictDelimiter := True;
    SA.DelimitedText := NormalizeToolchainVersionCore(A);
    SB.Delimiter := '.';
    SB.StrictDelimiter := True;
    SB.DelimitedText := NormalizeToolchainVersionCore(B);

    MaxCount := SA.Count;
    if SB.Count > MaxCount then
      MaxCount := SB.Count;

    for I := 0 to MaxCount - 1 do
    begin
      if I < SA.Count then
        PartA := SA[I]
      else
        PartA := '0';

      if I < SB.Count then
        PartB := SB[I]
      else
        PartB := '0';

      VA := StrToIntDef(PartA, 0);
      VB := StrToIntDef(PartB, 0);
      if VA < VB then
        Exit(-1);
      if VA > VB then
        Exit(1);
    end;
    Result := 0;
  finally
    SA.Free;
    SB.Free;
  end;
end;

procedure GetToolchainPolicyForSourceCore(const ASource: string; out AMin, ARec: string);
var
  SourceKey: string;
  MatchedKey: string;
begin
  SourceKey := LowerCase(Trim(ASource));
  if GetExternalToolchainPolicyCore(SourceKey, AMin, ARec, MatchedKey) then
    Exit;

  if (SourceKey = 'trunk') or (SourceKey = 'main') or (Pos('3.3.', SourceKey) = 1) then
  begin
    AMin := TOOLCHAIN_POLICY_MAINLINE_VERSION;
    ARec := TOOLCHAIN_POLICY_MAINLINE_VERSION;
    Exit;
  end;

  if SourceKey = TOOLCHAIN_POLICY_MAINLINE_VERSION then
  begin
    AMin := TOOLCHAIN_POLICY_VERSION_304;
    ARec := TOOLCHAIN_POLICY_VERSION_320;
    Exit;
  end;

  if Pos('3.2.', SourceKey) = 1 then
  begin
    AMin := TOOLCHAIN_POLICY_VERSION_304;
    ARec := TOOLCHAIN_POLICY_MAINLINE_VERSION;
    Exit;
  end;

  if Pos('3.0.', SourceKey) = 1 then
  begin
    AMin := TOOLCHAIN_POLICY_VERSION_264;
    ARec := TOOLCHAIN_POLICY_VERSION_304;
    Exit;
  end;

  AMin := TOOLCHAIN_POLICY_MAINLINE_VERSION;
  ARec := TOOLCHAIN_POLICY_MAINLINE_VERSION;
end;

function EvaluateToolchainFPCVersionPolicyCore(
  const ASourceVersion, AFPCVersion: string;
  out AStatus, AReason, AMin, ARec: string
): Boolean;
var
  CompareMin: Integer;
  CompareRec: Integer;
begin
  if not GToolchainPolicyLoaded then
    LoadToolchainPolicyAutoCore;

  GetToolchainPolicyForSourceCore(ASourceVersion, AMin, ARec);
  CompareMin := CompareToolchainVersionCore(AFPCVersion, AMin);
  CompareRec := CompareToolchainVersionCore(AFPCVersion, ARec);

  if CompareMin < 0 then
  begin
    AStatus := 'FAIL';
    AReason := 'fpc < min';
    Exit(False);
  end;

  if CompareRec < 0 then
  begin
    AStatus := 'WARN';
    AReason := 'fpc < recommended';
    Exit(True);
  end;

  AStatus := 'OK';
  AReason := 'fpc >= recommended';
  Result := True;
end;

finalization
  ResetToolchainPolicyFlowCore;

end.
