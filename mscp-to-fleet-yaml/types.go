package main

import (
	"os"

	"gopkg.in/yaml.v3"
)

// FleetPolicy represents a Fleet policy structure
type FleetPolicy struct {
	APIVersion string     `yaml:"apiVersion"`
	Kind       string     `yaml:"kind"`
	Spec       PolicySpec `yaml:"spec"`
}

// PolicySpec represents the policy specification
type PolicySpec struct {
	Name         string   `yaml:"name"`
	Platforms    string   `yaml:"platforms"`
	Platform     string   `yaml:"platform"`
	Description  string   `yaml:"description"`
	Resolution   string   `yaml:"resolution"`
	Query        string   `yaml:"query"`
	Purpose      string   `yaml:"purpose"`
	Tags         []string `yaml:"tags"`
	Contributors string   `yaml:"contributors"`
}

// Baseline represents a baseline configuration
type Baseline struct {
	Title   string    `yaml:"title"`
	Profile []Section `yaml:"profile"`
}

// Section represents a section in a baseline
type Section struct {
	Section string   `yaml:"section"`
	Rules   []string `yaml:"rules"`
}

// Rule represents a security rule definition
type Rule struct {
	ID         string                 `yaml:"id"`
	Title      string                 `yaml:"title"`
	Discussion string                 `yaml:"discussion"`
	Fix        string                 `yaml:"fix"`
	Check      string                 `yaml:"check"`
	References map[string]interface{} `yaml:"references"`
}

// QueryMapping represents a pattern-to-query mapping
type QueryMapping struct {
	Pattern string
	Query   string
}

// CreateQueryMappings returns the comprehensive query mappings
func CreateQueryMappings() []QueryMapping {
	return []QueryMapping{
		// Audit-related policies
		{`.*audit.*files.*not.*contain.*access.*control.*lists.*`,
			"SELECT 1 FROM file WHERE (path LIKE '/var/audit/%' OR path LIKE '/etc/security/%') AND extended_attributes LIKE '%com.apple.acl%';"},

		{`.*audit.*folder.*not.*contain.*access.*control.*lists.*`,
			"SELECT 1 FROM file WHERE (path LIKE '/var/audit/%' OR path LIKE '/etc/security/%') AND type = 'directory' AND extended_attributes LIKE '%com.apple.acl%';"},

		{`.*enable.*security.*auditing.*`,
			"SELECT 1 FROM launchd WHERE name = 'com.apple.auditd' AND state = 'running';"},

		{`.*audit.*capacity.*warning.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/audit_control' AND content LIKE '%minfree%';"},

		{`.*shut.*down.*upon.*audit.*failure.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/audit_control' AND content LIKE '%policy: ahlt%';"},

		{`.*audit.*log.*files.*group.*wheel.*`,
			"SELECT 1 FROM file WHERE path LIKE '/var/audit/%' AND gid = 0;"},

		{`.*audit.*log.*files.*mode.*440.*`,
			"SELECT 1 FROM file WHERE path LIKE '/var/audit/%' AND mode <= '440';"},

		{`.*audit.*log.*files.*owned.*root.*`,
			"SELECT 1 FROM file WHERE path LIKE '/var/audit/%' AND uid = 0;"},

		{`.*audit.*folders.*group.*wheel.*`,
			"SELECT 1 FROM file WHERE path = '/var/audit' AND type = 'directory' AND gid = 0;"},

		{`.*audit.*folders.*owned.*root.*`,
			"SELECT 1 FROM file WHERE path = '/var/audit' AND type = 'directory' AND uid = 0;"},

		{`.*audit.*folders.*mode.*700.*`,
			"SELECT 1 FROM file WHERE path = '/var/audit' AND type = 'directory' AND mode <= '700';"},

		// Audit event policies
		{`.*audit.*authorization.*authentication.*events.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%aa%';"},

		{`.*audit.*administrative.*action.*events.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%ad%';"},

		{`.*audit.*failed.*program.*execution.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-ex%';"},

		{`.*audit.*deletions.*object.*attributes.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fd%';"},

		{`.*audit.*failed.*change.*object.*attributes.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fm%';"},

		{`.*audit.*failed.*read.*actions.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fr%';"},

		{`.*audit.*failed.*write.*actions.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%-fw%';"},

		{`.*audit.*log.*in.*log.*out.*events.*`,
			"SELECT 1 FROM file WHERE path = '/etc/security/auditcontrol' AND content LIKE '%lo%';"},

		// FileVault policies
		{`.*filevault.*enabled.*`,
			"SELECT 1 FROM disk_encryption WHERE name = 'FileVault' AND encrypted = 1;"},

		{`.*filevault.*auto.*login.*disabled.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.loginwindow' AND name='DisableFDEAutoLogin' AND (value = 1 OR value = 'true'));"},

		// Firewall policies
		{`.*firewall.*enabled.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.security.firewall' AND name='EnableFirewall' AND (value = 1 OR value = 'true'));"},

		{`.*firewall.*stealth.*mode.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.security.firewall' AND name='EnableStealthMode' AND (value = 1 OR value = 'true'));"},

		// Screen saver policies
		{`.*screen.*saver.*password.*required.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.screensaver' AND name='askForPassword' AND (value = 1 OR value = 'true'));"},

		{`.*screen.*saver.*timeout.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.screensaver' AND name='idleTime' AND (value = 1 OR value = 'true'));"},

		// Location services
		{`.*location.*services.*disabled.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.locationd' AND name='LocationServicesEnabled' AND (value = 1 OR value = 'true'));"},

		// Bluetooth
		{`.*bluetooth.*disabled.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.MCXBluetooth' AND name='DisableBluetooth' AND (value = 1 OR value = 'true'));"},

		// Guest account
		{`.*guest.*account.*disabled.*`,
			"SELECT 1 WHERE EXISTS (SELECT 1 FROM managed_policies WHERE domain='com.apple.MCX' AND name='DisableGuestAccount' AND (value = 1 OR value = 'true'));"},

		// Software updates
		{`.*software.*update.*automatic.*`,
			"SELECT 1 FROM software_update WHERE software_update_required = '0';"},

		// Generic managed policy fallback
		{`.*`,
			"SELECT 1 FROM managed_policies WHERE domain = 'com.apple.applicationaccess';"},
	}
}

// LoadYAML loads a YAML file into the given interface
func LoadYAML(filename string, v interface{}) error {
	data, err := os.ReadFile(filename)
	if err != nil {
		return err
	}
	return yaml.Unmarshal(data, v)
}

// SaveYAML saves the given interface to a YAML file
func SaveYAML(filename string, v interface{}) error {
	data, err := yaml.Marshal(v)
	if err != nil {
		return err
	}
	return os.WriteFile(filename, data, 0644)
}

// MarshalYAML marshals the given interface to YAML bytes
func MarshalYAML(v interface{}) ([]byte, error) {
	return yaml.Marshal(v)
}
