unit meta_editor_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Menus, Dialogs, ExtCtrls, ComCtrls,
  VirtualTrees, fpjson, jsonparser, fpdev.git;

type
  TNodeKind = (nkValue, nkObject, nkArray);

  PNodeData = ^TNodeData;
  TNodeData = record
    Json: TJSONData;
    Key: String;
    Kind: TNodeKind;
  end;

  { TFormMain }

  TFormMain = class(TForm)
    MainMenu1: TMainMenu;
    MenuItemFile: TMenuItem;
    MenuItemOpen: TMenuItem;
    MenuItemSave: TMenuItem;
    MenuItemSaveAs: TMenuItem;
    MenuItemClone: TMenuItem;
    MenuItemSep1: TMenuItem;
    MenuItemPull: TMenuItem;
    MenuItemCommitPush: TMenuItem;
    MenuItemSep2: TMenuItem;
    MenuItemExit: TMenuItem;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    StatusBar1: TStatusBar;
    Splitter1: TSplitter;
    PanelLeft: TPanel;
    VST: TVirtualStringTree;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MenuItemExitClick(Sender: TObject);
    procedure MenuItemOpenClick(Sender: TObject);
    procedure MenuItemSaveAsClick(Sender: TObject);
    procedure MenuItemSaveClick(Sender: TObject);
    procedure MenuItemPullClick(Sender: TObject);
    procedure MenuItemCommitPushClick(Sender: TObject);
    procedure VSTFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure VSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
    procedure VSTInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
      var ChildCount: Cardinal);
    procedure VSTInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode;
      var InitialStates: TVirtualNodeInitStates);
    procedure VSTNewText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; const NewText: String);
  private
    FJson: TJSONData;
    FFileName: String;
    FModified: Boolean;
    FRepoRoot: String;
    FGit: TGitManager;
    procedure SetModified(AValue: Boolean);
    procedure AfterLoad;
    procedure BuildTree;
    procedure UpdateCaption;
    function AddJsonNode(const Parent: PVirtualNode; const AKey: String; AJson: TJSONData): PVirtualNode;
    function GetNodeData(Node: PVirtualNode): PNodeData;
    procedure ClearJson;
    function ConfirmDiscardChanges: Boolean;
    procedure DoOpenFile(const AFileName: String);
    function FormatJsonText: String;
    function FindRepoRootFromFile(const AFileName: String): String;
    function EnsureRepoForFile: Boolean;
    function RelativePathToRepo(const AbsPath: String): String;
    function EnsureIndexJsonExistsInRepo(const RepoRoot: String): String;
    procedure EnsureBasicStructure;
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
begin
  VST.NodeDataSize := SizeOf(TNodeData);
  VST.Header.Options := VST.Header.Options + [hoVisible, hoAutoResize, hoColumnResize];
  VST.Header.Columns.Clear;
  with VST.Header.Columns.Add do
  begin
    Text := 'Name';
    Width := 320;
  end;
  with VST.Header.Columns.Add do
  begin
    Text := 'Value';
    Width := 520;
  end;
  VST.Header.MainColumn := 0;
  VST.TreeOptions.MiscOptions := VST.TreeOptions.MiscOptions + [toEditable, toFullRepaintOnResize, toInitOnSave];
  VST.TreeOptions.SelectionOptions := VST.TreeOptions.SelectionOptions + [toFullRowSelect, toRightClickSelect];
  VST.TreeOptions.PaintOptions := VST.TreeOptions.PaintOptions + [toShowHorzGridLines, toShowTreeLines, toThemeAware];
  VST.Header.AutoSizeIndex := 1;

  OpenDialog1.Filter := 'JSON files|*.json|All files|*.*';
  SaveDialog1.Filter := 'JSON files|*.json|All files|*.*';

  UpdateCaption;
  FGit := TGitManager.Create;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FGit);
  ClearJson;
end;

procedure TFormMain.MenuItemExitClick(Sender: TObject);
begin
  if ConfirmDiscardChanges then
    Close;
end;

