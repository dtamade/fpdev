#!/usr/bin/env python3
"""
分析和整理项目目录结构
"""

import os
import shutil
from pathlib import Path
from datetime import datetime

def analyze_directory_structure():
    """分析当前目录结构的问题"""
    issues = []
    suggestions = []
    
    project_root = Path('.')
    
    # 1. 分析根目录的文件
    root_files = [f for f in project_root.iterdir() if f.is_file()]
    
    # 检查根目录是否有临时文件或不应该在根目录的文件
    temp_files = []
    misplaced_files = []
    
    for file in root_files:
        filename = file.name.lower()
        
        # 临时文件
        if any(ext in filename for ext in ['.compiled', '.o', '.ppu', '.exe', '.dll', '.log']):
            temp_files.append(file)
        
        # 测试文件不应该在根目录
        if filename.startswith('test_') and filename.endswith('.lpi'):
            misplaced_files.append(file)
    
    if temp_files:
        issues.append({
            'type': 'temp_files_in_root',
            'files': temp_files,
            'description': '根目录存在临时文件',
            'suggestion': '移动到适当的bin/或lib/目录，或删除'
        })
    
    if misplaced_files:
        issues.append({
            'type': 'misplaced_test_files',
            'files': misplaced_files,
            'description': '测试文件不应在根目录',
            'suggestion': '移动到tests/目录'
        })
    
    # 2. 分析tests目录结构
    tests_dir = project_root / 'tests'
    if tests_dir.exists():
        # 检查tests目录下的文件组织
        test_issues = analyze_tests_directory(tests_dir)
        issues.extend(test_issues)
    
    # 3. 分析plays目录
    plays_dir = project_root / 'plays'
    if plays_dir.exists():
        play_issues = analyze_plays_directory(plays_dir)
        issues.extend(play_issues)
    
    # 4. 分析examples目录
    examples_dir = project_root / 'examples'
    if examples_dir.exists():
        example_issues = analyze_examples_directory(examples_dir)
        issues.extend(example_issues)
    
    # 5. 分析bin和lib目录
    bin_issues = analyze_output_directories(project_root)
    issues.extend(bin_issues)
    
    return issues

def analyze_tests_directory(tests_dir):
    """分析tests目录的问题"""
    issues = []
    
    # 检查是否有备份文件
    backup_files = list(tests_dir.rglob('*.backup.*'))
    if backup_files:
        issues.append({
            'type': 'backup_files_in_tests',
            'files': backup_files,
            'description': 'tests目录存在备份文件',
            'suggestion': '清理备份文件或移动到专门的备份目录'
        })
    
    # 检查是否有编译产物（排除bin和lib目录）
    compiled_files = []
    for pattern in ['*.exe', '*.o', '*.ppu', '*.compiled']:
        for file in tests_dir.rglob(pattern):
            # 跳过bin和lib目录中的文件，这些是正常的
            if 'bin' not in file.parts and 'lib' not in file.parts:
                compiled_files.append(file)

    if compiled_files:
        issues.append({
            'type': 'compiled_files_in_tests',
            'files': compiled_files,
            'description': 'tests目录存在编译产物（不在bin/lib目录）',
            'suggestion': '移动到各自的bin/lib目录或清理'
        })
    
    # 检查目录结构是否符合模块化组织
    subdirs = [d for d in tests_dir.iterdir() if d.is_dir() and not d.name.startswith('.')]
    
    # 检查是否有不规范的目录名
    irregular_dirs = []
    for subdir in subdirs:
        if not subdir.name.startswith('fpdev.') and subdir.name not in ['bin', 'lib', 'data', 'migrated']:
            irregular_dirs.append(subdir)
    
    if irregular_dirs:
        issues.append({
            'type': 'irregular_test_dirs',
            'files': irregular_dirs,
            'description': '测试目录命名不规范',
            'suggestion': '重命名为fpdev.模块名格式或移动到合适位置'
        })
    
    return issues

