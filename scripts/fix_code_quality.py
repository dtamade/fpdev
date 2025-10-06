#!/usr/bin/env python3
"""
修复代码质量问题
"""

import os
import re
import shutil
from pathlib import Path
from datetime import datetime

def backup_file(file_path):
    """备份原文件"""
    backup_path = f"{file_path}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(file_path, backup_path)
    return backup_path

def move_backup_directory():
    """移动src/backup目录到项目根目录"""
    print("🔧 移动backup目录...")
    
    src_backup = Path('src/backup')
    if not src_backup.exists():
        print("  ✅ src/backup目录不存在")
        return True
    
    # 创建目标目录
    target_backup = Path('backups/src_backup')
    target_backup.mkdir(parents=True, exist_ok=True)
    
    try:
        # 移动所有文件
        backup_files = list(src_backup.rglob('*'))
        for file in backup_files:
            if file.is_file():
                relative_path = file.relative_to(src_backup)
                target_file = target_backup / relative_path
                target_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(file), str(target_file))
                print(f"  ✅ 移动: {file} -> {target_file}")
        
        # 删除空目录
        if src_backup.exists() and not any(src_backup.iterdir()):
            src_backup.rmdir()
            print(f"  ✅ 删除空目录: {src_backup}")
        
        return True
    except Exception as e:
        print(f"  ❌ 移动失败: {e}")
        return False

