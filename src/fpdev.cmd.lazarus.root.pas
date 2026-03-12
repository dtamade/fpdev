unit fpdev.cmd.lazarus.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(['lazarus'], CreateNamespaceRootShellCommand(['lazarus']), []);

end.
