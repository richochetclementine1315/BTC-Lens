package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"chain-lens/pkg/parser"
	"chain-lens/pkg/types"
)

func main() {
	// Check arguments
	if len(os.Args) < 2 {
		printError("INVALID_ARGS", "Usage: cli <fixture.json> or cli --block <blk.dat> <rev.dat> <xor.dat>")
		os.Exit(1)
	}

	// Block mode
	if os.Args[1] == "--block" {
		if len(os.Args) < 5 {
			printError("INVALID_ARGS", "Block mode requires: --block <blk.dat> <rev.dat> <xor.dat>")
			os.Exit(1)
		}
		handleBlockMode(os.Args[2], os.Args[3], os.Args[4])
		return
	}

	// Transaction mode
	handleTransactionMode(os.Args[1])
}

func handleTransactionMode(fixturePath string) {
	// Read fixture file
	fixtureData, err := os.ReadFile(fixturePath)
	if err != nil {
		printError("FILE_NOT_FOUND", fmt.Sprintf("Failed to read fixture: %v", err))
		os.Exit(1)
	}

	// Parse fixture JSON
	var fixture types.Fixture
	if err := json.Unmarshal(fixtureData, &fixture); err != nil {
		printError("INVALID_FIXTURE", fmt.Sprintf("Failed to parse fixture JSON: %v", err))
		os.Exit(1)
	}

	// Parse transaction
	result, err := parser.ParseTransaction(fixture)
	if err != nil {
		printError("INVALID_TX", err.Error())
		os.Exit(1)
	}

	// Create output directory
	if err := os.MkdirAll("out", 0755); err != nil {
		printError("IO_ERROR", fmt.Sprintf("Failed to create output directory: %v", err))
		os.Exit(1)
	}

	// Write to file
	outputPath := filepath.Join("out", result.Txid+".json")
	outputJSON, _ := json.MarshalIndent(result, "", "  ")
	if err := os.WriteFile(outputPath, outputJSON, 0644); err != nil {
		printError("IO_ERROR", fmt.Sprintf("Failed to write output file: %v", err))
		os.Exit(1)
	}

	// Print to stdout
	fmt.Println(string(outputJSON))
	os.Exit(0)
}

func handleBlockMode(blkPath, revPath, xorPath string) {
	// Validate files exist
	for _, path := range []string{blkPath, revPath, xorPath} {
		if _, err := os.Stat(path); os.IsNotExist(err) {
			printError("FILE_NOT_FOUND", fmt.Sprintf("File not found: %s", path))
			os.Exit(1)
		}
	}

	// Parse blocks
	blocks, err := parser.ParseBlock(blkPath, revPath, xorPath)
	if err != nil {
		printError("INVALID_BLOCK", err.Error())
		os.Exit(1)
	}

	// Create output directory
	if err := os.MkdirAll("out", 0755); err != nil {
		printError("IO_ERROR", fmt.Sprintf("Failed to create output directory: %v", err))
		os.Exit(1)
	}

	// Write each block to file
	for _, block := range blocks {
		outputPath := filepath.Join("out", block.BlockHeader.BlockHash+".json")
		outputJSON, _ := json.MarshalIndent(block, "", "  ")
		if err := os.WriteFile(outputPath, outputJSON, 0644); err != nil {
			printError("IO_ERROR", fmt.Sprintf("Failed to write block output: %v", err))
			os.Exit(1)
		}
	}

	os.Exit(0)
}

func printError(code, message string) {
	type errorOutput struct {
		OK    bool             `json:"ok"`
		Error *types.ErrorInfo `json:"error"`
	}
	errOutput := errorOutput{
		OK: false,
		Error: &types.ErrorInfo{
			Code:    code,
			Message: message,
		},
	}
	errJSON, _ := json.Marshal(errOutput)
	fmt.Println(string(errJSON))
	fmt.Fprintf(os.Stderr, "Error: %s\n", message)
}
