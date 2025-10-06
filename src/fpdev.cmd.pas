unit fpdev.cmd;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.cmd

命令


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type

  { TFPCMD }

  TFPCMD = class
  private
    FParams: TStringArray;
    FChilds: array of TFPCMD;
  public
    constructor Create(const aParams: array of string);
    procedure Execute; virtual;
    procedure AddChild(const aChild: TFPCMD);
    function  Find(const aName: string): TFPCMD;


  end;

implementation

constructor TFPCMD.Create(const aParams: array of string);
var
  i: Integer;
begin
  inherited Create;
  SetLength(FParams, Length(aParams));
  for i := 0 to High(aParams) do
    FParams[i] := aParams[i];
end;

procedure TFPCMD.Execute;
begin
end;

procedure TFPCMD.AddChild(const aChild: TFPCMD);
begin
  SetLength(FChilds, Length(FChilds) + 1);
  FChilds[High(FChilds)] := aChild;
end;

function TFPCMD.Find(const aName: string): TFPCMD;
var
  child: TFPCMD;
begin
  Result := nil;

  for child in FChilds do
  begin
    if SameText(child.FParams[0], aName) then
      Exit(child);
  end;
end;

end.