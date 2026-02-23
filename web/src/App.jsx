import React, { useState } from 'react';
import axios from 'axios';
import './App.css';
import TransactionFlow from './components/TransactionFlow';
import SegWitSavings from './components/SegWitSavings';
import TechnicalDetails from './components/TechnicalDetails';

function App() {
  const [fixtureInput, setFixtureInput] = useState('');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const analyzeTransaction = async () => {
    setLoading(true);
    setError(null);

    try {
      const fixture = JSON.parse(fixtureInput);
      const response = await axios.post('/api/analyze', fixture);
      setResult(response.data);
    } catch (err) {
      setError(err.response?.data?.error?.message || err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadExample = () => {
    const example = {
      "network": "mainnet",
      "raw_tx": "020000000111111111111111111111111111111111111111111111111111111111111111110000000000ffffffff02b0040000000000001976a914010101010101010101010101010101010101010188ac00000000000000000a6a08736f622d3230323600000000",
      "prevouts": [{
        "txid": "1111111111111111111111111111111111111111111111111111111111111111",
        "vout": 0,
        "value_sats": 2000,
        "script_pubkey_hex": "76a914020202020202020202020202020202020202020288ac"
      }]
    };
    setFixtureInput(JSON.stringify(example, null, 2));
  };

  return (
    <div className="App">
      <header className="header">
        <h1>Chain Lens</h1>
        <p>Bitcoin Transaction Visualizer for Humans</p>
      </header>

      <div className="container">
        <div className="input-section">
          <h2>📝 Input Transaction</h2>
          <textarea
            value={fixtureInput}
            onChange={(e) => setFixtureInput(e.target.value)}
            placeholder='Paste fixture JSON here: {"network":"mainnet","raw_tx":"...","prevouts":[...]}'
            rows={10}
          />
          <div className="button-group">
            <button onClick={analyzeTransaction} disabled={loading}>
              {loading ? '⏳ Analyzing...' : '🔍 Analyze Transaction'}
            </button>
            <button onClick={loadExample} className="secondary">
              📄 Load Example
            </button>
          </div>
          {error && <div className="error">❌ Error: {error}</div>}
        </div>

        {result && result.ok && (
          <div className="results">
            <div className="summary-card">
              <h2>📊 Transaction Summary</h2>
              <div className="summary-grid">
                <div className="summary-item">
                  <span className="label">Transaction ID</span>
                  <span className="value mono">{result.txid.substring(0, 16)}...</span>
                </div>
                <div className="summary-item">
                  <span className="label">Type</span>
                  <span className="value">{result.segwit ? '⚡ SegWit' : '📜 Legacy'}</span>
                </div>
                <div className="summary-item">
                  <span className="label">Fee</span>
                  <span className="value">{result.fee_sats.toLocaleString()} sats</span>
                </div>
                <div className="summary-item">
                  <span className="label">Fee Rate</span>
                  <span className="value">{result.fee_rate_sat_vb.toFixed(2)} sat/vB</span>
                </div>
                <div className="summary-item">
                  <span className="label">Size</span>
                  <span className="value">{result.vbytes} vBytes</span>
                </div>
                <div className="summary-item">
                  <span className="label">Weight</span>
                  <span className="value">{result.weight.toLocaleString()} WU</span>
                </div>
              </div>
            </div>

            <TransactionFlow result={result} />

            {result.segwit && result.segwit_savings && (
              <SegWitSavings savings={result.segwit_savings} />
            )}

            {result.warnings && result.warnings.length > 0 && (
              <div className="warnings-card">
                <h2>⚠️ Warnings</h2>
                {result.warnings.map((w, i) => (
                  <div key={i} className="warning-item">
                    {w.code === 'HIGH_FEE' && '💸 High fee detected'}
                    {w.code === 'DUST_OUTPUT' && '🪙 Dust output detected'}
                    {w.code === 'RBF_SIGNALING' && '🔄 Transaction is replaceable (RBF)'}
                    {w.code === 'UNKNOWN_OUTPUT_SCRIPT' && '❓ Unknown script type'}
                  </div>
                ))}
              </div>
            )}

            <TechnicalDetails result={result} />
          </div>
        )}
      </div>
    </div>
  );
}

export default App;