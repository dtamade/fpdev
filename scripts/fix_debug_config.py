#!/usr/bin/env python3
"""
自动修复所有 .lpi 文件的 Debug BuildMode 配置
只处理 tests/ 目录下的文件，避免修改第三方源码
"""

import os
import xml.etree.ElementTree as ET
from pathlib import Path
import shutil
from datetime import datetime

def backup_file(file_path):
    """备份原文件"""
    backup_path = f"{file_path}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(file_path, backup_path)
    return backup_path

def create_debug_build_mode():
    """创建标准的Debug BuildMode XML元素"""
    debug_item = ET.Element('Item', Name='Debug')
    
    compiler_options = ET.SubElement(debug_item, 'CompilerOptions')
    ET.SubElement(compiler_options, 'Version', Value='11')
    
    # Target
    target = ET.SubElement(compiler_options, 'Target')
    ET.SubElement(target, 'Filename', Value='bin/$(ProjectName)')
    
    # SearchPaths
    search_paths = ET.SubElement(compiler_options, 'SearchPaths')
    ET.SubElement(search_paths, 'IncludeFiles', Value='$(ProjOutDir);../../src')
    ET.SubElement(search_paths, 'OtherUnitFiles', Value='../../src')
    ET.SubElement(search_paths, 'UnitOutputDirectory', Value='lib/$(TargetCPU)-$(TargetOS)')
    
    # Parsing - 断言
    parsing = ET.SubElement(compiler_options, 'Parsing')
    syntax_options = ET.SubElement(parsing, 'SyntaxOptions')
    ET.SubElement(syntax_options, 'IncludeAssertionCode', Value='True')
    
    # CodeGeneration - 运行时检查
    code_generation = ET.SubElement(compiler_options, 'CodeGeneration')
    checks = ET.SubElement(code_generation, 'Checks')
    ET.SubElement(checks, 'IOChecks', Value='True')
    ET.SubElement(checks, 'RangeChecks', Value='True')
    ET.SubElement(checks, 'OverflowChecks', Value='True')
    ET.SubElement(checks, 'StackChecks', Value='True')
    ET.SubElement(code_generation, 'VerifyObjMethodCallValidity', Value='True')
    
    # Linking - 调试信息
    linking = ET.SubElement(compiler_options, 'Linking')
    debugging = ET.SubElement(linking, 'Debugging')
    ET.SubElement(debugging, 'DebugInfoType', Value='dsDwarf3')
    ET.SubElement(debugging, 'UseHeaptrc', Value='True')
    ET.SubElement(debugging, 'TrashVariables', Value='True')
    ET.SubElement(debugging, 'UseExternalDbgSyms', Value='True')
    
    # Other - 忽略某些消息
    other = ET.SubElement(compiler_options, 'Other')
    compiler_messages = ET.SubElement(other, 'CompilerMessages')
    ET.SubElement(compiler_messages, 'IgnoredMessages', idx5024='True')
    
    return debug_item

def fix_lpi_file(lpi_path):
    """修复单个 .lpi 文件的 Debug 配置"""
    try:
        # 备份原文件
        backup_path = backup_file(lpi_path)
        print(f"  📁 备份: {backup_path}")
        
        # 解析XML
        tree = ET.parse(lpi_path)
        root = tree.getroot()
        
        # 查找或创建 BuildModes
        build_modes = root.find('.//BuildModes')
        if build_modes is None:
            # 在 ProjectOptions 下创建 BuildModes
            project_options = root.find('.//ProjectOptions')
            if project_options is None:
                print(f"  ❌ 无法找到 ProjectOptions 节点")
                return False
            
            build_modes = ET.SubElement(project_options, 'BuildModes')
            
            # 添加 Default BuildMode
            default_item = ET.SubElement(build_modes, 'Item', Name='Default', Default='True')
        
        # 检查是否已有Debug模式
        debug_mode = None
        for item in build_modes.findall('Item'):
            name_attr = item.get('Name')
            if name_attr and name_attr.lower() == 'debug':
                debug_mode = item
                break
        
        if debug_mode is not None:
            # 移除现有的Debug模式
            build_modes.remove(debug_mode)
            print(f"  🔄 移除现有Debug配置")
        
        # 添加标准Debug配置
        debug_item = create_debug_build_mode()
        build_modes.append(debug_item)
        print(f"  ✅ 添加标准Debug配置")
        
        # 保存文件
        tree.write(lpi_path, encoding='UTF-8', xml_declaration=True)
        
        # 格式化XML（简单的缩进）
        format_xml_file(lpi_path)
        
        return True
        
    except Exception as e:
        print(f"  ❌ 处理失败: {str(e)}")
        return False

def format_xml_file(file_path):
    """简单的XML格式化"""
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
        indent_xml(root)
        tree.write(file_path, encoding='UTF-8', xml_declaration=True)
    except:
        pass  # 格式化失败不影响功能

def indent_xml(elem, level=0):
    """递归缩进XML元素"""
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
        for elem in elem:
            indent_xml(elem, level + 1)
        if not elem.tail or not elem.tail.strip():
            elem.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i

def should_process_file(file_path):
    """判断是否应该处理该文件"""
    path_str = str(file_path)
    
    # 只处理 tests/ 目录下的文件
    if not 'tests' in path_str:
        return False
    
    # 排除第三方源码目录
    exclude_dirs = ['sources/', 'reference/']
    for exclude_dir in exclude_dirs:
        if exclude_dir in path_str:
            return False
    
    return True

def main():
    """主函数"""
    project_root = Path('.')
    
    # 查找所有需要处理的 .lpi 文件
    all_lpi_files = list(project_root.rglob('*.lpi'))
    lpi_files = [f for f in all_lpi_files if should_process_file(f)]
    
    print(f"🔍 找到 {len(all_lpi_files)} 个 .lpi 文件")
    print(f"📋 需要处理 {len(lpi_files)} 个测试工程文件")
    print("=" * 80)
    
    success_count = 0
    fail_count = 0
    
    for lpi_file in lpi_files:
        print(f"\n🔧 处理: {lpi_file}")
        if fix_lpi_file(lpi_file):
            success_count += 1
        else:
            fail_count += 1
    
    print(f"\n" + "=" * 80)
    print(f"📊 处理完成:")
    print(f"✅ 成功: {success_count}")
    print(f"❌ 失败: {fail_count}")
    print(f"📁 总计: {len(lpi_files)}")
    
    if success_count > 0:
        print(f"\n🎉 已为 {success_count} 个测试工程添加标准Debug配置！")
        print(f"💡 备份文件已保存，如有问题可以恢复")

if __name__ == '__main__':
    main()
