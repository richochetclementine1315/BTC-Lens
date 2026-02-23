package types

// TransactionOutput represents the complete JSON output for a transaction
type TransactionOutput struct {
	OK              bool           `json:"ok"`
	Network         string         `json:"network,omitempty"`
	Segwit          bool           `json:"segwit"`
	Txid            string         `json:"txid,omitempty"`
	Wtxid           *string        `json:"wtxid"`
	Version         int32          `json:"version,omitempty"`
	Locktime        uint32         `json:"locktime"`
	SizeBytes       int            `json:"size_bytes,omitempty"`
	Weight          int            `json:"weight,omitempty"`
	Vbytes          int            `json:"vbytes,omitempty"`
	FeeSats         int64          `json:"fee_sats,omitempty"`
	FeeRateSatVb    float64        `json:"fee_rate_sat_vb,omitempty"`
	TotalInputSats  int64          `json:"total_input_sats,omitempty"`
	TotalOutputSats int64          `json:"total_output_sats,omitempty"`
	RbfSignaling    bool           `json:"rbf_signaling"`
	LocktimeType    string         `json:"locktime_type,omitempty"`
	LocktimeValue   uint32         `json:"locktime_value"`
	VinCount        int            `json:"vin_count,omitempty"`
	VoutCount       int            `json:"vout_count,omitempty"`
	VoutScriptTypes []string       `json:"vout_script_types"`
	SegwitSavings   *SegwitSavings `json:"segwit_savings"`
	Vin             []Input        `json:"vin"`
	Vout            []Output       `json:"vout"`
	Warnings        []Warning      `json:"warnings"`
	Error           *ErrorInfo     `json:"error,omitempty"`
}

// Input represents a transaction input
type Input struct {
	Txid             string           `json:"txid"`
	Vout             uint32           `json:"vout"`
	Sequence         uint32           `json:"sequence"`
	ScriptSigHex     string           `json:"script_sig_hex"`
	ScriptAsm        string           `json:"script_asm"`
	Witness          []string         `json:"witness"`
	WitnessScriptAsm *string          `json:"witness_script_asm,omitempty"`
	ScriptType       string           `json:"script_type"`
	Address          *string          `json:"address"`
	Prevout          Prevout          `json:"prevout"`
	RelativeTimelock RelativeTimelock `json:"relative_timelock"`
}

// Output represents a transaction output
type Output struct {
	N                int     `json:"n"`
	ValueSats        int64   `json:"value_sats"`
	ScriptPubkeyHex  string  `json:"script_pubkey_hex"`
	ScriptAsm        string  `json:"script_asm"`
	ScriptType       string  `json:"script_type"`
	Address          *string `json:"address"`
	OpReturnDataHex  string  `json:"op_return_data_hex,omitempty"`
	OpReturnDataUtf8 *string `json:"op_return_data_utf8,omitempty"`
	OpReturnProtocol string  `json:"op_return_protocol,omitempty"`
}

// Prevout represents the previous output being spent
type Prevout struct {
	ValueSats       int64  `json:"value_sats"`
	ScriptPubkeyHex string `json:"script_pubkey_hex"`
}

// RelativeTimelock represents BIP68 relative timelock
type RelativeTimelock struct {
	Enabled bool   `json:"enabled"`
	Type    string `json:"type,omitempty"`
	Value   uint32 `json:"value,omitempty"`
}

// SegwitSavings represents witness discount analysis
type SegwitSavings struct {
	WitnessBytes    int     `json:"witness_bytes"`
	NonWitnessBytes int     `json:"non_witness_bytes"`
	TotalBytes      int     `json:"total_bytes"`
	WeightActual    int     `json:"weight_actual"`
	WeightIfLegacy  int     `json:"weight_if_legacy"`
	SavingsPct      float64 `json:"savings_pct"`
}

// Warning represents a transaction warning
type Warning struct {
	Code string `json:"code"`
}

// ErrorInfo represents an error response
type ErrorInfo struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Fixture represents the input JSON fixture
type Fixture struct {
	Network  string         `json:"network"`
	RawTx    string         `json:"raw_tx"`
	Prevouts []PrevoutInput `json:"prevouts"`
}

// PrevoutInput represents a prevout in the fixture
type PrevoutInput struct {
	Txid            string `json:"txid"`
	Vout            uint32 `json:"vout"`
	ValueSats       int64  `json:"value_sats"`
	ScriptPubkeyHex string `json:"script_pubkey_hex"`
}

// BlockOutput represents the JSON output for a block
type BlockOutput struct {
	OK           bool                `json:"ok"`
	Mode         string              `json:"mode"`
	BlockHeader  BlockHeader         `json:"block_header"`
	TxCount      int                 `json:"tx_count"`
	Coinbase     CoinbaseInfo        `json:"coinbase"`
	Transactions []TransactionOutput `json:"transactions"`
	BlockStats   BlockStats          `json:"block_stats"`
	Error        *ErrorInfo          `json:"error,omitempty"`
}

// BlockHeader represents block header information
type BlockHeader struct {
	Version         int32  `json:"version"`
	PrevBlockHash   string `json:"prev_block_hash"`
	MerkleRoot      string `json:"merkle_root"`
	MerkleRootValid bool   `json:"merkle_root_valid"`
	Timestamp       uint32 `json:"timestamp"`
	Bits            string `json:"bits"`
	Nonce           uint32 `json:"nonce"`
	BlockHash       string `json:"block_hash"`
}

// CoinbaseInfo represents coinbase transaction info
type CoinbaseInfo struct {
	Bip34Height       int64  `json:"bip34_height"`
	CoinbaseScriptHex string `json:"coinbase_script_hex"`
	TotalOutputSats   int64  `json:"total_output_sats"`
}

// BlockStats represents block-level statistics
type BlockStats struct {
	TotalFeesSats     int64          `json:"total_fees_sats"`
	TotalWeight       int            `json:"total_weight"`
	AvgFeeRateSatVb   float64        `json:"avg_fee_rate_sat_vb"`
	ScriptTypeSummary map[string]int `json:"script_type_summary"`
}
