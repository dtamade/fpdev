unit fpdev.cmd.env.hook;

{
  fpdev system env hook command

  Generate shell integration scripts for automatic version switching (similar to nvm's cd hook)

  Usage:
    fpdev system env hook bash     # Generate bash integration script
    fpdev system env hook zsh      # Generate zsh integration script
    fpdev system env hook fish     # Generate fish integration script

  Installation:
    # Bash (~/.bashrc)
    eval "$(fpdev system env hook bash)"

    # Zsh (~/.zshrc)
    eval "$(fpdev system env hook zsh)"

    # Fish (~/.config/fish/config.fish)
    fpdev system env hook fish | source
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry, fpdev.exitcodes;

type
  { TShellHookCommand - Generate shell integration scripts }
  TShellHookCommand = class(TInterfacedObject, ICommand)
  private
    function GenerateBashHook: string;
    function GenerateZshHook: string;
    function GenerateFishHook: string;
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function ShellHookCommandFactory: ICommand;

implementation

uses
  fpdev.command.utils;

const
  HELP_SHELL_HOOK = 'Usage: fpdev system env hook <shell>' + LineEnding +
                    '' + LineEnding +
                    'Generate shell integration script for automatic version switching.' + LineEnding +
                    '' + LineEnding +
                    'Supported shells:' + LineEnding +
                    '  bash    Generate Bash integration script' + LineEnding +
                    '  zsh     Generate Zsh integration script' + LineEnding +
                    '  fish    Generate Fish integration script' + LineEnding +
                    '' + LineEnding +
                    'Installation:' + LineEnding +
                    '' + LineEnding +
                    '  Bash (add to ~/.bashrc):' + LineEnding +
                    '    eval "$(fpdev system env hook bash)"' + LineEnding +
                    '' + LineEnding +
                    '  Zsh (add to ~/.zshrc):' + LineEnding +
                    '    eval "$(fpdev system env hook zsh)"' + LineEnding +
                    '' + LineEnding +
                    '  Fish (add to ~/.config/fish/config.fish):' + LineEnding +
                    '    fpdev system env hook fish | source' + LineEnding +
                    '' + LineEnding +
                    'Features:' + LineEnding +
                    '  - Automatic version switching when entering directories with .fpdevrc' + LineEnding +
                    '  - Environment variable setup (PATH, FPCDIR, etc.)' + LineEnding +
                    '  - Silent operation (no output unless version changes)';

  // Bash/Zsh hook script
  BASH_HOOK_SCRIPT =
    '# fpdev shell integration for Bash/Zsh' + LineEnding +
    '# Auto-switches FPC/Lazarus version based on .fpdevrc' + LineEnding +
    '' + LineEnding +
    '_fpdev_hook() {' + LineEnding +
    '  local fpdevrc' + LineEnding +
    '  local dir="$PWD"' + LineEnding +
    '  local found=""' + LineEnding +
    '  local depth=0' + LineEnding +
    '  local max_depth=10' + LineEnding +
    '' + LineEnding +
    '  # Search for .fpdevrc or fpdev.toml' + LineEnding +
    '  while [[ -n "$dir" && "$depth" -lt "$max_depth" ]]; do' + LineEnding +
    '    if [[ -f "$dir/.fpdevrc" ]]; then' + LineEnding +
    '      found="$dir/.fpdevrc"' + LineEnding +
    '      break' + LineEnding +
    '    elif [[ -f "$dir/fpdev.toml" ]]; then' + LineEnding +
    '      found="$dir/fpdev.toml"' + LineEnding +
    '      break' + LineEnding +
    '    fi' + LineEnding +
    '    dir="${dir%/*}"' + LineEnding +
    '    ((depth++))' + LineEnding +
    '  done' + LineEnding +
    '' + LineEnding +
    '  # Check if config changed' + LineEnding +
    '  if [[ "$found" != "$_FPDEV_CURRENT_CONFIG" ]]; then' + LineEnding +
    '    export _FPDEV_CURRENT_CONFIG="$found"' + LineEnding +
    '    if [[ -n "$found" ]]; then' + LineEnding +
    '      # Activate version from config' + LineEnding +
    '      local version' + LineEnding +
    '      version=$(fpdev system env resolve 2>/dev/null)' + LineEnding +
    '      if [[ -n "$version" && "$version" != "$_FPDEV_CURRENT_VERSION" ]]; then' + LineEnding +
    '        export _FPDEV_CURRENT_VERSION="$version"' + LineEnding +
    '        # Source activation script if exists' + LineEnding +
    '        local fpdev_root' + LineEnding +
    '        fpdev_root=$(fpdev system env data-root 2>/dev/null)' + LineEnding +
    '        local activate_script="$fpdev_root/env/activate-$version.sh"' + LineEnding +
    '        if [[ -f "$activate_script" ]]; then' + LineEnding +
    '          source "$activate_script"' + LineEnding +
    '          echo "fpdev: Switched to FPC $version (from $found)"' + LineEnding +
    '        else' + LineEnding +
    '          echo "fpdev: FPC $version not installed. Run: fpdev fpc install $version"' + LineEnding +
    '        fi' + LineEnding +
    '      fi' + LineEnding +
    '    fi' + LineEnding +
    '  fi' + LineEnding +
    '}' + LineEnding +
    '' + LineEnding +
    '# Hook into cd command' + LineEnding +
    'if [[ -n "$BASH_VERSION" ]]; then' + LineEnding +
    '  # Bash: use PROMPT_COMMAND' + LineEnding +
    '  if [[ ! "$PROMPT_COMMAND" =~ _fpdev_hook ]]; then' + LineEnding +
    '    PROMPT_COMMAND="_fpdev_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"' + LineEnding +
    '  fi' + LineEnding +
    'elif [[ -n "$ZSH_VERSION" ]]; then' + LineEnding +
    '  # Zsh: use chpwd hook' + LineEnding +
    '  autoload -U add-zsh-hook' + LineEnding +
    '  add-zsh-hook chpwd _fpdev_hook' + LineEnding +
    '  # Run once on shell start' + LineEnding +
    '  _fpdev_hook' + LineEnding +
    'fi' + LineEnding +
    '' + LineEnding +
    '# Run hook on shell start' + LineEnding +
    '_fpdev_hook';

  // Fish hook script
  FISH_HOOK_SCRIPT =
    '# fpdev shell integration for Fish' + LineEnding +
    '# Auto-switches FPC/Lazarus version based on .fpdevrc' + LineEnding +
    '' + LineEnding +
    'function _fpdev_hook --on-variable PWD --description "fpdev auto-switch"' + LineEnding +
    '  set -l dir $PWD' + LineEnding +
    '  set -l found ""' + LineEnding +
    '  set -l depth 0' + LineEnding +
    '  set -l max_depth 10' + LineEnding +
    '' + LineEnding +
    '  # Search for .fpdevrc or fpdev.toml' + LineEnding +
    '  while test -n "$dir" -a $depth -lt $max_depth' + LineEnding +
    '    if test -f "$dir/.fpdevrc"' + LineEnding +
    '      set found "$dir/.fpdevrc"' + LineEnding +
    '      break' + LineEnding +
    '    else if test -f "$dir/fpdev.toml"' + LineEnding +
    '      set found "$dir/fpdev.toml"' + LineEnding +
    '      break' + LineEnding +
    '    end' + LineEnding +
    '    set dir (dirname $dir)' + LineEnding +
    '    set depth (math $depth + 1)' + LineEnding +
    '  end' + LineEnding +
    '' + LineEnding +
    '  # Check if config changed' + LineEnding +
    '  if test "$found" != "$_FPDEV_CURRENT_CONFIG"' + LineEnding +
    '    set -gx _FPDEV_CURRENT_CONFIG "$found"' + LineEnding +
    '    if test -n "$found"' + LineEnding +
    '      # Activate version from config' + LineEnding +
    '      set -l version (fpdev system env resolve 2>/dev/null)' + LineEnding +
    '      if test -n "$version" -a "$version" != "$_FPDEV_CURRENT_VERSION"' + LineEnding +
    '        set -gx _FPDEV_CURRENT_VERSION "$version"' + LineEnding +
    '        # Source activation script if exists' + LineEnding +
    '        set -l fpdev_root (fpdev system env data-root 2>/dev/null)' + LineEnding +
    '        set -l activate_script "$fpdev_root/env/activate-$version.fish"' + LineEnding +
    '        if test -f "$activate_script"' + LineEnding +
    '          source "$activate_script"' + LineEnding +
    '          echo "fpdev: Switched to FPC $version (from $found)"' + LineEnding +
    '        else' + LineEnding +
    '          echo "fpdev: FPC $version not installed. Run: fpdev fpc install $version"' + LineEnding +
    '        end' + LineEnding +
    '      end' + LineEnding +
    '    end' + LineEnding +
    '  end' + LineEnding +
    'end' + LineEnding +
    '' + LineEnding +
    '# Run hook on shell start' + LineEnding +
    '_fpdev_hook';

function ShellHookCommandFactory: ICommand;
begin
  Result := TShellHookCommand.Create;
end;

{ TShellHookCommand }

function TShellHookCommand.Name: string;
begin
  Result := 'hook';
end;

function TShellHookCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TShellHookCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TShellHookCommand.GenerateBashHook: string;
begin
  Result := BASH_HOOK_SCRIPT;
end;

function TShellHookCommand.GenerateZshHook: string;
begin
  // Zsh uses the same script as Bash with minor differences handled internally
  Result := BASH_HOOK_SCRIPT;
end;

function TShellHookCommand.GenerateFishHook: string;
begin
  Result := FISH_HOOK_SCRIPT;
end;

function TShellHookCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LShell: string;
  I: Integer;
  LUnknownOption: string;
begin
  Result := EXIT_OK;

  // Check help flag
  for I := 0 to High(AParams) do
  begin
    if (AParams[I] = '-h') or (AParams[I] = '--help') then
    begin
      if Length(AParams) > 1 then
      begin
        Ctx.Err.WriteLn(HELP_SHELL_HOOK);
        Exit(EXIT_USAGE_ERROR);
      end;
      Ctx.Out.WriteLn(HELP_SHELL_HOOK);
      Exit(EXIT_OK);
    end;
  end;

  if FindUnknownOption(AParams, ['--help', '-h'], LUnknownOption) then
  begin
    Ctx.Err.WriteLn(HELP_SHELL_HOOK);
    Exit(EXIT_USAGE_ERROR);
  end;

  // Shell parameter required
  if Length(AParams) = 0 then
  begin
    Ctx.Err.WriteLn('Error: Missing shell type. Usage: fpdev system env hook <bash|zsh|fish>');
    Ctx.Err.WriteLn('');
    Ctx.Err.WriteLn('Run "fpdev system env hook --help" for more information.');
    Exit(EXIT_ERROR);
  end;

  if CountPositionalArgs(AParams) <> 1 then
  begin
    Ctx.Err.WriteLn(HELP_SHELL_HOOK);
    Exit(EXIT_USAGE_ERROR);
  end;

  LShell := LowerCase(AParams[0]);

  case LShell of
    'bash':
      Ctx.Out.WriteLn(GenerateBashHook);
    'zsh':
      Ctx.Out.WriteLn(GenerateZshHook);
    'fish':
      Ctx.Out.WriteLn(GenerateFishHook);
  else
    Ctx.Err.WriteLn('Error: Unknown shell "' + LShell + '". Supported: bash, zsh, fish');
    Exit(EXIT_ERROR);
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'env', 'hook'], @ShellHookCommandFactory, []);

end.
