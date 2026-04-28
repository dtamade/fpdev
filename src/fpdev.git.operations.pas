unit fpdev.git.operations;

{$mode objfpc}{$H+}

interface

uses
  fpdev.git.operations.impl;

type
  // Default entrypoint for TGitOperations and IGitCliRunner.
  IGitCliRunner = fpdev.git.operations.impl.IGitCliRunner;
  TGitOperations = fpdev.git.operations.impl.TGitOperations;

implementation

end.
