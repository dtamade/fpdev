#!/usr/bin/env python3
"""
分析和修复测试文件的命名规范问题
"""

import os
import re
from pathlib import Path
from datetime import datetime

def analyze_test_file_naming():
    """分析测试文件命名规范"""
    tests_dir = Path('tests')
    issues = []
    
    # 查找所有 .pas 文件
    pas_files = list(tests_dir.rglob('*.pas'))
    
    print(f"🔍 找到 {len(pas_files)} 个 .pas 文件")
    print("=" * 80)
    
    for pas_file in pas_files:
        relative_path = pas_file.relative_to(Path('.'))
        
        # 检查文件名是否符合 "命名空间+.test.pas" 格式
        filename = pas_file.name
        
        # 排除非测试文件
        if not any(keyword in filename.lower() for keyword in ['test', 'case']):
            continue
            
        # 检查是否符合命名规范
        if not filename.endswith('.test.pas'):
            # 检查是否是其他合理的测试文件命名
            if not any(pattern in filename.lower() for pattern in ['.testcase.', '.tests.', 'test_', '_test']):
                issues.append({
                    'file': relative_path,
                    'type': 'naming',
                    'issue': f'文件名不符合 "命名空间.test.pas" 格式: {filename}',
                    'suggestion': f'建议重命名为: {filename.replace(".pas", ".test.pas")}'
                })
    
    return issues

def analyze_variable_naming(file_path):
    """分析单个文件的变量命名规范"""
    issues = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except:
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                content = f.read()
        except:
            return [{'file': file_path, 'type': 'encoding', 'issue': '无法读取文件编码'}]
    
    lines = content.split('\n')
    
    # 查找局部变量声明
    in_var_section = False
    in_procedure = False
    current_procedure = ""
    
    for i, line in enumerate(lines, 1):
        line_stripped = line.strip()
        
        # 检测过程/函数开始
        if re.match(r'^\s*(procedure|function)\s+', line_stripped, re.IGNORECASE):
            in_procedure = True
            match = re.match(r'^\s*(procedure|function)\s+(\w+)', line_stripped, re.IGNORECASE)
            if match:
                current_procedure = match.group(2)
        
        # 检测var关键字
        if re.match(r'^\s*var\s*$', line_stripped, re.IGNORECASE) and in_procedure:
            in_var_section = True
            continue
        
        # 检测var段结束
        if in_var_section and (re.match(r'^\s*(begin|const|type)\s*$', line_stripped, re.IGNORECASE) or 
                              line_stripped.startswith('procedure') or line_stripped.startswith('function')):
            in_var_section = False
        
        # 分析局部变量
        if in_var_section and line_stripped and not line_stripped.startswith('//'):
            # 匹配变量声明 (变量名: 类型)
            var_match = re.match(r'^\s*(\w+(?:\s*,\s*\w+)*)\s*:\s*', line_stripped)
            if var_match:
                var_names = [name.strip() for name in var_match.group(1).split(',')]
                for var_name in var_names:
                    if not var_name.startswith('L') and len(var_name) > 1:
                        issues.append({
                            'file': file_path,
                            'type': 'variable_naming',
                            'line': i,
                            'procedure': current_procedure,
                            'issue': f'局部变量 "{var_name}" 应以 L 开头',
                            'suggestion': f'建议重命名为: L{var_name}'
                        })
        
        # 检测过程/函数结束
        if re.match(r'^\s*end\s*;\s*$', line_stripped) and in_procedure:
            in_procedure = False
            in_var_section = False
            current_procedure = ""
    
    return issues

