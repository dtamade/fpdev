unit fpdev.cmd.project;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  fpdev.cmd.project.root,
  fpdev.project.manager;

type
  TProjectTemplate = fpdev.project.manager.TProjectTemplate;
  TProjectTemplateArray = fpdev.project.manager.TProjectTemplateArray;
  TProjectManager = fpdev.project.manager.TProjectManager;

implementation

end.
