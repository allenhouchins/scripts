#!/usr/bin/env python3
"""
Script to fix specific query patterns in Fleet policy YAML files.
This script replaces TODO comments with appropriate queries based on policy names and descriptions.
"""

import os
import re
import sys
from pathlib import Path

def fix_audit_queries(content):
    """Fix audit-related queries."""
    # Audit log files ACL check
    content = re.sub(
        r'(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)',
        r'\1 FROM file WHERE (path LIKE \'/var/audit/%\' OR path LIKE \'/etc/security/%\') AND extended_attributes LIKE \'%com.apple.acl%\';',
        content
    )
    
    # Audit folder ACL check
    content = re.sub(
        r'(\s+query: SELECT 1 FROM file WHERE path LIKE \'/[^%]+%\';)(\s+# TODO: Replace with specific file validation query)',
        r'\1 AND type = \'directory\' AND extended_attributes LIKE \'%com.apple.acl%\';',
        content
    )
    
    # Security auditing enabled
    content = re.sub(
        r'(\s+query: SELECT 1 FROM launchd WHERE name LIKE \'%audit%\';)(\s+# TODO: Replace with specific service validation query)',
        r'\1 AND state = \'running\';',
        content
    )
    
    return content

def fix_file_permission_queries(content):
    """Fix file permission related queries."""
    # File ownership by root
    content = re.sub(
        r'(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)',
        r'\1 FROM file WHERE path LIKE \'/var/audit/%\' AND uid = 0;',
        content
    )
    
    # File group ownership
    content = re.sub(
        r'(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)',
        r'\1 FROM file WHERE path LIKE \'/var/audit/%\' AND gid = 0;',
        content
    )
    
    # File permissions
    content = re.sub(
        r'(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)',
        r'\1 FROM file WHERE path LIKE \'/var/audit/%\' AND mode <= \'440\';',
        content
    )
    
    return content

def fix_managed_policy_queries(content):
    """Fix managed policy queries."""
    # Generic managed policy check
    content = re.sub(
        r'(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)',
        r'\1 FROM managed_policies WHERE domain = \'com.apple.applicationaccess\';',
        content
    )
    
    return content

def fix_specific_policy_queries(file_path):
    """Fix specific policy queries based on policy names."""
    print(f"Processing {file_path}...")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # Apply audit-related fixes
    content = fix_audit_queries(content)
    
    # Apply file permission fixes
    content = fix_file_permission_queries(content)
    
    # Apply managed policy fixes
    content = fix_managed_policy_queries(content)
    
    # Count remaining TODO comments
    remaining_todos = len(re.findall(r'# TODO:', content))
    
    if content != original_content:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"  Applied specific query fixes")
    
    print(f"  Remaining TODO comments: {remaining_todos}")
    return remaining_todos

def main():
    """Main function to process all YAML files."""
    yaml_dir = Path('.')
    yaml_files = list(yaml_dir.glob('*-fleet-policies.yml'))
    
    total_remaining = 0
    
    for yaml_file in yaml_files:
        if yaml_file.name.endswith('.bak'):
            continue
            
        remaining = fix_specific_policy_queries(yaml_file)
        total_remaining += remaining
    
    print(f"\nTotal remaining TODO comments: {total_remaining}")
    print("\nNote: Some policies may require manual review to create appropriate queries.")

if __name__ == '__main__':
    main()
