unit fpdev.cmd.fpc.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['fpc'], CreateNamespaceRootShellCommand(['fpc']), []);

end.
