package analyzer

import (
	"bytes"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"strings"
)

// ClassifyOutputScript determines the script type of an output
func ClassifyOutputScript(scriptPubkey []byte) string {
	if len(scriptPubkey) == 0 {
		return "unknown"
	}

	// P2PKH: OP_DUP OP_HASH160 <20 bytes> OP_EQUALVERIFY OP_CHECKSIG
	if len(scriptPubkey) == 25 &&
		scriptPubkey[0] == 0x76 && // OP_DUP
		scriptPubkey[1] == 0xa9 && // OP_HASH160
		scriptPubkey[2] == 0x14 && // Push 20 bytes
		scriptPubkey[23] == 0x88 && // OP_EQUALVERIFY
		scriptPubkey[24] == 0xac { // OP_CHECKSIG
		return "p2pkh"
	}

	// P2SH: OP_HASH160 <20 bytes> OP_EQUAL
	if len(scriptPubkey) == 23 &&
		scriptPubkey[0] == 0xa9 && // OP_HASH160
		scriptPubkey[1] == 0x14 && // Push 20 bytes
		scriptPubkey[22] == 0x87 { // OP_EQUAL
		return "p2sh"
	}

	// P2WPKH: OP_0 <20 bytes>
	if len(scriptPubkey) == 22 &&
		scriptPubkey[0] == 0x00 && // OP_0
		scriptPubkey[1] == 0x14 { // Push 20 bytes
		return "p2wpkh"
	}

	// P2WSH: OP_0 <32 bytes>
	if len(scriptPubkey) == 34 &&
		scriptPubkey[0] == 0x00 && // OP_0
		scriptPubkey[1] == 0x20 { // Push 32 bytes
		return "p2wsh"
	}

	// P2TR: OP_1 <32 bytes>
	if len(scriptPubkey) == 34 &&
		scriptPubkey[0] == 0x51 && // OP_1
		scriptPubkey[1] == 0x20 { // Push 32 bytes
		return "p2tr"
	}

	// OP_RETURN: starts with OP_RETURN (0x6a)
	if len(scriptPubkey) > 0 && scriptPubkey[0] == 0x6a {
		return "op_return"
	}

	return "unknown"
}

// ClassifyInputScript determines the script type of an input
func ClassifyInputScript(scriptSig []byte, witness [][]byte, prevoutScript []byte) string {
	hasWitness := len(witness) > 0
	scriptSigEmpty := len(scriptSig) == 0

	prevoutType := ClassifyOutputScript(prevoutScript)

	// P2TR keypath: empty scriptSig, 1 witness item (64 or 65 bytes signature), prevout is P2TR
	if scriptSigEmpty && len(witness) == 1 && (len(witness[0]) == 64 || len(witness[0]) == 65) && prevoutType == "p2tr" {
		return "p2tr_keypath"
	}

	// P2TR scriptpath: empty scriptSig, witness with script + control block, prevout is P2TR
	if scriptSigEmpty && len(witness) > 1 && prevoutType == "p2tr" {
		// Control block starts with 0xc0 or 0xc1 (leaf version bits)
		lastItem := witness[len(witness)-1]
		if len(lastItem) > 0 && (lastItem[0]&0xfe) == 0xc0 {
			return "p2tr_scriptpath"
		}
	}

	// P2WPKH: empty scriptSig, 2 witness items, prevout is P2WPKH
	if scriptSigEmpty && len(witness) == 2 && prevoutType == "p2wpkh" {
		return "p2wpkh"
	}

	// P2WSH: empty scriptSig, witness present, prevout is P2WSH
	if scriptSigEmpty && hasWitness && prevoutType == "p2wsh" {
		return "p2wsh"
	}

	// P2SH-P2WPKH: scriptSig is OP_PUSHBYTES_22 <0014{20-byte-hash}>, 2 witness items
	// scriptSig = 0x16 0x00 0x14 <20 bytes> = 23 bytes total
	if len(scriptSig) == 23 && scriptSig[0] == 0x16 && scriptSig[1] == 0x00 && scriptSig[2] == 0x14 && len(witness) == 2 {
		return "p2sh-p2wpkh"
	}

	// P2SH-P2WSH: scriptSig is OP_PUSHBYTES_34 <0020{32-byte-hash}>, witness present
	// scriptSig = 0x22 0x00 0x20 <32 bytes> = 35 bytes total
	if len(scriptSig) == 35 && scriptSig[0] == 0x22 && scriptSig[1] == 0x00 && scriptSig[2] == 0x20 && hasWitness {
		return "p2sh-p2wsh"
	}

	// P2PKH: scriptSig present (sig + pubkey push), no witness, prevout is P2PKH
	if !scriptSigEmpty && !hasWitness && prevoutType == "p2pkh" {
		return "p2pkh"
	}

	// Fallback for mixed SegWit transactions:
	// A legacy input in a SegWit tx may appear with empty scriptSig but no witness.
	// Identify by prevout type.
	if scriptSigEmpty && !hasWitness {
		switch prevoutType {
		case "p2pkh", "p2sh":
			return prevoutType
		}
	}

	return "unknown"
}

