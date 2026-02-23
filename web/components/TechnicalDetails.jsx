import React, { useState } from 'react';
import './TechnicalDetails.css';

function TechnicalDetails({ result }) {
    const [expanded, setExpanded] = useState(false);

    return (
        <div className="technical-card">
            <button className="expand-button" onClick={() => setExpanded(!expanded)}>
                {expanded ? '▼' : '▶'} Technical Details (for developers)
            </button>

            {expanded && (
                <div className="technical-content">
                    <div className="detail-section">
                        <h3>Transaction IDs</h3>
                        <div className="detail-item">
                            <span className="detail-label">TXID:</span>
                            <code>{result.txid}</code>
                        </div>
                        {result.wtxid && (
                            <div className="detail-item">
                                <span className="detail-label">WTXID:</span>
                                <code>{result.wtxid}</code>
                            </div>
                        )}
                    </div>

                    <div className="detail-section">
                        <h3>Size & Weight</h3>
                        <div className="detail-item">
                            <span className="detail-label">Size:</span>
                            <span>{result.size_bytes} bytes</span>
                        </div>
                        <div className="detail-item">
                            <span className="detail-label">Weight:</span>
                            <span>{result.weight} WU</span>
                        </div>
                        <div className="detail-item">
                            <span className="detail-label">Virtual Size:</span>
                            <span>{result.vbytes} vBytes</span>
                        </div>
                    </div>

                    <div className="detail-section">
                        <h3>Inputs</h3>
                        {result.vin.map((input, i) => (
                            <div key={i} className="input-detail">
                                <h4>Input #{i}</h4>
                                <div className="detail-item">
                                    <span className="detail-label">Previous TX:</span>
                                    <code>{input.txid}</code>
                                </div>
                                <div className="detail-item">
                                    <span className="detail-label">Output Index:</span>
                                    <span>{input.vout}</span>
                                </div>
                                <div className="detail-item">
                                    <span className="detail-label">ScriptSig (hex):</span>
                                    <code className="hex-data">{input.script_sig_hex || '(empty)'}</code>
                                </div>
                                <div className="detail-item">
                                    <span className="detail-label">ScriptSig (asm):</span>
                                    <code className="asm-data">{input.script_asm || '(empty)'}</code>
                                </div>
                                {input.witness && input.witness.length > 0 && (
                                    <div className="detail-item">
                                        <span className="detail-label">Witness:</span>
                                        <div className="witness-items">
                                            {input.witness.map((item, j) => (
                                                <code key={j} className="witness-item">[{j}] {item}</code>
                                            ))}
                                        </div>
                                    </div>
                                )}
                                <div className="detail-item">
                                    <span className="detail-label">Sequence:</span>
                                    <code>0x{input.sequence.toString(16).padStart(8, '0')}</code>
                                </div>
                            </div>
                        ))}
                    </div>

                    <div className="detail-section">
                        <h3>Outputs</h3>
                        {result.vout.map((output, i) => (
                            <div key={i} className="output-detail">
                                <h4>Output #{i}</h4>
                                <div className="detail-item">
                                    <span className="detail-label">Value:</span>
                                    <span>{output.value_sats} satoshis</span>
                                </div>
                                <div className="detail-item">
                                    <span className="detail-label">ScriptPubKey (hex):</span>
                                    <code className="hex-data">{output.script_pubkey_hex}</code>
                                </div>
                                <div className="detail-item">
                                    <span className="detail-label">ScriptPubKey (asm):</span>
                                    <code className="asm-data">{output.script_asm}</code>
                                </div>
                                <div className="detail-item">
                                    <span className="detail-label">Type:</span>
                                    <span>{output.script_type}</span>
                                </div>
                                {output.address && (
                                    <div className="detail-item">
                                        <span className="detail-label">Address:</span>
                                        <code>{output.address}</code>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>

                    <div className="detail-section">
                        <h3>Locktime & RBF</h3>
                        <div className="detail-item">
                            <span className="detail-label">Locktime:</span>
                            <span>{result.locktime} ({result.locktime_type})</span>
                        </div>
                        <div className="detail-item">
                            <span className="detail-label">RBF Signaling:</span>
                            <span>{result.rbf_signaling ? 'Yes' : 'No'}</span>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

export default TechnicalDetails;