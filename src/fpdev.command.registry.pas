unit fpdev.command.registry;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.utils, fpdev.command.intf;

type
  TCommandFactory = function: IFpdevCommand;

  { TCommandNode }
  TCommandNode = class
  public
    Name: string;
    Parent: TCommandNode;
    Children: TStringList; // name -> TObject(TCommandNode)
    Factory: TCommandFactory;
    constructor Create(const AName: string);
    destructor Destroy; override;
    function FindChild(const AName: string): TCommandNode;
    function EnsureChild(const AName: string): TCommandNode;
  end;

type
  { TCommandRegistry }
  TCommandRegistry = class
  private
    FCommands: TStringList; // name -> IFpdevCommand (stored as Obj) [legacy]
    FRoot: TCommandNode;    // path-based root
  public
    constructor Create;
    destructor Destroy; override;
    // Legacy single-level API
    procedure Register(const ACmd: IFpdevCommand);
    function Resolve(const AName: string): IFpdevCommand;
    function Dispatch(const AArgs: array of string; const Ctx: ICommandContext): Integer;
    // New path-based API
    procedure RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
    function DispatchPath(const AArgs: array of string; const Ctx: ICommandContext): Integer;
  end;

function GlobalCommandRegistry: TCommandRegistry;

implementation

{ TCommandNode }

constructor TCommandNode.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  Children := TStringList.Create;
  Children.CaseSensitive := False;
  Children.Sorted := False;
  Children.Duplicates := dupIgnore;
  Factory := nil;
end;

destructor TCommandNode.Destroy;
var i: Integer;
begin
  for i := 0 to Children.Count-1 do
    TObject(Children.Objects[i]).Free;
  Children.Free;
  inherited Destroy;
end;

function TCommandNode.FindChild(const AName: string): TCommandNode;
var idx: Integer;
begin
  idx := Children.IndexOf(AName);
  if idx >= 0 then
    Result := TCommandNode(Children.Objects[idx])
  else
    Result := nil;
end;

function TCommandNode.EnsureChild(const AName: string): TCommandNode;
var C: TCommandNode; idx: Integer;
begin
  C := FindChild(AName);
  if C <> nil then Exit(C);
  C := TCommandNode.Create(AName);
  C.Parent := Self;
  idx := Children.Add(AName);
  Children.Objects[idx] := C;
  Result := C;
end;

var
  GRegistry: TCommandRegistry = nil;

{ TCommandRegistry }

constructor TCommandRegistry.Create;
begin
  inherited Create;
  FCommands := TStringList.Create; // legacy map (will be removed)
  FCommands.CaseSensitive := False;
  FCommands.Sorted := False;
  FCommands.Duplicates := dupIgnore;
  FRoot := TCommandNode.Create('');
end;

destructor TCommandRegistry.Destroy;
begin
  FRoot.Free;
  FCommands.Free;
  inherited Destroy;
end;
procedure TCommandRegistry.RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
var
  i: Integer;
  Node: TCommandNode;
begin
  Node := FRoot;
  for i := Low(APath) to High(APath) do
    Node := Node.EnsureChild(LowerCase(APath[i]));
  Node.Factory := AFactory;
  // 别名注册为同级子节点的多名称映射
  if Assigned(Node.Parent) then
    for i := Low(Aliases) to High(Aliases) do
      Node.Parent.EnsureChild(LowerCase(Aliases[i])).Factory := AFactory;
end;

function TCommandRegistry.DispatchPath(const AArgs: array of string; const Ctx: ICommandContext): Integer;
var
  i, ExecIndex: Integer;
  Node, Child, LastNode: TCommandNode;
  Rest: array of string;
  Cmd: IFpdevCommand;
begin
  Result := 0;
  Node := FRoot;
  LastNode := nil;
  ExecIndex := 0;
  // 最长可执行前缀匹配：匹配到最近的含 Factory 的节点，剩余作为参数
  i := 0;
  while (i <= High(AArgs)) and (Node <> nil) do
  begin
    if (i > High(AArgs)) or (AArgs[i] = '') then Break;
    Child := Node.FindChild(LowerCase(AArgs[i]));
    if Child = nil then Break;
    Node := Child;
    Inc(i);
    if Assigned(Node.Factory) then
    begin
      LastNode := Node;
      ExecIndex := i; // 执行点后的参数起始索引
    end;
  end;

  if (LastNode <> nil) then
  begin
    Cmd := LastNode.Factory();
    SetLength(Rest, Length(AArgs) - ExecIndex);
    if Length(Rest) > 0 then Move(AArgs[ExecIndex], Rest[0], (Length(AArgs)-ExecIndex)*SizeOf(string));
    Cmd.Execute(Rest, Ctx);
    Ctx.SaveIfModified;
  end
  else
  begin
    // 自动帮助：列出当前节点子命令（若无可执行前缀）
    if (Node <> nil) and (Node.Children.Count > 0) then
    begin
      WriteLn('可用子命令:');
      for i := 0 to Node.Children.Count-1 do
        WriteLn('  ', Node.Children[i]);
      Result := 0;
    end
    else
      Result := 1;
  end;
end;


procedure TCommandRegistry.Register(const ACmd: IFpdevCommand);
var
  i: Integer;
  LNames: TStringArray;
begin
  if ACmd = nil then Exit;
  // 主名
  FCommands.Values[ACmd.Name] := IntToHex(PtrUInt(Pointer(ACmd)), SizeOf(Pointer)*2);
  // 别名
  LNames := ACmd.Aliases;
  for i := 0 to High(LNames) do
    FCommands.Values[LNames[i]] := IntToHex(PtrUInt(Pointer(ACmd)), SizeOf(Pointer)*2);
end;

function TCommandRegistry.Resolve(const AName: string): IFpdevCommand;
var
  i: Integer;
  LCmd: IFpdevCommand;
begin
  Result := nil;
  for i := 0 to FCommands.Count - 1 do
  begin
    if SameText(FCommands.Names[i], AName) then
    begin
      Pointer(LCmd) := Pointer(StrToQWordDef(FCommands.ValueFromIndex[i], 0));
      Exit(LCmd);
    end;
  end;
end;
function TCommandRegistry.Dispatch(const AArgs: array of string; const Ctx: ICommandContext): Integer;
begin
  // 兼容旧接口：直接走路径分发
  Result := DispatchPath(AArgs, Ctx);
end;

function GlobalCommandRegistry: TCommandRegistry;
begin
  if GRegistry = nil then
    GRegistry := TCommandRegistry.Create;
  Result := GRegistry;
end;

end.

