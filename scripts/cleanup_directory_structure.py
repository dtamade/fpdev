#!/usr/bin/env python3
"""
清理和整理项目目录结构
"""

import os
import shutil
from pathlib import Path
from datetime import datetime

def create_backup_directory():
    """创建备份目录"""
    backup_dir = Path('backups') / f"cleanup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    backup_dir.mkdir(parents=True, exist_ok=True)
    return backup_dir

def cleanup_root_temp_files():
    """清理根目录的临时文件"""
    print("🧹 清理根目录临时文件...")
    
    project_root = Path('.')
    temp_files = []
    
    # 查找临时文件
    for file in project_root.iterdir():
        if file.is_file():
            filename = file.name.lower()
            if any(ext in filename for ext in ['.compiled', '.log']) and not filename.startswith('changelog'):
                temp_files.append(file)
            elif filename == 'git2.dll':  # 这个应该在bin目录
                temp_files.append(file)
    
    if temp_files:
        print(f"  找到 {len(temp_files)} 个临时文件")
        for file in temp_files:
            try:
                if file.name == 'git2.dll':
                    # 移动到bin目录
                    bin_dir = Path('bin')
                    bin_dir.mkdir(exist_ok=True)
                    target = bin_dir / file.name
                    if not target.exists():
                        shutil.move(str(file), str(target))
                        print(f"    ✅ 移动: {file.name} -> bin/{file.name}")
                    else:
                        file.unlink()
                        print(f"    ✅ 删除: {file.name} (bin目录已有)")
                else:
                    # 删除其他临时文件
                    file.unlink()
                    print(f"    ✅ 删除: {file.name}")
            except Exception as e:
                print(f"    ❌ 处理失败: {file.name} - {e}")
    else:
        print("  ✅ 根目录无需清理")

def cleanup_backup_files():
    """清理备份文件"""
    print("\n🧹 整理备份文件...")
    
    # 创建备份目录
    backup_dir = Path('backups')
    backup_dir.mkdir(exist_ok=True)
    
    # 查找所有备份文件
    project_root = Path('.')
    backup_files = list(project_root.rglob('*.backup.*'))
    
    if backup_files:
        print(f"  找到 {len(backup_files)} 个备份文件")
        
        # 按日期组织备份文件
        for backup_file in backup_files:
            try:
                # 提取日期信息
                parts = backup_file.name.split('.backup.')
                if len(parts) >= 2:
                    date_part = parts[1]
                    date_dir = backup_dir / date_part[:8]  # YYYYMMDD
                    date_dir.mkdir(exist_ok=True)
                    
                    # 保持相对路径结构
                    relative_path = backup_file.relative_to(project_root)
                    target_dir = date_dir / relative_path.parent
                    target_dir.mkdir(parents=True, exist_ok=True)
                    
                    target_file = target_dir / backup_file.name
                    shutil.move(str(backup_file), str(target_file))
                    print(f"    ✅ 移动: {relative_path} -> backups/{date_part[:8]}/{relative_path}")
                else:
                    # 无法解析日期，移动到通用目录
                    general_dir = backup_dir / 'general'
                    general_dir.mkdir(exist_ok=True)
                    target = general_dir / backup_file.name
                    shutil.move(str(backup_file), str(target))
                    print(f"    ✅ 移动: {backup_file.relative_to(project_root)} -> backups/general/{backup_file.name}")
            except Exception as e:
                print(f"    ❌ 处理失败: {backup_file} - {e}")
    else:
        print("  ✅ 无备份文件需要整理")

def cleanup_compiled_files():
    """清理编译产物"""
    print("\n🧹 清理编译产物...")
    
    tests_dir = Path('tests')
    examples_dir = Path('examples')
    
    # 清理tests目录的编译产物
    if tests_dir.exists():
        print("  清理tests目录...")
        compiled_files = []
        
        # 查找编译产物，但保留bin和lib目录中的
        for pattern in ['*.exe', '*.o', '*.ppu', '*.compiled']:
            for file in tests_dir.rglob(pattern):
                # 跳过bin和lib目录中的文件
                if 'bin' not in file.parts and 'lib' not in file.parts:
                    compiled_files.append(file)
        
        if compiled_files:
            print(f"    找到 {len(compiled_files)} 个编译产物")
            for file in compiled_files:
                try:
                    file.unlink()
                    print(f"      ✅ 删除: {file.relative_to(tests_dir)}")
                except Exception as e:
                    print(f"      ❌ 删除失败: {file} - {e}")
        else:
            print("    ✅ tests目录无编译产物需要清理")
    
    # 清理examples目录的编译产物
    if examples_dir.exists():
        print("  清理examples目录...")
        compiled_files = []
        
        for pattern in ['*.exe', '*.o', '*.ppu', '*.compiled']:
            for file in examples_dir.rglob(pattern):
                if 'bin' not in file.parts and 'lib' not in file.parts:
                    compiled_files.append(file)
        
        if compiled_files:
            print(f"    找到 {len(compiled_files)} 个编译产物")
            for file in compiled_files:
                try:
                    file.unlink()
                    print(f"      ✅ 删除: {file.relative_to(examples_dir)}")
                except Exception as e:
                    print(f"      ❌ 删除失败: {file} - {e}")
        else:
            print("    ✅ examples目录无编译产物需要清理")