// DisassembleScript converts script bytes to human-readable ASM per spec format.
//
// Format rules:
//   - OP_0 for 0x00
//   - OP_1..OP_16 for 0x51..0x60
//   - OP_PUSHBYTES_<n> <hex> for direct pushes 0x01..0x4b
//   - OP_PUSHDATA1 <hex> for 0x4c
//   - OP_PUSHDATA2 <hex> for 0x4d
//   - OP_PUSHDATA4 <hex> for 0x4e
//   - Named opcode for all known opcodes
//   - OP_UNKNOWN_0x<nn> for unknown bytes
func DisassembleScript(script []byte) string {
	if len(script) == 0 {
		return ""
	}

	var parts []string
	i := 0
	for i < len(script) {
		op := script[i]
		i++

		switch {
		case op == 0x00:
			parts = append(parts, "OP_0")

		case op >= 0x01 && op <= 0x4b:
			// Direct push: op bytes of data follow
			n := int(op)
			if i+n > len(script) {
				// Truncated — emit raw
				parts = append(parts, fmt.Sprintf("OP_PUSHBYTES_%d", n))
				i = len(script)
				break
			}
			data := script[i : i+n]
			parts = append(parts, fmt.Sprintf("OP_PUSHBYTES_%d %s", n, hex.EncodeToString(data)))
			i += n

		case op == 0x4c: // OP_PUSHDATA1
			if i >= len(script) {
				parts = append(parts, "OP_PUSHDATA1")
				break
			}
			n := int(script[i])
			i++
			if i+n > len(script) {
				n = len(script) - i
			}
			data := script[i : i+n]
			parts = append(parts, fmt.Sprintf("OP_PUSHDATA1 %s", hex.EncodeToString(data)))
			i += n

		case op == 0x4d: // OP_PUSHDATA2
			if i+1 >= len(script) {
				parts = append(parts, "OP_PUSHDATA2")
				break
			}
			n := int(binary.LittleEndian.Uint16(script[i : i+2]))
			i += 2
			if i+n > len(script) {
				n = len(script) - i
			}
			data := script[i : i+n]
			parts = append(parts, fmt.Sprintf("OP_PUSHDATA2 %s", hex.EncodeToString(data)))
			i += n

		case op == 0x4e: // OP_PUSHDATA4
			if i+3 >= len(script) {
				parts = append(parts, "OP_PUSHDATA4")
				break
			}
			n := int(binary.LittleEndian.Uint32(script[i : i+4]))
			i += 4
			if i+n > len(script) {
				n = len(script) - i
			}
			data := script[i : i+n]
			parts = append(parts, fmt.Sprintf("OP_PUSHDATA4 %s", hex.EncodeToString(data)))
			i += n

		default:
			parts = append(parts, opcodeToName(op))
		}
	}

	return strings.Join(parts, " ")
}

