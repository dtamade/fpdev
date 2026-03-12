{ ===== Registration ===== }

procedure TestPackageRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundInstall, FoundUninstall, FoundUpdate, FoundList: Boolean;
  FoundSearch, FoundInfo, FoundPublish, FoundClean: Boolean;
  FoundInstallLocal, FoundHelp, FoundDeps, FoundWhy, FoundCreate: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['package']);
  FoundInstall := False; FoundUninstall := False; FoundUpdate := False;
  FoundList := False; FoundSearch := False; FoundInfo := False;
  FoundPublish := False; FoundClean := False; FoundInstallLocal := False;
  FoundHelp := False; FoundDeps := False; FoundWhy := False; FoundCreate := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'install' then FoundInstall := True;
    if Children[I] = 'uninstall' then FoundUninstall := True;
    if Children[I] = 'update' then FoundUpdate := True;
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'search' then FoundSearch := True;
    if Children[I] = 'info' then FoundInfo := True;
    if Children[I] = 'publish' then FoundPublish := True;
    if Children[I] = 'clean' then FoundClean := True;
    if Children[I] = 'install-local' then FoundInstallLocal := True;
    if Children[I] = 'help' then FoundHelp := True;
    if Children[I] = 'deps' then FoundDeps := True;
    if Children[I] = 'why' then FoundWhy := True;
    if Children[I] = 'create' then FoundCreate := True;
  end;

  Check('package install registered', FoundInstall);
  Check('package uninstall registered', FoundUninstall);
  Check('package update registered', FoundUpdate);
  Check('package list registered', FoundList);
  Check('package search registered', FoundSearch);
  Check('package info registered', FoundInfo);
  Check('package publish registered', FoundPublish);
  Check('package clean registered', FoundClean);
  Check('package install-local registered', FoundInstallLocal);
  Check('package help registered', FoundHelp);
  Check('package deps registered', FoundDeps);
  Check('package why registered', FoundWhy);
  Check('package create not registered', not FoundCreate);
end;

procedure TestPackageRepoRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundList, FoundAdd, FoundRemove, FoundUpdate: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['package', 'repo']);
  FoundList := False; FoundAdd := False; FoundRemove := False; FoundUpdate := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'add' then FoundAdd := True;
    if Children[I] = 'remove' then FoundRemove := True;
    if Children[I] = 'update' then FoundUpdate := True;
  end;

  Check('package repo list registered', FoundList);
  Check('package repo add registered', FoundAdd);
  Check('package repo remove registered', FoundRemove);
  Check('package repo update registered', FoundUpdate);
end;
