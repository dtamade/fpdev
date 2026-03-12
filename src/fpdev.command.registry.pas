unit fpdev.command.registry;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.command.intf, fpdev.command.tree;

type
  TCommandFactory = fpdev.command.tree.TCommandFactory;

type
  { TCommandRegistry }
  TCommandRegistry = class
  private
    FRoot: TCommandNode;    // path-based root
  public
    constructor Create;
    destructor Destroy; override;
    // Path-based API
    procedure RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
    procedure RegisterSingletonPath(
      const APath: array of string;
      const ACommand: ICommand;
      const Aliases: array of string
    );
    function DispatchPath(const AArgs: array of string; const Ctx: IContext): Integer;
    // List subcommand names under specified path; empty path means root
    function ListChildren(const APath: array of string): TStringArray;
  end;

function GlobalCommandRegistry: TCommandRegistry;

implementation

uses
  fpdev.command.diagnostics,
  fpdev.command.helprouting,
  fpdev.command.lookup,
  fpdev.command.registration,
  fpdev.command.suggestions,
  fpdev.exitcodes;

var
  GRegistry: TCommandRegistry = nil;

{ TCommandRegistry }

constructor TCommandRegistry.Create;
begin
  inherited Create;
  FRoot := TCommandNode.Create('');
end;

destructor TCommandRegistry.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;

procedure TCommandRegistry.RegisterPath(
  const APath: array of string;
  AFactory: TCommandFactory;
  const Aliases: array of string
);
begin
  RegisterCommandPathCore(FRoot, APath, AFactory, Aliases);
end;

procedure TCommandRegistry.RegisterSingletonPath(
  const APath: array of string;
  const ACommand: ICommand;
  const Aliases: array of string
);
begin
  RegisterSingletonCommandPathCore(FRoot, APath, ACommand, Aliases);
end;

function TCommandRegistry.DispatchPath(const AArgs: array of string; const Ctx: IContext): Integer;
var
  Index: Integer;
  ExecIndex: Integer;
  LastNode, MatchedNode, EffNode, ParentNode: TCommandNode;
  Rest: TStringArray;
  Cmd: ICommand;
  j: Integer;
  SubCmds: TStringArray;
  Suggestion, UnknownCmd: string;
  LArgs: TStringArray;
  Match: TCommandDispatchLookup;
begin
  Result := EXIT_OK;
  Rest := nil;
  LArgs := nil;

  SetLength(LArgs, Length(AArgs));
  for Index := 0 to High(AArgs) do
    LArgs[Index] := AArgs[Index];
  LArgs := RewriteTrailingHelpFlag(LArgs, FRoot);

  Match := Default(TCommandDispatchLookup);
  MatchExecutablePrefixCore(FRoot, LArgs, Match);
  LastNode := Match.LastNode;
  MatchedNode := Match.MatchedNode;
  ParentNode := Match.ParentNode;
  ExecIndex := Match.ExecIndex;
  UnknownCmd := Match.UnknownCmd;

  if (LastNode <> nil) then
  begin
    if Assigned(LastNode.Command) then
      Cmd := LastNode.Command
    else
      Cmd := LastNode.Factory();
    SetLength(Rest, Length(LArgs) - ExecIndex);
    for j := 0 to High(Rest) do
      Rest[j] := LArgs[ExecIndex + j];
    Result := Cmd.Execute(Rest, Ctx);
    if Result = 0 then
      Ctx.SaveIfModified;
  end
  else if (ParentNode <> nil) and (UnknownCmd <> '') then
  begin
    // Command not found - try to suggest a similar command (prioritize over showing subcommands)
    SubCmds := nil;
    SetLength(SubCmds, ParentNode.Children.Count);
    for j := 0 to ParentNode.Children.Count - 1 do
      SubCmds[j] := ParentNode.Children[j];

    Suggestion := FindSimilarCommand(UnknownCmd, SubCmds);
    if Suggestion <> '' then
      WriteUnknownCommandSuggestion(Ctx.Err, UnknownCmd, Suggestion)
    else
      WriteUnknownCommandAvailableCommands(Ctx.Err, UnknownCmd, SubCmds);
    Result := EXIT_ERROR;
  end
  else if (MatchedNode <> nil) then
  begin
    // Get effective node (may be alias target)
    EffNode := MatchedNode.GetEffectiveNode;
    if EffNode.Children.Count > 0 then
    begin
      // Node matched but has no factory - show available subcommands
      // Output to stderr since user input was incomplete (no subcommand specified)
      SubCmds := nil;
      SetLength(SubCmds, EffNode.Children.Count);
      for j := 0 to EffNode.Children.Count - 1 do
        SubCmds[j] := EffNode.Children[j];
      WriteMissingSubcommandUsage(Ctx.Err, EffNode.Name, SubCmds);
      Result := EXIT_USAGE_ERROR;
    end
    else
      Result := EXIT_ERROR;
  end
  else
  begin
    // No match found: return non-zero, let upper layer output help/error
    Result := EXIT_ERROR;
  end;
end;

function TCommandRegistry.ListChildren(const APath: array of string): TStringArray;
begin
  Result := ListChildrenAtPathCore(FRoot, APath);
end;

function GlobalCommandRegistry: TCommandRegistry;
begin
  if GRegistry = nil then
    GRegistry := TCommandRegistry.Create;
  Result := GRegistry;
end;

finalization
  GRegistry.Free;

end.
