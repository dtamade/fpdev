unit fpdev.result;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{
  **FPDev Result Type**: Rust-inspired error handling

  Inspired by Rust's Result<T, E> type, this provides explicit error handling
  without exceptions. Makes error handling visible in function signatures.

  Philosophy:
  - Errors are values, not exceptions
  - Explicit is better than implicit
  - Compiler forces error handling

  Example:
    function DivideNumbers(A, B: Integer): TResult;
    begin
      if B = 0 then
        Exit(TResult.Err('Division by zero'));
      Exit(TResult.Ok(A / B));
    end;

    var R: TResult;
    R := DivideNumbers(10, 0);
    if R.IsOk then
      WriteLn('Result: ', R.Value)
    else
      WriteLn('Error: ', R.Error);
}

interface

uses
  SysUtils;

type
  {** Generic Result<T, E> for typed success/error **}
  {** For now, we use string-based errors (Pascal generics limitation) **}

  { TResult - Basic Result type with string value and error }
  TResult = record
  private
    FIsOk: Boolean;
    FValue: string;
    FError: string;
  public
    class function Ok(const AValue: string): TResult; static;
    class function Err(const AError: string): TResult; static;

    function IsOk: Boolean; inline;
    function IsErr: Boolean; inline;

    function Value: string;
    function Error: string;

    function Expect(const AMsg: string): string;
    function Unwrap: string;
    function UnwrapOr(const ADefault: string): string;
  end;

  { TIntResult - Result with Integer value }
  TIntResult = record
  private
    FIsOk: Boolean;
    FValue: Integer;
    FError: string;
  public
    class function Ok(const AValue: Integer): TIntResult; static;
    class function Err(const AError: string): TIntResult; static;

    function IsOk: Boolean; inline;
    function IsErr: Boolean; inline;

    function Value: Integer;
    function Error: string;

    function Expect(const AMsg: string): Integer;
    function Unwrap: Integer;
    function UnwrapOr(const ADefault: Integer): Integer;
  end;

  { TBoolResult - Result with Boolean value }
  TBoolResult = record
  private
    FIsOk: Boolean;
    FValue: Boolean;
    FError: string;
  public
    class function Ok(const AValue: Boolean): TBoolResult; static;
    class function Err(const AError: string): TBoolResult; static;

    function IsOk: Boolean; inline;
    function IsErr: Boolean; inline;

    function Value: Boolean;
    function Error: string;

    function Expect(const AMsg: string): Boolean;
    function Unwrap: Boolean;
    function UnwrapOr(const ADefault: Boolean): Boolean;
  end;

  {** Common Result type aliases **}
  TStringResult = TResult;

{** Function types for map/chain operations **}
type
  TStringMapFunc = function(const Value: string): string;
  TStringChainFunc = function(const Value: string): TResult;
  TStringErrorMapFunc = function(const Error: string): string;
  TStringOrElseFunc = function(const Error: string): TResult;
  TStringUnwrapOrElseFunc = function(const Error: string): string;
  TStringInspectProc = procedure(const Value: string);
  TStringInspectErrProc = procedure(const Error: string);

  TIntMapFunc = function(const Value: Integer): Integer;
  TIntChainFunc = function(const Value: Integer): TIntResult;
  TIntErrorMapFunc = function(const Error: string): string;
  TIntOrElseFunc = function(const Error: string): TIntResult;
  TIntUnwrapOrElseFunc = function(const Error: string): Integer;
  TIntInspectProc = procedure(const Value: Integer);
  TIntInspectErrProc = procedure(const Error: string);

  TBoolMapFunc = function(const Value: Boolean): Boolean;
  TBoolChainFunc = function(const Value: Boolean): TBoolResult;
  TBoolErrorMapFunc = function(const Error: string): string;
  TBoolOrElseFunc = function(const Error: string): TBoolResult;
  TBoolUnwrapOrElseFunc = function(const Error: string): Boolean;
  TBoolInspectProc = procedure(const Value: Boolean);
  TBoolInspectErrProc = procedure(const Error: string);

{** Functional combinators (Rust-style helper functions) **}

