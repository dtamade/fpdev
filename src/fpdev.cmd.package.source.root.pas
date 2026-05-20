unit fpdev.cmd.package.source.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(
    ['package', 'source'],
    CreateNamespaceRootShellCommand(['package', 'source']),
    []
  );

end.
