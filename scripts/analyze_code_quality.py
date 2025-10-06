#!/usr/bin/env python3
"""
分析项目代码质量问题
"""

import os
import re
from pathlib import Path
from collections import defaultdict

def analyze_temp_files_and_debug_code():
    """分析临时文件和调试代码"""
    issues = []
    
    src_dir = Path('src')
    if not src_dir.exists():
        return issues
    
    # 查找临时文件
    temp_files = []
    for pattern in ['*.tmp', '*.bak', '*.orig', '*.backup']:
        temp_files.extend(src_dir.rglob(pattern))
    
    if temp_files:
        issues.append({
            'type': 'temp_files',
            'files': temp_files,
            'description': 'src目录存在临时文件',
            'suggestion': '删除临时文件'
        })
    
    # 查找调试代码
    pas_files = list(src_dir.rglob('*.pas'))
    debug_code_files = []
    
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
        
        # 查找调试相关代码
        debug_patterns = [
            r'writeln\s*\(',  # 调试输出
            r'write\s*\(',    # 调试输出
            r'//\s*debug',    # 调试注释
            r'//\s*todo',     # TODO注释
            r'//\s*fixme',    # FIXME注释
            r'//\s*hack',     # HACK注释
        ]
        
        debug_lines = []
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            line_lower = line.lower()
            for pattern in debug_patterns:
                if re.search(pattern, line_lower, re.IGNORECASE):
                    debug_lines.append((i, line.strip()))
        
        if debug_lines:
            debug_code_files.append({
                'file': pas_file,
                'debug_lines': debug_lines[:5]  # 只显示前5个
            })
    
    if debug_code_files:
        issues.append({
            'type': 'debug_code',
            'files': debug_code_files,
            'description': '发现调试代码和TODO注释',
            'suggestion': '清理调试代码，处理TODO项'
        })
    
    return issues

def analyze_unused_code():
    """分析未使用的代码"""
    issues = []
    
    src_dir = Path('src')
    if not src_dir.exists():
        return issues
    
    pas_files = list(src_dir.rglob('*.pas'))
    
    # 分析未使用的单元
    all_units = set()
    used_units = set()
    
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
        
        # 提取单元名
        unit_match = re.search(r'unit\s+(\w+)', content, re.IGNORECASE)
        if unit_match:
            all_units.add(unit_match.group(1).lower())
        
        # 提取uses子句中的单元
        uses_matches = re.findall(r'uses\s+(.*?);', content, re.IGNORECASE | re.DOTALL)
        for uses_clause in uses_matches:
            units = re.findall(r'\b(\w+)\b', uses_clause)
            for unit in units:
                if unit.lower() not in ['in', 'out']:  # 排除关键字
                    used_units.add(unit.lower())
    
    # 查找可能未使用的单元（这只是一个粗略的检查）
    potentially_unused = all_units - used_units
    
    if potentially_unused:
        issues.append({
            'type': 'potentially_unused_units',
            'units': list(potentially_unused),
            'description': f'发现 {len(potentially_unused)} 个可能未使用的单元',
            'suggestion': '检查这些单元是否真的未使用'
        })
    
    return issues

def analyze_code_style():
    """分析代码风格问题"""
    issues = []
    
    src_dir = Path('src')
    if not src_dir.exists():
        return issues
    
    pas_files = list(src_dir.rglob('*.pas'))
    style_issues = []
    
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
        
        file_issues = []
        lines = content.split('\n')
        
        for i, line in enumerate(lines, 1):
            # 检查行尾空格
            if line.endswith(' ') or line.endswith('\t'):
                file_issues.append(f"行 {i}: 行尾有空格")
            
            # 检查制表符
            if '\t' in line:
                file_issues.append(f"行 {i}: 使用了制表符")
            
            # 检查过长的行
            if len(line) > 120:
                file_issues.append(f"行 {i}: 行过长 ({len(line)} 字符)")
        
        if file_issues:
            style_issues.append({
                'file': pas_file,
                'issues': file_issues[:5]  # 只显示前5个
            })
    
    if style_issues:
        issues.append({
            'type': 'code_style',
            'files': style_issues,
            'description': '发现代码风格问题',
            'suggestion': '统一代码风格：移除行尾空格，使用空格代替制表符，控制行长度'
        })
    
    return issues

