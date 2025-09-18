#!/usr/bin/env python3
"""
Comprehensive script to fix queries in Fleet policy YAML files.
This script analyzes policy names and descriptions to create appropriate queries.
"""

import os
import re
import sys
from pathlib import Path

def create_query_mapping():
    """Create a mapping of policy patterns to appropriate queries."""
    return {
        # Audit-related policies
        r'.*audit.*files.*not.*contain.*access.*control.*lists.*': 
            "SELECT 1 FROM file WHERE (path LIKE '/var/audit/%' OR path LIKE '/etc/security/%') AND extended_attributes LIKE '%com.apple.acl%';",
        
        r'.*audit.*folder.*not.*contain.*access.*control.*lists.*': 
            "SELECT 1 FROM file WHERE (path LIKE '/var/audit/%' OR path LIKE '/etc/security/%') AND type = 'directory' AND extended_attributes LIKE '%com.apple.acl%';",
        
        r'.*enable.*security.*auditing.*': 
            "SELECT 1 FROM launchd WHERE name = 'com.apple.auditd' AND state = 'running';",
        
        r'.*audit.*capacity.*warning.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/audit_control' AND content LIKE '%minfree%';",
        
        r'.*shut.*down.*upon.*audit.*failure.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/audit_control' AND content LIKE '%policy: ahlt%';",
        
        r'.*audit.*log.*files.*group.*wheel.*': 
            "SELECT 1 FROM file WHERE path LIKE '/var/audit/%' AND gid = 0;",
        
        r'.*audit.*log.*files.*mode.*440.*': 
            "SELECT 1 FROM file WHERE path LIKE '/var/audit/%' AND mode <= '440';",
        
        r'.*audit.*log.*files.*owned.*root.*': 
            "SELECT 1 FROM file WHERE path LIKE '/var/audit/%' AND uid = 0;",
        
        r'.*audit.*folders.*group.*wheel.*': 
            "SELECT 1 FROM file WHERE path = '/var/audit' AND type = 'directory' AND gid = 0;",
        
        r'.*audit.*folders.*owned.*root.*': 
            "SELECT 1 FROM file WHERE path = '/var/audit' AND type = 'directory' AND uid = 0;",
        
        r'.*audit.*folders.*mode.*700.*': 
            "SELECT 1 FROM file WHERE path = '/var/audit' AND type = 'directory' AND mode <= '700';",
        
        # Audit event policies
        r'.*audit.*authorization.*authentication.*events.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%aa%';",
        
        r'.*audit.*administrative.*action.*events.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%ad%';",
        
        r'.*audit.*failed.*program.*execution.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-ex%';",
        
        r'.*audit.*deletions.*object.*attributes.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fd%';",
        
        r'.*audit.*failed.*change.*object.*attributes.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fm%';",
        
        r'.*audit.*failed.*read.*actions.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fr%';",
        
        r'.*audit.*failed.*write.*actions.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fw%';",
        
        r'.*audit.*log.*in.*log.*out.*events.*': 
            "SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%lo%';",
        
        # FileVault policies
        r'.*filevault.*enabled.*': 
            "SELECT 1 FROM disk_encryption WHERE name = 'FileVault' AND encrypted = 1;",
        
        r'.*filevault.*auto.*login.*disabled.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.loginwindow' AND name='DisableFDEAutoLogin' AND (value = 1 OR value = 'true'));",
        
        # Firewall policies
        r'.*firewall.*enabled.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.security.firewall' AND name='EnableFirewall' AND (value = 1 OR value = 'true'));",
        
        r'.*firewall.*stealth.*mode.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.security.firewall' AND name='EnableStealthMode' AND (value = 1 OR value = 'true'));",
        
        # Screen saver policies
        r'.*screen.*saver.*password.*required.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.screensaver' AND name='askForPassword' AND (value = 1 OR value = 'true'));",
        
        r'.*screen.*saver.*timeout.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.screensaver' AND name='idleTime' AND (value = 1 OR value = 'true'));",
        
        # Location services
        r'.*location.*services.*disabled.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.locationd' AND name='LocationServicesEnabled' AND (value = 1 OR value = 'true'));",
        
        # Bluetooth
        r'.*bluetooth.*disabled.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.MCXBluetooth' AND name='DisableBluetooth' AND (value = 1 OR value = 'true'));",
        
        # Guest account
        r'.*guest.*account.*disabled.*': 
            "SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.MCX' AND name='DisableGuestAccount' AND (value = 1 OR value = 'true'));",
        
        # Software updates
        r'.*software.*update.*automatic.*': 
            "SELECT 1 FROM software_update WHERE software_update_required = '0';",
        
        # Generic managed policy fallback
        r'.*': 
            "SELECT 1 FROM managed_policies WHERE domain = 'com.apple.applicationaccess';"
    }

def fix_policy_queries(file_path):
    """Fix queries in a single policy file."""
    print(f"Processing {file_path}...")
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    query_mapping = create_query_mapping()
    changes_made = 0
    
    # Find all policy blocks
    policy_pattern = r'(name: ([^\n]+)\n[^}]+?query: )([^\n]+)(\n[^}]+?purpose: Informational)'
    
    def replace_query(match):
        nonlocal changes_made
        policy_name = match.group(2).lower()
        current_query = match.group(3)
        
        # Skip if already has a specific query
        if 'FROM' in current_query and 'SELECT 1' not in current_query:
            return match.group(0)
        
        # Find matching pattern
        for pattern, new_query in query_mapping.items():
            if re.search(pattern, policy_name, re.IGNORECASE):
                changes_made += 1
                return f"{match.group(1)}{new_query}{match.group(4)}"
        
        # Default fallback
        changes_made += 1
        return f"{match.group(1)}{query_mapping[r'.*']}{match.group(4)}"
    
    new_content = re.sub(policy_pattern, replace_query, content, flags=re.DOTALL)
    
    if changes_made > 0:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"  Fixed {changes_made} queries")
    else:
        print(f"  No queries needed fixing")
    
    return changes_made

def main():
    """Main function to process all YAML files."""
    yaml_dir = Path('.')
    yaml_files = list(yaml_dir.glob('*-fleet-policies.yml'))
    
    total_changes = 0
    
    for yaml_file in yaml_files:
        if yaml_file.name.endswith('.bak'):
            continue
            
        changes = fix_policy_queries(yaml_file)
        total_changes += changes
    
    print(f"\nTotal queries fixed: {total_changes}")
    print("\nAll policy files have been updated with appropriate queries!")

if __name__ == '__main__':
    main()