{ Map: Transform the success value if Ok, propagate error if Err }
function ResultMap(const R: TResult; MapFunc: TStringMapFunc): TResult;
function IntResultMap(const R: TIntResult; MapFunc: TIntMapFunc): TIntResult;
function BoolResultMap(const R: TBoolResult; MapFunc: TBoolMapFunc): TBoolResult;

{ AndThen: Chain operations that may fail, short-circuit on error }
function ResultAndThen(const R: TResult; ChainFunc: TStringChainFunc): TResult;
function IntResultAndThen(const R: TIntResult; ChainFunc: TIntChainFunc): TIntResult;
function BoolResultAndThen(const R: TBoolResult; ChainFunc: TBoolChainFunc): TBoolResult;

{ MapErr: Transform the error value if Err, propagate value if Ok }
function ResultMapErr(const R: TResult; MapFunc: TStringErrorMapFunc): TResult;
function IntResultMapErr(const R: TIntResult; MapFunc: TIntErrorMapFunc): TIntResult;
function BoolResultMapErr(const R: TBoolResult; MapFunc: TBoolErrorMapFunc): TBoolResult;

{ OrElse: Recover from error with fallback function, pass through if Ok }
function ResultOrElse(const R: TResult; RecoverFunc: TStringOrElseFunc): TResult;
function IntResultOrElse(const R: TIntResult; RecoverFunc: TIntOrElseFunc): TIntResult;
function BoolResultOrElse(const R: TBoolResult; RecoverFunc: TBoolOrElseFunc): TBoolResult;

{ UnwrapOrElse: Unwrap value or compute default from error (lazy evaluation) }
function ResultUnwrapOrElse(const R: TResult; DefaultFunc: TStringUnwrapOrElseFunc): string;
function IntResultUnwrapOrElse(const R: TIntResult; DefaultFunc: TIntUnwrapOrElseFunc): Integer;
function BoolResultUnwrapOrElse(const R: TBoolResult; DefaultFunc: TBoolUnwrapOrElseFunc): Boolean;

{ Inspect: Inspect Ok value without consuming (for logging/debugging) }
function ResultInspect(const R: TResult; InspectProc: TStringInspectProc): TResult;
function IntResultInspect(const R: TIntResult; InspectProc: TIntInspectProc): TIntResult;
function BoolResultInspect(const R: TBoolResult; InspectProc: TBoolInspectProc): TBoolResult;

{ InspectErr: Inspect Err value without consuming (for logging/debugging) }
function ResultInspectErr(const R: TResult; InspectProc: TStringInspectErrProc): TResult;
function IntResultInspectErr(const R: TIntResult; InspectProc: TIntInspectErrProc): TIntResult;
function BoolResultInspectErr(const R: TBoolResult; InspectProc: TBoolInspectErrProc): TBoolResult;

implementation

{ TResult }

class function TResult.Ok(const AValue: string): TResult;
begin
  Result.FIsOk := True;
  Result.FValue := AValue;
  Result.FError := '';
end;

class function TResult.Err(const AError: string): TResult;
begin
  Result.FIsOk := False;
  Result.FValue := '';
  Result.FError := AError;
end;

function TResult.IsOk: Boolean;
begin
  Result := FIsOk;
end;

function TResult.IsErr: Boolean;
begin
  Result := not FIsOk;
end;

function TResult.Value: string;
begin
  if not FIsOk then
    raise Exception.Create('Attempted to get value from Err result: ' + FError);
  Result := FValue;
end;

function TResult.Error: string;
begin
  if FIsOk then
    raise Exception.Create('Attempted to get error from Ok result');
  Result := FError;
end;

function TResult.Expect(const AMsg: string): string;
begin
  if not FIsOk then
    raise Exception.CreateFmt('%s: %s', [AMsg, FError]);
  Result := FValue;
end;

function TResult.Unwrap: string;
begin
  if not FIsOk then
    raise Exception.Create('Called unwrap on Err result: ' + FError);
  Result := FValue;
end;

function TResult.UnwrapOr(const ADefault: string): string;
begin
  if FIsOk then
    Result := FValue
  else
    Result := ADefault;
