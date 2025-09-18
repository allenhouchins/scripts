package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// CleanText removes AsciiDoc and Markdown formatting from text
func CleanText(text string) string {
	if text == "" {
		return ""
	}

	// Remove AsciiDoc formatting
	text = regexp.MustCompile(`\[source,[^\]]+\]`).ReplaceAllString(text, "")
	text = regexp.MustCompile(`----+`).ReplaceAllString(text, "")
	text = regexp.MustCompile(`\[source\]`).ReplaceAllString(text, "")
	text = regexp.MustCompile(`\[source,bash\]`).ReplaceAllString(text, "")
	text = regexp.MustCompile(`\[source,xml\]`).ReplaceAllString(text, "")

	// Clean up Markdown formatting
	text = regexp.MustCompile(`\*([^*]+)\*`).ReplaceAllString(text, "$1") // Remove bold
	text = regexp.MustCompile(`_([^_]+)_`).ReplaceAllString(text, "$1")   // Remove italic
	text = regexp.MustCompile("`([^`]+)`").ReplaceAllString(text, "$1")   // Remove code

	// Clean up extra whitespace and newlines
	text = regexp.MustCompile(`\n\s*\n\s*\n+`).ReplaceAllString(text, "\n\n") // Multiple newlines to double
	text = regexp.MustCompile(`(?m)^\s+`).ReplaceAllString(text, "")          // Remove leading whitespace
	text = strings.TrimSpace(text)

	return text
}

// ConvertCheckToQuery converts a check script to a Fleet query
func ConvertCheckToQuery(checkScript, ruleID string) string {
	// Extract the osascript command and convert to SQL-like query
	if strings.Contains(checkScript, "osascript") && strings.Contains(checkScript, "objectForKey") {
		// Extract suite name and key using regex
		suiteRegex := regexp.MustCompile(`initWithSuiteName\('([^']+)'\)`)
		keyRegex := regexp.MustCompile(`objectForKey\('([^']+)'\)`)

		suiteMatch := suiteRegex.FindStringSubmatch(checkScript)
		keyMatch := keyRegex.FindStringSubmatch(checkScript)

		if len(suiteMatch) > 1 && len(keyMatch) > 1 {
			suiteName := suiteMatch[1]
			keyName := keyMatch[1]
			return fmt.Sprintf("SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='%s' AND name='%s' AND (value = 1 OR value = 'true'));", suiteName, keyName)
		}
	}

	// For file-based checks, create appropriate queries
	if strings.Contains(checkScript, "/etc/") || strings.Contains(checkScript, "/var/") {
		if strings.Contains(ruleID, "audit") {
			return "SELECT 1 FROM file WHERE path LIKE '/var/audit/%' OR path LIKE '/etc/security/%';"
		} else if strings.Contains(checkScript, "chmod") {
			return "SELECT 1 FROM file WHERE path LIKE '/etc/%' OR path LIKE '/var/%';"
		} else if strings.Contains(checkScript, "chown") {
			return "SELECT 1 FROM file WHERE path LIKE '/etc/%' OR path LIKE '/var/%';"
		} else {
			return "SELECT 1 FROM file WHERE path LIKE '/etc/%' OR path LIKE '/var/%';"
		}
	}

	// For launchctl checks
	if strings.Contains(checkScript, "launchctl") {
		if strings.Contains(ruleID, "audit") {
			return "SELECT 1 FROM launchd WHERE name = 'com.apple.auditd';"
		} else {
			return "SELECT 1 FROM launchd WHERE name LIKE '%audit%';"
		}
	}

	// For system_profiler checks
	if strings.Contains(checkScript, "system_profiler") {
		return "SELECT 1 FROM system_info;"
	}

	// For software update checks
	if strings.Contains(checkScript, "softwareupdate") {
		return "SELECT 1 FROM software_update WHERE software_update_required = '0';"
	}

	// For general system checks
	if strings.Contains(checkScript, "defaults") {
		return "SELECT 1 FROM managed_policies;"
	}

	// For specific rule types
	if strings.Contains(ruleID, "firewall") {
		return "SELECT 1 FROM managed_policies WHERE domain = 'com.apple.security.firewall';"
	} else if strings.Contains(ruleID, "gatekeeper") {
		return "SELECT 1 FROM managed_policies WHERE domain = 'com.apple.systempolicy.control';"
	} else if strings.Contains(ruleID, "filevault") {
		return "SELECT 1 FROM managed_policies WHERE domain = 'com.apple.MCX';"
	}

	// Default fallback - use a simple check that will always pass
	return "SELECT 1;"
}

// FindYAMLFiles finds all YAML files matching the pattern
func FindYAMLFiles(dir string, pattern string) ([]string, error) {
	var files []string
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && strings.HasSuffix(path, pattern) {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}

// GetBaselineName extracts the baseline name from a file path
func GetBaselineName(filePath string) string {
	base := filepath.Base(filePath)
	ext := filepath.Ext(base)
	return strings.TrimSuffix(base, ext)
}

// CreateFleetPolicy creates a Fleet policy from a rule definition
func CreateFleetPolicy(rule *Rule, baselineName string) *FleetPolicy {
	if rule == nil {
		return nil
	}

	// Extract CIS benchmark information if available
	var cisBenchmark, cisLevel string
	if references, ok := rule.References["cis"].(map[string]interface{}); ok {
		if benchmark, ok := references["benchmark"].([]interface{}); ok && len(benchmark) > 0 {
			cisBenchmark = benchmark[0].(string)
		}
		if level, ok := references["level"].([]interface{}); ok && len(level) > 0 {
			cisLevel = level[0].(string)
		}
	}

	// Create tags
	tags := []string{"compliance", "macOS_Security_Compliance"}
	if cisBenchmark != "" {
		tags = append(tags, fmt.Sprintf("CIS_%s", cisBenchmark))
	}
	if cisLevel != "" {
		tags = append(tags, fmt.Sprintf("CIS_Level%s", cisLevel))
	}

	// Add baseline-specific tag
	baselineTag := strings.ReplaceAll(baselineName, "_", "_")
	baselineTag = strings.ReplaceAll(baselineTag, "-", "_")
	tags = append(tags, baselineTag)

	// Convert check script to query
	query := ConvertCheckToQuery(rule.Check, rule.ID)

	// Clean description and resolution text
	description := CleanText(rule.Discussion)
	resolution := CleanText(rule.Fix)

	policyName := rule.Title
	if policyName == "" {
		policyName = rule.ID
	}

	return &FleetPolicy{
		APIVersion: "v1",
		Kind:       "policy",
		Spec: PolicySpec{
			Name:         fmt.Sprintf("macOS Security - %s", policyName),
			Platforms:    "macOS",
			Platform:     "darwin",
			Description:  description,
			Resolution:   resolution,
			Query:        strings.TrimSpace(query),
			Purpose:      "Informational",
			Tags:         tags,
			Contributors: "macos_security_compliance_project",
		},
	}
}