procedure TFormMain.MenuItemOpenClick(Sender: TObject);
begin
  if not ConfirmDiscardChanges then
    Exit;
  if OpenDialog1.Execute then
    DoOpenFile(OpenDialog1.FileName);
end;

procedure TFormMain.MenuItemSaveAsClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
  begin
    FFileName := SaveDialog1.FileName;
    MenuItemSaveClick(Sender);
  end;
end;

procedure TFormMain.MenuItemSaveClick(Sender: TObject);
var
  S: String;
  FS: TFileStream;
begin
  if FJson = nil then Exit;
  if FFileName = '' then
  begin
    if not SaveDialog1.Execute then Exit;
    FFileName := SaveDialog1.FileName;
  end;
  EnsureBasicStructure;
  S := FormatJsonText;
  FS := TFileStream.Create(FFileName, fmCreate);
  try
    if Length(S) > 0 then
      FS.WriteBuffer(Pointer(S)^, Length(S));
  finally
    FS.Free;
  end;
  SetModified(False);
end;

procedure TFormMain.VSTFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  Data: PNodeData;
begin
  Data := GetNodeData(Node);
  if Data <> nil then
  begin
    Data^.Json := nil;
    Data^.Key := '';
  end;
end;

procedure TFormMain.VSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
var
  Data: PNodeData;
  J: TJSONData;
begin
  Data := GetNodeData(Node);
  if (Data = nil) or (Data^.Json = nil) then Exit;
  J := Data^.Json;
  if Column = 0 then
  begin
    CellText := Data^.Key;
  end
  else
  begin
    case J.JSONType of
      jtString: CellText := J.AsString;
      jtNumber: CellText := J.AsString;
      jtBoolean: CellText := J.AsString;
      jtNull: CellText := 'null';
      jtArray: CellText := '<array (' + IntToStr(TJSONArray(J).Count) + ')>';
      jtObject: CellText := '<object (' + IntToStr(TJSONObject(J).Count) + ')>';
    else
      CellText := '';
    end;
  end;
end;

procedure TFormMain.VSTInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
  var ChildCount: Cardinal);
begin
  // Not used (we build nodes explicitly)
  ChildCount := 0;
end;

procedure TFormMain.VSTInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode;
  var InitialStates: TVirtualNodeInitStates);
begin
  // Not used (we build nodes explicitly)
end;

procedure TFormMain.VSTNewText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; const NewText: String);
var
  Data: PNodeData;
  FS: TFormatSettings;
  I64: Int64;
  F64: Double;
  B: Boolean;
begin
  if Column <> 1 then Exit;
  Data := GetNodeData(Node);
  if (Data = nil) or (Data^.Json = nil) then Exit;

  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  case Data^.Json.JSONType of
    jtString:
      begin
        Data^.Json.AsString := NewText;
        SetModified(True);
        VST.InvalidateNode(Node);
      end;
    jtNumber:
      begin
        if TryStrToInt64(NewText, I64) then
        begin
          Data^.Json.AsInt64 := I64;
          SetModified(True);
          VST.InvalidateNode(Node);
        end
        else if TryStrToFloat(NewText, F64, FS) then
        begin
          Data^.Json.AsFloat := F64;
          SetModified(True);
          VST.InvalidateNode(Node);
        end;
      end;
    jtBoolean:
      begin
        if SameText(NewText, 'true') or SameText(NewText, '1') then B := True
        else if SameText(NewText, 'false') or SameText(NewText, '0') then B := False
        else Exit;
        Data^.Json.AsBoolean := B;
        SetModified(True);
        VST.InvalidateNode(Node);
      end;
  else
    Exit;
  end;
end;

procedure TFormMain.SetModified(AValue: Boolean);
begin
  if FModified = AValue then Exit;
  FModified := AValue;
  UpdateCaption;
end;

procedure TFormMain.AfterLoad;
begin
  EnsureBasicStructure;
  BuildTree;
  SetModified(False);
end;

