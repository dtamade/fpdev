unit fpdev.cmd.package.repo.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(
    ['package', 'repo'],
    CreateNamespaceRootShellCommand(['package', 'repo']),
    []
  );

end.
