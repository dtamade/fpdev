unit fpdev.cmd.help;

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.help

帮助


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$mode objfpc}{$H+}

interface

uses
  sysutils,
  fpdev.terminal,
  fpdev.command.registry,
  fpdev.command.intf;

procedure ListChildrenDynamic(const PathParts: array of string);
function PrintUsage(const Parts: array of string): Boolean;
procedure execute(const aParams: array of string);

implementation

procedure ListChildrenDynamic(const PathParts: array of string);
var
  children: TStringArray;
  i: Integer;
begin
  children := GlobalCommandRegistry.ListChildren(PathParts);
  if Length(children) = 0 then
  begin
    WriteLn('未找到命令或无子命令。');
    Exit;
  end;
  WriteLn('可用子命令:');
  for i := 0 to High(children) do
    WriteLn('  ', children[i]);
end;

function PrintUsage(const Parts: array of string): Boolean;
var
  cmd, sub, sub2: string;
begin
  Result := False;
  if Length(Parts)=0 then Exit(False);
  cmd := LowerCase(Parts[0]);
  if Length(Parts) > 1 then sub := LowerCase(Parts[1]) else sub := '';
  if Length(Parts) > 2 then sub2 := LowerCase(Parts[2]) else sub2 := '';

  if cmd = 'help' then
  begin
    WriteLn('用法: fpdev help [command [subcommand]]');
    WriteLn('示例:');
    WriteLn('  fpdev help fpc');
    WriteLn('  fpdev help lazarus');
    Exit(True);
  end
  else if cmd = 'version' then
  begin
    WriteLn('用法: fpdev version');
    Exit(True);
  end
  else if cmd = 'fpc' then
  begin
    if (sub = 'install') then
    begin
      WriteLn('用法: fpdev fpc install <version> [--from-source] [--jobs=<n>] [--prefix=<dir>]');
      WriteLn('示例: fpdev fpc install 3.2.2 --from-source --jobs=4 --prefix=C:/toolchains/fpc-3.2.2');
      Exit(True);
    end
    else if (sub = 'list') then
    begin
      WriteLn('用法: fpdev fpc list [--all]');
      Exit(True);
    end
    else if (sub = 'use') or (sub = 'default') then
    begin
      WriteLn('用法: fpdev fpc use <version>   (别名: default)');
      Exit(True);
    end
    else if (sub = 'current') then
    begin
      WriteLn('用法: fpdev fpc current');
      Exit(True);
    end
    else if (sub = 'show') then
    begin
      WriteLn('用法: fpdev fpc show <version>');
      Exit(True);
    end
    else if (sub = 'doctor') or (sub = 'update') then
    begin
      WriteLn('用法: fpdev fpc ', sub);
      Exit(True);
    end
    else
    begin
      WriteLn('FPC 管理常用子命令: install, list, use(default), current, show, doctor, update');
      WriteLn('示例:');
      WriteLn('  fpdev fpc install 3.2.2 --from-source');
      WriteLn('  fpdev fpc use 3.2.2');
      Exit(True);
    end;
  end
  else if cmd = 'lazarus' then
  begin
    if (sub = 'install') then
    begin
      WriteLn('用法: fpdev lazarus install <version> [--from-source]');
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'current') then
    begin
      WriteLn('用法: fpdev lazarus ', sub);
      Exit(True);
    end
    else if (sub = 'use') or (sub = 'default') then
    begin
      WriteLn('用法: fpdev lazarus use <version>   (别名: default)');
      Exit(True);
    end
    else if (sub = 'run') then
    begin
      WriteLn('用法: fpdev lazarus run');
      Exit(True);
    end
    else
    begin
      WriteLn('Lazarus 管理常用子命令: install, list, use(default), current, run');
      WriteLn('示例:');
      WriteLn('  fpdev lazarus install 3.0 --from-source');
      WriteLn('  fpdev lazarus use 3.0');
      Exit(True);
    end;
  end
  else if cmd = 'project' then
  begin
    if (sub = 'new') then
    begin
      WriteLn('用法: fpdev project new <template> <name>');
      WriteLn('示例: fpdev project new console hello-world');
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'build') or (sub = 'clean') then
    begin
      WriteLn('用法: fpdev project ', sub);
      Exit(True);
    end
    else
    begin
      WriteLn('项目管理常用子命令: new, list, build, clean');
      WriteLn('示例: fpdev project new gui myapp');
      Exit(True);
    end;
  end
  else if cmd = 'package' then
  begin
    if (sub = 'install') then
    begin
      WriteLn('用法: fpdev package install <package>');
      Exit(True);
    end
    else if (sub = 'list') then
    begin
      WriteLn('用法: fpdev package list [--all]');
      Exit(True);
    end
    else if (sub = 'search') then
    begin
      WriteLn('用法: fpdev package search <keyword>');
      WriteLn('示例: fpdev package search json');
      Exit(True);
    end
    else if (sub = 'repo') then
    begin
      if (sub2 = 'add') then
      begin
        WriteLn('用法: fpdev package repo add <name> <url>');
        WriteLn('示例: fpdev package repo add custom https://example.com/repo');
        Exit(True);
      end
      else if (sub2 = 'remove') or (sub2 = 'rm') or (sub2 = 'del') then
      begin
        WriteLn('用法: fpdev package repo remove <name>   (别名: rm, del)');
        Exit(True);
      end
      else if (sub2 = 'list') or (sub2 = 'ls') then
      begin
        WriteLn('用法: fpdev package repo list   (别名: ls)');
        Exit(True);
      end
      else
      begin
        WriteLn('用法:');
        WriteLn('  fpdev package repo add <name> <url>');
        WriteLn('  fpdev package repo remove <name>   (别名: rm, del)');
        WriteLn('  fpdev package repo list           (别名: ls)');
        Exit(True);
      end;
    end
    else
    begin
      WriteLn('包管理常用子命令: install, list, search, repo');
      Exit(True);
    end;
  end
  else if cmd = 'cross' then
  begin
  else if cmd = 'repo' then
  begin
    if (sub = 'add') then
    begin
      WriteLn('用法: fpdev repo add <name> <index_url_or_path>');
      Exit(True);
    end
    else if (sub = 'remove') or (sub = 'rm') or (sub = 'del') then
    begin
      WriteLn('用法: fpdev repo remove <name>   (别名: rm, del)');
      Exit(True);
    end
    else if (sub = 'list') or (sub = 'ls') then
    begin
      WriteLn('用法: fpdev repo list   (别名: ls)');
      Exit(True);
    end
    else if (sub = 'show') then
    begin
      WriteLn('用法: fpdev repo show <name>');
      Exit(True);
    end
    else if (sub = 'versions') then
    begin
      WriteLn('用法: fpdev repo versions fpc [--repo=<name|url|path>] [--os=<os>] [--arch=<arch>] [--limit=N] [--json]');
      Exit(True);
    end
    else if (sub = 'default') then
    begin
      WriteLn('用法: fpdev repo default <name>   # 切换默认仓库镜像');
      Exit(True);
    end
    else
    begin
      WriteLn('仓库管理子命令: add, remove(rm,del), list(ls), show, versions');
      Exit(True);
    end;
  end;
    if (sub = 'list') then
    begin
      WriteLn('用法: fpdev cross list [--all]');
      Exit(True);
    end
    else if (sub = 'install') then
    begin
      WriteLn('用法: fpdev cross install <target>');
      WriteLn('示例: fpdev cross install win64');
      Exit(True);
    end
    else if (sub = 'configure') then
    begin
      WriteLn('用法: fpdev cross configure <target> --binutils=<path> --libraries=<path>');
      Exit(True);
    end
    else
    begin
      WriteLn('交叉编译常用子命令: list, install, configure');
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure execute(const aParams: array of string);
var
  LParamCount: Integer;
begin
  LParamCount := Length(aParams);

  if LParamCount > 0 then
  begin
    // 优先打印常用命令用法/示例
    if PrintUsage(aParams) then Exit;
    // 否则列出子命令
    ListChildrenDynamic(aParams);
    Exit;
  end;

  WriteLn('FPDev - Free Pascal Development Tool');
  WriteLn('');
  WriteLn('用法: fpdev [command] [options]');
  WriteLn('');
  ListChildrenDynamic([]);
  WriteLn('');
  WriteLn('维护开关:');
  WriteLn('  --check-toolchain');
  WriteLn('  --check-policy <src>');
  WriteLn('  --fetch-tool <name> <ver> <os> <arch> --manifest <path> [--dest <zip>]');
  WriteLn('  --extract-zip <zip> <dest>');
  WriteLn('  --ensure-source <name> <ver> --local <dir|zip> [--sha256 <hex>] [--strict]');
  WriteLn('  --import-bundle <dir|zip>');
end;

end.