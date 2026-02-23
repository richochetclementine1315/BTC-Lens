import React from 'react';
import './SegWitSavings.css';

function Bar({ label, value, max, color }) {
    const pct = max > 0 ? Math.min((value / max) * 100, 100) : 0;
    return (
        <div className="bar-row">
            <span className="bar-label">{label}</span>
            <div className="bar-track">
                <div className="bar-fill" style={{ width: `${pct}%`, background: color }} />
            </div>
            <span className="bar-value">{value.toLocaleString()} bytes</span>
        </div>
    );
}

function SegWitSavings({ savings }) {
    const { witness_bytes, non_witness_bytes, total_bytes, weight_actual, weight_if_legacy, savings_pct } = savings;

    return (
        <div className="glass-card segwit-card">
            <div className="section-title">SegWit Savings</div>

            <div className="segwit-headline">
                <div className="savings-ring">
                    <svg viewBox="0 0 60 60" className="ring-svg">
                        <circle cx="30" cy="30" r="24" fill="none" stroke="rgba(96,165,250,0.12)" strokeWidth="6" />
                        <circle
                            cx="30" cy="30" r="24"
                            fill="none"
                            stroke="var(--blue)"
                            strokeWidth="6"
                            strokeDasharray={`${(savings_pct / 100) * 150.8} 150.8`}
                            strokeLinecap="round"
                            transform="rotate(-90 30 30)"
                        />
                    </svg>
                    <div className="ring-label">
                        <span className="ring-pct">{savings_pct.toFixed(1)}%</span>
                        <span className="ring-sub">saved</span>
                    </div>
                </div>

                <div className="segwit-stats">
                    <div className="sw-stat">
                        <span className="sw-stat-label">Weight Actual</span>
                        <span className="sw-stat-value">{weight_actual.toLocaleString()} <small>WU</small></span>
                    </div>
                    <div className="sw-stat">
                        <span className="sw-stat-label">Weight if Legacy</span>
                        <span className="sw-stat-value legacy-weight">{weight_if_legacy.toLocaleString()} <small>WU</small></span>
                    </div>
                    <div className="sw-stat">
                        <span className="sw-stat-label">Weight Saved</span>
                        <span className="sw-stat-value" style={{ color: 'var(--green)' }}>
                            {(weight_if_legacy - weight_actual).toLocaleString()} <small>WU</small>
                        </span>
                    </div>
                </div>
            </div>

            <div className="bars-section">
                <Bar label="Witness" value={witness_bytes} max={total_bytes} color="var(--blue)" />
                <Bar label="Non-Witness" value={non_witness_bytes} max={total_bytes} color="var(--purple)" />
            </div>

            <p className="segwit-explainer">
                SegWit discounts witness data by 75%. Witness bytes count as¼ weight unit each vs 4 WU for legacy bytes, meaning this transaction would be <strong>{Math.round(savings_pct)}% heavier</strong> without SegWit.
            </p>
        </div>
    );
}

export default SegWitSavings;
