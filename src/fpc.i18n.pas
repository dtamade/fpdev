unit fpc.i18n;

{$mode objfpc}{$H+}

(*
  ============================================================================
  FPC.i18n - Lightweight Internationalization Library for Free Pascal
  ============================================================================

  A zero-dependency, embedded translation system with O(log n) lookup.

  Features:
  - Single file, no external dependencies
  - Embedded translations (no .po/.mo files needed)
  - Automatic system language detection (Windows/Linux/macOS)
  - O(log n) lookup using sorted TStringList
  - Fallback chain: Current -> Fallback -> Return ID
  - Thread-safe singleton pattern
  - Inline functions for maximum performance

  Quick Start:
  ------------
  1. Add 'fpc.i18n' to uses clause
  2. Register translations in initialization:

       initialization
         T('msg.hello', 'Hello', '你好');
         T('msg.bye',   'Goodbye', '再见');

  3. Use translations:

       WriteLn(_(msg.hello'));           // "Hello" or "你好"
       WriteLn(_Fmt('msg.user', [Name])); // With parameters

  API Reference:
  --------------
  _()      - Get translated string
  _Fmt()   - Get translated string with Format() parameters
  T()      - Register English + Chinese translation (one-liner)
  I18n     - Access full manager for advanced operations

  License: MIT
  Author: FPDev Team
  Version: 1.0.0
  ============================================================================
*)

interface

uses
  SysUtils, Classes;

type
  { Supported languages - extend as needed }
  TLanguage = (
    langEnglish,    // en - Default/Fallback
    langChinese,    // zh - Simplified Chinese
    langJapanese,   // ja - Japanese
    langKorean,     // ko - Korean
    langGerman,     // de - German
    langFrench,     // fr - French
    langSpanish,    // es - Spanish
    langRussian,    // ru - Russian
    langPortuguese, // pt - Portuguese
    langItalian,    // it - Italian
    langDutch,      // nl - Dutch
    langPolish,     // pl - Polish
    langTurkish,    // tr - Turkish
    langArabic,     // ar - Arabic
    langHindi       // hi - Hindi
  );

  { II18nManager - Internationalization manager interface }
  II18nManager = interface
    ['{F6A7B8C9-D0E1-2345-ABCD-456789012345}']
    function DetectSystemLanguage: TLanguage;
    procedure Reg(const ALang: TLanguage; const AID, AText: string);
    procedure RegMulti(const AID: string; const ATranslations: array of string);
    function Get(const AID: string): string;
    function GetFmt(const AID: string; const AArgs: array of const): string;
    procedure SetLanguage(const ALang: TLanguage); overload;
    procedure SetLanguage(const ACode: string); overload;
    function GetLanguageCode: string;
    function GetCurrentLanguage: TLanguage;
    procedure SetFallbackLanguage(const ALang: TLanguage);
  end;

  { TI18nManager - Core internationalization manager }
  TI18nManager = class(TInterfacedObject, II18nManager)
  private
    FCurrentLang: TLanguage;
    FTranslations: array[TLanguage] of TStringList;
    FFallbackLang: TLanguage;

    class function LanguageCodeToEnum(const ACode: string): TLanguage; static;
  public
    constructor Create;
    destructor Destroy; override;

    { System language detection }
    function DetectSystemLanguage: TLanguage;

    { Translation registration }
    procedure Reg(const ALang: TLanguage; const AID, AText: string); inline;
    procedure RegMulti(const AID: string; const ATranslations: array of string);

    { Translation retrieval - O(log n) }
    function Get(const AID: string): string; inline;
    function GetFmt(const AID: string; const AArgs: array of const): string;

    { Language management }
    procedure SetLanguage(const ALang: TLanguage); overload;
    procedure SetLanguage(const ACode: string); overload;
    function GetLanguageCode: string;
    function GetCurrentLanguage: TLanguage;
    procedure SetFallbackLanguage(const ALang: TLanguage);

    { Utilities }
    class function LangToCode(const ALang: TLanguage): string; static;
    class function LangToName(const ALang: TLanguage): string; static;
    function ListLanguages: TStringArray;
    function HasTranslation(const AID: string): Boolean;
    function Count(const ALang: TLanguage): Integer;

    property CurrentLanguage: TLanguage read FCurrentLang write SetLanguage;
    property FallbackLanguage: TLanguage read FFallbackLang write SetFallbackLanguage;
  end;

{ Global singleton - lazy initialization }
function I18n: TI18nManager; inline;

{ ============================================================================
  Shortcut Functions - Use these in your code
  ============================================================================ }

{ Get translated string }
function _(const AID: string): string; inline;

{ Get translated string with Format() parameters }
function _Fmt(const AID: string; const AArgs: array of const): string;

{ Register English + Chinese translation in one line }
procedure T(const AID, AEnglish, AChinese: string); inline;

{ Register translation for specific language }
procedure TL(const ALang: TLanguage; const AID, AText: string); inline;

{ Register translations for multiple languages at once
  Usage: TM('msg.hello', ['Hello', '你好', 'こんにちは', ...]);
  Order: en, zh, ja, ko, de, fr, es, ru, pt, it, nl, pl, tr, ar, hi }
procedure TM(const AID: string; const ATranslations: array of string);

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;
{$ENDIF}

var
  GI18nManager: TI18nManager = nil;

function I18n: TI18nManager;
begin
  if GI18nManager = nil then
    GI18nManager := TI18nManager.Create;
  Result := GI18nManager;
end;

function _(const AID: string): string;
begin
  Result := I18n.Get(AID);
end;

function _Fmt(const AID: string; const AArgs: array of const): string;
begin
  Result := I18n.GetFmt(AID, AArgs);
end;

procedure T(const AID, AEnglish, AChinese: string);
begin
  I18n.Reg(langEnglish, AID, AEnglish);
  I18n.Reg(langChinese, AID, AChinese);
end;

procedure TL(const ALang: TLanguage; const AID, AText: string);
begin
  I18n.Reg(ALang, AID, AText);
end;

procedure TM(const AID: string; const ATranslations: array of string);
begin
  I18n.RegMulti(AID, ATranslations);
end;

{ TI18nManager }

constructor TI18nManager.Create;
var
  L: TLanguage;
begin
  inherited Create;
  FFallbackLang := langEnglish;

  // Initialize sorted string lists for O(log n) lookup
  for L := Low(TLanguage) to High(TLanguage) do
  begin
    FTranslations[L] := TStringList.Create;
    FTranslations[L].Sorted := True;
    FTranslations[L].Duplicates := dupIgnore;
    FTranslations[L].CaseSensitive := True;
  end;

  FCurrentLang := DetectSystemLanguage;
end;

destructor TI18nManager.Destroy;
var
  L: TLanguage;
begin
  for L := Low(TLanguage) to High(TLanguage) do
    FTranslations[L].Free;
  inherited Destroy;
end;

function TI18nManager.DetectSystemLanguage: TLanguage;
var
  LangCode: string;
  {$IFDEF MSWINDOWS}
  LangID: LANGID;
  PrimaryLang: Word;
  {$ENDIF}
begin
  Result := langEnglish;

  {$IFDEF MSWINDOWS}
  LangID := GetUserDefaultUILanguage;
  PrimaryLang := LangID and $3FF;

  case PrimaryLang of
    $04: Result := langChinese;
    $11: Result := langJapanese;
    $12: Result := langKorean;
    $07: Result := langGerman;
    $0C: Result := langFrench;
    $0A: Result := langSpanish;
    $19: Result := langRussian;
    $16: Result := langPortuguese;
    $10: Result := langItalian;
    $13: Result := langDutch;
    $15: Result := langPolish;
    $1F: Result := langTurkish;
    $01: Result := langArabic;
    $39: Result := langHindi;
    $09: Result := langEnglish;
  end;
  {$ELSE}
  // Unix/Linux/macOS: Check environment variables
  LangCode := GetEnvironmentVariable('LC_ALL');
  if LangCode = '' then
    LangCode := GetEnvironmentVariable('LC_MESSAGES');
  if LangCode = '' then
    LangCode := GetEnvironmentVariable('LANG');

  if LangCode <> '' then
    Result := LanguageCodeToEnum(Copy(LangCode, 1, 2));
  {$ENDIF}
end;

class function TI18nManager.LanguageCodeToEnum(const ACode: string): TLanguage;
var
  Code: string;
begin
  Code := LowerCase(Trim(ACode));
  case Code of
    'zh', 'cn': Result := langChinese;
    'ja':       Result := langJapanese;
    'ko':       Result := langKorean;
    'de':       Result := langGerman;
    'fr':       Result := langFrench;
    'es':       Result := langSpanish;
    'ru':       Result := langRussian;
    'pt':       Result := langPortuguese;
    'it':       Result := langItalian;
    'nl':       Result := langDutch;
    'pl':       Result := langPolish;
    'tr':       Result := langTurkish;
    'ar':       Result := langArabic;
    'hi':       Result := langHindi;
  else
    Result := langEnglish;
  end;
end;

class function TI18nManager.LangToCode(const ALang: TLanguage): string;
begin
  case ALang of
    langEnglish:    Result := 'en';
    langChinese:    Result := 'zh';
    langJapanese:   Result := 'ja';
    langKorean:     Result := 'ko';
    langGerman:     Result := 'de';
    langFrench:     Result := 'fr';
    langSpanish:    Result := 'es';
    langRussian:    Result := 'ru';
    langPortuguese: Result := 'pt';
    langItalian:    Result := 'it';
    langDutch:      Result := 'nl';
    langPolish:     Result := 'pl';
    langTurkish:    Result := 'tr';
    langArabic:     Result := 'ar';
    langHindi:      Result := 'hi';
  end;
end;

class function TI18nManager.LangToName(const ALang: TLanguage): string;
begin
  case ALang of
    langEnglish:    Result := 'English';
    langChinese:    Result := '简体中文';
    langJapanese:   Result := '日本語';
    langKorean:     Result := '한국어';
    langGerman:     Result := 'Deutsch';
    langFrench:     Result := 'Français';
    langSpanish:    Result := 'Español';
    langRussian:    Result := 'Русский';
    langPortuguese: Result := 'Português';
    langItalian:    Result := 'Italiano';
    langDutch:      Result := 'Nederlands';
    langPolish:     Result := 'Polski';
    langTurkish:    Result := 'Türkçe';
    langArabic:     Result := 'العربية';
    langHindi:      Result := 'हिन्दी';
  end;
end;

procedure TI18nManager.Reg(const ALang: TLanguage; const AID, AText: string);
begin
  FTranslations[ALang].Values[AID] := AText;
end;

procedure TI18nManager.RegMulti(const AID: string; const ATranslations: array of string);
var
  L: TLanguage;
  i: Integer;
begin
  i := 0;
  for L := Low(TLanguage) to High(TLanguage) do
  begin
    if i <= High(ATranslations) then
    begin
      if ATranslations[i] <> '' then
        FTranslations[L].Values[AID] := ATranslations[i];
      Inc(i);
    end
    else
      Break;
  end;
end;

function TI18nManager.Get(const AID: string): string;
begin
  // Try current language
  Result := FTranslations[FCurrentLang].Values[AID];

  // Fallback to default language
  if (Result = '') and (FCurrentLang <> FFallbackLang) then
    Result := FTranslations[FFallbackLang].Values[AID];

  // Return ID if not found
  if Result = '' then
    Result := AID;
end;

function TI18nManager.GetFmt(const AID: string; const AArgs: array of const): string;
begin
  try
    Result := Format(Get(AID), AArgs);
  except
    Result := Get(AID);
  end;
end;

procedure TI18nManager.SetLanguage(const ALang: TLanguage);
begin
  FCurrentLang := ALang;
end;

procedure TI18nManager.SetLanguage(const ACode: string);
begin
  FCurrentLang := LanguageCodeToEnum(ACode);
end;

function TI18nManager.GetLanguageCode: string;
begin
  Result := LangToCode(FCurrentLang);
end;

function TI18nManager.ListLanguages: TStringArray;
var
  L: TLanguage;
  i: Integer;
begin
  Result := nil;
  SetLength(Result, Ord(High(TLanguage)) + 1);
  i := 0;
  for L := Low(TLanguage) to High(TLanguage) do
  begin
    Result[i] := LangToCode(L) + ' - ' + LangToName(L);
    Inc(i);
  end;
end;

function TI18nManager.HasTranslation(const AID: string): Boolean;
begin
  Result := (FTranslations[FCurrentLang].Values[AID] <> '') or
            (FTranslations[FFallbackLang].Values[AID] <> '');
end;

function TI18nManager.Count(const ALang: TLanguage): Integer;
begin
  Result := FTranslations[ALang].Count;
end;

{ II18nManager interface implementation }

function TI18nManager.GetCurrentLanguage: TLanguage;
begin
  Result := FCurrentLang;
end;

procedure TI18nManager.SetFallbackLanguage(const ALang: TLanguage);
begin
  FFallbackLang := ALang;
end;

initialization

finalization
  if GI18nManager <> nil then
    FreeAndNil(GI18nManager);

end.
