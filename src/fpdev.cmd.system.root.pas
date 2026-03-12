unit fpdev.cmd.system.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['system'], CreateNamespaceRootShellCommand(['system']), []);

end.
