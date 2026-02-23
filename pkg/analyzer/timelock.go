package analyzer

// GetLocktimeType determines if locktime is block height, timestamp, or none
func GetLocktimeType(locktime uint32) string {
	if locktime == 0 {
		return "none"
	}
	if locktime < 500000000 {
		return "block_height"
	}
	return "unix_timestamp"
}

// ParseRelativeTimelock decodes BIP68 relative timelock from sequence
func ParseRelativeTimelock(sequence uint32) (enabled bool, tlType string, value uint32) {
	// BIP68: if bit 31 is set, relative timelock is disabled
	if sequence&(1<<31) != 0 {
		return false, "", 0
	}

	// If sequence >= 0xfffffffe, no relative timelock (used for absolute locktime)
	if sequence >= 0xfffffffe {
		return false, "", 0
	}

	// Bit 22 determines type: 0 = blocks, 1 = time
	if sequence&(1<<22) != 0 {
		// Time-based: value in 512-second increments
		value = (sequence & 0xffff) * 512
		return true, "time", value
	}

	// Block-based
	value = sequence & 0xffff
	return true, "blocks", value
}

// IsRBFSignaling checks if transaction signals BIP125 replaceability
func IsRBFSignaling(sequences []uint32) bool {
	// Any input with sequence < 0xfffffffe signals RBF
	for _, seq := range sequences {
		if seq < 0xfffffffe {
			return true
		}
	}
	return false
}
