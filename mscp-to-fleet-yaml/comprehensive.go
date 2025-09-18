package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// ComprehensiveQueryFixer handles comprehensive query fixing
type ComprehensiveQueryFixer struct {
	queryMappings []QueryMapping
}

// NewComprehensiveQueryFixer creates a new comprehensive query fixer
func NewComprehensiveQueryFixer() *ComprehensiveQueryFixer {
	return &ComprehensiveQueryFixer{
		queryMappings: CreateQueryMappings(),
	}
}

// FixPolicyQueries fixes queries in a single policy file
func (cqf *ComprehensiveQueryFixer) FixPolicyQueries(filePath string) (int, error) {
	fmt.Printf("Processing %s...\n", filePath)

	content, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("failed to read file %s: %w", filePath, err)
	}

	originalContent := string(content)
	changesMade := 0

	// Find all policy blocks using regex
	policyPattern := regexp.MustCompile(`(?s)(name: ([^\n]+)\n[^}]+?query: )([^\n]+)(\n[^}]+?purpose: Informational)`)

	newContent := policyPattern.ReplaceAllStringFunc(originalContent, func(match string) string {
		submatches := policyPattern.FindStringSubmatch(match)
		if len(submatches) < 5 {
			return match
		}

		policyName := strings.ToLower(submatches[2])
		currentQuery := submatches[3]

		// Skip if already has a specific query
		if strings.Contains(currentQuery, "FROM") && !strings.Contains(currentQuery, "SELECT 1") {
			return match
		}

		// Find matching pattern
		for _, mapping := range cqf.queryMappings {
			pattern, err := regexp.Compile("(?i)" + mapping.Pattern)
			if err != nil {
				continue
			}
			if pattern.MatchString(policyName) {
				changesMade++
				return fmt.Sprintf("%s%s%s", submatches[1], mapping.Query, submatches[4])
			}
		}

		// Default fallback
		changesMade++
		return fmt.Sprintf("%s%s%s", submatches[1], cqf.queryMappings[len(cqf.queryMappings)-1].Query, submatches[4])
	})

	if changesMade > 0 {
		err = os.WriteFile(filePath, []byte(newContent), 0644)
		if err != nil {
			return 0, fmt.Errorf("failed to write file %s: %w", filePath, err)
		}
		fmt.Printf("  Fixed %d queries\n", changesMade)
	} else {
		fmt.Printf("  No queries needed fixing\n")
	}

	return changesMade, nil
}

// ProcessAllFiles processes all YAML files in the current directory
func (cqf *ComprehensiveQueryFixer) ProcessAllFiles() error {
	yamlFiles, err := filepath.Glob("*-fleet-policies.yml")
	if err != nil {
		return fmt.Errorf("failed to find YAML files: %w", err)
	}

	totalChanges := 0

	for _, yamlFile := range yamlFiles {
		if strings.HasSuffix(yamlFile, ".bak") {
			continue
		}

		changes, err := cqf.FixPolicyQueries(yamlFile)
		if err != nil {
			fmt.Printf("Error processing %s: %v\n", yamlFile, err)
			continue
		}
		totalChanges += changes
	}

	fmt.Printf("\nTotal queries fixed: %d\n", totalChanges)
	fmt.Println("\nAll policy files have been updated with appropriate queries!")
	return nil
}

// RunComprehensive runs the comprehensive query fixer
func RunComprehensive() error {
	fixer := NewComprehensiveQueryFixer()
	return fixer.ProcessAllFiles()
}
