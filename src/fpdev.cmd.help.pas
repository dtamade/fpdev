unit fpdev.cmd.help;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.help

Help


## Declaration

Please retain the copyright notice of this project when forwarding or using it in your own projects. Thank you.

fafafaStudio
Email:dtamade@gmail.com
QQ Group:685403987  QQ:179033731

}

{$mode objfpc}{$H+}

interface

uses
  sysutils,
  fpdev.terminal,
  fpdev.command.registry,
  fpdev.command.intf;

procedure ListChildrenDynamic(const PathParts: array of string);
function PrintUsage(const Parts: array of string): Boolean;
procedure execute(const aParams: array of string);

implementation

procedure ListChildrenDynamic(const PathParts: array of string);
var
  children: TStringArray;
  i: Integer;
begin
  children := GlobalCommandRegistry.ListChildren(PathParts);
  if Length(children) = 0 then
  begin
    WriteLn('No command found or no subcommands available.');
    Exit;
  end;
  WriteLn('Available subcommands:');
  for i := 0 to High(children) do
    WriteLn('  ', children[i]);
end;

function PrintUsage(const Parts: array of string): Boolean;
var
  cmd, sub, sub2: string;
begin
  Result := False;
  if Length(Parts)=0 then Exit(False);
  cmd := LowerCase(Parts[0]);
  if Length(Parts) > 1 then sub := LowerCase(Parts[1]) else sub := '';
  if Length(Parts) > 2 then sub2 := LowerCase(Parts[2]) else sub2 := '';

  if cmd = 'help' then
  begin
    WriteLn('Usage: fpdev help [command [subcommand]]');
    WriteLn('Examples:');
    WriteLn('  fpdev help fpc');
    WriteLn('  fpdev help lazarus');
    Exit(True);
  end
  else if cmd = 'version' then
  begin
    WriteLn('Usage: fpdev version');
    Exit(True);
  end
  else if cmd = 'fpc' then
  begin
    if (sub = 'install') then
    begin
      WriteLn('Usage: fpdev fpc install <version> [--from-source] [--jobs=<n>] [--prefix=<dir>]');
      WriteLn('Example: fpdev fpc install 3.2.2 --from-source --jobs=4 --prefix=C:/toolchains/fpc-3.2.2');
      Exit(True);
    end
    else if (sub = 'list') then
    begin
      WriteLn('Usage: fpdev fpc list [--all]');
      Exit(True);
    end
    else if (sub = 'use') or (sub = 'default') then
    begin
      WriteLn('Usage: fpdev fpc use <version>   (alias: default)');
      Exit(True);
    end
    else if (sub = 'current') then
    begin
      WriteLn('Usage: fpdev fpc current');
      Exit(True);
    end
    else if (sub = 'show') then
    begin
      WriteLn('Usage: fpdev fpc show <version>');
      Exit(True);
    end
    else if (sub = 'doctor') or (sub = 'update') then
    begin
      WriteLn('Usage: fpdev fpc ', sub);
      Exit(True);
    end
    else
    begin
      WriteLn('Common FPC management subcommands: install, list, use(default), current, show, doctor, update');
      WriteLn('Examples:');
      WriteLn('  fpdev fpc install 3.2.2 --from-source');
      WriteLn('  fpdev fpc use 3.2.2');
      Exit(True);
    end;
  end
  else if cmd = 'lazarus' then
  begin
    if (sub = 'install') then
    begin
      WriteLn('Usage: fpdev lazarus install <version> [--from-source]');
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'current') then
    begin
      WriteLn('Usage: fpdev lazarus ', sub);
      Exit(True);
    end
    else if (sub = 'use') or (sub = 'default') then
    begin
      WriteLn('Usage: fpdev lazarus use <version>   (alias: default)');
      Exit(True);
    end
    else if (sub = 'run') then
    begin
      WriteLn('Usage: fpdev lazarus run');
      Exit(True);
    end
    else
    begin
      WriteLn('Common Lazarus management subcommands: install, list, use(default), current, run');
      WriteLn('Examples:');
      WriteLn('  fpdev lazarus install 3.0 --from-source');
      WriteLn('  fpdev lazarus use 3.0');
      Exit(True);
    end;
  end
  else if cmd = 'project' then
  begin
    if (sub = 'new') then
    begin
      WriteLn('Usage: fpdev project new <template> <name>');
      WriteLn('Example: fpdev project new console hello-world');
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'build') or (sub = 'clean') then
    begin
      WriteLn('Usage: fpdev project ', sub);
      Exit(True);
    end
    else
    begin
      WriteLn('Common project management subcommands: new, list, build, clean');
      WriteLn('Example: fpdev project new gui myapp');
      Exit(True);
    end;
  end
  else if cmd = 'package' then
  begin
    if (sub = 'install') then
    begin
      WriteLn('Usage: fpdev package install <package>');
      Exit(True);
    end
    else if (sub = 'list') then
    begin
      WriteLn('Usage: fpdev package list [--all]');
      Exit(True);
    end
    else if (sub = 'search') then
    begin
      WriteLn('Usage: fpdev package search <keyword>');
      WriteLn('Example: fpdev package search json');
      Exit(True);
    end
    else if (sub = 'repo') then
    begin
      if (sub2 = 'add') then
      begin
        WriteLn('Usage: fpdev package repo add <name> <url>');
        WriteLn('Example: fpdev package repo add custom https://example.com/repo');
        Exit(True);
      end
      else if (sub2 = 'remove') or (sub2 = 'rm') or (sub2 = 'del') then
      begin
        WriteLn('Usage: fpdev package repo remove <name>   (alias: rm, del)');
        Exit(True);
      end
      else if (sub2 = 'list') or (sub2 = 'ls') then
      begin
        WriteLn('Usage: fpdev package repo list   (alias: ls)');
        Exit(True);
      end
      else
      begin
        WriteLn('Usage:');
        WriteLn('  fpdev package repo add <name> <url>');
        WriteLn('  fpdev package repo remove <name>   (alias: rm, del)');
        WriteLn('  fpdev package repo list           (alias: ls)');
        Exit(True);
      end;
    end
    else
    begin
      WriteLn('Common package management subcommands: install, list, search, repo');
      Exit(True);
    end;
  end
  else if cmd = 'cross' then
  begin
    if (sub = 'list') then
    begin
      WriteLn('Usage: fpdev cross list [--all]');
      Exit(True);
    end
    else if (sub = 'install') then
    begin
      WriteLn('Usage: fpdev cross install <target>');
      WriteLn('Example: fpdev cross install win64');
      Exit(True);
    end
    else if (sub = 'configure') then
    begin
      WriteLn('Usage: fpdev cross configure <target> --binutils=<path> --libraries=<path>');
      Exit(True);
    end
    else
    begin
      WriteLn('Common cross-compilation subcommands: list, install, configure');
      Exit(True);
    end;
  end
  else if cmd = 'repo' then
  begin
    if (sub = 'add') then
    begin
      WriteLn('Usage: fpdev repo add <name> <index_url_or_path>');
      Exit(True);
    end
    else if (sub = 'remove') or (sub = 'rm') or (sub = 'del') then
    begin
      WriteLn('Usage: fpdev repo remove <name>   (alias: rm, del)');
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'ls') then
    begin
      WriteLn('Usage: fpdev repo list   (alias: ls)');
      Exit(True);
    end
    else if (sub = 'show') then
    begin
      WriteLn('Usage: fpdev repo show <name>');
      Exit(True);
    end
    else if (sub = 'versions') then
    begin
      WriteLn('Usage: fpdev repo versions fpc [--repo=<name|url|path>] [--os=<os>] [--arch=<arch>] [--limit=N] [--json]');
      Exit(True);
    end
    else if (sub = 'default') then
    begin
      WriteLn('Usage: fpdev repo default <name>   # Switch default repository mirror');
      Exit(True);
    end
    else
    begin
      WriteLn('Repository management subcommands: add, remove(rm,del), list(ls), show, versions, default');
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure execute(const aParams: array of string);
var
  LParamCount: Integer;
begin
  LParamCount := Length(aParams);

  if LParamCount > 0 then
  begin
    // Print usage/examples for common commands first
    if PrintUsage(aParams) then Exit;
    // Otherwise list subcommands
    ListChildrenDynamic(aParams);
    Exit;
  end;

  WriteLn('FPDev - Free Pascal Development Tool');
  WriteLn('');
  WriteLn('Usage: fpdev [command] [options]');
  WriteLn('');
  ListChildrenDynamic([]);
  WriteLn('');
  WriteLn('Maintenance switches:');
  WriteLn('  --check-toolchain');
  WriteLn('  --check-policy <src>');
  WriteLn('  --fetch-tool <name> <ver> <os> <arch> --manifest <path> [--dest <zip>]');
  WriteLn('  --extract-zip <zip> <dest>');
  WriteLn('  --ensure-source <name> <ver> --local <dir|zip> [--sha256 <hex>] [--strict]');
  WriteLn('  --import-bundle <dir|zip>');
end;

end.