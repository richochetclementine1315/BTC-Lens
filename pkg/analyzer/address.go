package analyzer

import (
	"github.com/btcsuite/btcd/btcutil"
	"github.com/btcsuite/btcd/chaincfg"
)

// GetAddressFromScript derives a Bitcoin address from a scriptPubKey
// Returns nil if script type doesn't have an address (e.g., OP_RETURN, unknown)
func GetAddressFromScript(scriptPubkey []byte, network string) *string {
	scriptType := ClassifyOutputScript(scriptPubkey)

	var netParams *chaincfg.Params
	if network == "mainnet" {
		netParams = &chaincfg.MainNetParams
	} else {
		netParams = &chaincfg.TestNet3Params
	}

	var addr btcutil.Address
	var err error

	switch scriptType {
	case "p2pkh":
		// Extract 20-byte hash (bytes 3-22)
		if len(scriptPubkey) != 25 {
			return nil
		}
		hash := scriptPubkey[3:23]
		addr, err = btcutil.NewAddressPubKeyHash(hash, netParams)

	case "p2sh":
		// Extract 20-byte hash (bytes 2-21)
		if len(scriptPubkey) != 23 {
			return nil
		}
		hash := scriptPubkey[2:22]
		addr, err = btcutil.NewAddressScriptHash(hash, netParams)

	case "p2wpkh":
		// Extract 20-byte hash (bytes 2-21)
		if len(scriptPubkey) != 22 {
			return nil
		}
		hash := scriptPubkey[2:22]
		addr, err = btcutil.NewAddressWitnessPubKeyHash(hash, netParams)

	case "p2wsh":
		// Extract 32-byte hash (bytes 2-33)
		if len(scriptPubkey) != 34 {
			return nil
		}
		hash := scriptPubkey[2:34]
		addr, err = btcutil.NewAddressWitnessScriptHash(hash, netParams)

	case "p2tr":
		// Extract 32-byte pubkey (bytes 2-33)
		if len(scriptPubkey) != 34 {
			return nil
		}
		pubkey := scriptPubkey[2:34]
		addr, err = btcutil.NewAddressTaproot(pubkey, netParams)

	default:
		return nil
	}

	if err != nil {
		return nil
	}

	addrStr := addr.EncodeAddress()
	return &addrStr
}