// opcodeToName returns the spec-canonical name for an opcode byte.
// Based on Bitcoin Core script/script.h opcode table.
func opcodeToName(op byte) string {
	switch op {
	// Small integers
	case 0x4f:
		return "OP_1NEGATE"
	case 0x50:
		return "OP_RESERVED"
	case 0x51:
		return "OP_1"
	case 0x52:
		return "OP_2"
	case 0x53:
		return "OP_3"
	case 0x54:
		return "OP_4"
	case 0x55:
		return "OP_5"
	case 0x56:
		return "OP_6"
	case 0x57:
		return "OP_7"
	case 0x58:
		return "OP_8"
	case 0x59:
		return "OP_9"
	case 0x5a:
		return "OP_10"
	case 0x5b:
		return "OP_11"
	case 0x5c:
		return "OP_12"
	case 0x5d:
		return "OP_13"
	case 0x5e:
		return "OP_14"
	case 0x5f:
		return "OP_15"
	case 0x60:
		return "OP_16"
	// Flow control
	case 0x61:
		return "OP_NOP"
	case 0x62:
		return "OP_VER"
	case 0x63:
		return "OP_IF"
	case 0x64:
		return "OP_NOTIF"
	case 0x65:
		return "OP_VERIF"
	case 0x66:
		return "OP_VERNOTIF"
	case 0x67:
		return "OP_ELSE"
	case 0x68:
		return "OP_ENDIF"
	case 0x69:
		return "OP_VERIFY"
	case 0x6a:
		return "OP_RETURN"
	// Stack
	case 0x6b:
		return "OP_TOALTSTACK"
	case 0x6c:
		return "OP_FROMALTSTACK"
	case 0x6d:
		return "OP_2DROP"
	case 0x6e:
		return "OP_2DUP"
	case 0x6f:
		return "OP_3DUP"
	case 0x70:
		return "OP_2OVER"
	case 0x71:
		return "OP_2ROT"
	case 0x72:
		return "OP_2SWAP"
	case 0x73:
		return "OP_IFDUP"
	case 0x74:
		return "OP_DEPTH"
	case 0x75:
		return "OP_DROP"
	case 0x76:
		return "OP_DUP"
	case 0x77:
		return "OP_NIP"
	case 0x78:
		return "OP_OVER"
	case 0x79:
		return "OP_PICK"
	case 0x7a:
		return "OP_ROLL"
	case 0x7b:
		return "OP_ROT"
	case 0x7c:
		return "OP_SWAP"
	case 0x7d:
		return "OP_TUCK"
	// Splice
	case 0x7e:
		return "OP_CAT"
	case 0x7f:
		return "OP_SUBSTR"
	case 0x80:
		return "OP_LEFT"
	case 0x81:
		return "OP_RIGHT"
	case 0x82:
		return "OP_SIZE"
	// Bitwise
	case 0x83:
		return "OP_INVERT"
	case 0x84:
		return "OP_AND"
	case 0x85:
		return "OP_OR"
	case 0x86:
		return "OP_XOR"
	case 0x87:
		return "OP_EQUAL"
	case 0x88:
		return "OP_EQUALVERIFY"
	case 0x89:
		return "OP_RESERVED1"
	case 0x8a:
		return "OP_RESERVED2"
	// Arithmetic
	case 0x8b:
		return "OP_1ADD"
	case 0x8c:
		return "OP_1SUB"
	case 0x8d:
		return "OP_2MUL"
	case 0x8e:
		return "OP_2DIV"
	case 0x8f:
		return "OP_NEGATE"
	case 0x90:
		return "OP_ABS"
	case 0x91:
		return "OP_NOT"
	case 0x92:
		return "OP_0NOTEQUAL"
	case 0x93:
		return "OP_ADD"
	case 0x94:
		return "OP_SUB"
	case 0x95:
		return "OP_MUL"
	case 0x96:
		return "OP_DIV"
	case 0x97:
		return "OP_MOD"
	case 0x98:
		return "OP_LSHIFT"
	case 0x99:
		return "OP_RSHIFT"
	case 0x9a:
		return "OP_BOOLAND"
	case 0x9b:
		return "OP_BOOLOR"
	case 0x9c:
		return "OP_NUMEQUAL"
	case 0x9d:
		return "OP_NUMEQUALVERIFY"
	case 0x9e:
		return "OP_NUMNOTEQUAL"
	case 0x9f:
		return "OP_LESSTHAN"
	case 0xa0:
		return "OP_GREATERTHAN"
	case 0xa1:
		return "OP_LESSTHANOREQUAL"
	case 0xa2:
		return "OP_GREATERTHANOREQUAL"
	case 0xa3:
		return "OP_MIN"
	case 0xa4:
		return "OP_MAX"
	case 0xa5:
		return "OP_WITHIN"
	// Crypto
	case 0xa6:
		return "OP_RIPEMD160"
	case 0xa7:
		return "OP_SHA1"
	case 0xa8:
		return "OP_SHA256"
	case 0xa9:
		return "OP_HASH160"
	case 0xaa:
		return "OP_HASH256"
	case 0xab:
		return "OP_CODESEPARATOR"
	case 0xac:
		return "OP_CHECKSIG"
	case 0xad:
		return "OP_CHECKSIGVERIFY"
	case 0xae:
		return "OP_CHECKMULTISIG"
	case 0xaf:
		return "OP_CHECKMULTISIGVERIFY"
	// Locktime
	case 0xb0:
		return "OP_NOP1"
	case 0xb1:
		return "OP_CHECKLOCKTIMEVERIFY"
	case 0xb2:
		return "OP_CHECKSEQUENCEVERIFY"
	case 0xb3:
		return "OP_NOP4"
	case 0xb4:
		return "OP_NOP5"
	case 0xb5:
		return "OP_NOP6"
	case 0xb6:
		return "OP_NOP7"
	case 0xb7:
		return "OP_NOP8"
	case 0xb8:
		return "OP_NOP9"
	case 0xb9:
		return "OP_NOP10"
	// Tapscript
	case 0xba:
		return "OP_CHECKSIGADD"
	case 0xfd:
		return "OP_PUBKEYHASH"
	case 0xfe:
		return "OP_PUBKEY"
	case 0xff:
		return "OP_INVALIDOPCODE"
	}
	return fmt.Sprintf("OP_UNKNOWN_0x%02x", op)
}

