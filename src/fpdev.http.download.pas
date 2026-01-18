unit fpdev.http.download;

{$mode objfpc}{$H+}

{ DEPRECATED: This unit is deprecated and will be removed in a future version.
  Please use fpdev.toolchain.fetcher instead, which provides:
  - Multi-mirror fallback support
  - SHA256/SHA512 hash verification
  - Manifest integration
  - Better error handling

  Migration guide:
  - Replace THTTPDownloader with fpdev.toolchain.fetcher functions
  - Use FetchWithMirrors() for multi-mirror downloads
  - Use FetchFromManifest() for manifest-based downloads
}

interface

uses
  Classes, SysUtils, fphttpclient, opensslsockets;

type
  TProgressCallback = procedure(ATotal, ACurrent: Int64) of object;

  { THTTPDownloader - HTTP file downloader with progress tracking }
  THTTPDownloader = class
  private
    FLastError: string;
    FOnProgress: TProgressCallback;
    FClient: TFPHTTPClient;
    procedure HTTPDataReceived(Sender: TObject; const ContentLength, CurrentPos: Int64);
  public
    constructor Create;
    destructor Destroy; override;

    { Download file from URL to destination }
    function Download(const AURL, ADestFile: string): Boolean;

    { Get last error message }
    function GetLastError: string;

    { Progress callback }
    property OnProgress: TProgressCallback read FOnProgress write FOnProgress;
  end;

implementation

{ THTTPDownloader }

constructor THTTPDownloader.Create;
begin
  inherited Create;
  FClient := TFPHTTPClient.Create(nil);
  FClient.AllowRedirect := True;
  FLastError := '';
end;

destructor THTTPDownloader.Destroy;
begin
  FClient.Free;
  inherited Destroy;
end;

procedure THTTPDownloader.HTTPDataReceived(Sender: TObject; const ContentLength, CurrentPos: Int64);
begin
  if Assigned(FOnProgress) then
    FOnProgress(ContentLength, CurrentPos);
end;

function THTTPDownloader.Download(const AURL, ADestFile: string): Boolean;
var
  Stream: TFileStream;
  OldHandler: TDataEvent;
begin
  Result := False;
  FLastError := '';

  try
    // Create destination file
    Stream := TFileStream.Create(ADestFile, fmCreate);
    try
      // Set up progress callback
      OldHandler := FClient.OnDataReceived;
      try
        FClient.OnDataReceived := @HTTPDataReceived;

        // Download file
        FClient.Get(AURL, Stream);
        Result := True;
      finally
        FClient.OnDataReceived := OldHandler;
      end;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;

      // Clean up partial download
      if FileExists(ADestFile) then
        DeleteFile(ADestFile);
    end;
  end;
end;

function THTTPDownloader.GetLastError: string;
begin
  Result := FLastError;
end;

end.
