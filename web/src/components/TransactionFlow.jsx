import React from 'react';
import './TransactionFlow.css';

function satsBtc(sats) {
    return (sats / 1e8).toFixed(8).replace(/\.?0+$/, '') + ' BTC';
}

function ScriptTypePill({ type }) {
    const colors = {
        p2pkh: '#f59e0b', p2sh: '#8b5cf6', p2wpkh: '#3b82f6',
        p2wsh: '#06b6d4', p2tr: '#ec4899', op_return: '#6b7280', unknown: '#374151'
    };
    return (
        <span className="script-pill" style={{ background: `${colors[type] || '#374151'}22`, borderColor: `${colors[type] || '#374151'}55`, color: colors[type] || '#9ca3af' }}>
            {type}
        </span>
    );
}

function InputNode({ input, index }) {
    return (
        <div className="flow-node input-node">
            <div className="node-index">#{index}</div>
            <div className="node-address">{input.address ? truncate(input.address, 16) : 'Unknown'}</div>
            <div className="node-amount">{input.prevout.value_sats.toLocaleString()} sats</div>
            <ScriptTypePill type={input.script_type} />
        </div>
    );
}

function OutputNode({ output, index }) {
    const isOpReturn = output.script_type === 'op_return';
    return (
        <div className={`flow-node output-node ${isOpReturn ? 'op-return-node' : ''}`}>
            <div className="node-index">#{index}</div>
            <div className="node-address">
                {isOpReturn ? <span style={{ color: 'var(--text-muted)', fontStyle: 'italic' }}>OP_RETURN</span>
                    : (output.address ? truncate(output.address, 16) : 'Unknown')}
            </div>
            <div className="node-amount">{output.value_sats.toLocaleString()} sats</div>
            <ScriptTypePill type={output.script_type} />
            {output.op_return_data_utf8 && (
                <div className="op-return-text">"{output.op_return_data_utf8}"</div>
            )}
        </div>
    );
}

function truncate(str, len) {
    if (!str || str.length <= len * 2 + 3) return str;
    return str.slice(0, len) + '…' + str.slice(-8);
}

function TransactionFlow({ result }) {
    const totalInput = result.total_input_sats;
    const totalOutput = result.total_output_sats;
    const fee = result.fee_sats;
    const feePct = totalInput > 0 ? ((fee / totalInput) * 100).toFixed(2) : '0.00';

    return (
        <div className="glass-card flow-card">
            <div className="section-title">Value Flow</div>

            <div className="flow-layout">
                {/* Inputs */}
                <div className="flow-col">
                    <div className="flow-col-header">
                        <span>📥 Inputs</span>
                        <span className="flow-total">{(totalInput / 1e8).toFixed(8)} BTC</span>
                    </div>
                    <div className="flow-nodes">
                        {result.vin.map((input, i) => (
                            <InputNode key={i} input={input} index={i} />
                        ))}
                    </div>
                </div>

                {/* Center arrow */}
                <div className="flow-center">
                    <div className="flow-arrow-line" />
                    <div className="fee-bubble">
                        <div className="fee-label">Miner Fee</div>
                        <div className="fee-amount">{fee.toLocaleString()} sats</div>
                        <div className="fee-rate">{result.fee_rate_sat_vb.toFixed(2)} sat/vB</div>
                        <div className="fee-pct">{feePct}% of input</div>
                    </div>
                    <div className="flow-arrow-head">→</div>
                </div>

                {/* Outputs */}
                <div className="flow-col">
                    <div className="flow-col-header">
                        <span>📤 Outputs</span>
                        <span className="flow-total">{(totalOutput / 1e8).toFixed(8)} BTC</span>
                    </div>
                    <div className="flow-nodes">
                        {result.vout.map((output, i) => (
                            <OutputNode key={i} output={output} index={i} />
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
}

export default TransactionFlow;
