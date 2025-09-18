package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// QueryFixer handles fixing generic queries in YAML files
type QueryFixer struct{}

// NewQueryFixer creates a new query fixer
func NewQueryFixer() *QueryFixer {
	return &QueryFixer{}
}

// FixGenericQueries fixes generic queries in a YAML file
func (qf *QueryFixer) FixGenericQueries(filePath string) (int, error) {
	fmt.Printf("Processing %s...\n", filePath)

	content, err := os.ReadFile(filePath)
	if err != nil {
		return 0, fmt.Errorf("failed to read file %s: %w", filePath, err)
	}

	originalContent := string(content)
	changes := 0

	// Fix generic SELECT 1; queries
	// These should be replaced with meaningful queries based on policy context
	select1Pattern := regexp.MustCompile(`(\s+query: SELECT 1;)(\s+purpose: Informational)`)
	originalContent = select1Pattern.ReplaceAllStringFunc(originalContent, func(match string) string {
		changes++
		return strings.Replace(match, "SELECT 1;", "SELECT 1;  # TODO: Replace with specific query for this policy", 1)
	})

	// Fix overly generic file path queries
	filePathPattern := regexp.MustCompile(`(\s+query: SELECT 1 FROM file WHERE path LIKE '/[^%]+%';)(\s+purpose: Informational)`)
	originalContent = filePathPattern.ReplaceAllStringFunc(originalContent, func(match string) string {
		changes++
		return strings.Replace(match, "SELECT 1 FROM file WHERE path LIKE '/[^%]+%';", "SELECT 1 FROM file WHERE path LIKE '/[^%]+%';  # TODO: Replace with specific file validation query", 1)
	})

	// Fix generic launchd queries
	launchdPattern := regexp.MustCompile(`(\s+query: SELECT 1 FROM launchd WHERE name LIKE '%[^%]+%';)(\s+purpose: Informational)`)
	originalContent = launchdPattern.ReplaceAllStringFunc(originalContent, func(match string) string {
		changes++
		return strings.Replace(match, "SELECT 1 FROM launchd WHERE name LIKE '%[^%]+%';", "SELECT 1 FROM launchd WHERE name LIKE '%[^%]+%';  # TODO: Replace with specific service validation query", 1)
	})

	if changes > 0 {
		err = os.WriteFile(filePath, []byte(originalContent), 0644)
		if err != nil {
			return 0, fmt.Errorf("failed to write file %s: %w", filePath, err)
		}
		fmt.Printf("  Added %d TODO comments for generic queries\n", changes)
	} else {
		fmt.Printf("  No generic queries found to fix\n")
	}

	return changes, nil
}

// ProcessAllFiles processes all YAML files in the current directory
func (qf *QueryFixer) ProcessAllFiles() error {
	yamlFiles, err := filepath.Glob("*-fleet-policies.yml")
	if err != nil {
		return fmt.Errorf("failed to find YAML files: %w", err)
	}

	totalChanges := 0

	for _, yamlFile := range yamlFiles {
		if strings.HasSuffix(yamlFile, ".bak") {
			continue
		}

		changes, err := qf.FixGenericQueries(yamlFile)
		if err != nil {
			fmt.Printf("Error processing %s: %v\n", yamlFile, err)
			continue
		}
		totalChanges += changes
	}

	fmt.Printf("\nTotal changes made: %d\n", totalChanges)
	fmt.Println("\nNext steps:")
	fmt.Println("1. Review the TODO comments in each file")
	fmt.Println("2. Replace TODO comments with specific queries based on policy requirements")
	fmt.Println("3. Test the corrected queries")
	return nil
}

// RunFixQueries runs the query fixer
func RunFixQueries() error {
	fixer := NewQueryFixer()
	return fixer.ProcessAllFiles()
}
