#!/usr/bin/env python3
"""
Script to fix generic queries in Fleet policy YAML files.
This script identifies and corrects common problematic query patterns.
"""

import os
import re
import sys
from pathlib import Path

def fix_generic_queries(file_path):
    """Fix generic queries in a YAML file."""
    print(f"Processing {file_path}...")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Fix generic SELECT 1; queries
    # These should be replaced with meaningful queries based on policy context
    content = re.sub(
        r'(\s+query: SELECT 1;)(\s+purpose: Informational)',
        r'\1  # TODO: Replace with specific query for this policy\2',
        content
    )
    
    # Fix overly generic file path queries
    content = re.sub(
        r'(\s+query: SELECT 1 FROM file WHERE path LIKE \'/[^%]+%\';)(\s+purpose: Informational)',
        r'\1  # TODO: Replace with specific file validation query\2',
        content
    )
    
    # Fix generic launchd queries
    content = re.sub(
        r'(\s+query: SELECT 1 FROM launchd WHERE name LIKE \'%[^%]+%\';)(\s+purpose: Informational)',
        r'\1  # TODO: Replace with specific service validation query\2',
        content
    )
    
    # Count changes made
    changes = len(re.findall(r'# TODO:', content)) - len(re.findall(r'# TODO:', original_content))
    
    if changes > 0:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"  Added {changes} TODO comments for generic queries")
        return changes
    else:
        print(f"  No generic queries found to fix")
        return 0

def main():
    """Main function to process all YAML files."""
    yaml_dir = Path('.')
    yaml_files = list(yaml_dir.glob('*-fleet-policies.yml'))
    
    total_changes = 0
    
    for yaml_file in yaml_files:
        if yaml_file.name.endswith('.bak'):
            continue
            
        changes = fix_generic_queries(yaml_file)
        total_changes += changes
    
    print(f"\nTotal changes made: {total_changes}")
    print("\nNext steps:")
    print("1. Review the TODO comments in each file")
    print("2. Replace TODO comments with specific queries based on policy requirements")
    print("3. Test the corrected queries")

if __name__ == '__main__':
    main()