def analyze_plays_directory(plays_dir):
    """分析plays目录的问题"""
    issues = []
    
    # plays目录应该包含临时验证和实验性代码
    # 检查是否有应该移动到examples的内容
    subdirs = [d for d in plays_dir.iterdir() if d.is_dir()]
    
    for subdir in subdirs:
        # 如果包含完整的示例代码，可能应该移动到examples
        if (subdir / 'README.md').exists() or (subdir / 'example_').exists():
            issues.append({
                'type': 'mature_code_in_plays',
                'files': [subdir],
                'description': f'{subdir.name} 可能已经成熟，应考虑移动到examples',
                'suggestion': '评估是否移动到examples目录'
            })
    
    return issues

def analyze_examples_directory(examples_dir):
    """分析examples目录的问题"""
    issues = []
    
    # 检查examples是否有编译产物
    compiled_files = []
    for pattern in ['*.exe', '*.o', '*.ppu', '*.compiled']:
        compiled_files.extend(examples_dir.rglob(pattern))
    
    if compiled_files:
        issues.append({
            'type': 'compiled_files_in_examples',
            'files': compiled_files,
            'description': 'examples目录存在编译产物',
            'suggestion': '清理编译产物，保持examples目录整洁'
        })
    
    return issues

def analyze_output_directories(project_root):
    """分析输出目录的问题"""
    issues = []
    
    bin_dir = project_root / 'bin'
    lib_dir = project_root / 'lib'
    
    # 检查bin目录是否有源码文件
    if bin_dir.exists():
        source_files = []
        for pattern in ['*.pas', '*.pp', '*.inc']:
            source_files.extend(bin_dir.rglob(pattern))
        
        if source_files:
            issues.append({
                'type': 'source_files_in_bin',
                'files': source_files,
                'description': 'bin目录存在源码文件',
                'suggestion': '移动源码文件到src目录'
            })
    
    # 检查lib目录是否过于混乱
    if lib_dir.exists():
        lib_files = list(lib_dir.rglob('*'))
        if len(lib_files) > 100:  # 如果文件太多
            issues.append({
                'type': 'cluttered_lib_dir',
                'files': [lib_dir],
                'description': f'lib目录文件过多({len(lib_files)}个)',
                'suggestion': '考虑按模块组织lib目录或定期清理'
            })
    
    return issues

def generate_cleanup_plan(issues):
    """生成清理计划"""
    plan = {
        'immediate': [],  # 立即执行
        'review': [],     # 需要审查
        'optional': []    # 可选执行
    }
    
    for issue in issues:
        issue_type = issue['type']
        
        if issue_type in ['temp_files_in_root', 'backup_files_in_tests', 'compiled_files_in_tests', 'compiled_files_in_examples']:
            plan['immediate'].append(issue)
        elif issue_type in ['misplaced_test_files', 'irregular_test_dirs']:
            plan['review'].append(issue)
        else:
            plan['optional'].append(issue)
    
    return plan

def main():
    """主函数"""
    print("🔍 分析项目目录结构...")
    print("=" * 80)
    
    # 分析目录结构
    issues = analyze_directory_structure()
    
    # 生成清理计划
    plan = generate_cleanup_plan(issues)
    
    # 统计报告
    print(f"📊 分析结果:")
    print(f"总问题数: {len(issues)}")
    print(f"立即处理: {len(plan['immediate'])}")
    print(f"需要审查: {len(plan['review'])}")
    print(f"可选处理: {len(plan['optional'])}")
    
    # 详细报告
    print(f"\n⚠️  问题详情:")
    
    for category, category_issues in plan.items():
        if not category_issues:
            continue
            
        category_names = {
            'immediate': '🔴 立即处理',
            'review': '🟡 需要审查', 
            'optional': '🟢 可选处理'
        }
        
        print(f"\n{category_names[category]}:")
        
        for issue in category_issues:
            print(f"  📁 {issue['description']}")
            print(f"     💡 {issue['suggestion']}")
            
            # 显示前5个文件
            files = issue['files'][:5]
            for file in files:
                print(f"     📄 {file}")
            
            if len(issue['files']) > 5:
                print(f"     ... 还有 {len(issue['files']) - 5} 个文件")
            print()
    
    # 生成建议
    print(f"\n🔧 整理建议:")
    print("1. 立即清理临时文件和编译产物")
    print("2. 整理备份文件到专门目录")
    print("3. 规范化测试目录命名")
    print("4. 评估plays目录中的成熟代码")
    print("5. 建立定期清理机制")
    
    return len(issues)

if __name__ == '__main__':
    exit_code = main()
    exit(exit_code)