// ParseOpReturn extracts data from OP_RETURN output.
// Handles all push opcodes: direct (0x01-0x4b), PUSHDATA1, PUSHDATA2, PUSHDATA4.
// Multiple data pushes are concatenated.
func ParseOpReturn(script []byte) (dataHex string, dataUtf8 *string, protocol string) {
	if len(script) == 0 || script[0] != 0x6a {
		return "", nil, "unknown"
	}

	// Collect all data pushes after OP_RETURN
	var allData []byte
	i := 1
	for i < len(script) {
		opcode := script[i]
		i++

		var pushLen int
		if opcode >= 0x01 && opcode <= 0x4b {
			pushLen = int(opcode)
		} else if opcode == 0x4c { // OP_PUSHDATA1
			if i >= len(script) {
				break
			}
			pushLen = int(script[i])
			i++
		} else if opcode == 0x4d { // OP_PUSHDATA2
			if i+1 >= len(script) {
				break
			}
			pushLen = int(binary.LittleEndian.Uint16(script[i : i+2]))
			i += 2
		} else if opcode == 0x4e { // OP_PUSHDATA4
			if i+3 >= len(script) {
				break
			}
			pushLen = int(binary.LittleEndian.Uint32(script[i : i+4]))
			i += 4
		} else {
			break
		}

		if i+pushLen > len(script) {
			break
		}
		allData = append(allData, script[i:i+pushLen]...)
		i += pushLen
	}

	dataHex = hex.EncodeToString(allData)

	// Try UTF-8 decode — use unicode/utf8 valid check
	if len(allData) > 0 {
		if isValidUTF8(allData) {
			str := string(allData)
			dataUtf8 = &str
		}
		// else dataUtf8 = nil (JSON null)
	}

	// Detect protocol
	if len(allData) >= 4 && bytes.Equal(allData[:4], []byte{0x6f, 0x6d, 0x6e, 0x69}) {
		protocol = "omni"
	} else if len(allData) >= 5 && bytes.Equal(allData[:5], []byte{0x01, 0x09, 0xf9, 0x11, 0x02}) {
		protocol = "opentimestamps"
	} else {
		protocol = "unknown"
	}

	return dataHex, dataUtf8, protocol
}

// isValidUTF8 checks if bytes are valid UTF-8 using Go's built-in rune iteration
func isValidUTF8(data []byte) bool {
	s := string(data)
	for _, r := range s {
		if r == '\uFFFD' {
			return false
		}
	}
	return true
}
