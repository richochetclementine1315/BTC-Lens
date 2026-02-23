import React, { useState } from 'react';
import './TechnicalDetails.css';

function CopyBtn({ text }) {
    const [copied, setCopied] = useState(false);
    return (
        <button className="td-copy-btn" onClick={() => {
            navigator.clipboard.writeText(text);
            setCopied(true);
            setTimeout(() => setCopied(false), 1500);
        }}>
            {copied ? '✓' : '⧉'}
        </button>
    );
}

function HexField({ label, value, truncate = true }) {
    const [expanded, setExpanded] = useState(false);
    if (!value) return null;
    const display = truncate && !expanded && value.length > 64
        ? value.slice(0, 32) + '…' + value.slice(-8)
        : value;
    return (
        <div className="td-field">
            <div className="td-field-header">
                <span className="td-label">{label}</span>
                <div className="td-actions">
                    {truncate && value.length > 64 && (
                        <button className="td-expand-btn" onClick={() => setExpanded(!expanded)}>
                            {expanded ? 'collapse' : 'expand'}
                        </button>
                    )}
                    <CopyBtn text={value} />
                </div>
            </div>
            <code className="td-hex">{display}</code>
        </div>
    );
}

function Section({ title, children }) {
    return (
        <div className="td-section">
            <div className="td-section-title">{title}</div>
            {children}
        </div>
    );
}

function TechnicalDetails({ result }) {
    const [expanded, setExpanded] = useState(false);

    return (
        <div className="glass-card td-card">
            <button className="td-toggle" onClick={() => setExpanded(!expanded)}>
                <span>🛠 Technical Details</span>
                <span className="td-chevron" style={{ transform: expanded ? 'rotate(180deg)' : 'none' }}>▾</span>
            </button>

            {expanded && (
                <div className="td-content">
                    {/* IDs */}
                    <Section title="Transaction IDs">
                        <HexField label="TXID" value={result.txid} truncate={false} />
                        {result.wtxid && <HexField label="wTXID" value={result.wtxid} truncate={false} />}
                    </Section>

                    {/* Size */}
                    <Section title="Size & Encoding">
                        <div className="td-row-grid">
                            <div className="td-kv"><span className="td-label">Total size</span><span className="td-val">{result.size_bytes} bytes</span></div>
                            <div className="td-kv"><span className="td-label">Weight</span><span className="td-val">{result.weight} WU</span></div>
                            <div className="td-kv"><span className="td-label">Virtual size</span><span className="td-val">{result.vbytes} vB</span></div>
                            <div className="td-kv"><span className="td-label">Version</span><span className="td-val">v{result.version}</span></div>
                            <div className="td-kv"><span className="td-label">Locktime</span><span className="td-val">{result.locktime} ({result.locktime_type})</span></div>
                            <div className="td-kv"><span className="td-label">RBF</span><span className="td-val" style={{ color: result.rbf_signaling ? 'var(--accent)' : 'var(--text-muted)' }}>{result.rbf_signaling ? 'Yes' : 'No'}</span></div>
                        </div>
                    </Section>

                    {/* Inputs */}
                    <Section title={`Inputs (${result.vin.length})`}>
                        {result.vin.map((inp, i) => (
                            <div key={i} className="td-input-block">
                                <div className="td-block-header">Input #{i} — {inp.script_type}</div>
                                <HexField label="Prev TXID" value={inp.txid} truncate={false} />
                                <div className="td-row-grid">
                                    <div className="td-kv"><span className="td-label">Vout</span><span className="td-val">{inp.vout}</span></div>
                                    <div className="td-kv"><span className="td-label">Sequence</span><span className="td-val mono">0x{inp.sequence.toString(16).padStart(8, '0')}</span></div>
                                    <div className="td-kv"><span className="td-label">Address</span><span className="td-val mono small">{inp.address || '—'}</span></div>
                                    <div className="td-kv"><span className="td-label">Value</span><span className="td-val">{inp.prevout.value_sats.toLocaleString()} sats</span></div>
                                </div>
                                {inp.script_sig_hex && <HexField label="ScriptSig (hex)" value={inp.script_sig_hex} />}
                                {inp.script_asm && (
                                    <div className="td-field">
                                        <span className="td-label">ScriptSig (ASM)</span>
                                        <code className="td-asm">{inp.script_asm || '(empty)'}</code>
                                    </div>
                                )}
                                {inp.witness && inp.witness.length > 0 && (
                                    <div className="td-field">
                                        <span className="td-label">Witness ({inp.witness.length} items)</span>
                                        <div className="td-witness">
                                            {inp.witness.map((item, j) => (
                                                <div key={j} className="td-witness-item">
                                                    <span className="td-wi-idx">[{j}]</span>
                                                    <code className="td-hex small">{item || '(empty)'}</code>
                                                    {item && <CopyBtn text={item} />}
                                                </div>
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </div>
                        ))}
                    </Section>

                    {/* Outputs */}
                    <Section title={`Outputs (${result.vout.length})`}>
                        {result.vout.map((out, i) => (
                            <div key={i} className="td-input-block">
                                <div className="td-block-header">Output #{i} — {out.script_type}</div>
                                <div className="td-row-grid">
                                    <div className="td-kv"><span className="td-label">Value</span><span className="td-val accent">{out.value_sats.toLocaleString()} sats</span></div>
                                    <div className="td-kv"><span className="td-label">Address</span><span className="td-val mono small">{out.address || '—'}</span></div>
                                </div>
                                <HexField label="ScriptPubKey (hex)" value={out.script_pubkey_hex} />
                                {out.script_asm && (
                                    <div className="td-field">
                                        <span className="td-label">ScriptPubKey (ASM)</span>
                                        <code className="td-asm">{out.script_asm}</code>
                                    </div>
                                )}
                                {out.op_return_data_hex && <HexField label="OP_RETURN data" value={out.op_return_data_hex} />}
                                {out.op_return_data_utf8 && (
                                    <div className="td-field">
                                        <span className="td-label">OP_RETURN (UTF-8)</span>
                                        <code className="td-asm">{out.op_return_data_utf8}</code>
                                    </div>
                                )}
                            </div>
                        ))}
                    </Section>
                </div>
            )}
        </div>
    );
}

export default TechnicalDetails;
