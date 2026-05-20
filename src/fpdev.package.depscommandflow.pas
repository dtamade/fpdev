unit fpdev.package.depscommandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

type
  TPackageDepsCommandPlan = record
    PackageName: string;
    ShowFlat: Boolean;
    MaxDepth: Integer;
  end;

  TPackageDepsProvider = function(const APackageName: string): TStringArray of object;
  TProjectDepsReader = function: TStringArray of object;

function PreparePackageDepsCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageDepsCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageDepsCommandPlanCore(
  const APlan: TPackageDepsCommandPlan;
  const AOut, AErr: IOutput;
  AGetDeps: TPackageDepsProvider;
  AGetProjectDeps: TProjectDepsReader
): Integer;

implementation

uses
  Classes,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteDepsUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
end;

procedure WriteDepsHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPTIONS));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_TREE));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_FLAT));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_DEPTH));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_OPT_HELP));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLES));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_CURRENT));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_PACKAGE));
  AOut.WriteLn(_(HELP_PACKAGE_DEPS_EXAMPLE_FLAT));
end;

procedure PrintDepTree(const AOut: IOutput; AGetDeps: TPackageDepsProvider;
  const APackageName, APrefix: string; ADepth, AMaxDepth: Integer;
  AVisited: TStringList);
var
  Deps: TStringArray;
  I: Integer;
  IsLast: Boolean;
  Connector, ChildPrefix, DepName: string;
  SpacePos: SizeInt;
begin
  if (AOut = nil) or (not Assigned(AGetDeps)) then Exit;
  if (AMaxDepth > 0) and (ADepth > AMaxDepth) then Exit;

  Deps := AGetDeps(APackageName);
  for I := 0 to High(Deps) do
  begin
    IsLast := (I = High(Deps));
    if IsLast then begin Connector := '`-- '; ChildPrefix := '    '; end
    else begin Connector := '+-- '; ChildPrefix := '|   '; end;

    AOut.WriteLn(APrefix + Connector + Deps[I]);

    SpacePos := Pos(' ', Deps[I]);
    if SpacePos > 0 then
      DepName := Copy(Deps[I], 1, SpacePos - 1)
    else
      DepName := Deps[I];

    if AVisited.IndexOf(DepName) < 0 then
    begin
      AVisited.Add(DepName);
      PrintDepTree(AOut, AGetDeps, DepName, APrefix + ChildPrefix,
        ADepth + 1, AMaxDepth, AVisited);
    end;
  end;
end;

function PreparePackageDepsCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageDepsCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  MaxDepthStr: string;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageDepsCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteDepsHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, ['--tree', '--flat', '--depth='], UnknownOption) then
  begin
    AShouldExit := True;
    WriteDepsUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.ShowFlat := HasFlag(AParams, 'flat');
  APlan.MaxDepth := 0;
  if GetFlagValue(AParams, 'depth', MaxDepthStr) then
  begin
    if (not TryStrToInt(MaxDepthStr, APlan.MaxDepth)) or (APlan.MaxDepth < 0) then
    begin
      AShouldExit := True;
      WriteDepsUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteDepsUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.PackageName := GetPositionalArg(AParams, 0);
end;

function ExecutePackageDepsCommandPlanCore(
  const APlan: TPackageDepsCommandPlan;
  const AOut, AErr: IOutput;
  AGetDeps: TPackageDepsProvider;
  AGetProjectDeps: TProjectDepsReader
): Integer;
var
  LPackageName: string;
  LDeps: TStringArray;
  I: Integer;
  Visited: TStringList;
begin
  if AErr <> nil then;
  Result := EXIT_OK;

  LPackageName := Trim(APlan.PackageName);
  if LPackageName = '' then
    LPackageName := _(CMD_PKG_DEPS_CURRENT_PROJECT);

  if AOut <> nil then
  begin
    AOut.WriteLn(_Fmt(CMD_PKG_DEPS_HEADER, [LPackageName]));
    AOut.WriteLn('');
  end;

  LDeps := nil;
  if APlan.PackageName = '' then
  begin
    if Assigned(AGetProjectDeps) then
      LDeps := AGetProjectDeps();
  end
  else
  begin
    if Assigned(AGetDeps) then
      LDeps := AGetDeps(APlan.PackageName);
  end;

  if Length(LDeps) = 0 then
  begin
    if AOut <> nil then
      AOut.WriteLn('  (none)');
  end
  else if APlan.ShowFlat then
  begin
    if AOut <> nil then
      for I := 0 to High(LDeps) do
        AOut.WriteLn('  ' + LDeps[I]);
  end
  else
  begin
    if AOut <> nil then
    begin
      Visited := TStringList.Create;
      try
        Visited.CaseSensitive := False;
        Visited.Add(LPackageName);
        AOut.WriteLn(LPackageName);
        if APlan.PackageName = '' then
        begin
          for I := 0 to High(LDeps) do
          begin
            if I = High(LDeps) then
              AOut.WriteLn('`-- ' + LDeps[I])
            else
              AOut.WriteLn('+-- ' + LDeps[I]);
            if Visited.IndexOf(LDeps[I]) < 0 then
            begin
              Visited.Add(LDeps[I]);
              if I = High(LDeps) then
                PrintDepTree(AOut, AGetDeps, LDeps[I], '    ', 2, APlan.MaxDepth, Visited)
              else
                PrintDepTree(AOut, AGetDeps, LDeps[I], '|   ', 2, APlan.MaxDepth, Visited);
            end;
          end;
        end
        else
          PrintDepTree(AOut, AGetDeps, APlan.PackageName, '', 1, APlan.MaxDepth, Visited);
      finally
        Visited.Free;
      end;
    end;
  end;

  if AOut <> nil then
  begin
    AOut.WriteLn('');
    AOut.WriteLn(_Fmt(CMD_PKG_DEPS_TOTAL, [Length(LDeps)]));
  end;
end;

end.
