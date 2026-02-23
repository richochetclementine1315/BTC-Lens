package utils

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"io"
)

// ReadCompactSize reads a Bitcoin CompactSize (variable-length integer)
// Used in transaction serialization (NOT in undo files)
func ReadCompactSize(r io.Reader) (uint64, error) {
	var b [1]byte
	if _, err := io.ReadFull(r, b[:]); err != nil {
		return 0, err
	}

	switch b[0] {
	case 0xfd:
		var v uint16
		if err := binary.Read(r, binary.LittleEndian, &v); err != nil {
			return 0, err
		}
		return uint64(v), nil
	case 0xfe:
		var v uint32
		if err := binary.Read(r, binary.LittleEndian, &v); err != nil {
			return 0, err
		}
		return uint64(v), nil
	case 0xff:
		var v uint64
		if err := binary.Read(r, binary.LittleEndian, &v); err != nil {
			return 0, err
		}
		return v, nil
	default:
		return uint64(b[0]), nil
	}
}

// WriteCompactSize writes a CompactSize integer
func WriteCompactSize(w io.Writer, val uint64) error {
	if val < 0xfd {
		_, err := w.Write([]byte{byte(val)})
		return err
	} else if val <= 0xffff {
		if _, err := w.Write([]byte{0xfd}); err != nil {
			return err
		}
		return binary.Write(w, binary.LittleEndian, uint16(val))
	} else if val <= 0xffffffff {
		if _, err := w.Write([]byte{0xfe}); err != nil {
			return err
		}
		return binary.Write(w, binary.LittleEndian, uint32(val))
	} else {
		if _, err := w.Write([]byte{0xff}); err != nil {
			return err
		}
		return binary.Write(w, binary.LittleEndian, val)
	}
}

// DoubleSHA256 computes double SHA256 hash (used for txid, block hash)
func DoubleSHA256(data []byte) []byte {
	first := sha256.Sum256(data)
	second := sha256.Sum256(first[:])
	return second[:]
}

// ReverseBytes reverses a byte slice (for display convention)
func ReverseBytes(b []byte) []byte {
	reversed := make([]byte, len(b))
	for i := range b {
		reversed[i] = b[len(b)-1-i]
	}
	return reversed
}

// HexToBytes converts hex string to bytes with validation
func HexToBytes(hexStr string) ([]byte, error) {
	if len(hexStr)%2 != 0 {
		return nil, errors.New("invalid hex string: odd length")
	}
	return hex.DecodeString(hexStr)
}

// XORDecode decodes XOR-obfuscated data (used for blk*.dat and rev*.dat)
func XORDecode(data []byte, key []byte) []byte {
	if len(key) == 0 {
		return data
	}
	// Check if key is all zeros (no transformation needed)
	allZero := true
	for _, b := range key {
		if b != 0 {
			allZero = false
			break
		}
	}
	if allZero {
		return data
	}
	result := make([]byte, len(data))
	for i := range data {
		result[i] = data[i] ^ key[i%len(key)]
	}
	return result
}

// ReadVarInt reads a CompactSize variable-length integer (for tx parsing)
func ReadVarInt(r io.Reader) (uint64, error) {
	return ReadCompactSize(r)
}

// ReadBitcoinVarInt reads Bitcoin Core's custom variable-length integer format
// used in undo files (rev*.dat). This is NOT the same as CompactSize.
//
// Encoding: each byte uses its low 7 bits as data. If bit 7 is set, more bytes follow.
// The value is built in big-endian 7-bit chunks with an implicit +1 for each continuation byte.
// This is the same encoding used in Bitcoin Core's serialize.h (CVarInt).
func ReadBitcoinVarInt(r io.Reader) (uint64, error) {
	var n uint64
	var b [1]byte
	for {
		if _, err := io.ReadFull(r, b[:]); err != nil {
			return 0, err
		}
		n = (n << 7) | uint64(b[0]&0x7f)
		if b[0]&0x80 == 0 {
			// Final byte
			return n, nil
		}
		// More bytes follow; increment by 1 per continuation (encoding invariant)
		n++
	}
}

// DecompressAmount decompresses a Bitcoin Core compressed amount.
// Exact implementation matching Bitcoin Core's serialize.h DecompressAmount().
//
// Bitcoin Core encoding:
//
//	n=0 → 0 satoshis
//	n>0: x = n-1; e = x%10; x /= 10
//	  if e<9: d = (x%9)+1; x /= 9; result = (x*10 + d) * 10^e
//	  if e==9: result = (x+1) * 10^9
func DecompressAmount(x uint64) int64 {
	if x == 0 {
		return 0
	}
	x--
	e := x % 10
	x /= 10
	var n uint64
	if e < 9 {
		d := x%9 + 1
		x /= 9
		n = x*10 + d
		for i := uint64(0); i < e; i++ {
			n *= 10
		}
	} else {
		n = x + 1
		for i := uint64(0); i < 9; i++ {
			n *= 10
		}
	}
	return int64(n)
}

// IsValidUTF8 checks if bytes are valid UTF-8
func IsValidUTF8(data []byte) bool {
	str := string(data)
	return []byte(str)[0] != 0xef || len(data) == 0 // Avoid replacement character
}
