unit fpdev.output.intf;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  { Console colors }
  TConsoleColor = (
    ccDefault,
    ccBlack,
    ccRed,
    ccGreen,
    ccYellow,
    ccBlue,
    ccMagenta,
    ccCyan,
    ccWhite,
    ccBrightBlack,
    ccBrightRed,
    ccBrightGreen,
    ccBrightYellow,
    ccBrightBlue,
    ccBrightMagenta,
    ccBrightCyan,
    ccBrightWhite
  );

  { Console text styles }
  TConsoleStyle = (
    csNone,
    csBold,
    csDim,
    csItalic,
    csUnderline
  );

  IOutput = interface
    ['{2CE5A51A-7F79-4C77-8D58-4E0A4F687D2C}']
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    { Color support }
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    { Semantic output helpers }
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
  end;

implementation

end.
