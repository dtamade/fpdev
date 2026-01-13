unit fpdev.lazarus.config;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DOM, XMLRead, XMLWrite, fpdev.utils.fs;

type
  { TLazarusIDEConfig }
  TLazarusIDEConfig = class
  private
    FConfigDir: string;
    FEnvOptionsPath: string;
    FEditorOptionsPath: string;

    function EnsureConfigDir: Boolean;
    function LoadXMLDoc(const APath: string): TXMLDocument;
    function SaveXMLDoc(ADoc: TXMLDocument; const APath: string): Boolean;
    function FindOrCreateNode(ADoc: TXMLDocument; AParent: TDOMElement;
      const ANodeName: string): TDOMElement;
    function GetNodeValue(ANode: TDOMElement; const AAttrName: string): string;
    procedure SetNodeValue(ANode: TDOMElement; const AAttrName, AValue: string);

  public
    constructor Create(const AConfigDir: string);
    destructor Destroy; override;

    // Compiler configuration
    function SetCompilerPath(const AFPCPath: string): Boolean;
    function GetCompilerPath: string;

    // Library paths
    function SetLibraryPath(const APath: string): Boolean;
    function GetLibraryPath: string;
    function AddLibrarySearchPath(const APath: string): Boolean;

    // FPC source path
    function SetFPCSourcePath(const APath: string): Boolean;
    function GetFPCSourcePath: string;

    // Make path
    function SetMakePath(const APath: string): Boolean;
    function GetMakePath: string;

    // Debugger path
    function SetDebuggerPath(const APath: string): Boolean;
    function GetDebuggerPath: string;

    // Target configuration
    function SetTargetOS(const AOS: string): Boolean;
    function SetTargetCPU(const ACPU: string): Boolean;
    function GetTargetOS: string;
    function GetTargetCPU: string;

    // Import/Export
    function ExportConfig(const AExportPath: string): Boolean;
    function ImportConfig(const AImportPath: string): Boolean;

    // Backup/Restore
    function BackupConfig: string;  // Returns backup path or empty on failure
    function RestoreConfig(const ABackupPath: string): Boolean;

    // Utility
    function ValidateConfig: Boolean;
    function GetConfigSummary: string;

    property ConfigDir: string read FConfigDir;
  end;

implementation

{ TLazarusIDEConfig }

constructor TLazarusIDEConfig.Create(const AConfigDir: string);
begin
  inherited Create;
  FConfigDir := AConfigDir;
  FEnvOptionsPath := FConfigDir + PathDelim + 'environmentoptions.xml';
  FEditorOptionsPath := FConfigDir + PathDelim + 'editoroptions.xml';
end;

destructor TLazarusIDEConfig.Destroy;
begin
  inherited Destroy;
end;

function TLazarusIDEConfig.EnsureConfigDir: Boolean;
begin
  Result := DirectoryExists(FConfigDir);
  if not Result then
    Result := EnsureDir(FConfigDir);
end;

function TLazarusIDEConfig.LoadXMLDoc(const APath: string): TXMLDocument;
begin
  Result := nil;
  if not FileExists(APath) then
    Exit;

  try
    ReadXMLFile(Result, APath);
  except
    on E: Exception do
    begin
      if Result <> nil then
        Result.Free;
      Result := nil;
    end;
  end;
end;

function TLazarusIDEConfig.SaveXMLDoc(ADoc: TXMLDocument; const APath: string): Boolean;
begin
  Result := False;
  if ADoc = nil then
    Exit;

  try
    WriteXMLFile(ADoc, APath);
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TLazarusIDEConfig.FindOrCreateNode(ADoc: TXMLDocument; AParent: TDOMElement;
  const ANodeName: string): TDOMElement;
var
  NodeList: TDOMNodeList;
begin
  Result := nil;
  if (ADoc = nil) or (AParent = nil) then
    Exit;

  NodeList := AParent.GetElementsByTagName(UnicodeString(ANodeName));
  try
    if NodeList.Count > 0 then
      Result := NodeList.Item[0] as TDOMElement
    else
    begin
      Result := ADoc.CreateElement(UnicodeString(ANodeName));
      AParent.AppendChild(Result);
    end;
  finally
    NodeList.Free;
  end;
