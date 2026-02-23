package analyzer

import "chain-lens/pkg/types"

// GenerateWarnings creates warning array based on transaction analysis
func GenerateWarnings(
	feeSats int64,
	feeRate float64,
	rbfSignaling bool,
	outputs []types.Output,
) []types.Warning {
	warnings := make([]types.Warning, 0)

	// HIGH_FEE: fee > 1M sats OR fee rate > 200 sat/vB
	if feeSats > 1000000 || feeRate > 200 {
		warnings = append(warnings, types.Warning{Code: "HIGH_FEE"})
	}

	// DUST_OUTPUT: any non-OP_RETURN output < 546 sats
	for _, out := range outputs {
		if out.ScriptType != "op_return" && out.ValueSats < 546 {
			warnings = append(warnings, types.Warning{Code: "DUST_OUTPUT"})
			break
		}
	}

	// UNKNOWN_OUTPUT_SCRIPT: any output has unknown script type
	for _, out := range outputs {
		if out.ScriptType == "unknown" {
			warnings = append(warnings, types.Warning{Code: "UNKNOWN_OUTPUT_SCRIPT"})
			break
		}
	}

	// RBF_SIGNALING
	if rbfSignaling {
		warnings = append(warnings, types.Warning{Code: "RBF_SIGNALING"})
	}

	return warnings
}
