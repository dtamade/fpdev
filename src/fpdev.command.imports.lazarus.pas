unit fpdev.command.imports.lazarus;

{$mode objfpc}{$H+}

interface

uses
  fpdev.cmd.lazarus.root,
  fpdev.cmd.lazarus.list,
  fpdev.cmd.lazarus.current,
  fpdev.cmd.lazarus.use,
  fpdev.cmd.lazarus.run,
  fpdev.cmd.lazarus.test,
  fpdev.cmd.lazarus.install,
  fpdev.cmd.lazarus.uninstall,
  fpdev.cmd.lazarus.show,
  fpdev.cmd.lazarus.configure,
  fpdev.cmd.lazarus.doctor,
  fpdev.cmd.lazarus.update,
  fpdev.cmd.lazarus.help;

procedure EnsureLazarusCommandImports;

implementation

procedure EnsureLazarusCommandImports;
begin
end;

end.
