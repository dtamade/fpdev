unit fpdev.cmd.package.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['package'], CreateNamespaceRootShellCommand(['package']), []);

end.
