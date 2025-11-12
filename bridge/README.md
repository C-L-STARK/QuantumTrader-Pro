# QuantumTrader Pro - WebSocket Bridge Server

WebSocket Bridge Server that connects the QuantumTrader Pro mobile app to MT4/MT5 trading terminals.

## Features

- **REST API Endpoints** for account management, signal retrieval, and trade execution
- **WebSocket Support** for real-time price updates and live trading
- **LHFX Integration** with practice account support
- **Production-Ready** with comprehensive error handling and logging

## Installation

```bash
cd bridge
npm install
```

## Dependencies

- `express` - Web server framework
- `ws` - WebSocket implementation
- `cors` - Cross-origin resource sharing

## Configuration

Default configuration:
- **Port:** 8080
- **LHFX Demo Server:** LHFXDemo-Server
- **Practice Account:** 194302

## Usage

### Start the Server

```bash
npm start
```

Or with nodemon for development:

```bash
npm run dev
```

### API Endpoints

#### Health Check
```
GET /api/health
```
Returns server status and uptime.

#### Connect to MT4/MT5
```
POST /api/connect
Content-Type: application/json

{
  "login": 194302,
  "password": "ajty2ky",
  "server": "LHFXDemo-Server"
}
```

#### Get Trading Signals
```
GET /api/signals?account=194302
```

Returns ML-generated trading signals with confidence scores.

#### Get Open Positions
```
GET /api/positions?account=194302
```

Returns all active trading positions.

#### Execute Trade
```
POST /api/trade
Content-Type: application/json

{
  "account": 194302,
  "symbol": "EURUSD",
  "type": "BUY",
  "volume": 0.01,
  "stop_loss": 1.0850,
  "take_profit": 1.0950
}
```

#### Close Position
```
POST /api/close
Content-Type: application/json

{
  "account": 194302,
  "ticket": 123456
}
```

### WebSocket Connection

Connect to WebSocket for real-time updates:

```javascript
const ws = new WebSocket('ws://localhost:8080');

ws.onopen = () => {
  // Subscribe to price updates
  ws.send(JSON.stringify({
    type: 'subscribe',
    symbols: ['EURUSD', 'GBPUSD']
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);
};
```

#### WebSocket Message Types

**Subscribe to Symbols:**
```json
{
  "type": "subscribe",
  "symbols": ["EURUSD", "GBPUSD"]
}
```

**Price Update:**
```json
{
  "type": "price",
  "symbol": "EURUSD",
  "bid": 1.0900,
  "ask": 1.0902,
  "timestamp": 1699875600000
}
```

**Signal Update:**
```json
{
  "type": "signal",
  "symbol": "EURUSD",
  "action": "BUY",
  "confidence": 0.85,
  "timestamp": 1699875600000
}
```

## Integration with MT4/MT5

1. **Install Expert Advisor**
   - Copy `QuantumTraderPro.mq4` to MT4's `MQL4/Experts/` directory
   - Compile in MetaEditor
   - Attach to chart

2. **Configure Bridge URL**
   - In MT4: Tools → Options → Expert Advisors
   - Add `http://localhost:8080` to allowed URLs
   - Restart MT4

3. **Install Indicators**
   - Copy `QuantumTrendIndicator.mq4` and `MLSignalOverlay.mq4` to `MQL4/Indicators/`
   - Compile and attach to charts

## Mobile App Integration

The mobile app connects automatically to the bridge server. Configure the endpoint in app settings:

**Settings → API Endpoint → `http://your-server-ip:8080`**

## Security Notes

- **Production Use:** Change default passwords and use HTTPS
- **Firewall:** Restrict access to trusted IP addresses only
- **Authentication:** Implement JWT or API key authentication for production

## Troubleshooting

### Connection Issues

1. Check if server is running: `curl http://localhost:8080/api/health`
2. Verify MT4 is running and connected to broker
3. Check firewall settings
4. Ensure WebRequest URLs are allowed in MT4

### No Price Updates

1. Verify WebSocket connection is established
2. Check if symbols are subscribed correctly
3. Ensure MT4 terminal is receiving live quotes

## Development

Run with nodemon for auto-restart on code changes:

```bash
npm run dev
```

## License

MIT - QuantumTrader Pro

## Support

For issues and questions, visit: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues
