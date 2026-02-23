import React from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import './SegWitSavings.css';

function SegWitSavings({ savings }) {
    const data = [
        {
            name: 'Actual (SegWit)',
            weight: savings.weight_actual,
            fill: '#48bb78'
        },
        {
            name: 'If Legacy',
            weight: savings.weight_if_legacy,
            fill: '#f56565'
        }
    ];

    return (
        <div className="savings-card">
            <h2>⚡ SegWit Savings</h2>
            <p className="savings-description">
                SegWit (Segregated Witness) reduces transaction weight by separating signature data.
                This transaction saves <strong>{savings.savings_pct.toFixed(2)}%</strong> in weight!
            </p>

            <div className="savings-stats">
                <div className="stat-item">
                    <span className="stat-label">Witness Data</span>
                    <span className="stat-value">{savings.witness_bytes} bytes</span>
                </div>
                <div className="stat-item">
                    <span className="stat-label">Non-Witness Data</span>
                    <span className="stat-value">{savings.non_witness_bytes} bytes</span>
                </div>
                <div className="stat-item">
                    <span className="stat-label">Total Size</span>
                    <span className="stat-value">{savings.total_bytes} bytes</span>
                </div>
                <div className="stat-item highlight">
                    <span className="stat-label">Weight Savings</span>
                    <span className="stat-value">{savings.savings_pct.toFixed(2)}%</span>
                </div>
            </div>

            <ResponsiveContainer width="100%" height={300}>
                <BarChart data={data}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis label={{ value: 'Weight Units', angle: -90, position: 'insideLeft' }} />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="weight" fill="#667eea" />
                </BarChart>
            </ResponsiveContainer>

            <div className="savings-explanation">
                <h3>🎓 Why does this matter?</h3>
                <p>
                    Transaction fees are based on weight (size). SegWit gives witness data a 75% discount,
                    making transactions cheaper. This is why modern wallets use SegWit addresses (bc1...).
                </p>
            </div>
        </div>
    );
}

export default SegWitSavings;