end;

function TLazarusIDEConfig.GetNodeValue(ANode: TDOMElement; const AAttrName: string): string;
begin
  Result := '';
  if ANode = nil then
    Exit;
  Result := string(ANode.GetAttribute(UnicodeString(AAttrName)));
end;

procedure TLazarusIDEConfig.SetNodeValue(ANode: TDOMElement; const AAttrName, AValue: string);
begin
  if ANode = nil then
    Exit;
  ANode.SetAttribute(UnicodeString(AAttrName), UnicodeString(AValue));
end;

function TLazarusIDEConfig.SetCompilerPath(const AFPCPath: string): Boolean;
var
  Doc: TXMLDocument;
  Root, EnvOpts, CompilerOpts: TDOMElement;
begin
  Result := False;
  if not EnsureConfigDir then
    Exit;

  Doc := LoadXMLDoc(FEnvOptionsPath);
  try
    if Doc = nil then
    begin
      // Create new document
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOpts := FindOrCreateNode(Doc, Root, 'EnvironmentOptions');
    CompilerOpts := FindOrCreateNode(Doc, EnvOpts, 'CompilerFilename');
    SetNodeValue(CompilerOpts, 'Value', AFPCPath);

    Result := SaveXMLDoc(Doc, FEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.GetCompilerPath: string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';
  Doc := LoadXMLDoc(FEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    NodeList := Root.GetElementsByTagName('CompilerFilename');
    try
      if NodeList.Count > 0 then
        Result := GetNodeValue(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.SetLibraryPath(const APath: string): Boolean;
var
  Doc: TXMLDocument;
  Root, EnvOpts, LibOpts: TDOMElement;
begin
  Result := False;
  if not EnsureConfigDir then
    Exit;

  Doc := LoadXMLDoc(FEnvOptionsPath);
  try
    if Doc = nil then
    begin
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOpts := FindOrCreateNode(Doc, Root, 'EnvironmentOptions');
    LibOpts := FindOrCreateNode(Doc, EnvOpts, 'LazarusDirectory');
    SetNodeValue(LibOpts, 'Value', APath);

    Result := SaveXMLDoc(Doc, FEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.GetLibraryPath: string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';
  Doc := LoadXMLDoc(FEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    NodeList := Root.GetElementsByTagName('LazarusDirectory');
    try
      if NodeList.Count > 0 then
        Result := GetNodeValue(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.AddLibrarySearchPath(const APath: string): Boolean;
var
  CurrentPath: string;
begin
  CurrentPath := GetLibraryPath;
  if CurrentPath <> '' then
    Result := SetLibraryPath(CurrentPath + PathSeparator + APath)
  else
    Result := SetLibraryPath(APath);
end;

function TLazarusIDEConfig.SetFPCSourcePath(const APath: string): Boolean;
var
  Doc: TXMLDocument;
  Root, EnvOpts, SrcOpts: TDOMElement;
begin
  Result := False;
  if not EnsureConfigDir then
    Exit;

  Doc := LoadXMLDoc(FEnvOptionsPath);
  try
    if Doc = nil then
    begin
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOpts := FindOrCreateNode(Doc, Root, 'EnvironmentOptions');
    SrcOpts := FindOrCreateNode(Doc, EnvOpts, 'FPCSourceDirectory');
    SetNodeValue(SrcOpts, 'Value', APath);

    Result := SaveXMLDoc(Doc, FEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.GetFPCSourcePath: string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';
  Doc := LoadXMLDoc(FEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    NodeList := Root.GetElementsByTagName('FPCSourceDirectory');
    try
      if NodeList.Count > 0 then
        Result := GetNodeValue(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.SetMakePath(const APath: string): Boolean;
var
  Doc: TXMLDocument;
  Root, EnvOpts, MakeOpts: TDOMElement;
begin
  Result := False;
  if not EnsureConfigDir then
    Exit;

  Doc := LoadXMLDoc(FEnvOptionsPath);
  try
    if Doc = nil then
    begin
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOpts := FindOrCreateNode(Doc, Root, 'EnvironmentOptions');
    MakeOpts := FindOrCreateNode(Doc, EnvOpts, 'MakeFilename');
    SetNodeValue(MakeOpts, 'Value', APath);

    Result := SaveXMLDoc(Doc, FEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.GetMakePath: string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';
  Doc := LoadXMLDoc(FEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    NodeList := Root.GetElementsByTagName('MakeFilename');
    try
      if NodeList.Count > 0 then
        Result := GetNodeValue(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.SetDebuggerPath(const APath: string): Boolean;
var
  Doc: TXMLDocument;
  Root, EnvOpts, DbgOpts: TDOMElement;
begin
  Result := False;
  if not EnsureConfigDir then
    Exit;

  Doc := LoadXMLDoc(FEnvOptionsPath);
  try
    if Doc = nil then
    begin
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOpts := FindOrCreateNode(Doc, Root, 'EnvironmentOptions');
    DbgOpts := FindOrCreateNode(Doc, EnvOpts, 'DebuggerFilename');
    SetNodeValue(DbgOpts, 'Value', APath);

    Result := SaveXMLDoc(Doc, FEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.GetDebuggerPath: string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';
  Doc := LoadXMLDoc(FEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    NodeList := Root.GetElementsByTagName('DebuggerFilename');
    try
      if NodeList.Count > 0 then
        Result := GetNodeValue(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.SetTargetOS(const AOS: string): Boolean;
var
  Doc: TXMLDocument;
  Root, EnvOpts, TargetOpts: TDOMElement;
begin
  Result := False;
  if not EnsureConfigDir then
    Exit;

  Doc := LoadXMLDoc(FEnvOptionsPath);
  try
    if Doc = nil then
    begin
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOpts := FindOrCreateNode(Doc, Root, 'EnvironmentOptions');
    TargetOpts := FindOrCreateNode(Doc, EnvOpts, 'TargetOS');
    SetNodeValue(TargetOpts, 'Value', AOS);

    Result := SaveXMLDoc(Doc, FEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.SetTargetCPU(const ACPU: string): Boolean;
var
  Doc: TXMLDocument;
  Root, EnvOpts, TargetOpts: TDOMElement;
begin
  Result := False;
  if not EnsureConfigDir then
    Exit;

  Doc := LoadXMLDoc(FEnvOptionsPath);
  try
    if Doc = nil then
    begin
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOpts := FindOrCreateNode(Doc, Root, 'EnvironmentOptions');
    TargetOpts := FindOrCreateNode(Doc, EnvOpts, 'TargetCPU');
    SetNodeValue(TargetOpts, 'Value', ACPU);

    Result := SaveXMLDoc(Doc, FEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.GetTargetOS: string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';
  Doc := LoadXMLDoc(FEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    NodeList := Root.GetElementsByTagName('TargetOS');
    try
      if NodeList.Count > 0 then
        Result := GetNodeValue(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.GetTargetCPU: string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';
  Doc := LoadXMLDoc(FEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    NodeList := Root.GetElementsByTagName('TargetCPU');
    try
      if NodeList.Count > 0 then
        Result := GetNodeValue(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TLazarusIDEConfig.ExportConfig(const AExportPath: string): Boolean;
var
  SrcFiles: array[0..1] of string;
  DstFiles: array[0..1] of string;
  i: Integer;
  SrcStream, DstStream: TFileStream;
begin
  Result := False;

  SrcFiles[0] := FEnvOptionsPath;
  SrcFiles[1] := FEditorOptionsPath;
  DstFiles[0] := AExportPath + PathDelim + 'environmentoptions.xml';
  DstFiles[1] := AExportPath + PathDelim + 'editoroptions.xml';

  if not DirectoryExists(AExportPath) then
    if not EnsureDir(AExportPath) then
      Exit;

  try
    for i := 0 to High(SrcFiles) do
    begin
      if FileExists(SrcFiles[i]) then
      begin
        SrcStream := TFileStream.Create(SrcFiles[i], fmOpenRead or fmShareDenyWrite);
        try
          DstStream := TFileStream.Create(DstFiles[i], fmCreate);
          try
            DstStream.CopyFrom(SrcStream, SrcStream.Size);
          finally
            DstStream.Free;
          end;
        finally
          SrcStream.Free;
        end;
      end;
    end;
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TLazarusIDEConfig.ImportConfig(const AImportPath: string): Boolean;
var
  SrcFiles: array[0..1] of string;
  DstFiles: array[0..1] of string;
  i: Integer;
  SrcStream, DstStream: TFileStream;
begin
  Result := False;

  if not EnsureConfigDir then
    Exit;

  SrcFiles[0] := AImportPath + PathDelim + 'environmentoptions.xml';
  SrcFiles[1] := AImportPath + PathDelim + 'editoroptions.xml';
  DstFiles[0] := FEnvOptionsPath;
  DstFiles[1] := FEditorOptionsPath;

  try
    for i := 0 to High(SrcFiles) do
    begin
      if FileExists(SrcFiles[i]) then
      begin
        SrcStream := TFileStream.Create(SrcFiles[i], fmOpenRead or fmShareDenyWrite);
        try
          DstStream := TFileStream.Create(DstFiles[i], fmCreate);
          try
            DstStream.CopyFrom(SrcStream, SrcStream.Size);
          finally
            DstStream.Free;
          end;
        finally
          SrcStream.Free;
        end;
      end;
    end;
    Result := True;
  except
    on E: Exception do
      Result := False;
  end;
end;

function TLazarusIDEConfig.BackupConfig: string;
var
  BackupDir, BackupPath: string;
  Timestamp: string;
begin
  Result := '';

  // Only backup if config file exists
  if not FileExists(FEnvOptionsPath) then
    Exit;

  try
    // Create backup directory
    BackupDir := FConfigDir + PathDelim + 'backups';
    if not DirectoryExists(BackupDir) then
      if not EnsureDir(BackupDir) then
        Exit;

    // Generate timestamp-based backup name
    Timestamp := FormatDateTime('yyyymmdd_hhnnss', Now);
    BackupPath := BackupDir + PathDelim + 'environmentoptions_' + Timestamp + '.xml';

    // Copy config file to backup
    if ExportConfig(BackupDir + PathDelim + Timestamp) then
      Result := BackupDir + PathDelim + Timestamp;

  except
    on E: Exception do
      Result := '';
  end;
end;

function TLazarusIDEConfig.RestoreConfig(const ABackupPath: string): Boolean;
begin
  Result := False;

  if not DirectoryExists(ABackupPath) then
    Exit;

  Result := ImportConfig(ABackupPath);
end;

function TLazarusIDEConfig.ValidateConfig: Boolean;
var
  CompilerPath, LazarusPath: string;
begin
  Result := False;

  // Check if config file exists
  if not FileExists(FEnvOptionsPath) then
    Exit;

  // Check if compiler path is set and exists
  CompilerPath := GetCompilerPath;
  if (CompilerPath = '') or (not FileExists(CompilerPath)) then
    Exit;

  // Check if Lazarus directory is set and exists
  LazarusPath := GetLibraryPath;
  if (LazarusPath = '') or (not DirectoryExists(LazarusPath)) then
    Exit;

  Result := True;
end;

function TLazarusIDEConfig.GetConfigSummary: string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add('Lazarus IDE Configuration');
    SL.Add('------------------------');
    SL.Add('Config directory: ' + FConfigDir);
    SL.Add('Compiler path: ' + GetCompilerPath);
    SL.Add('Lazarus directory: ' + GetLibraryPath);
    SL.Add('FPC source path: ' + GetFPCSourcePath);
    SL.Add('Make path: ' + GetMakePath);
    SL.Add('Debugger path: ' + GetDebuggerPath);
    SL.Add('Target OS: ' + GetTargetOS);
    SL.Add('Target CPU: ' + GetTargetCPU);
    SL.Add('');
    if ValidateConfig then
      SL.Add('Status: Valid')
    else
      SL.Add('Status: Invalid or incomplete');
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

end.
