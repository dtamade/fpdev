unit fpdev.cmd.lazarus;

{
  Compatibility shim for legacy fpdev.cmd.lazarus imports.
  New code should use fpdev.lazarus.manager and fpdev.cmd.lazarus.root.
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  fpdev.lazarus.manager, fpdev.lazarus.types;

type
  ILazarusGitClient = fpdev.lazarus.manager.ILazarusGitClient;
  TLazarusVersionInfo = fpdev.lazarus.types.TLazarusVersionInfo;
  TLazarusVersionArray = fpdev.lazarus.types.TLazarusVersionArray;
  TLazarusManager = fpdev.lazarus.manager.TLazarusManager;

implementation

end.