def analyze_testcase_coverage(file_path):
    """分析TTestCase类是否覆盖所有公开接口"""
    issues = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except:
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                content = f.read()
        except:
            return [{'file': file_path, 'type': 'encoding', 'issue': '无法读取文件编码'}]
    
    # 查找TTestCase类定义
    testcase_classes = re.findall(r'(\w+)\s*=\s*class\s*\(\s*TTestCase\s*\)', content, re.IGNORECASE)
    
    for class_name in testcase_classes:
        # 查找published方法
        class_pattern = rf'{re.escape(class_name)}\s*=\s*class\s*\(\s*TTestCase\s*\)(.*?)(?=\n\s*\w+\s*=\s*class|\nend\.|\nimplementation|\Z)'
        class_match = re.search(class_pattern, content, re.DOTALL | re.IGNORECASE)
        
        if class_match:
            class_content = class_match.group(1)
            
            # 查找published段
            published_match = re.search(r'published(.*?)(?=private|protected|public|end)', class_content, re.DOTALL | re.IGNORECASE)
            
            if not published_match:
                issues.append({
                    'file': file_path,
                    'type': 'testcase_coverage',
                    'class': class_name,
                    'issue': f'TTestCase类 "{class_name}" 缺少 published 段',
                    'suggestion': '添加 published 段并声明测试方法'
                })
            else:
                published_content = published_match.group(1)
                # 查找测试方法
                test_methods = re.findall(r'procedure\s+(\w+)', published_content, re.IGNORECASE)
                
                if not test_methods:
                    issues.append({
                        'file': file_path,
                        'type': 'testcase_coverage',
                        'class': class_name,
                        'issue': f'TTestCase类 "{class_name}" 的 published 段没有测试方法',
                        'suggestion': '添加测试方法，如 Test_MethodName'
                    })
    
    return issues

def main():
    """主函数"""
    print("🔍 分析测试文件命名规范...")
    
    # 1. 分析文件命名
    naming_issues = analyze_test_file_naming()
    
    # 2. 分析变量命名和TTestCase覆盖
    tests_dir = Path('tests')
    pas_files = list(tests_dir.rglob('*.pas'))
    
    all_issues = naming_issues.copy()
    
    for pas_file in pas_files:
        # 只分析测试相关文件
        if any(keyword in pas_file.name.lower() for keyword in ['test', 'case']):
            var_issues = analyze_variable_naming(pas_file)
            testcase_issues = analyze_testcase_coverage(pas_file)
            all_issues.extend(var_issues)
            all_issues.extend(testcase_issues)
    
    # 3. 统计和报告
    issue_types = {}
    for issue in all_issues:
        issue_type = issue['type']
        if issue_type not in issue_types:
            issue_types[issue_type] = []
        issue_types[issue_type].append(issue)
    
    print(f"\n📊 分析结果:")
    print(f"总问题数: {len(all_issues)}")
    for issue_type, issues in issue_types.items():
        print(f"{issue_type}: {len(issues)} 个问题")
    
    # 4. 详细报告
    print(f"\n⚠️  详细问题列表:")
    
    for issue_type, issues in issue_types.items():
        if not issues:
            continue
            
        print(f"\n📁 {issue_type.upper()} 问题:")
        for issue in issues[:10]:  # 只显示前10个
            print(f"  📄 {issue['file']}")
            if 'line' in issue:
                print(f"     行 {issue['line']}: {issue['issue']}")
            else:
                print(f"     {issue['issue']}")
            if 'suggestion' in issue:
                print(f"     💡 {issue['suggestion']}")
            print()
        
        if len(issues) > 10:
            print(f"  ... 还有 {len(issues) - 10} 个类似问题")
    
    # 5. 生成修复建议
    print(f"\n🔧 修复建议:")
    print("1. 文件命名: 将测试单元重命名为 '命名空间.test.pas' 格式")
    print("2. 变量命名: 局部变量以 L 开头，如 LManager, LResult")
    print("3. TTestCase覆盖: 确保每个TTestCase类都有published段和测试方法")
    print("4. 测试方法命名: 使用 Test_MethodName 或 Test_MethodName_Scenario 格式")

if __name__ == '__main__':
    main()