def move_misplaced_test_files():
    """移动错位的测试文件"""
    print("\n🧹 整理错位的测试文件...")
    
    project_root = Path('.')
    tests_dir = Path('tests')
    tests_dir.mkdir(exist_ok=True)
    
    # 查找根目录中的测试文件
    test_files = []
    for file in project_root.iterdir():
        if file.is_file() and file.name.startswith('test_') and file.name.endswith('.lpi'):
            test_files.append(file)
    
    if test_files:
        print(f"  找到 {len(test_files)} 个错位的测试文件")
        for file in test_files:
            try:
                target = tests_dir / file.name
                if not target.exists():
                    shutil.move(str(file), str(target))
                    print(f"    ✅ 移动: {file.name} -> tests/{file.name}")
                else:
                    print(f"    ⚠️  跳过: {file.name} (目标已存在)")
            except Exception as e:
                print(f"    ❌ 移动失败: {file.name} - {e}")
    else:
        print("  ✅ 无错位的测试文件")

def organize_test_directories():
    """组织测试目录结构"""
    print("\n🧹 组织测试目录结构...")
    
    tests_dir = Path('tests')
    if not tests_dir.exists():
        print("  ✅ tests目录不存在，跳过")
        return
    
    # 检查不规范的目录名
    subdirs = [d for d in tests_dir.iterdir() if d.is_dir() and not d.name.startswith('.')]
    irregular_dirs = []
    
    for subdir in subdirs:
        if not subdir.name.startswith('fpdev.') and subdir.name not in ['bin', 'lib', 'data', 'migrated', 'backups']:
            irregular_dirs.append(subdir)
    
    if irregular_dirs:
        print(f"  找到 {len(irregular_dirs)} 个不规范的目录")
        for dir in irregular_dirs:
            print(f"    📁 {dir.name} - 建议重命名或重新组织")
    else:
        print("  ✅ 测试目录结构规范")

def create_gitignore_entries():
    """创建或更新.gitignore文件"""
    print("\n🧹 更新.gitignore文件...")
    
    gitignore_path = Path('.gitignore')
    
    # 需要忽略的模式
    ignore_patterns = [
        "# 编译产物",
        "*.exe",
        "*.o", 
        "*.ppu",
        "*.compiled",
        "*.dbg",
        "",
        "# 临时文件",
        "*.log",
        "*.tmp",
        "*.bak",
        "",
        "# 备份文件",
        "*.backup.*",
        "backups/",
        "",
        "# IDE文件",
        "*.lps",
        "",
        "# 输出目录中的编译产物",
        "bin/*.exe",
        "bin/*.o",
        "bin/*.ppu",
        "lib/*.o",
        "lib/*.ppu",
        "",
        "# 测试临时目录",
        "tests/tmp*/",
        "tests/bin/tmp*/",
        ""
    ]
    
    try:
        # 读取现有内容
        existing_content = ""
        if gitignore_path.exists():
            with open(gitignore_path, 'r', encoding='utf-8') as f:
                existing_content = f.read()
        
        # 检查哪些模式需要添加
        new_patterns = []
        for pattern in ignore_patterns:
            if pattern and pattern not in existing_content:
                new_patterns.append(pattern)
        
        if new_patterns:
            with open(gitignore_path, 'a', encoding='utf-8') as f:
                f.write('\n# 自动添加的忽略模式\n')
                for pattern in new_patterns:
                    f.write(pattern + '\n')
            print(f"    ✅ 添加了 {len([p for p in new_patterns if p and not p.startswith('#')])} 个新的忽略模式")
        else:
            print("    ✅ .gitignore已经包含必要的模式")
            
    except Exception as e:
        print(f"    ❌ 更新.gitignore失败: {e}")

def main():
    """主函数"""
    print("🧹 开始清理和整理项目目录结构...")
    print("=" * 80)
    
    try:
        # 1. 清理根目录临时文件
        cleanup_root_temp_files()
        
        # 2. 整理备份文件
        cleanup_backup_files()
        
        # 3. 清理编译产物
        cleanup_compiled_files()
        
        # 4. 移动错位的测试文件
        move_misplaced_test_files()
        
        # 5. 组织测试目录结构
        organize_test_directories()
        
        # 6. 更新.gitignore
        create_gitignore_entries()
        
        print("\n" + "=" * 80)
        print("🎉 目录结构整理完成！")
        print("\n📋 整理总结:")
        print("✅ 清理了根目录临时文件")
        print("✅ 整理了备份文件到backups目录")
        print("✅ 清理了编译产物")
        print("✅ 移动了错位的测试文件")
        print("✅ 检查了测试目录结构")
        print("✅ 更新了.gitignore文件")
        
        print("\n💡 后续建议:")
        print("1. 定期运行此脚本清理临时文件")
        print("2. 建立构建后自动清理机制")
        print("3. 在CI/CD中集成目录结构检查")
        
    except Exception as e:
        print(f"\n❌ 清理过程中出现错误: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit_code = main()
    exit(exit_code)
