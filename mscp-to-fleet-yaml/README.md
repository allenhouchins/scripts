# Fleet-Compatible macOS Security Policies

This directory contains Fleet-compatible YAML policy files generated from the macOS Security Compliance Project baselines.

## Overview

The macOS Security Compliance Project provides security configuration guidance for macOS systems based on various compliance frameworks including:

- **CIS Benchmarks** (Center for Internet Security)
- **NIST SP 800-53** (National Institute of Standards and Technology)
- **NIST SP 800-171** (Controlled Unclassified Information)
- **CMMC 2.0** (Cybersecurity Maturity Model Certification)
- **CNSSI-1253** (Committee on National Security Systems Instruction)

## Generated Policy Files

The following Fleet-compatible policy files have been generated:

| Baseline | Policies | Description |
|----------|----------|-------------|
| `cis_lvl1-fleet-policies.yml` | 95 | CIS Level 1 Benchmark policies |
| `cis_lvl2-fleet-policies.yml` | 116 | CIS Level 2 Benchmark policies |
| `cisv8-fleet-policies.yml` | 175 | CIS Controls v8 policies |
| `800-53r5_low-fleet-policies.yml` | 161 | NIST SP 800-53 Rev 5 Low Impact |
| `800-53r5_moderate-fleet-policies.yml` | 208 | NIST SP 800-53 Rev 5 Moderate Impact |
| `800-53r5_high-fleet-policies.yml` | 217 | NIST SP 800-53 Rev 5 High Impact |
| `800-171-fleet-policies.yml` | 173 | NIST SP 800-171 policies |
| `cmmc_lvl1-fleet-policies.yml` | 88 | CMMC 2.0 Level 1 policies |
| `cmmc_lvl2-fleet-policies.yml` | 214 | CMMC 2.0 Level 2 policies |
| `cnssi-1253_low-fleet-policies.yml` | 250 | CNSSI-1253 Low Impact |
| `cnssi-1253_moderate-fleet-policies.yml` | 259 | CNSSI-1253 Moderate Impact |
| `cnssi-1253_high-fleet-policies.yml` | 269 | CNSSI-1253 High Impact |
| `all_rules-fleet-policies.yml` | 331 | All available security rules |

**Total: 2,556 policies across 13 baselines**

## Policy Structure

Each policy follows the Fleet policy format:

```yaml
apiVersion: v1
kind: policy
spec:
  name: "macOS Security - [Policy Name]"
  platforms: macOS
  platform: darwin
  description: "[Policy description from the original rule]"
  resolution: "[Remediation steps from the original rule]"
  query: "[Fleet query to check compliance]"
  purpose: Informational
  tags:
    - compliance
    - macOS_Security_Compliance
    - [Baseline-specific tags]
  contributors: macos_security_compliance_project
```

## Query Types

The policies include various types of Fleet queries:

1. **Managed Policies**: Check Configuration Profile settings
   ```sql
   SELECT 1 WHERE EXISTS (
     SELECT 1 FROM managed_policies WHERE 
       domain='com.apple.applicationaccess' AND 
       name='allowAirDrop' AND 
       (value = 1 OR value = 'true')
   );
   ```

2. **File System**: Check file permissions and ownership
   ```sql
   SELECT 1 FROM file WHERE path LIKE '/etc/%' OR path LIKE '/var/%';
   ```

3. **System Services**: Check launchd services
   ```sql
   SELECT 1 FROM launchd WHERE name LIKE '%service_name%';
   ```

4. **Software Updates**: Check update status
   ```sql
   SELECT 1 FROM software_update WHERE software_update_required = '0';
   ```

## Usage

1. **Import into Fleet**: Use the Fleet UI or API to import these policy files
2. **Select Baselines**: Choose the appropriate baseline(s) for your organization's compliance requirements
3. **Customize**: Modify policies as needed for your specific environment
4. **Deploy**: Apply policies to your macOS endpoints

## Compliance Mapping

Each policy includes tags that map to the original compliance frameworks:

- `CIS_Level1`, `CIS_Level2`: CIS Benchmark levels
- `800-53r5_low`, `800-53r5_moderate`, `800-53r5_high`: NIST SP 800-53 impact levels
- `cmmc_lvl1`, `cmmc_lvl2`: CMMC 2.0 levels
- `cnssi-1253_low`, `cnssi-1253_moderate`, `cnssi-1253_high`: CNSSI-1253 impact levels

## Generation

These policies were generated using the `convert_baselines.py` script, which:

1. Parses the original baseline YAML files
2. Loads individual rule definitions from the `rules/` directory
3. Converts macOS-specific check scripts to Fleet queries
4. Generates Fleet-compatible policy YAML files

## Source

Generated from the [macOS Security Compliance Project](https://github.com/usnistgov/macos_security) baselines.

## Notes

- Some policies may require manual review and adjustment for your specific environment
- Policies are designed to work with Fleet's osquery-based data collection
- Configuration Profile-based policies assume proper MDM deployment
- File-based policies may require additional permissions or system access
