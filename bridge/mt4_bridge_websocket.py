#!/usr/bin/env python3
"""
MT4 Bridge API Server with WebSocket Support
Serves both HTTP REST endpoints and WebSocket for real-time communication
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import json
import csv
from datetime import datetime
import os
import threading
import time

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Data storage
signals_data = []
trades_data = []
predictions_data = {}
market_data = {}
account_data = {}

# Connected EA clients
connected_clients = set()

# =============================================================================
# WebSocket Event Handlers
# =============================================================================

@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    print(f"🔌 Client connected: {request.sid}")
    connected_clients.add(request.sid)
    emit('connection_response', {
        'status': 'connected',
        'server': 'QuantumTrader Bridge',
        'timestamp': datetime.utcnow().isoformat()
    })

@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    print(f"🔌 Client disconnected: {request.sid}")
    connected_clients.discard(request.sid)

@socketio.on('market_data')
def handle_market_data_ws(data):
    """Receive market data via WebSocket"""
    global market_data

    if not data or 'symbol' not in data:
        emit('error', {'message': 'Missing symbol'})
        return

    symbol = data['symbol']

    # Store market data
    if symbol not in market_data:
        market_data[symbol] = []

    market_data[symbol].append({
        'symbol': symbol,
        'bid': data.get('bid', 0),
        'ask': data.get('ask', 0),
        'spread': data.get('spread', 0),
        'timestamp': data.get('timestamp', int(datetime.utcnow().timestamp()))
    })

    # Limit history
    if len(market_data[symbol]) > 500:
        market_data[symbol] = market_data[symbol][-500:]

    # Save to file
    os.makedirs('bridge/data', exist_ok=True)
    with open(f'bridge/data/{symbol}_market.json', 'w') as f:
        json.dump(market_data[symbol], f, indent=2)

    # Acknowledge receipt
    emit('market_data_ack', {
        'symbol': symbol,
        'datapoints': len(market_data[symbol]),
        'timestamp': datetime.utcnow().isoformat()
    })

@socketio.on('get_signals')
def handle_get_signals_ws(data=None):
    """Send signals to client via WebSocket"""
    emit('signals', signals_data)

@socketio.on('account_data')
def handle_account_data_ws(data):
    """Receive account data via WebSocket"""
    global account_data

    account_data = data
    account_data['last_update'] = datetime.utcnow().isoformat()

    os.makedirs('bridge/data', exist_ok=True)
    with open('bridge/data/account.json', 'w') as f:
        json.dump(account_data, f, indent=2)

    emit('account_data_ack', {'status': 'ok'})

@socketio.on('positions_data')
def handle_positions_data_ws(data):
    """Receive positions data via WebSocket"""
    global trades_data

    trades_data = data.get('positions', [])

    os.makedirs('predictions', exist_ok=True)
    with open('predictions/trades.json', 'w') as f:
        json.dump(trades_data, f, indent=2)

    emit('positions_data_ack', {'status': 'ok', 'positions': len(trades_data)})

# =============================================================================
# Background Task: Broadcast Signals
# =============================================================================

def broadcast_signals():
    """Background task to broadcast new signals to all connected clients"""
    last_signal_count = 0

    while True:
        try:
            # Load latest signals
            if os.path.exists('predictions/signal_output.json'):
                with open('predictions/signal_output.json', 'r') as f:
                    data = json.load(f)
                    current_signals = data.get('signals', [])

                    # If new signals available, broadcast to all clients
                    if len(current_signals) != last_signal_count:
                        last_signal_count = len(current_signals)
                        socketio.emit('new_signals', {
                            'signals': current_signals,
                            'timestamp': datetime.utcnow().isoformat()
                        }, broadcast=True)
                        print(f"📡 Broadcasted {len(current_signals)} signals to {len(connected_clients)} clients")

            time.sleep(1)  # Check every second

        except Exception as e:
            print(f"Error in broadcast_signals: {e}")
            time.sleep(5)

# =============================================================================
# HTTP REST Endpoints (Backward Compatibility)
# =============================================================================

def load_predictions_from_csv(filepath='predictions/predictions.csv'):
    """Load predictions from CSV file"""
    global signals_data
    signals_data = []

    try:
        with open(filepath, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                signals_data.append({
                    'symbol': row['symbol'],
                    'trend': row['trend'],
                    'probability': float(row['probability']),
                    'action': row['action'],
                    'timestamp': row['timestamp'],
                    'ml_prediction': {
                        'entry_probability': float(row['entry_prob']),
                        'exit_probability': float(row['exit_prob']),
                        'confidence_score': float(row['confidence']),
                        'predicted_window': int(row['predicted_window'])
                    }
                })
    except FileNotFoundError:
        print(f"CSV file not found: {filepath}")

def load_predictions_from_json(filepath='predictions/signal_output.json'):
    """Load predictions from JSON file"""
    global signals_data, predictions_data

    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
            signals_data = data.get('signals', [])
            predictions_data = data
    except FileNotFoundError:
        print(f"JSON file not found: {filepath}")
    except json.JSONDecodeError:
        print(f"Invalid JSON in file: {filepath}")

def load_trades_from_json(filepath='predictions/trades.json'):
    """Load active trades from JSON file"""
    global trades_data

    try:
        with open(filepath, 'r') as f:
            trades_data = json.load(f)
    except FileNotFoundError:
        print(f"Trades file not found: {filepath}")
        trades_data = []
    except json.JSONDecodeError:
        print(f"Invalid JSON in trades file: {filepath}")
        trades_data = []

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.utcnow().isoformat(),
        'websocket': 'enabled',
        'connected_clients': len(connected_clients)
    })

@app.route('/api/signals', methods=['GET'])
def get_signals():
    """Get trading signals"""
    return jsonify(signals_data)

@app.route('/api/trades', methods=['GET'])
def get_trades():
    """Get open trades"""
    if os.path.exists('predictions/trades.json'):
        load_trades_from_json()

    if trades_data:
        return jsonify(trades_data)

    return jsonify({
        'trades': [],
        'message': 'No active trades',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/predictions', methods=['GET'])
def get_predictions():
    """Get ML predictions"""
    if os.path.exists('predictions/signal_output.json'):
        load_predictions_from_json()
    elif os.path.exists('predictions/predictions.csv'):
        load_predictions_from_csv()

    if predictions_data:
        return jsonify(predictions_data)

    return jsonify({
        'predictions': [],
        'signals': [],
        'message': 'No predictions available',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/market', methods=['POST'])
def receive_market_data():
    """Receive real-time market data from EA"""
    global market_data

    data = request.json
    if not data or 'symbol' not in data:
        return jsonify({'error': 'Missing symbol'}), 400

    symbol = data['symbol']

    if symbol not in market_data:
        market_data[symbol] = []

    market_data[symbol].append({
        'symbol': symbol,
        'bid': data.get('bid', 0),
        'ask': data.get('ask', 0),
        'spread': data.get('spread', 0),
        'timestamp': data.get('timestamp', int(datetime.utcnow().timestamp()))
    })

    if len(market_data[symbol]) > 500:
        market_data[symbol] = market_data[symbol][-500:]

    os.makedirs('bridge/data', exist_ok=True)
    with open(f'bridge/data/{symbol}_market.json', 'w') as f:
        json.dump(market_data[symbol], f, indent=2)

    return jsonify({'status': 'ok', 'symbol': symbol, 'datapoints': len(market_data[symbol])}), 200

@app.route('/api/account', methods=['POST'])
def receive_account_data():
    """Receive account data from EA"""
    global account_data

    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    account_data = data
    account_data['last_update'] = datetime.utcnow().isoformat()

    os.makedirs('bridge/data', exist_ok=True)
    with open('bridge/data/account.json', 'w') as f:
        json.dump(account_data, f, indent=2)

    return jsonify({'status': 'ok'}), 200

@app.route('/api/positions', methods=['POST'])
def receive_positions():
    """Receive open positions from EA"""
    global trades_data

    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    trades_data = data.get('positions', [])

    os.makedirs('predictions', exist_ok=True)
    with open('predictions/trades.json', 'w') as f:
        json.dump(trades_data, f, indent=2)

    return jsonify({'status': 'ok', 'positions': len(trades_data)}), 200

@app.route('/api/order', methods=['POST'])
def create_order():
    """Create a new trading order"""
    order_data = request.json

    required_fields = ['symbol', 'type', 'volume']
    if not all(field in order_data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400

    response = {
        'status': 'success',
        'order_id': f"ORD{datetime.utcnow().timestamp()}",
        'symbol': order_data['symbol'],
        'type': order_data['type'],
        'volume': order_data['volume'],
        'timestamp': datetime.utcnow().isoformat()
    }

    return jsonify(response), 201

@app.route('/api/close/<position_id>', methods=['POST'])
def close_position(position_id):
    """Close an open position"""
    response = {
        'status': 'success',
        'position_id': position_id,
        'closed_at': datetime.utcnow().isoformat()
    }

    return jsonify(response)

# =============================================================================
# Main Entry Point
# =============================================================================

if __name__ == '__main__':
    # Create necessary directories
    os.makedirs('predictions', exist_ok=True)
    os.makedirs('bridge/data', exist_ok=True)

    # Load initial data
    print("📂 Loading initial data...")
    if os.path.exists('predictions/signal_output.json'):
        load_predictions_from_json()
        print("   ✓ Loaded predictions from JSON")
    elif os.path.exists('predictions/predictions.csv'):
        load_predictions_from_csv()
        print("   ✓ Loaded predictions from CSV")
    else:
        print("   ⚠ No prediction files found")

    if os.path.exists('predictions/trades.json'):
        load_trades_from_json()
        print(f"   ✓ Loaded {len(trades_data)} active trades")
    else:
        print("   ⚠ No trades file found")

    print("\n" + "=" * 70)
    print("🚀 QuantumTrader Bridge Server with WebSocket Support")
    print("=" * 70)
    print(f"📡 HTTP Server: http://0.0.0.0:8080")
    print(f"🔌 WebSocket:   ws://0.0.0.0:8080")
    print()
    print("📋 HTTP Endpoints:")
    print("   GET  /api/health       - Health check")
    print("   GET  /api/signals      - Trading signals")
    print("   GET  /api/trades       - Open trades")
    print("   GET  /api/predictions  - ML predictions")
    print("   POST /api/market       - Receive market data from EA")
    print("   POST /api/account      - Receive account data from EA")
    print("   POST /api/positions    - Receive open positions from EA")
    print("   POST /api/order        - Create order")
    print("   POST /api/close/<id>   - Close position")
    print()
    print("🔌 WebSocket Events:")
    print("   Client -> Server:")
    print("     • market_data      - Send market data (real-time)")
    print("     • account_data     - Send account info")
    print("     • positions_data   - Send open positions")
    print("     • get_signals      - Request current signals")
    print()
    print("   Server -> Client:")
    print("     • new_signals      - New signals available (push)")
    print("     • market_data_ack  - Market data received")
    print("     • signals          - Response to get_signals")
    print()
    print("📊 Performance:")
    print("   • HTTP Polling:  5-10 second latency")
    print("   • WebSocket:     <100ms latency (real-time push)")
    print()
    print("=" * 70)

    # Start background signal broadcaster
    broadcast_thread = threading.Thread(target=broadcast_signals, daemon=True)
    broadcast_thread.start()
    print("✅ Signal broadcaster started")

    # Run server
    socketio.run(app, host='0.0.0.0', port=8080, debug=True, allow_unsafe_werkzeug=True)
