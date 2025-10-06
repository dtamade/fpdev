#!/usr/bin/env python3
"""
分析所有 .lpi 文件的 Debug BuildMode 配置状态
"""

import os
import xml.etree.ElementTree as ET
from pathlib import Path

def analyze_lpi_file(lpi_path):
    """分析单个 .lpi 文件的 Debug 配置"""
    try:
        tree = ET.parse(lpi_path)
        root = tree.getroot()
        
        # 查找 BuildModes
        build_modes = root.find('.//BuildModes')
        if build_modes is None:
            return {
                'file': lpi_path,
                'has_debug_mode': False,
                'debug_config': {},
                'issues': ['No BuildModes section found']
            }
        
        # 查找 Debug BuildMode
        debug_mode = None
        for item in build_modes.findall('Item'):
            name_attr = item.get('Name')
            if name_attr and name_attr.lower() == 'debug':
                debug_mode = item
                break
        
        if debug_mode is None:
            return {
                'file': lpi_path,
                'has_debug_mode': False,
                'debug_config': {},
                'issues': ['No Debug BuildMode found']
            }
        
        # 分析 Debug 配置
        compiler_options = debug_mode.find('CompilerOptions')
        if compiler_options is None:
            return {
                'file': lpi_path,
                'has_debug_mode': True,
                'debug_config': {},
                'issues': ['Debug mode has no CompilerOptions']
            }
        
        config = {}
        issues = []
        
        # 检查断言
        parsing = compiler_options.find('.//Parsing/SyntaxOptions')
        if parsing is not None:
            assertion = parsing.find('IncludeAssertionCode')
            config['assertions'] = assertion is not None and assertion.get('Value') == 'True'
        else:
            config['assertions'] = False
            issues.append('No assertion configuration found')
        
        # 检查运行时检查
        checks = compiler_options.find('.//CodeGeneration/Checks')
        if checks is not None:
            config['io_checks'] = checks.find('IOChecks') is not None and checks.find('IOChecks').get('Value') == 'True'
            config['range_checks'] = checks.find('RangeChecks') is not None and checks.find('RangeChecks').get('Value') == 'True'
            config['overflow_checks'] = checks.find('OverflowChecks') is not None and checks.find('OverflowChecks').get('Value') == 'True'
            config['stack_checks'] = checks.find('StackChecks') is not None and checks.find('StackChecks').get('Value') == 'True'
        else:
            config.update({'io_checks': False, 'range_checks': False, 'overflow_checks': False, 'stack_checks': False})
            issues.append('No runtime checks configuration found')
        
        # 检查调试信息
        debugging = compiler_options.find('.//Linking/Debugging')
        if debugging is not None:
            debug_info = debugging.find('DebugInfoType')
            config['debug_info'] = debug_info.get('Value') if debug_info is not None else 'None'
            
            heaptrc = debugging.find('UseHeaptrc')
            config['heaptrc'] = heaptrc is not None and heaptrc.get('Value') == 'True'
            
            trash_vars = debugging.find('TrashVariables')
            config['trash_variables'] = trash_vars is not None and trash_vars.get('Value') == 'True'
        else:
            config.update({'debug_info': 'None', 'heaptrc': False, 'trash_variables': False})
            issues.append('No debugging configuration found')
        
        # 检查是否符合标准
        if config.get('debug_info') != 'dsDwarf3':
            issues.append(f"Debug info should be dsDwarf3, found: {config.get('debug_info')}")
        
        if not config.get('heaptrc'):
            issues.append('HeapTrc should be enabled')
        
        if not all([config.get('assertions'), config.get('io_checks'), 
                   config.get('range_checks'), config.get('overflow_checks'), 
                   config.get('stack_checks')]):
            issues.append('Some runtime checks are disabled')
        
        return {
            'file': lpi_path,
            'has_debug_mode': True,
            'debug_config': config,
            'issues': issues
        }
        
    except Exception as e:
        return {
            'file': lpi_path,
            'has_debug_mode': False,
            'debug_config': {},
            'issues': [f'Error parsing file: {str(e)}']
        }

def main():
    """主函数"""
    project_root = Path('.')
    
    # 查找所有 .lpi 文件
    lpi_files = list(project_root.rglob('*.lpi'))
    
    print(f"Found {len(lpi_files)} .lpi files")
    print("=" * 80)
    
    results = []
    for lpi_file in lpi_files:
        result = analyze_lpi_file(lpi_file)
        results.append(result)
    
    # 统计结果
    total_files = len(results)
    files_with_debug = sum(1 for r in results if r['has_debug_mode'])
    files_with_issues = sum(1 for r in results if r['issues'])
    
    print(f"\n📊 统计结果:")
    print(f"总文件数: {total_files}")
    print(f"有Debug模式: {files_with_debug}")
    print(f"有问题的文件: {files_with_issues}")
    print(f"完全符合标准: {total_files - files_with_issues}")
    
    # 显示有问题的文件
    print(f"\n⚠️  需要修复的文件:")
    for result in results:
        if result['issues']:
            print(f"\n📁 {result['file']}")
            for issue in result['issues']:
                print(f"   ❌ {issue}")
            if result['debug_config']:
                print(f"   📋 当前配置: {result['debug_config']}")

if __name__ == '__main__':
    main()
