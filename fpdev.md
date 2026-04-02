# fpdev

## system
系统维护命令。

### help
显示帮助信息：`fpdev system help`

### version
显示版本信息和运行时变量：`fpdev system version`

### index update
更新索引数据库：`fpdev system index update`

## fpc

### install <version>
安装指定版本 fpc。

### uninstall <version>
卸载指定版本 fpc。

### list
列出所有已安装的 fpc。

### use <version>
切换当前使用的 fpc 版本。

### update <version>
从源码更新构建 fpc：`fpdev fpc update <version>`

## lazarus

### install <version>
安装指定版本的 Lazarus。

### uninstall <version>
卸载指定版本的 Lazarus。

### list
列出所有已安装的 Lazarus。

### update <version>
从仓库代码更新指定版本的 Lazarus：`fpdev lazarus update <version>`

### use <version>
切换当前使用的 Lazarus 版本。

### run [version]
运行 Lazarus。

## cross
交叉环境。

### install <targetOS>-<targetCPU>-[version]
安装指定平台的交叉环境。

### uninstall <targetOS>-<targetCPU>-[version]
卸载指定交叉编译环境。

### list
列出所有已安装的交叉编译环境。

### update <targetOS>-<targetCPU>-[version]
更新指定交叉编译环境：`fpdev cross update <targetOS>-<targetCPU>-[version]`

## package
组件包管理。

### install <package>-<version>
安装指定的组件包。

### uninstall <package>
卸载指定的组件包。

### list
列出所有已安装的组件包。

### search <package>
搜索可用的组件包。

### update <package>
更新包：`fpdev package update <package>`

## project
项目管理。

### new <project>
创建一个新的 fpc 项目。

### build
编译当前项目。

### run
编译并运行当前项目。

### clean
清理当前项目的构建文件。

### test
运行当前项目的测试。
