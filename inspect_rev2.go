//go:build ignore
// +build ignore

package main

import (
	"encoding/binary"
	"fmt"
	"os"
)

func xorDecode(data, key []byte) []byte {
	if len(key) == 0 {
		return data
	}
	result := make([]byte, len(data))
	for i := range data {
		result[i] = data[i] ^ key[i%len(key)]
	}
	return result
}

func main() {
	xorKey, _ := os.ReadFile("fixtures/blocks/xor.dat")

	for _, name := range []string{"rev04330", "rev05051"} {
		data, err := os.ReadFile("fixtures/blocks/" + name + ".dat")
		if err != nil {
			fmt.Printf("Error reading %s: %v\n", name, err)
			continue
		}
		decoded := xorDecode(data, xorKey)
		fmt.Printf("\n=== %s.dat (len=%d) ===\n", name, len(decoded))
		fmt.Printf("First 50 bytes (hex): ")
		for i := 0; i < 50 && i < len(decoded); i++ {
			fmt.Printf("%02x ", decoded[i])
		}
		fmt.Println()

		// Bytes 0-3: magic?
		if len(decoded) >= 8 {
			magic := binary.BigEndian.Uint32(decoded[0:4])
			size := binary.LittleEndian.Uint32(decoded[4:8])
			fmt.Printf("Bytes 0-3 (magic?) = %08x\n", magic)
			fmt.Printf("Bytes 4-7 (size LE) = %d\n", size)
		}
		// Byte 8: CompactSize for txundo count?
		if len(decoded) >= 9 {
			b := decoded[8]
			fmt.Printf("Byte 8 = %02x (%d)\n", b, b)
			if b == 0xfd && len(decoded) >= 11 {
				v := binary.LittleEndian.Uint16(decoded[9:11])
				fmt.Printf("  (CompactSize 0xfd) => count = %d\n", v)
			}
		}
		// Also check byte at offset 8, treating as CVarInt
		fmt.Printf("Bytes 8-15: ")
		for i := 8; i < 16 && i < len(decoded); i++ {
			fmt.Printf("%02x ", decoded[i])
		}
		fmt.Println()
	}
}
