package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	var (
		command = flag.String("command", "", "Command to run: convert, fix-queries, fix-specific, comprehensive")
		help    = flag.Bool("help", false, "Show help")
	)

	flag.Parse()

	if *help || *command == "" {
		showHelp()
		return
	}

	switch *command {
	case "convert":
		if err := RunConvert(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	case "fix-queries":
		if err := RunFixQueries(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	case "fix-specific":
		if err := RunFixSpecific(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	case "comprehensive":
		if err := RunComprehensive(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", *command)
		showHelp()
		os.Exit(1)
	}
}

func showHelp() {
	fmt.Println("Fleet Policy Converter - Convert macOS Security Compliance Project to Fleet YAML")
	fmt.Println("")
	fmt.Println("Usage:")
	fmt.Println("  go run . -command <command> [options]")
	fmt.Println("")
	fmt.Println("Commands:")
	fmt.Println("  convert      - Convert baselines to Fleet-compatible YAML format")
	fmt.Println("  fix-queries  - Fix generic queries in existing YAML files")
	fmt.Println("  fix-specific - Fix specific query patterns based on policy names")
	fmt.Println("  comprehensive - Comprehensive query fixing with pattern matching")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  go run . -command convert")
	fmt.Println("  go run . -command fix-queries")
	fmt.Println("  go run . -command comprehensive")
}
