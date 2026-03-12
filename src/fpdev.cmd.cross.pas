unit fpdev.cmd.cross;

{$mode objfpc}{$H+}

interface

uses
  fpdev.cross.manager;

type
  TCrossToolchainDownloaderFactory = fpdev.cross.manager.TCrossToolchainDownloaderFactory;
  TCrossTargetInfo = fpdev.cross.manager.TCrossTargetInfo;
  TCrossTargetArray = fpdev.cross.manager.TCrossTargetArray;
  TCrossCompilerManager = fpdev.cross.manager.TCrossCompilerManager;

var
  CrossToolchainDownloaderFactory: TCrossToolchainDownloaderFactory
    absolute fpdev.cross.manager.CrossToolchainDownloaderFactory;

implementation

end.
