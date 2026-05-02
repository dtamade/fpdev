unit fpdev.lazarus.config.envoptionsflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DOM;

function SetLazarusEnvOptionValueCore(
  const AEnvOptionsPath, ANodeName, AValue: string
): Boolean;
function GetLazarusEnvOptionValueCore(
  const AEnvOptionsPath, ANodeName: string
): string;

implementation

uses
  XMLRead, XMLWrite;

function LoadLazarusXMLDocCore(const APath: string): TXMLDocument;
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

function SaveLazarusXMLDocCore(ADoc: TXMLDocument; const APath: string): Boolean;
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

function FindOrCreateLazarusNodeCore(
  ADoc: TXMLDocument;
  AParent: TDOMElement;
  const ANodeName: string
): TDOMElement;
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

function GetLazarusNodeValueCore(
  ANode: TDOMElement;
  const AAttrName: string
): string;
begin
  Result := '';
  if ANode = nil then
    Exit;
  Result := string(ANode.GetAttribute(UnicodeString(AAttrName)));
end;

procedure SetLazarusNodeValueCore(
  ANode: TDOMElement;
  const AAttrName, AValue: string
);
begin
  if ANode = nil then
    Exit;
  ANode.SetAttribute(UnicodeString(AAttrName), UnicodeString(AValue));
end;

function SetLazarusEnvOptionValueCore(
  const AEnvOptionsPath, ANodeName, AValue: string
): Boolean;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  EnvOptions: TDOMElement;
  TargetNode: TDOMElement;
begin
  Result := False;

  Doc := LoadLazarusXMLDocCore(AEnvOptionsPath);
  try
    if Doc = nil then
    begin
      Doc := TXMLDocument.Create;
      Root := Doc.CreateElement('CONFIG');
      Doc.AppendChild(Root);
    end
    else
      Root := Doc.DocumentElement;

    EnvOptions := FindOrCreateLazarusNodeCore(Doc, Root, 'EnvironmentOptions');
    TargetNode := FindOrCreateLazarusNodeCore(Doc, EnvOptions, ANodeName);
    SetLazarusNodeValueCore(TargetNode, 'Value', AValue);

    Result := SaveLazarusXMLDocCore(Doc, AEnvOptionsPath);
  finally
    Doc.Free;
  end;
end;

function GetLazarusEnvOptionValueCore(
  const AEnvOptionsPath, ANodeName: string
): string;
var
  Doc: TXMLDocument;
  Root: TDOMElement;
  NodeList: TDOMNodeList;
begin
  Result := '';

  Doc := LoadLazarusXMLDocCore(AEnvOptionsPath);
  if Doc = nil then
    Exit;

  try
    Root := Doc.DocumentElement;
    if Root = nil then
      Exit;

    NodeList := Root.GetElementsByTagName(UnicodeString(ANodeName));
    try
      if NodeList.Count > 0 then
        Result := GetLazarusNodeValueCore(NodeList.Item[0] as TDOMElement, 'Value');
    finally
      NodeList.Free;
    end;
  finally
    Doc.Free;
  end;
end;

end.
