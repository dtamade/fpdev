unit fpdev.cmd.cache;

{
================================================================================
  fpdev.cmd.cache - Global Cache Management Command
================================================================================

  Provides commands for managing all fpdev caches:
  - fpdev system cache status    - Show overall cache status
  - fpdev system cache stats     - Show detailed cache statistics
  - fpdev system cache path      - Show cache directory paths

  Aggregates information from:
  - FPC build cache
  - Lazarus cache
  - Package registry cache
  - Index cache

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry;

type
  TCacheCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowHelp(const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateCacheCommand: ICommand;

implementation

uses
  fpdev.command.namespacehelp,
  fpdev.cache.commandflow;

function CreateCacheCommand: ICommand;
begin
  Result := TCacheCommand.Create;
end;

function TCacheCommand.Name: string;
begin
  Result := 'cache';
end;

function TCacheCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCacheCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

procedure TCacheCommand.ShowHelp(const Ctx: IContext);
begin
  WriteCacheHelp(Ctx);
end;

function TCacheCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteNamespaceRootCommandCore(
    AParams,
    Ctx,
    'Usage: fpdev system cache <command>',
    @ShowHelp,
    @ShowHelp
  );
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'cache'], @CreateCacheCommand, []);

end.