def analyze_hardcoded_constants():
    """分析硬编码常量"""
    issues = []
    
    src_dir = Path('src')
    if not src_dir.exists():
        return issues
    
    pas_files = list(src_dir.rglob('*.pas'))
    hardcoded_files = []
    
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
        
        # 查找可能的硬编码常量
        hardcoded_patterns = [
            r"'[A-Z]:\\[^']*'",  # Windows路径
            r"'/[^']*'",         # Unix路径
            r"'https?://[^']*'", # URL
            r"'\d+\.\d+\.\d+'",  # 版本号
        ]
        
        hardcoded_items = []
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            for pattern in hardcoded_patterns:
                matches = re.findall(pattern, line)
                for match in matches:
                    hardcoded_items.append((i, match))
        
        if hardcoded_items:
            hardcoded_files.append({
                'file': pas_file,
                'items': hardcoded_items[:3]  # 只显示前3个
            })
    
    if hardcoded_files:
        issues.append({
            'type': 'hardcoded_constants',
            'files': hardcoded_files,
            'description': '发现硬编码常量',
            'suggestion': '考虑将硬编码常量提取到配置文件或常量定义中'
        })
    
    return issues

def analyze_backup_directory():
    """分析backup目录"""
    issues = []
    
    backup_dir = Path('src/backup')
    if backup_dir.exists():
        backup_files = list(backup_dir.rglob('*'))
        if backup_files:
            issues.append({
                'type': 'backup_in_src',
                'files': backup_files,
                'description': 'src目录中存在backup子目录',
                'suggestion': '移动backup目录到项目根目录的backups目录中'
            })
    
    return issues

def main():
    """主函数"""
    print("🔍 分析代码质量...")
    print("=" * 80)
    
    all_issues = []
    
    # 1. 分析临时文件和调试代码
    print("📋 分析临时文件和调试代码...")
    temp_issues = analyze_temp_files_and_debug_code()
    all_issues.extend(temp_issues)
    
    # 2. 分析未使用代码
    print("📋 分析未使用代码...")
    unused_issues = analyze_unused_code()
    all_issues.extend(unused_issues)
    
    # 3. 分析代码风格
    print("📋 分析代码风格...")
    style_issues = analyze_code_style()
    all_issues.extend(style_issues)
    
    # 4. 分析硬编码常量
    print("📋 分析硬编码常量...")
    hardcoded_issues = analyze_hardcoded_constants()
    all_issues.extend(hardcoded_issues)
    
    # 5. 分析backup目录
    print("📋 分析backup目录...")
    backup_issues = analyze_backup_directory()
    all_issues.extend(backup_issues)
    
    # 统计报告
    print(f"\n📊 分析结果:")
    print(f"总问题数: {len(all_issues)}")
    
    issue_types = defaultdict(int)
    for issue in all_issues:
        issue_types[issue['type']] += 1
    
    for issue_type, count in issue_types.items():
        print(f"{issue_type}: {count} 个问题")
    
    # 详细报告
    print(f"\n⚠️  问题详情:")
    
    for issue in all_issues:
        print(f"\n📁 {issue['description']}")
        print(f"   💡 {issue['suggestion']}")
        
        if issue['type'] == 'debug_code':
            for file_info in issue['files'][:3]:  # 只显示前3个文件
                print(f"   📄 {file_info['file']}")
                for line_num, line_content in file_info['debug_lines']:
                    print(f"      行 {line_num}: {line_content}")
        elif issue['type'] == 'code_style':
            for file_info in issue['files'][:3]:  # 只显示前3个文件
                print(f"   📄 {file_info['file']}")
                for issue_desc in file_info['issues']:
                    print(f"      {issue_desc}")
        elif issue['type'] == 'hardcoded_constants':
            for file_info in issue['files'][:3]:  # 只显示前3个文件
                print(f"   📄 {file_info['file']}")
                for line_num, constant in file_info['items']:
                    print(f"      行 {line_num}: {constant}")
        elif issue['type'] == 'potentially_unused_units':
            units = issue['units'][:10]  # 只显示前10个
            print(f"   📄 可能未使用的单元: {', '.join(units)}")
            if len(issue['units']) > 10:
                print(f"   ... 还有 {len(issue['units']) - 10} 个")
        else:
            files = issue['files'][:5]  # 只显示前5个文件
            for file in files:
                print(f"   📄 {file}")
            if len(issue['files']) > 5:
                print(f"   ... 还有 {len(issue['files']) - 5} 个文件")
    
    print(f"\n🔧 优化建议:")
    print("1. 清理调试代码和TODO注释")
    print("2. 移除临时文件和备份目录")
    print("3. 统一代码风格和格式")
    print("4. 提取硬编码常量到配置")
    print("5. 检查并移除未使用的代码")
    
    return len(all_issues)

if __name__ == '__main__':
    exit_code = main()
    exit(exit_code)
