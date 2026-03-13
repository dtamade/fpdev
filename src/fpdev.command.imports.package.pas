unit fpdev.command.imports.package;

{$mode objfpc}{$H+}

interface

uses
  fpdev.cmd.package.root,
  fpdev.cmd.package.install,
  fpdev.cmd.package.list,
  fpdev.cmd.package.search,
  fpdev.cmd.package.info,
  fpdev.cmd.package.uninstall,
  fpdev.cmd.package.update,
  fpdev.cmd.package.clean,
  fpdev.cmd.package.install_local,
  fpdev.cmd.package.publish,
  fpdev.cmd.package.deps,
  fpdev.cmd.package.why,
  fpdev.cmd.package.repo.root,
  fpdev.cmd.package.repo.add,
  fpdev.cmd.package.repo.remove,
  fpdev.cmd.package.repo.update,
  fpdev.cmd.package.repo.list,
  fpdev.cmd.package.help;

procedure EnsurePackageCommandImports;

implementation

procedure EnsurePackageCommandImports;
begin
end;

end.
