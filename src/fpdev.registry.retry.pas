unit fpdev.registry.retry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, fpdev.registry.client.intf;

type
  { TExponentialBackoffRetry - Exponential backoff retry policy }
  TExponentialBackoffRetry = class(TInterfacedObject, IRetryPolicy)
  private
    FConfig: TRetryConfig;
    function IsRetryableStatusCode(const AStatusCode: Integer): Boolean;
  public
    constructor Create(const AConfig: TRetryConfig);

    { IRetryPolicy implementation }
    function ShouldRetry(const AAttempt: Integer; const AStatusCode: Integer): Boolean;
    function GetDelay(const AAttempt: Integer): Integer;
    function GetMaxRetries: Integer;
  end;

  { TNoRetryPolicy - No retry policy (fail immediately) }
  TNoRetryPolicy = class(TInterfacedObject, IRetryPolicy)
  public
    { IRetryPolicy implementation }
    function ShouldRetry(const AAttempt: Integer; const AStatusCode: Integer): Boolean;
    function GetDelay(const AAttempt: Integer): Integer;
    function GetMaxRetries: Integer;
  end;

{ Helper functions }
function CreateDefaultRetryConfig: TRetryConfig;
function CreateAggressiveRetryConfig: TRetryConfig;
function CreateConservativeRetryConfig: TRetryConfig;

implementation

{ TExponentialBackoffRetry }

constructor TExponentialBackoffRetry.Create(const AConfig: TRetryConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TExponentialBackoffRetry.IsRetryableStatusCode(const AStatusCode: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;

  // Check if status code is in retryable list
  for I := 0 to High(FConfig.RetryableStatusCodes) do
  begin
    if FConfig.RetryableStatusCodes[I] = AStatusCode then
    begin
      Result := True;
      Exit;
    end;
  end;

  // Default retryable status codes (if list is empty)
  if Length(FConfig.RetryableStatusCodes) = 0 then
  begin
    // 5xx server errors
    if (AStatusCode >= 500) and (AStatusCode < 600) then
      Result := True
    // 408 Request Timeout
    else if AStatusCode = 408 then
      Result := True
    // 429 Too Many Requests
    else if AStatusCode = 429 then
      Result := True;
  end;
end;

function TExponentialBackoffRetry.ShouldRetry(const AAttempt: Integer; const AStatusCode: Integer): Boolean;
begin
  Result := False;

  // Check if we've exceeded max retries
  if AAttempt >= FConfig.MaxRetries then
    Exit;

  // Check if status code is retryable
  if not IsRetryableStatusCode(AStatusCode) then
    Exit;

  Result := True;
end;

function TExponentialBackoffRetry.GetDelay(const AAttempt: Integer): Integer;
var
  Delay: Double;
begin
  // Calculate exponential backoff: InitialDelay * (BackoffMultiplier ^ Attempt)
  Delay := FConfig.InitialDelay * Power(FConfig.BackoffMultiplier, AAttempt);

  // Cap at MaxDelay
  if Delay > FConfig.MaxDelay then
    Delay := FConfig.MaxDelay;

  Result := Trunc(Delay);
end;

function TExponentialBackoffRetry.GetMaxRetries: Integer;
begin
  Result := FConfig.MaxRetries;
end;

{ TNoRetryPolicy }

function TNoRetryPolicy.ShouldRetry(const AAttempt: Integer; const AStatusCode: Integer): Boolean;
begin
  Result := False;
end;

function TNoRetryPolicy.GetDelay(const AAttempt: Integer): Integer;
begin
  Result := 0;
end;

function TNoRetryPolicy.GetMaxRetries: Integer;
begin
  Result := 0;
end;

{ Helper functions }

function CreateDefaultRetryConfig: TRetryConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MaxRetries := 3;
  Result.InitialDelay := 1000;  // 1 second
  Result.MaxDelay := 30000;     // 30 seconds
  Result.BackoffMultiplier := 2.0;
  SetLength(Result.RetryableStatusCodes, 0);  // Use default list
end;

function CreateAggressiveRetryConfig: TRetryConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MaxRetries := 5;
  Result.InitialDelay := 500;   // 0.5 seconds
  Result.MaxDelay := 60000;     // 60 seconds
  Result.BackoffMultiplier := 2.0;
  SetLength(Result.RetryableStatusCodes, 0);  // Use default list
end;

function CreateConservativeRetryConfig: TRetryConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MaxRetries := 2;
  Result.InitialDelay := 2000;  // 2 seconds
  Result.MaxDelay := 15000;     // 15 seconds
  Result.BackoffMultiplier := 2.0;
  SetLength(Result.RetryableStatusCodes, 0);  // Use default list
end;

end.
