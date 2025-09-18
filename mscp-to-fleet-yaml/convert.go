package main

import (
	"fmt"
	"os"
	"path/filepath"
)

// BaselineConverter handles conversion of baselines to Fleet format
type BaselineConverter struct {
	projectRoot  string
	baselinesDir string
	rulesDir     string
	outputDir    string
}

// NewBaselineConverter creates a new baseline converter
func NewBaselineConverter(projectRoot string) *BaselineConverter {
	return &BaselineConverter{
		projectRoot:  projectRoot,
		baselinesDir: filepath.Join(projectRoot, "baselines"),
		rulesDir:     filepath.Join(projectRoot, "rules"),
		outputDir:    filepath.Join(projectRoot, "fleet"),
	}
}

// LoadRule loads a rule definition from the rules directory
func (bc *BaselineConverter) LoadRule(ruleID string) (*Rule, error) {
	// Try different possible locations for the rule
	possiblePaths := []string{
		filepath.Join(bc.rulesDir, "os", ruleID+".yaml"),
		filepath.Join(bc.rulesDir, "system_settings", ruleID+".yaml"),
		filepath.Join(bc.rulesDir, "audit", ruleID+".yaml"),
		filepath.Join(bc.rulesDir, "auth", ruleID+".yaml"),
		filepath.Join(bc.rulesDir, "icloud", ruleID+".yaml"),
		filepath.Join(bc.rulesDir, "pwpolicy", ruleID+".yaml"),
		filepath.Join(bc.rulesDir, "supplemental", ruleID+".yaml"),
	}

	for _, path := range possiblePaths {
		if _, err := os.Stat(path); err == nil {
			var rule Rule
			err := LoadYAML(path, &rule)
			if err != nil {
				return nil, fmt.Errorf("failed to load rule %s from %s: %w", ruleID, path, err)
			}
			return &rule, nil
		}
	}

	fmt.Printf("Warning: Could not find rule %s\n", ruleID)
	return nil, nil
}

// ConvertBaselineToFleet converts a baseline to Fleet-compatible YAML
func (bc *BaselineConverter) ConvertBaselineToFleet(baselinePath string) (int, error) {
	var baseline Baseline
	err := LoadYAML(baselinePath, &baseline)
	if err != nil {
		return 0, fmt.Errorf("failed to load baseline %s: %w", baselinePath, err)
	}

	baselineName := GetBaselineName(baselinePath)
	outputFile := filepath.Join(bc.outputDir, baselineName+"-fleet-policies.yml")

	policies := []*FleetPolicy{}

	// Process each section and its rules
	for _, section := range baseline.Profile {
		rules := section.Rules

		for _, ruleID := range rules {
			rule, err := bc.LoadRule(ruleID)
			if err != nil {
				fmt.Printf("Error loading rule %s: %v\n", ruleID, err)
				continue
			}
			if rule != nil {
				policy := CreateFleetPolicy(rule, baselineName)
				if policy != nil {
					policies = append(policies, policy)
				}
			}
		}
	}

	// Write all policies to output file
	err = os.MkdirAll(bc.outputDir, 0755)
	if err != nil {
		return 0, fmt.Errorf("failed to create output directory: %w", err)
	}

	file, err := os.Create(outputFile)
	if err != nil {
		return 0, fmt.Errorf("failed to create output file %s: %w", outputFile, err)
	}
	defer file.Close()

	// Write header
	title := baseline.Title
	if title == "" {
		title = baselineName
	}
	fmt.Fprintf(file, "# Fleet policies for %s\n", title)
	fmt.Fprintf(file, "# Generated from macOS Security Compliance Project\n\n")

	// Write policies
	for i, policy := range policies {
		data, err := MarshalYAML(policy)
		if err != nil {
			fmt.Printf("Error marshaling policy %d: %v\n", i, err)
			continue
		}
		file.Write(data)
		file.WriteString("---\n")
	}

	fmt.Printf("Converted %s: %d policies written to %s\n", baselineName, len(policies), outputFile)
	return len(policies), nil
}

// ConvertAllBaselines converts all baseline files
func (bc *BaselineConverter) ConvertAllBaselines() error {
	// Ensure output directory exists
	err := os.MkdirAll(bc.outputDir, 0755)
	if err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Find all baseline files
	baselineFiles, err := filepath.Glob(filepath.Join(bc.baselinesDir, "*.yaml"))
	if err != nil {
		return fmt.Errorf("failed to find baseline files: %w", err)
	}

	totalPolicies := 0
	for _, baselineFile := range baselineFiles {
		count, err := bc.ConvertBaselineToFleet(baselineFile)
		if err != nil {
			fmt.Printf("Error converting %s: %v\n", baselineFile, err)
			continue
		}
		totalPolicies += count
	}

	fmt.Printf("\nConversion complete! Generated %d total policies across %d baselines.\n", totalPolicies, len(baselineFiles))
	fmt.Printf("Output directory: %s\n", bc.outputDir)
	return nil
}

// RunConvert runs the baseline conversion
func RunConvert() error {
	// Set up paths - you may need to adjust this path
	projectRoot := "/Users/allen/GitHub/macos_security"

	// Check if the project root exists
	if _, err := os.Stat(projectRoot); os.IsNotExist(err) {
		fmt.Printf("Project root %s does not exist. Please update the path in convert.go\n", projectRoot)
		return fmt.Errorf("project root not found: %s", projectRoot)
	}

	converter := NewBaselineConverter(projectRoot)
	return converter.ConvertAllBaselines()
}
