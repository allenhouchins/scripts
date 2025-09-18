package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// SpecificQueryFixer handles fixing specific query patterns
type SpecificQueryFixer struct{}

// NewSpecificQueryFixer creates a new specific query fixer
func NewSpecificQueryFixer() *SpecificQueryFixer {
	return &SpecificQueryFixer{}
}

// FixAuditQueries fixes audit-related queries
func (sqf *SpecificQueryFixer) FixAuditQueries(content string) string {
	// Audit log files ACL check
	auditACLPattern := regexp.MustCompile(`(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)`)
	content = auditACLPattern.ReplaceAllString(content, "$1 FROM file WHERE (path LIKE '/var/audit/%' OR path LIKE '/etc/security/%') AND extended_attributes LIKE '%com.apple.acl%';")

	// Audit folder ACL check
	auditFolderPattern := regexp.MustCompile(`(\s+query: SELECT 1 FROM file WHERE path LIKE '/[^%]+%';)(\s+# TODO: Replace with specific file validation query)`)
	content = auditFolderPattern.ReplaceAllString(content, "$1 AND type = 'directory' AND extended_attributes LIKE '%com.apple.acl%';")

	// Security auditing enabled
	auditServicePattern := regexp.MustCompile(`(\s+query: SELECT 1 FROM launchd WHERE name LIKE '%audit%';)(\s+# TODO: Replace with specific service validation query)`)
	content = auditServicePattern.ReplaceAllString(content, "$1 AND state = 'running';")

	return content
}

// FixFilePermissionQueries fixes file permission related queries
func (sqf *SpecificQueryFixer) FixFilePermissionQueries(content string) string {
	// File ownership by root
	fileOwnershipPattern := regexp.MustCompile(`(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)`)
	content = fileOwnershipPattern.ReplaceAllString(content, "$1 FROM file WHERE path LIKE '/var/audit/%' AND uid = 0;")

	// File group ownership
	fileGroupPattern := regexp.MustCompile(`(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)`)
	content = fileGroupPattern.ReplaceAllString(content, "$1 FROM file WHERE path LIKE '/var/audit/%' AND gid = 0;")

	// File permissions
	filePermissionsPattern := regexp.MustCompile(`(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)`)
	content = filePermissionsPattern.ReplaceAllString(content, "$1 FROM file WHERE path LIKE '/var/audit/%' AND mode <= '440';")

	return content
}

// FixManagedPolicyQueries fixes managed policy queries
func (sqf *SpecificQueryFixer) FixManagedPolicyQueries(content string) string {
	// Generic managed policy check
	managedPolicyPattern := regexp.MustCompile(`(\s+query: SELECT 1;)(\s+# TODO: Replace with specific query for this policy)`)
	content = managedPolicyPattern.ReplaceAllString(content, "$1 FROM managed_policies WHERE domain = 'com.apple.applicationaccess';")

	return content
}

// FixSpecificPolicyQueries fixes specific policy queries based on policy names
func (sqf *SpecificQueryFixer) FixSpecificPolicyQueries(filePath string) (int, error) {
	fmt.Printf("Processing %s...\n", filePath)

	content, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("failed to read file %s: %w", filePath, err)
	}

	originalContent := string(content)
	contentStr := originalContent

	// Apply audit-related fixes
	contentStr = sqf.FixAuditQueries(contentStr)

	// Apply file permission fixes
	contentStr = sqf.FixFilePermissionQueries(contentStr)

	// Apply managed policy fixes
	contentStr = sqf.FixManagedPolicyQueries(contentStr)

	// Count remaining TODO comments
	remainingTodos := strings.Count(contentStr, "# TODO:")

	if contentStr != originalContent {
		err = os.WriteFile(filePath, []byte(contentStr), 0644)
		if err != nil {
			return 0, fmt.Errorf("failed to write file %s: %w", filePath, err)
		}
		fmt.Printf("  Applied specific query fixes\n")
	}

	fmt.Printf("  Remaining TODO comments: %d\n", remainingTodos)
	return remainingTodos, nil
}

// ProcessAllFiles processes all YAML files in the current directory
func (sqf *SpecificQueryFixer) ProcessAllFiles() error {
	yamlFiles, err := filepath.Glob("*-fleet-policies.yml")
	if err != nil {
		return fmt.Errorf("failed to find YAML files: %w", err)
	}

	totalRemaining := 0

	for _, yamlFile := range yamlFiles {
		if strings.HasSuffix(yamlFile, ".bak") {
			continue
		}

		remaining, err := sqf.FixSpecificPolicyQueries(yamlFile)
		if err != nil {
			fmt.Printf("Error processing %s: %v\n", yamlFile, err)
			continue
		}
		totalRemaining += remaining
	}

	fmt.Printf("\nTotal remaining TODO comments: %d\n", totalRemaining)
	fmt.Println("\nNote: Some policies may require manual review to create appropriate queries.")
	return nil
}

// RunFixSpecific runs the specific query fixer
func RunFixSpecific() error {
	fixer := NewSpecificQueryFixer()
	return fixer.ProcessAllFiles()
}
