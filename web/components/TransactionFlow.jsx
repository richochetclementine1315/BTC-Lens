import React from 'react';
import './TransactionFlow.css';

function TransactionFlow({ result }) {
    const totalInput = result.total_input_sats;
    const totalOutput = result.total_output_sats;
    const fee = result.fee_sats;

    return (
        <div className="flow-card">
            <h2>💰 Value Flow</h2>
            <p className="flow-description">
                This transaction spends <strong>{result.vin.length} input(s)</strong> and creates{' '}
                <strong>{result.vout.length} output(s)</strong>. The difference between inputs and outputs
                is the <strong>fee</strong> paid to miners.
            </p>

            <div className="flow-diagram">
                {/* Inputs */}
                <div className="flow-column">
                    <h3>📥 Inputs ({totalInput.toLocaleString()} sats)</h3>
                    {result.vin.map((input, i) => (
                        <div key={i} className="flow-item input-item">
                            <div className="flow-label">Input #{i}</div>
                            <div className="flow-address">{input.address || 'Unknown'}</div>
                            <div className="flow-amount">{input.prevout.value_sats.toLocaleString()} sats</div>
                            <div className="flow-type">{input.script_type}</div>
                        </div>
                    ))}
                </div>

                {/* Arrow */}
                <div className="flow-arrow">
                    <div className="arrow-line"></div>
                    <div className="arrow-head">→</div>
                    <div className="fee-badge">
                        Fee: {fee.toLocaleString()} sats
                        <br />
                        ({result.fee_rate_sat_vb.toFixed(2)} sat/vB)
                    </div>
                </div>

                {/* Outputs */}
                <div className="flow-column">
                    <h3>📤 Outputs ({totalOutput.toLocaleString()} sats)</h3>
                    {result.vout.map((output, i) => (
                        <div key={i} className="flow-item output-item">
                            <div className="flow-label">Output #{i}</div>
                            <div className="flow-address">
                                {output.script_type === 'op_return'
                                    ? '📝 OP_RETURN'
                                    : output.address || 'Unknown'}
                            </div>
                            <div className="flow-amount">{output.value_sats.toLocaleString()} sats</div>
                            <div className="flow-type">{output.script_type}</div>
                            {output.op_return_data_utf8 && (
                                <div className="op-return-data">"{output.op_return_data_utf8}"</div>
                            )}
                        </div>
                    ))}
                </div>
            </div>

            <div className="flow-explanation">
                <h3>🎓 What's happening here?</h3>
                <ul>
                    <li><strong>Inputs</strong> are previous outputs being spent (like taking money from your wallet)</li>
                    <li><strong>Outputs</strong> are new destinations for the Bitcoin (like giving money to someone)</li>
                    <li><strong>Fee</strong> is the difference - it goes to miners who include this transaction in a block</li>
                    <li><strong>Script types</strong> determine how the Bitcoin can be spent (different lock mechanisms)</li>
                </ul>
            </div>
        </div>
    );
}

export default TransactionFlow;