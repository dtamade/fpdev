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
  fpdev.command.registry,
  fpdev.output.intf,
  fpdev.output.console,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure ListChildrenDynamic(const PathParts: array of string);
function PrintUsage(const Parts: array of string): Boolean;
procedure execute(const aParams: array of string);

procedure ListChildrenDynamic(const PathParts: array of string; const Outp: IOutput);
function PrintUsage(const Parts: array of string; const Outp: IOutput): Boolean;
procedure execute(const aParams: array of string; const Outp: IOutput);

implementation

uses
  fpdev.command.intf,
  fpdev.config.interfaces,
  fpdev.exitcodes,
  fpdev.logger.intf;

type
  { THelpContext - Minimal context for routing "fpdev help <leaf>" to "<leaf> --help" }
  THelpContext = class(TInterfacedObject, IContext)
  private
    FOut: IOutput;
    FErr: IOutput;
  public
    constructor Create(const AOut, AErr: IOutput);
    function Config: IConfigManager;
    function Out: IOutput;
    function Err: IOutput;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

constructor THelpContext.Create(const AOut, AErr: IOutput);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
end;

function THelpContext.Config: IConfigManager;
begin
  Result := nil;
end;

function THelpContext.Out: IOutput;
begin
  Result := FOut;
end;

function THelpContext.Err: IOutput;
begin
  Result := FErr;
end;

function THelpContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure THelpContext.SaveIfModified;
begin
  // help routing must be side-effect free
end;

function TryDispatchLeafHelp(const PathParts: array of string; const Outp: IOutput): Boolean;
var
  Args: TStringArray;
  I: Integer;
  Code: Integer;
  Ctx: IContext;
begin
  Result := False;
  if Length(PathParts) = 0 then Exit(False);

  Args := nil;
  SetLength(Args, Length(PathParts) + 1);
  for I := 0 to High(PathParts) do
    Args[I] := PathParts[I];
  Args[High(Args)] := '--help';

  Ctx := THelpContext.Create(Outp, Outp);
  Code := GlobalCommandRegistry.Dispatch(Args, Ctx);
  Result := Code = EXIT_OK;
end;

procedure ListChildrenDynamic(const PathParts: array of string);
var
  Outp: IOutput;
begin
  Outp := TConsoleOutput.Create(False) as IOutput;
  ListChildrenDynamic(PathParts, Outp);
end;

procedure ListChildrenDynamic(const PathParts: array of string; const Outp: IOutput);
var
  children: TStringArray;
  i: Integer;
begin
  children := GlobalCommandRegistry.ListChildren(PathParts);
  if Length(children) = 0 then
  begin
    // Leaf command: route to "<command> --help" if available.
    if TryDispatchLeafHelp(PathParts, Outp) then
      Exit;
    Outp.WriteLn(_(HELP_NO_COMMAND_FOUND));
    Exit;
  end;
  Outp.WriteLn(_(HELP_AVAILABLE_SUBCOMMANDS));
  for i := 0 to High(children) do
    Outp.WriteLn('  ' + children[i]);
end;

function PrintUsage(const Parts: array of string): Boolean;
var
  Outp: IOutput;
begin
  Outp := TConsoleOutput.Create(False) as IOutput;
  Result := PrintUsage(Parts, Outp);
end;

