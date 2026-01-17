unit fpdev.i18n;

{$mode objfpc}{$H+}

(*
  fpdev i18n wrapper - Wraps the standalone fpc.i18n library.
*)

interface

uses
  fpc.i18n;

type
  { Re-export types from fpc.i18n }
  TLanguage = fpc.i18n.TLanguage;
  TI18nManager = fpc.i18n.TI18nManager;

  { Type for batch registration }
  TTranslation = record
    ID: string;
    Text: string;
  end;
  TTranslationArray = array of TTranslation;

const
  { Re-export language constants }
  langEnglish = fpc.i18n.langEnglish;
  langChinese = fpc.i18n.langChinese;
  langJapanese = fpc.i18n.langJapanese;
  langKorean = fpc.i18n.langKorean;
  langGerman = fpc.i18n.langGerman;
  langFrench = fpc.i18n.langFrench;
  langSpanish = fpc.i18n.langSpanish;
  langRussian = fpc.i18n.langRussian;

{ Re-export functions from fpc.i18n }
function I18n: TI18nManager; inline;
function _(const AID: string): string; inline;
function _Fmt(const AID: string; const AArgs: array of const): string;
procedure T(const AID, AEnglish, AChinese: string); inline;
function LanguageToCode(const ALang: TLanguage): string; inline;

implementation

function I18n: TI18nManager;
begin
  Result := fpc.i18n.I18n;
end;

function _(const AID: string): string;
begin
  Result := fpc.i18n._(AID);
end;

function _Fmt(const AID: string; const AArgs: array of const): string;
begin
  Result := fpc.i18n._Fmt(AID, AArgs);
end;

procedure T(const AID, AEnglish, AChinese: string);
begin
  fpc.i18n.T(AID, AEnglish, AChinese);
end;

function LanguageToCode(const ALang: TLanguage): string;
begin
  Result := TI18nManager.LangToCode(ALang);
end;

end.