end;

{ TIntResult }

class function TIntResult.Ok(const AValue: Integer): TIntResult;
begin
  Result.FIsOk := True;
  Result.FValue := AValue;
  Result.FError := '';
end;

class function TIntResult.Err(const AError: string): TIntResult;
begin
  Result.FIsOk := False;
  Result.FValue := 0;
  Result.FError := AError;
end;

function TIntResult.IsOk: Boolean;
begin
  Result := FIsOk;
end;

function TIntResult.IsErr: Boolean;
begin
  Result := not FIsOk;
end;

function TIntResult.Value: Integer;
begin
  if not FIsOk then
    raise Exception.Create('Attempted to get value from Err result: ' + FError);
  Result := FValue;
end;

function TIntResult.Error: string;
begin
  if FIsOk then
    raise Exception.Create('Attempted to get error from Ok result');
  Result := FError;
end;

function TIntResult.Expect(const AMsg: string): Integer;
begin
  if not FIsOk then
    raise Exception.CreateFmt('%s: %s', [AMsg, FError]);
  Result := FValue;
end;

function TIntResult.Unwrap: Integer;
begin
  if not FIsOk then
    raise Exception.Create('Called unwrap on Err result: ' + FError);
  Result := FValue;
end;

function TIntResult.UnwrapOr(const ADefault: Integer): Integer;
begin
  if FIsOk then
    Result := FValue
  else
    Result := ADefault;
end;

{ TBoolResult }

class function TBoolResult.Ok(const AValue: Boolean): TBoolResult;
begin
  Result.FIsOk := True;
  Result.FValue := AValue;
  Result.FError := '';
end;

class function TBoolResult.Err(const AError: string): TBoolResult;
begin
  Result.FIsOk := False;
  Result.FValue := False;
  Result.FError := AError;
end;

function TBoolResult.IsOk: Boolean;
begin
  Result := FIsOk;
end;

function TBoolResult.IsErr: Boolean;
begin
  Result := not FIsOk;
end;

function TBoolResult.Value: Boolean;
begin
  if not FIsOk then
    raise Exception.Create('Attempted to get value from Err result: ' + FError);
  Result := FValue;
end;

function TBoolResult.Error: string;
begin
  if FIsOk then
    raise Exception.Create('Attempted to get error from Ok result');
  Result := FError;
end;

function TBoolResult.Expect(const AMsg: string): Boolean;
begin
  if not FIsOk then
    raise Exception.CreateFmt('%s: %s', [AMsg, FError]);
  Result := FValue;
end;

function TBoolResult.Unwrap: Boolean;
begin
  if not FIsOk then
    raise Exception.Create('Called unwrap on Err result: ' + FError);
  Result := FValue;
end;

function TBoolResult.UnwrapOr(const ADefault: Boolean): Boolean;
begin
  if FIsOk then
    Result := FValue
  else
    Result := ADefault;
end;

{** Global helper functions for functional combinators **}

function ResultMap(const R: TResult; MapFunc: TStringMapFunc): TResult;
begin
  if R.IsOk then
    Result := TResult.Ok(MapFunc(R.Value))
  else
    Result := TResult.Err(R.Error);
end;

function ResultAndThen(const R: TResult; ChainFunc: TStringChainFunc): TResult;
begin
  if R.IsOk then
    Result := ChainFunc(R.Value)
  else
    Result := TResult.Err(R.Error);
end;

function IntResultMap(const R: TIntResult; MapFunc: TIntMapFunc): TIntResult;
begin
  if R.IsOk then
    Result := TIntResult.Ok(MapFunc(R.Value))
  else
    Result := TIntResult.Err(R.Error);
end;

function IntResultAndThen(const R: TIntResult; ChainFunc: TIntChainFunc): TIntResult;
begin
  if R.IsOk then
    Result := ChainFunc(R.Value)
  else
    Result := TIntResult.Err(R.Error);
end;

function BoolResultMap(const R: TBoolResult; MapFunc: TBoolMapFunc): TBoolResult;
begin
  if R.IsOk then
    Result := TBoolResult.Ok(MapFunc(R.Value))
  else
    Result := TBoolResult.Err(R.Error);
