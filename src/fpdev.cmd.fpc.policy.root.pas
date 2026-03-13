unit fpdev.cmd.fpc.policy.root;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.registry,
  fpdev.command.rootshell;

implementation

initialization
  GlobalCommandRegistry.RegisterSingletonPath(
    ['fpc', 'policy'],
    CreateNamespaceRootShellCommand(['fpc', 'policy']),
    []
  );

end.
