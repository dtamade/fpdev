unit fpdev.cmd.package.info;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry, fpdev.package.manager;

type
  TPackageInfoCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpjson,
  fpdev.command.utils,
  fpdev.package.types,
  fpdev.package.infocommandflow;

function TPackageInfoCommand.Name: string; begin Result := 'info'; end;
function TPackageInfoCommand.Aliases: TStringArray; begin Result := nil; end;
function TPackageInfoCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function PackageInfoFactory: ICommand;
begin
  Result := TPackageInfoCommand.Create;
end;

function TPackageInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TPackageManager;
  LPlan: TPackageInfoCommandPlan;
  LShouldExit: Boolean;
  LJsonOutput: Boolean;
  Info: TPackageInfo;
  JObj, JDeps: TJSONObject;
  JArr: TJSONArray;
  I: Integer;
begin
  LJsonOutput := HasFlag(AParams, 'json');

  Result := PreparePackageInfoCommandPlanCore(
    AParams,
    Ctx.Out,
    Ctx.Err,
    LPlan,
    LShouldExit
  );
  if LShouldExit then
    Exit(Result);

  LMgr := TPackageManager.Create(Ctx.Config);
  try
    if LJsonOutput then
    begin
      Info := LMgr.GetPackageInfoPublic(LPlan.PackageName);
      if Info.Name = '' then
      begin
        if Ctx.Err <> nil then
          Ctx.Err.WriteLn('Error: package not found: ' + LPlan.PackageName);
        Exit(1);
      end;
      JObj := TJSONObject.Create;
      try
        JObj.Add('name', Info.Name);
        JObj.Add('version', Info.Version);
        JObj.Add('description', Info.Description);
        JObj.Add('installed', Info.Installed);
        if Info.InstallPath <> '' then
          JObj.Add('installPath', Info.InstallPath);
        if Info.Author <> '' then
          JObj.Add('author', Info.Author);
        if Info.License <> '' then
          JObj.Add('license', Info.License);
        if Info.Homepage <> '' then
          JObj.Add('homepage', Info.Homepage);
        JArr := TJSONArray.Create;
        for I := 0 to High(Info.Dependencies) do
          JArr.Add(Info.Dependencies[I]);
        JObj.Add('dependencies', JArr);
        if Ctx.Out <> nil then
          Ctx.Out.WriteLn(JObj.FormatJSON);
      finally
        JObj.Free;
      end;
      Exit(0);
    end;

    Result := ExecutePackageInfoCommandPlanCore(
      LPlan,
      Ctx.Out,
      Ctx.Err,
      @LMgr.GetInstalledPackageList,
      @LMgr.ShowPackageInfo
    );
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','info'], @PackageInfoFactory, []);

end.
