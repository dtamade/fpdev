#!/usr/bin/env python3
"""
修复测试文件的命名规范问题
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

def fix_variable_naming(file_path):
    """修复单个文件的变量命名规范"""
    print(f"🔧 处理文件: {file_path}")
    
    # 备份文件
    backup_path = backup_file(file_path)
    print(f"  📁 备份: {backup_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except:
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                content = f.read()
        except Exception as e:
            print(f"  ❌ 无法读取文件: {e}")
            return False
    
    original_content = content
    lines = content.split('\n')
    modified_lines = []
    changes_made = []
    
    # 查找局部变量声明并修复
    in_var_section = False
    in_procedure = False
    current_procedure = ""
    
    for i, line in enumerate(lines):
        line_stripped = line.strip()
        modified_line = line
        
        # 检测过程/函数开始
        if re.match(r'^\s*(procedure|function)\s+', line_stripped, re.IGNORECASE):
            in_procedure = True
            match = re.match(r'^\s*(procedure|function)\s+(\w+)', line_stripped, re.IGNORECASE)
            if match:
                current_procedure = match.group(2)
        
        # 检测var关键字
        if re.match(r'^\s*var\s*$', line_stripped, re.IGNORECASE) and in_procedure:
            in_var_section = True
        
        # 检测var段结束
        elif in_var_section and (re.match(r'^\s*(begin|const|type)\s*$', line_stripped, re.IGNORECASE) or 
                                line_stripped.startswith('procedure') or line_stripped.startswith('function')):
            in_var_section = False
        
        # 修复局部变量命名
        if in_var_section and line_stripped and not line_stripped.startswith('//'):
            # 匹配变量声明 (变量名: 类型)
            var_match = re.match(r'^(\s*)(\w+(?:\s*,\s*\w+)*)\s*:\s*(.*)$', line)
            if var_match:
                indent = var_match.group(1)
                var_names_str = var_match.group(2)
                type_part = var_match.group(3)
                
                var_names = [name.strip() for name in var_names_str.split(',')]
                new_var_names = []
                
                for var_name in var_names:
                    if not var_name.startswith('L') and len(var_name) > 1:
                        new_var_name = 'L' + var_name
                        new_var_names.append(new_var_name)
                        changes_made.append(f"    变量 {var_name} -> {new_var_name} (行 {i+1})")
                        
                        # 在整个文件中替换这个变量的所有使用
                        # 使用词边界确保精确匹配
                        pattern = r'\b' + re.escape(var_name) + r'\b'
                        content = re.sub(pattern, new_var_name, content)
                    else:
                        new_var_names.append(var_name)
                
                if new_var_names != var_names:
                    modified_line = f"{indent}{', '.join(new_var_names)}: {type_part}"
        
        # 检测过程/函数结束
        if re.match(r'^\s*end\s*;\s*$', line_stripped) and in_procedure:
            in_procedure = False
            in_var_section = False
            current_procedure = ""
        
        modified_lines.append(modified_line)
    
    # 如果有修改，重新构建内容
    if changes_made:
        # 重新读取文件并应用所有变量名替换
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except:
            with open(file_path, 'r', encoding='latin-1') as f:
                content = f.read()
        
        # 应用所有变量重命名
        for change in changes_made:
            # 从变更信息中提取原变量名和新变量名
            match = re.search(r'变量 (\w+) -> (\w+)', change)
            if match:
                old_name = match.group(1)
                new_name = match.group(2)
                # 使用词边界确保精确匹配
                pattern = r'\b' + re.escape(old_name) + r'\b'
                content = re.sub(pattern, new_name, content)
        
        # 保存修改后的文件
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
        except:
            with open(file_path, 'w', encoding='latin-1') as f:
                f.write(content)
        
        print(f"  ✅ 完成修复，共 {len(changes_made)} 处变更:")
        for change in changes_made:
            print(f"  {change}")
        return True
    else:
        print(f"  ✅ 无需修改")
        return True

def rename_test_files():
    """重命名不符合规范的测试文件"""
    tests_dir = Path('tests')
    pas_files = list(tests_dir.rglob('*.pas'))
    
    renames = []
    
    for pas_file in pas_files:
        filename = pas_file.name
        
        # 检查是否是测试文件但不符合命名规范
        if any(keyword in filename.lower() for keyword in ['test', 'case']):
            if not filename.endswith('.test.pas') and not any(pattern in filename.lower() for pattern in ['.testcase.', '.tests.']):
                # 建议重命名
                if filename.startswith('test_'):
                    # test_xxx.pas -> xxx.test.pas
                    new_name = filename[5:].replace('.pas', '.test.pas')
                elif filename.endswith('_test.pas'):
                    # xxx_test.pas -> xxx.test.pas
                    new_name = filename.replace('_test.pas', '.test.pas')
                else:
                    # xxx.pas -> xxx.test.pas
                    new_name = filename.replace('.pas', '.test.pas')
                
                renames.append((pas_file, pas_file.parent / new_name))
    
    if renames:
        print(f"\n📝 建议重命名的文件:")
        for old_path, new_path in renames:
            print(f"  {old_path.relative_to(Path('.'))} -> {new_path.relative_to(Path('.'))}")
        
        response = input(f"\n是否执行重命名? (y/N): ")
        if response.lower() == 'y':
            for old_path, new_path in renames:
                try:
                    old_path.rename(new_path)
                    print(f"  ✅ 重命名: {old_path.name} -> {new_path.name}")
                except Exception as e:
                    print(f"  ❌ 重命名失败: {old_path.name} - {e}")
    else:
        print(f"\n✅ 所有测试文件命名都符合规范")

def main():
    """主函数"""
    print("🔧 开始修复测试文件命名规范...")
    
    # 1. 修复变量命名
    tests_dir = Path('tests')
    pas_files = list(tests_dir.rglob('*.pas'))
    
    # 只处理测试相关文件
    test_files = [f for f in pas_files if any(keyword in f.name.lower() for keyword in ['test', 'case'])]
    
    print(f"📋 找到 {len(test_files)} 个测试文件")
    print("=" * 80)
    
    success_count = 0
    fail_count = 0
    
    for test_file in test_files:
        if fix_variable_naming(test_file):
            success_count += 1
        else:
            fail_count += 1
    
    print(f"\n" + "=" * 80)
    print(f"📊 变量命名修复完成:")
    print(f"✅ 成功: {success_count}")
    print(f"❌ 失败: {fail_count}")
    print(f"📁 总计: {len(test_files)}")
    
    # 2. 文件重命名建议
    rename_test_files()
    
    print(f"\n🎉 命名规范修复完成！")
    print(f"💡 备份文件已保存，如有问题可以恢复")

if __name__ == '__main__':
    main()