function PrintUsage(const Parts: array of string; const Outp: IOutput): Boolean;
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
    Outp.WriteLn(_(HELP_FPC_USAGE));
    Outp.WriteLn(_(HELP_EXAMPLES));
    Outp.WriteLn('  fpdev help fpc');
    Outp.WriteLn('  fpdev help lazarus');
    Exit(True);
  end
  else if cmd = 'version' then
  begin
    Outp.WriteLn('Usage: fpdev version');
    Exit(True);
  end
  else if cmd = 'fpc' then
  begin
    if (sub = 'install') then
    begin
      Outp.WriteLn(_(HELP_FPC_INSTALL_USAGE));
      Outp.WriteLn(_(HELP_FPC_INSTALL_EXAMPLE));
      Exit(True);
    end
    else if (sub = 'list') then
    begin
      Outp.WriteLn(_(HELP_FPC_LIST_USAGE));
      Exit(True);
    end
    else if (sub = 'use') or (sub = 'default') then
    begin
      Outp.WriteLn(_(HELP_FPC_USE_USAGE) + '   ' + _Fmt(HELP_ALIAS, ['default']));
      Exit(True);
    end
    else if (sub = 'current') then
    begin
      Outp.WriteLn(_(HELP_FPC_CURRENT_USAGE));
      Exit(True);
    end
    else if (sub = 'show') then
    begin
      Outp.WriteLn(_(HELP_FPC_SHOW_USAGE));
      Exit(True);
    end
    else if (sub = 'doctor') or (sub = 'update') then
    begin
      Outp.WriteLn('Usage: fpdev fpc ' + sub);
      Exit(True);
    end
    else
    begin
      Outp.WriteLn(_(HELP_FPC_SUBCOMMANDS));
      Outp.WriteLn(_(HELP_EXAMPLES));
      Outp.WriteLn('  fpdev fpc install 3.2.2 --from-source');
      Outp.WriteLn('  fpdev fpc use 3.2.2');
      Exit(True);
    end;
  end
  else if cmd = 'lazarus' then
  begin
    if (sub = 'install') then
    begin
      Outp.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'current') then
    begin
      Outp.WriteLn('Usage: fpdev lazarus ' + sub);
      Exit(True);
    end
    else if (sub = 'use') or (sub = 'default') then
    begin
      Outp.WriteLn(_(HELP_LAZARUS_USE_USAGE) + '   ' + _Fmt(HELP_ALIAS, ['default']));
      Exit(True);
    end
    else if (sub = 'run') then
    begin
      Outp.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
      Exit(True);
    end
    else
    begin
      Outp.WriteLn(_(HELP_LAZARUS_SUBCOMMANDS));
      Outp.WriteLn(_(HELP_EXAMPLES));
      Outp.WriteLn('  fpdev lazarus install 3.0 --from-source');
      Outp.WriteLn('  fpdev lazarus use 3.0');
      Exit(True);
    end;
  end
  else if cmd = 'project' then
  begin
    if (sub = 'new') then
    begin
      Outp.WriteLn(_(HELP_PROJECT_NEW_USAGE));
      Outp.WriteLn(_(HELP_PROJECT_NEW_EXAMPLE));
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'build') or (sub = 'clean') then
    begin
      Outp.WriteLn('Usage: fpdev project ' + sub);
      Exit(True);
    end
    else
    begin
      Outp.WriteLn(_(HELP_PROJECT_SUBCOMMANDS));
      Outp.WriteLn(_(HELP_EXAMPLES) + ' fpdev project new gui myapp');
      Exit(True);
    end;
  end
  else if cmd = 'package' then
  begin
    if (sub = 'install') then
    begin
      Outp.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
      Exit(True);
    end
    else if (sub = 'list') then
    begin
      Outp.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
      Exit(True);
    end
    else if (sub = 'search') then
    begin
      Outp.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
      Outp.WriteLn(_(HELP_PACKAGE_SEARCH_EXAMPLE));
      Exit(True);
    end
    else if (sub = 'repo') then
    begin
      if (sub2 = 'add') then
      begin
        Outp.WriteLn(_(HELP_REPO_ADD_USAGE));
        Outp.WriteLn(_(HELP_EXAMPLES) + ' fpdev package repo add custom https://example.com/repo');
        Exit(True);
      end
      else if (sub2 = 'remove') or (sub2 = 'rm') or (sub2 = 'del') then
      begin
        Outp.WriteLn(_(HELP_REPO_REMOVE_USAGE) + '   ' + _Fmt(HELP_ALIAS, ['rm, del']));
        Exit(True);
      end
      else if (sub2 = 'list') or (sub2 = 'ls') then
      begin
        Outp.WriteLn(_(HELP_REPO_LIST_USAGE) + '   ' + _Fmt(HELP_ALIAS, ['ls']));
        Exit(True);
      end
      else
      begin
        Outp.WriteLn(_(HELP_PACKAGE_REPO_USAGE));
        Exit(True);
      end;
    end
    else
    begin
      Outp.WriteLn(_(HELP_PACKAGE_SUBCOMMANDS));
      Exit(True);
    end;
  end
  else if cmd = 'cross' then
  begin
    if (sub = 'list') then
    begin
      Outp.WriteLn(_(HELP_CROSS_LIST_USAGE));
      Exit(True);
    end
    else if (sub = 'install') then
    begin
      Outp.WriteLn(_(HELP_CROSS_INSTALL_USAGE));
      Outp.WriteLn(_(HELP_CROSS_INSTALL_EXAMPLE));
      Exit(True);
    end
    else if (sub = 'configure') then
    begin
      Outp.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
      Exit(True);
    end
    else
    begin
      Outp.WriteLn(_(HELP_CROSS_SUBCOMMANDS));
      Exit(True);
    end;
  end
  else if cmd = 'repo' then
  begin
    if (sub = 'add') then
    begin
      Outp.WriteLn(_(HELP_REPO_ADD_USAGE));
      Exit(True);
    end
    else if (sub = 'remove') or (sub = 'rm') or (sub = 'del') then
    begin
      Outp.WriteLn(_(HELP_REPO_REMOVE_USAGE) + '   ' + _Fmt(HELP_ALIAS, ['rm, del']));
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'ls') then
    begin
      Outp.WriteLn(_(HELP_REPO_LIST_USAGE) + '   ' + _Fmt(HELP_ALIAS, ['ls']));
      Exit(True);
    end
    else if (sub = 'show') then
    begin
      Outp.WriteLn(_(HELP_REPO_SHOW_USAGE));
      Exit(True);
    end
    else if (sub = 'versions') then
    begin
      Outp.WriteLn(_(HELP_REPO_VERSIONS_USAGE));
      Exit(True);
    end
    else if (sub = 'default') then
    begin
      Outp.WriteLn(_(HELP_REPO_DEFAULT_USAGE));
      Exit(True);
    end
    else
    begin
      Outp.WriteLn(_(HELP_REPO_SUBCOMMANDS));
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure execute(const aParams: array of string);
var
  Outp: IOutput;
begin
  Outp := TConsoleOutput.Create(False) as IOutput;
  execute(aParams, Outp);
end;

procedure execute(const aParams: array of string; const Outp: IOutput);
var
  LParamCount: Integer;
begin
  // When called as default (no args), show global help
  LParamCount := Length(aParams);

  if LParamCount > 0 then
  begin
    // Print usage/examples for common commands first
    if PrintUsage(aParams, Outp) then Exit;
    // Otherwise list subcommands
    ListChildrenDynamic(aParams, Outp);
    Exit;
  end;

  Outp.WriteLn('');
  Outp.WriteLn(_(HELP_GLOBAL_USAGE));
  Outp.WriteLn('');
  ListChildrenDynamic([], Outp);
  Outp.WriteLn('');
  Outp.WriteLn(_(HELP_MAINTENANCE_SWITCHES));
  Outp.WriteLn('  --check-toolchain');
  Outp.WriteLn('  --self-test');
  Outp.WriteLn('');
  Outp.WriteLn(_(HELP_TIP));
end;

end.
