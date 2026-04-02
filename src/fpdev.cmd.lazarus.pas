unit fpdev.cmd.lazarus;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  fpdev.cmd.lazarus.root,
  fpdev.lazarus.manager;

type
  ILazarusGitClient = fpdev.lazarus.manager.ILazarusGitClient;
  TLazarusVersionInfo = fpdev.lazarus.manager.TLazarusVersionInfo;
  TLazarusVersionArray = fpdev.lazarus.manager.TLazarusVersionArray;
  TLazarusManager = fpdev.lazarus.manager.TLazarusManager;

implementation

end.
