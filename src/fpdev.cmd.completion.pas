unit fpdev.cmd.completion;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry;

type
  TCompletionCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.command.utils;

function TCompletionCommand.Name: string; begin Result := 'completion'; end;
function TCompletionCommand.Aliases: TStringArray; begin Result := nil; end;
function TCompletionCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function CompletionFactory: ICommand;
begin
  Result := TCompletionCommand.Create;
end;

procedure WriteBashCompletion(const Ctx: IContext);
begin
  if Ctx.Out = nil then Exit;
  Ctx.Out.WriteLn('_fpdev_completions() {');
  Ctx.Out.WriteLn('  local cur prev words cword');
  Ctx.Out.WriteLn('  _init_completion || return');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('  local path=()');
  Ctx.Out.WriteLn('  for ((i=1; i<cword; i++)); do');
  Ctx.Out.WriteLn('    case "${words[i]}" in');
  Ctx.Out.WriteLn('      -*) ;;');
  Ctx.Out.WriteLn('      *) path+=("${words[i]}") ;;');
  Ctx.Out.WriteLn('    esac');
  Ctx.Out.WriteLn('  done');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('  local completions');
  Ctx.Out.WriteLn('  completions=$(fpdev completion --list "${path[@]}" 2>/dev/null)');
  Ctx.Out.WriteLn('  COMPREPLY=($(compgen -W "$completions" -- "$cur"))');
  Ctx.Out.WriteLn('}');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('complete -F _fpdev_completions fpdev');
end;

{ PLACEHOLDER_ZSH_FISH }

procedure WriteZshCompletion(const Ctx: IContext);
begin
  if Ctx.Out = nil then Exit;
  Ctx.Out.WriteLn('#compdef fpdev');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('_fpdev() {');
  Ctx.Out.WriteLn('  local -a path=()');
  Ctx.Out.WriteLn('  for word in "${words[@]:1:$((CURRENT-2))}"; do');
  Ctx.Out.WriteLn('    case "$word" in');
  Ctx.Out.WriteLn('      -*) ;;');
  Ctx.Out.WriteLn('      *) path+=("$word") ;;');
  Ctx.Out.WriteLn('    esac');
  Ctx.Out.WriteLn('  done');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('  local completions');
  Ctx.Out.WriteLn('  completions=(${(f)"$(fpdev completion --list "${path[@]}" 2>/dev/null)"})');
  Ctx.Out.WriteLn('  compadd -a completions');
  Ctx.Out.WriteLn('}');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('_fpdev "$@"');
end;

procedure WriteFishCompletion(const Ctx: IContext);
begin
  if Ctx.Out = nil then Exit;
  Ctx.Out.WriteLn('function __fpdev_complete');
  Ctx.Out.WriteLn('  set -l tokens (commandline -opc)');
  Ctx.Out.WriteLn('  set -l path');
  Ctx.Out.WriteLn('  for token in $tokens[2..-1]');
  Ctx.Out.WriteLn('    switch $token');
  Ctx.Out.WriteLn('      case ''-*''');
  Ctx.Out.WriteLn('      case ''*''');
  Ctx.Out.WriteLn('        set -a path $token');
  Ctx.Out.WriteLn('    end');
  Ctx.Out.WriteLn('  end');
  Ctx.Out.WriteLn('  fpdev completion --list $path 2>/dev/null');
  Ctx.Out.WriteLn('end');
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn('complete -c fpdev -f -a "(__fpdev_complete)"');
end;

procedure WriteListCompletions(const AParams: array of string; const Ctx: IContext);
var
  Path: array of string;
  Children: TStringArray;
  I, PathLen: Integer;
begin
  if Ctx.Out = nil then Exit;

  PathLen := 0;
  SetLength(Path, Length(AParams));
  for I := 0 to High(AParams) do
  begin
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      Path[PathLen] := AParams[I];
      Inc(PathLen);
    end;
  end;
  SetLength(Path, PathLen);

  Children := GlobalCommandRegistry.ListChildren(Path);
  for I := 0 to High(Children) do
    Ctx.Out.WriteLn(Children[I]);
end;

function TCompletionCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Shell: string;
  Rest: array of string;
  I, RestLen: Integer;
begin
  Result := 0;

  if HasFlag(AParams, 'list') then
  begin
    SetLength(Rest, Length(AParams));
    RestLen := 0;
    for I := 0 to High(AParams) do
    begin
      if (AParams[I] <> '--list') then
      begin
        Rest[RestLen] := AParams[I];
        Inc(RestLen);
      end;
    end;
    SetLength(Rest, RestLen);
    WriteListCompletions(Rest, Ctx);
    Exit(0);
  end;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Ctx.Out <> nil then
    begin
      Ctx.Out.WriteLn('Usage: fpdev completion <shell>');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Generate shell completion script.');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Supported shells: bash, zsh, fish');
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('Examples:');
      Ctx.Out.WriteLn('  eval "$(fpdev completion bash)"');
      Ctx.Out.WriteLn('  fpdev completion zsh > ~/.zfunc/_fpdev');
      Ctx.Out.WriteLn('  fpdev completion fish > ~/.config/fish/completions/fpdev.fish');
    end;
    Exit(0);
  end;

  Shell := '';
  if Length(AParams) > 0 then
    Shell := LowerCase(AParams[0]);

  if Shell = 'bash' then
    WriteBashCompletion(Ctx)
  else if Shell = 'zsh' then
    WriteZshCompletion(Ctx)
  else if Shell = 'fish' then
    WriteFishCompletion(Ctx)
  else
  begin
    if Ctx.Err <> nil then
    begin
      Ctx.Err.WriteLn('Usage: fpdev completion <bash|zsh|fish>');
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Generate shell completion script for the specified shell.');
    end;
    Exit(1);
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['completion'], @CompletionFactory, []);

end.