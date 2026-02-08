unit fpdev.build.cache.indexio;

{$mode objfpc}{$H+}

interface

uses
  Classes;

procedure BuildCacheLoadIndexEntries(const AIndexPath: string; AIndexEntries: TStringList);
procedure BuildCacheSaveIndexEntries(const AIndexPath: string; const AIndexEntries: TStringList);

implementation

uses
  SysUtils, fpjson, jsonparser;

procedure BuildCacheLoadIndexEntries(const AIndexPath: string; AIndexEntries: TStringList);
var
  JSONStr: TStringList;
  JSONData: TJSONData;
  JSONObj, EntryObj: TJSONObject;
  JSONArr: TJSONArray;
  i: Integer;
  Version, EntryJSON: string;
begin
  if not Assigned(AIndexEntries) then
    Exit;

  if not FileExists(AIndexPath) then
    Exit;

  JSONStr := TStringList.Create;
  try
    JSONStr.LoadFromFile(AIndexPath);

    try
      JSONData := GetJSON(JSONStr.Text);
      if not (JSONData is TJSONObject) then
      begin
        JSONData.Free;
        Exit;
      end;

      JSONObj := TJSONObject(JSONData);
      try
        if JSONObj.Find('entries') is TJSONArray then
        begin
          JSONArr := TJSONArray(JSONObj.Find('entries'));
          for i := 0 to JSONArr.Count - 1 do
          begin
            if JSONArr.Items[i] is TJSONObject then
            begin
              EntryObj := TJSONObject(JSONArr.Items[i]);
              Version := EntryObj.Get('version', '');
              if Version <> '' then
              begin
                EntryJSON := EntryObj.AsJSON;
                AIndexEntries.Add(Version + '=' + EntryJSON);
              end;
            end;
          end;
        end;
      finally
        JSONObj.Free;
      end;
    except
      // Invalid JSON, keep entries as-is (caller usually starts empty)
    end;
  finally
    JSONStr.Free;
  end;
end;

procedure BuildCacheSaveIndexEntries(const AIndexPath: string; const AIndexEntries: TStringList);
var
  JSONObj: TJSONObject;
  JSONArr: TJSONArray;
  EntryData: TJSONData;
  JSONStr: TStringList;
  i: Integer;
begin
  if not Assigned(AIndexEntries) then
    Exit;

  JSONObj := TJSONObject.Create;
  try
    JSONArr := TJSONArray.Create;

    for i := 0 to AIndexEntries.Count - 1 do
    begin
      try
        EntryData := GetJSON(AIndexEntries.ValueFromIndex[i]);
        if EntryData is TJSONObject then
          JSONArr.Add(EntryData)
        else
          EntryData.Free;
      except
        // Skip invalid entries
      end;
    end;

    JSONObj.Add('entries', JSONArr);
    JSONObj.Add('updated_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));

    JSONStr := TStringList.Create;
    try
      JSONStr.Text := JSONObj.FormatJSON;
      JSONStr.SaveToFile(AIndexPath);
    finally
      JSONStr.Free;
    end;
  finally
    JSONObj.Free;
  end;
end;

end.