procedure TFormMain.BuildTree;

  procedure AddObjectChildren(const ParentNode: PVirtualNode; Obj: TJSONObject);
  var
    I: Integer;
    Key: String;
    J: TJSONData;
  begin
    for I := 0 to Obj.Count - 1 do
    begin
      Key := Obj.Names[I];
      J := Obj.Elements[Key];
      AddJsonNode(ParentNode, Key, J);
    end;
  end;

  procedure AddArrayChildren(const ParentNode: PVirtualNode; Arr: TJSONArray);
  var
    I: Integer;
    J: TJSONData;
  begin
    for I := 0 to Arr.Count - 1 do
    begin
      J := Arr.Items[I];
      AddJsonNode(ParentNode, IntToStr(I), J);
    end;
  end;

var
  Root: PVirtualNode;
begin
  VST.BeginUpdate;
  try
    VST.Clear;
    if FJson = nil then Exit;
    case FJson.JSONType of
      jtObject:
        begin
          // Show object children at root level
          AddObjectChildren(nil, TJSONObject(FJson));
        end;
      jtArray:
        begin
          AddArrayChildren(nil, TJSONArray(FJson));
        end;
    else
      begin
        Root := AddJsonNode(nil, '(root)', FJson);
        VST.Expanded[Root] := False;
      end;
    end;
  finally
    VST.EndUpdate;
  end;
end;

procedure TFormMain.UpdateCaption;
var
  S: String;
begin
  if FFileName = '' then S := 'Untitled' else S := ExtractFileName(FFileName);
  if FModified then
    Caption := 'FPDev Metadata Editor - ' + S + ' *'
  else
    Caption := 'FPDev Metadata Editor - ' + S;
end;

function TFormMain.AddJsonNode(const Parent: PVirtualNode; const AKey: String; AJson: TJSONData): PVirtualNode;
var
  Node: PVirtualNode;
  Data: PNodeData;
  K: TNodeKind;

  procedure AddChildren;
  var
    I: Integer;
    Key: String;
    J: TJSONData;
    Obj: TJSONObject;
    Arr: TJSONArray;
  begin
    if AJson.JSONType = jtObject then
    begin
      Obj := TJSONObject(AJson);
      for I := 0 to Obj.Count - 1 do
      begin
        Key := Obj.Names[I];
        J := Obj.Elements[Key];
        AddJsonNode(Node, Key, J);
      end;
    end
    else if AJson.JSONType = jtArray then
    begin
      Arr := TJSONArray(AJson);
      for I := 0 to Arr.Count - 1 do
      begin
        J := Arr.Items[I];
        AddJsonNode(Node, IntToStr(I), J);
      end;
    end;
  end;

begin
  case AJson.JSONType of
    jtObject: K := nkObject;
    jtArray:  K := nkArray;
  else
    K := nkValue;
  end;

  Node := VST.AddChild(Parent);
  Data := GetNodeData(Node);
  Data^.Json := AJson;
  Data^.Key := AKey;
  Data^.Kind := K;

  if (K <> nkValue) then
    AddChildren;

  Exit(Node);
end;

function TFormMain.GetNodeData(Node: PVirtualNode): PNodeData;
begin
  if Node = nil then Exit(nil);
  Result := VST.GetNodeData(Node);
end;

procedure TFormMain.ClearJson;
begin
  if FJson <> nil then
  begin
    FJson.Free;
    FJson := nil;
  end;
end;

function TFormMain.ConfirmDiscardChanges: Boolean;
var
  Res: Integer;
begin
  if not FModified then Exit(True);
  Res := MessageDlg('未保存的更改将丢失，是否继续？', mtConfirmation, [mbYes, mbNo], 0);
  Result := (Res = mrYes);
end;

procedure TFormMain.DoOpenFile(const AFileName: String);
var
  FS: TFileStream;
  Parser: TJSONParser;
begin
  ClearJson;
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Parser := TJSONParser.Create(FS, [joUTF8]);
    try
      FJson := Parser.Parse;
    finally
      Parser.Free;
    end;
  finally
    FS.Free;
  end;
  FFileName := AFileName;
  FRepoRoot := FindRepoRootFromFile(FFileName);
  AfterLoad;
  UpdateCaption;
end;