end;

function BoolResultAndThen(const R: TBoolResult; ChainFunc: TBoolChainFunc): TBoolResult;
begin
  if R.IsOk then
    Result := ChainFunc(R.Value)
  else
    Result := TBoolResult.Err(R.Error);
end;

{** MapErr: Transform error values **}

function ResultMapErr(const R: TResult; MapFunc: TStringErrorMapFunc): TResult;
begin
  if R.IsErr then
    Result := TResult.Err(MapFunc(R.Error))
  else
    Result := TResult.Ok(R.Value);
end;

function IntResultMapErr(const R: TIntResult; MapFunc: TIntErrorMapFunc): TIntResult;
begin
  if R.IsErr then
    Result := TIntResult.Err(MapFunc(R.Error))
  else
    Result := TIntResult.Ok(R.Value);
end;

function BoolResultMapErr(const R: TBoolResult; MapFunc: TBoolErrorMapFunc): TBoolResult;
begin
  if R.IsErr then
    Result := TBoolResult.Err(MapFunc(R.Error))
  else
    Result := TBoolResult.Ok(R.Value);
end;

{** OrElse: Error recovery with fallback **}

function ResultOrElse(const R: TResult; RecoverFunc: TStringOrElseFunc): TResult;
begin
  if R.IsErr then
    Result := RecoverFunc(R.Error)
  else
    Result := TResult.Ok(R.Value);
end;

function IntResultOrElse(const R: TIntResult; RecoverFunc: TIntOrElseFunc): TIntResult;
begin
  if R.IsErr then
    Result := RecoverFunc(R.Error)
  else
    Result := TIntResult.Ok(R.Value);
end;

function BoolResultOrElse(const R: TBoolResult; RecoverFunc: TBoolOrElseFunc): TBoolResult;
begin
  if R.IsErr then
    Result := RecoverFunc(R.Error)
  else
    Result := TBoolResult.Ok(R.Value);
end;

{** UnwrapOrElse: Lazy default value computation **}

function ResultUnwrapOrElse(const R: TResult; DefaultFunc: TStringUnwrapOrElseFunc): string;
begin
  if R.IsOk then
    Result := R.Value
  else
    Result := DefaultFunc(R.Error);
end;

function IntResultUnwrapOrElse(const R: TIntResult; DefaultFunc: TIntUnwrapOrElseFunc): Integer;
begin
  if R.IsOk then
    Result := R.Value
  else
    Result := DefaultFunc(R.Error);
end;

function BoolResultUnwrapOrElse(const R: TBoolResult; DefaultFunc: TBoolUnwrapOrElseFunc): Boolean;
begin
  if R.IsOk then
    Result := R.Value
  else
    Result := DefaultFunc(R.Error);
end;

{** Inspect: Non-consuming value inspection **}

function ResultInspect(const R: TResult; InspectProc: TStringInspectProc): TResult;
begin
  if R.IsOk then
    InspectProc(R.Value);
  Result := R;
end;

function IntResultInspect(const R: TIntResult; InspectProc: TIntInspectProc): TIntResult;
begin
  if R.IsOk then
    InspectProc(R.Value);
  Result := R;
end;

function BoolResultInspect(const R: TBoolResult; InspectProc: TBoolInspectProc): TBoolResult;
begin
  if R.IsOk then
    InspectProc(R.Value);
  Result := R;
end;

{** InspectErr: Non-consuming error inspection **}

function ResultInspectErr(const R: TResult; InspectProc: TStringInspectErrProc): TResult;
begin
  if R.IsErr then
    InspectProc(R.Error);
  Result := R;
end;

function IntResultInspectErr(const R: TIntResult; InspectProc: TIntInspectErrProc): TIntResult;
begin
  if R.IsErr then
    InspectProc(R.Error);
  Result := R;
end;

function BoolResultInspectErr(const R: TBoolResult; InspectProc: TBoolInspectErrProc): TBoolResult;
begin
  if R.IsErr then
    InspectProc(R.Error);
  Result := R;
end;

end.
