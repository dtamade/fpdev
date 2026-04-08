unit fpdev.cmd.project;

{
  Compatibility shim for legacy fpdev.cmd.project imports.
  New code should use fpdev.project.manager and fpdev.cmd.project.root.
}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  fpdev.project.manager;

type
  TProjectTemplate = fpdev.project.manager.TProjectTemplate;
  TProjectTemplateArray = fpdev.project.manager.TProjectTemplateArray;
  TProjectManager = fpdev.project.manager.TProjectManager;

implementation

end.