function TFormMain.FormatJsonText: String;
begin
  if FJson = nil then Exit('');
  Result := FJson.FormatJSON;
  if (Result = '') or (Result[Length(Result)] <> #10) then
    Result := Result + LineEnding;
end;

function TFormMain.FindRepoRootFromFile(const AFileName: String): String;
var
  Dir: String;
begin
  Result := '';
  Dir := ExtractFileDir(AFileName);
  while (Dir <> '') and (Dir <> ExtractFileDrive(Dir) + PathDelim) do
  begin
    if DirectoryExists(IncludeTrailingPathDelimiter(Dir) + '.git') then
    begin
      Result := Dir;
      Exit;
    end;
    Dir := ExtractFileDir(Dir);
  end;
end;

function TFormMain.EnsureRepoForFile: Boolean;
begin
  Result := (FRepoRoot <> '') and DirectoryExists(IncludeTrailingPathDelimiter(FRepoRoot) + '.git');
end;

function TFormMain.RelativePathToRepo(const AbsPath: String): String;
begin
  if FRepoRoot = '' then Exit(AbsPath);
  Result := StringReplace(AbsPath, IncludeTrailingPathDelimiter(FRepoRoot), '', []);
end;

function TFormMain.EnsureIndexJsonExistsInRepo(const RepoRoot: String): String;
var
  Candidate: String;
begin
  Candidate := IncludeTrailingPathDelimiter(RepoRoot) + 'index.json';
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := IncludeTrailingPathDelimiter(RepoRoot) + 'repo' + PathDelim + 'index.json';
  if FileExists(Candidate) then Exit(Candidate);
  Result := '';
end;

procedure TFormMain.EnsureBasicStructure;
var
  Obj: TJSONObject;
begin
  if FJson = nil then Exit;
  if FJson.JSONType <> jtObject then Exit;
  Obj := TJSONObject(FJson);
  if Obj.Find('meta') = nil then
    Obj.Add('meta', TJSONObject.Create);
  if Obj.Find('catalog') = nil then
    Obj.Add('catalog', TJSONObject.Create);
end;

procedure TFormMain.MenuItemPullClick(Sender: TObject);
var
  Ok: Boolean;
begin
  if not EnsureRepoForFile then
  begin
    MessageDlg('当前文件不在 Git 仓库内，无法 Pull。', mtWarning, [mbOK], 0);
    Exit;
  end;
  if FModified then
    MenuItemSaveClick(Sender);
  Ok := FGit.UpdateRepository(FRepoRoot);
  if Ok then
    MessageDlg('已从远程更新 (git pull)。', mtInformation, [mbOK], 0)
  else
    MessageDlg('Pull 失败，请检查网络/凭据。', mtError, [mbOK], 0);
end;

procedure TFormMain.MenuItemCommitPushClick(Sender: TObject);
var
  Msg: String;
  Ok: Boolean;
  Rel: String;
begin
  if FFileName = '' then
  begin
    MessageDlg('请先打开一个 index.json 文件。', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not EnsureRepoForFile then
  begin
    MessageDlg('当前文件不在 Git 仓库内，无法提交与推送。', mtWarning, [mbOK], 0);
    Exit;
  end;
  MenuItemSaveClick(Sender);
  Rel := RelativePathToRepo(FFileName);
  Ok := FGit.Add(FRepoRoot, Rel);
  if not Ok then
  begin
    MessageDlg('git add 失败：' + Rel, mtError, [mbOK], 0);
    Exit;
  end;
  Msg := 'update index.json';
  if not InputQuery('提交说明', 'Commit message:', Msg) then
    Exit;
  Ok := FGit.Commit(FRepoRoot, Msg);
  if not Ok then
  begin
    MessageDlg('git commit 失败（可能没有更改或用户信息未配置）。', mtError, [mbOK], 0);
    Exit;
  end;
  Ok := FGit.Push(FRepoRoot, 'origin', '');
  if Ok then
    MessageDlg('已提交并推送到远程。', mtInformation, [mbOK], 0)
  else
    MessageDlg('git push 失败，请检查凭据/远程配置。', mtError, [mbOK], 0);
end;

end.