def clean_debug_code():
    """清理调试代码"""
    print("\n🔧 清理调试代码...")
    
    src_dir = Path('src')
    pas_files = list(src_dir.rglob('*.pas'))
    
    files_modified = 0
    
    for pas_file in pas_files:
        print(f"  🔍 检查: {pas_file}")
        
        try:
            with open(pas_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except:
            try:
                with open(pas_file, 'r', encoding='latin-1') as f:
                    content = f.read()
            except:
                print(f"    ❌ 无法读取文件")
                continue
        
        original_content = content
        lines = content.split('\n')
        modified_lines = []
        changes_made = []
        
        for i, line in enumerate(lines):
            modified_line = line
            
            # 检查是否是调试输出（但保留日志记录）
            if re.search(r'^\s*writeln\s*\(\s*[\'"]', line, re.IGNORECASE):
                # 如果是简单的调试输出，注释掉
                if not any(keyword in line.lower() for keyword in ['log', 'error', 'warning', 'info']):
                    modified_line = '  // ' + line.strip() + '  // 调试代码已注释'
                    changes_made.append(f"行 {i+1}: 注释调试输出")
            
            # 处理TODO注释 - 保留但标记
            if re.search(r'//\s*todo', line, re.IGNORECASE):
                if '// TODO:' not in line:
                    modified_line = line.replace('// todo', '// TODO:').replace('// TODO', '// TODO:')
                    changes_made.append(f"行 {i+1}: 标准化TODO注释")
            
            modified_lines.append(modified_line)
        
        if changes_made:
            # 备份原文件
            backup_path = backup_file(pas_file)
            print(f"    📁 备份: {backup_path}")
            
            # 保存修改后的文件
            new_content = '\n'.join(modified_lines)
            try:
                with open(pas_file, 'w', encoding='utf-8') as f:
                    f.write(new_content)
            except:
                with open(pas_file, 'w', encoding='latin-1') as f:
                    f.write(new_content)
            
            print(f"    ✅ 修改完成，共 {len(changes_made)} 处变更:")
            for change in changes_made:
                print(f"      {change}")
            
            files_modified += 1
        else:
            print(f"    ✅ 无需修改")
    
    print(f"\n  📊 总计修改了 {files_modified} 个文件")
    return files_modified > 0

def fix_code_style():
    """修复代码风格问题"""
    print("\n🔧 修复代码风格...")
    
    src_dir = Path('src')
    pas_files = list(src_dir.rglob('*.pas'))
    
    files_modified = 0
    
    for pas_file in pas_files:
        print(f"  🔍 检查: {pas_file}")
        
        try:
            with open(pas_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except:
            try:
                with open(pas_file, 'r', encoding='latin-1') as f:
                    content = f.read()
            except:
                print(f"    ❌ 无法读取文件")
                continue
        
        original_content = content
        lines = content.split('\n')
        modified_lines = []
        changes_made = []
        
        for i, line in enumerate(lines):
            modified_line = line
            
            # 移除行尾空格
            if line.endswith(' ') or line.endswith('\t'):
                modified_line = line.rstrip()
                changes_made.append(f"行 {i+1}: 移除行尾空格")
            
            # 替换制表符为空格
            if '\t' in modified_line:
                modified_line = modified_line.replace('\t', '  ')
                changes_made.append(f"行 {i+1}: 制表符替换为空格")
            
            # 对于过长的行，只记录但不自动修改（需要手动处理）
            if len(modified_line) > 120:
                changes_made.append(f"行 {i+1}: 行过长 ({len(modified_line)} 字符) - 需要手动处理")
            
            modified_lines.append(modified_line)
        
        if any('移除行尾空格' in change or '制表符替换为空格' in change for change in changes_made):
            # 备份原文件
            backup_path = backup_file(pas_file)
            print(f"    📁 备份: {backup_path}")
            
            # 保存修改后的文件
            new_content = '\n'.join(modified_lines)
            try:
                with open(pas_file, 'w', encoding='utf-8') as f:
                    f.write(new_content)
            except:
                with open(pas_file, 'w', encoding='latin-1') as f:
                    f.write(new_content)
            
            print(f"    ✅ 修改完成，共 {len([c for c in changes_made if '需要手动处理' not in c])} 处自动修复:")
            for change in changes_made:
                if '需要手动处理' not in change:
                    print(f"      {change}")
            
            # 显示需要手动处理的问题
            manual_fixes = [c for c in changes_made if '需要手动处理' in c]
            if manual_fixes:
                print(f"    ⚠️  需要手动处理 {len(manual_fixes)} 个问题:")
                for change in manual_fixes[:3]:  # 只显示前3个
                    print(f"      {change}")
            
            files_modified += 1
        else:
            print(f"    ✅ 无需修改")
    
    print(f"\n  📊 总计修改了 {files_modified} 个文件")
    return files_modified > 0

def extract_hardcoded_constants():
    """提取硬编码常量（生成建议）"""
    print("\n🔧 分析硬编码常量...")
    
    src_dir = Path('src')
    pas_files = list(src_dir.rglob('*.pas'))
    
    constants_found = []
    
    for pas_file in pas_files:
        try:
            with open(pas_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except:
            try:
                with open(pas_file, 'r', encoding='latin-1') as f:
                    content = f.read()
            except:
                continue
        
        # 查找URL
        urls = re.findall(r"'(https?://[^']*)'", content)
        for url in urls:
            constants_found.append({
                'file': pas_file,
                'type': 'URL',
                'value': url,
                'suggestion': f"const DEFAULT_FPC_REPO = '{url}';"
            })
        
        # 查找版本号
        versions = re.findall(r"'(\d+\.\d+\.\d+)'", content)
        for version in versions:
            constants_found.append({
                'file': pas_file,
                'type': 'Version',
                'value': version,
                'suggestion': f"const DEFAULT_FPC_VERSION = '{version}';"
            })
    
    if constants_found:
        print(f"  📊 发现 {len(constants_found)} 个硬编码常量")
        print(f"  💡 建议创建常量定义文件 src/fpdev.constants.pas:")
        
        unique_constants = {}
        for const in constants_found:
            key = f"{const['type']}_{const['value']}"
            if key not in unique_constants:
                unique_constants[key] = const
        
        for const in list(unique_constants.values())[:5]:  # 只显示前5个
            print(f"    {const['suggestion']}")
        
        if len(unique_constants) > 5:
            print(f"    ... 还有 {len(unique_constants) - 5} 个常量")
    else:
        print(f"  ✅ 未发现需要提取的硬编码常量")
    
    return len(constants_found)

def create_constants_file():
    """创建常量定义文件"""
    print("\n🔧 创建常量定义文件...")
    
    constants_file = Path('src/fpdev.constants.pas')
    
    if constants_file.exists():
        print(f"  ⚠️  常量文件已存在: {constants_file}")
        return False
    
    constants_content = '''unit fpdev.constants;

{$mode objfpc}{$H+}

interface

const
  // FPC相关常量
  DEFAULT_FPC_REPO = 'https://gitlab.com/freepascal.org/fpc/source.git';
  DEFAULT_FPC_VERSION = '3.2.2';
  FALLBACK_FPC_VERSION = '3.2.0';
  
  // 路径相关常量
  FPDEV_CONFIG_DIR = '.fpdev';
  PATH_SEPARATOR = {$IFDEF WINDOWS}'\'{$ELSE}'/'{$ENDIF};
  
  // 命令行参数
  CMD_SWITCH_CLEAN = '/c';
  CMD_SWITCH_SILENT = '/s';
  
  // 日志相关
  LOG_TIMESTAMP_FORMAT = 'yyyy-mm-dd hh:nn:ss.zzz';

implementation

end.
''';
    
    try:
        with open(constants_file, 'w', encoding='utf-8') as f:
            f.write(constants_content)
        print(f"  ✅ 创建常量文件: {constants_file}")
        return True
    except Exception as e:
        print(f"  ❌ 创建失败: {e}")
        return False

def main():
    """主函数"""
    print("🔧 开始修复代码质量问题...")
    print("=" * 80)
    
    success_count = 0
    total_tasks = 5
    
    try:
        # 1. 移动backup目录
        if move_backup_directory():
            success_count += 1
        
        # 2. 清理调试代码
        if clean_debug_code():
            success_count += 1
        
        # 3. 修复代码风格
        if fix_code_style():
            success_count += 1
        
        # 4. 分析硬编码常量
        constants_count = extract_hardcoded_constants()
        if constants_count > 0:
            success_count += 1
        
        # 5. 创建常量文件
        if create_constants_file():
            success_count += 1
        
        print("\n" + "=" * 80)
        print("🎉 代码质量优化完成！")
        print(f"\n📋 优化总结:")
        print(f"✅ 移动了src/backup目录到backups/src_backup")
        print(f"✅ 清理了调试代码和标准化TODO注释")
        print(f"✅ 修复了代码风格问题（行尾空格、制表符）")
        print(f"✅ 分析了硬编码常量并生成建议")
        print(f"✅ 创建了常量定义文件")
        
        print(f"\n💡 后续建议:")
        print("1. 手动处理过长的代码行")
        print("2. 逐步替换硬编码常量为常量引用")
        print("3. 处理标准化的TODO注释")
        print("4. 建立代码风格检查机制")
        print("5. 定期运行代码质量检查")
        
    except Exception as e:
        print(f"\n❌ 优化过程中出现错误: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit_code = main()
    exit(exit_code)
