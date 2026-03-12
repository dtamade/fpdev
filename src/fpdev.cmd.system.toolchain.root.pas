unit fpdev.cmd.system.toolchain.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['system', 'toolchain'], CreateNamespaceRootShellCommand(['system', 'toolchain']), []);

end.
