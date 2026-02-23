package main

import (
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"os"
)

func readCVarInt(r io.Reader) (uint64, error) {
	var n uint64
	var b [1]byte
	for {
		if _, err := io.ReadFull(r, b[:]); err != nil {
			return 0, err
		}
		n = (n << 7) | uint64(b[0]&0x7f)
		if b[0]&0x80 == 0 {
			return n, nil
		}
		n++
	}
}

func readCompactSize(r io.Reader) (uint64, error) {
	var b [1]byte
	if _, err := io.ReadFull(r, b[:]); err != nil {
		return 0, err
	}
	switch b[0] {
	case 0xfd:
		var v [2]byte
		io.ReadFull(r, v[:])
		return uint64(binary.LittleEndian.Uint16(v[:])), nil
	case 0xfe:
		var v [4]byte
		io.ReadFull(r, v[:])
		return uint64(binary.LittleEndian.Uint32(v[:])), nil
	case 0xff:
		var v [8]byte
		io.ReadFull(r, v[:])
		return binary.LittleEndian.Uint64(v[:]), nil
	default:
		return uint64(b[0]), nil
	}
}

func main() {
	f, err := os.Open("fixtures/blocks/rev04330.dat")
	if err != nil {
		fmt.Println("Open error:", err)
		return
	}
	defer f.Close()

	// Read and print first 80 bytes as hex
	buf := make([]byte, 80)
	n, _ := io.ReadFull(f, buf)
	fmt.Printf("First %d bytes of rev04330.dat:\n", n)
	for i := 0; i < n; i += 16 {
		end := i + 16
		if end > n {
			end = n
		}
		fmt.Printf("  %04x: %s\n", i, hex.EncodeToString(buf[i:end]))
	}
	f.Seek(0, 0)

	fmt.Println()

	// Approach 1: No prefix, read CompactSize directly
	cs1, _ := readCompactSize(f)
	fmt.Printf("If NO hash prefix: CompactSize at byte 0 = %d\n", cs1)
	f.Seek(0, 0)

	// Approach 2: Skip 32 bytes, then read CompactSize
	io.ReadFull(f, make([]byte, 32))
	cs2, _ := readCompactSize(f)
	fmt.Printf("If 32-byte hash prefix: CompactSize at byte 32 = %d\n", cs2)
	f.Seek(0, 0)

	// Approach 3: Read as CVarInt at byte 0
	cv1, _ := readCVarInt(f)
	fmt.Printf("As CVarInt at byte 0 = %d\n", cv1)
	f.Seek(0, 0)

	// Skip 32, read CVarInt
	io.ReadFull(f, make([]byte, 32))
	cv2, _ := readCVarInt(f)
	fmt.Printf("As CVarInt at byte 32 = %d\n", cv2)
}
