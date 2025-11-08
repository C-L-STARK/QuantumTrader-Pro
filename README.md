# 📱 QuantumTrader Pro

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android-green.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

**First Sterling QuantumTrader Pro**
Advanced MT4 Trading Application with Machine Learning Integration

*Built by Dezirae Stark*

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Documentation](#-documentation) • [Contributing](#-contributing)

</div>

---

## 🔮 Overview

**QuantumTrader Pro** is a full-featured Android mobile trading companion for MetaTrader 4 (MT4), featuring:

- 🔗 **MT4 Integration API**: Real-time polling of trading signals and market data
- 📈 **Trading Dashboard**: Multi-symbol monitoring with trend analysis
- 🤖 **Machine Learning Integration**: TFLite-powered predictive analytics
- 📤 **Telegram Remote Control**: Approve/deny trades remotely
- 📊 **Portfolio Management**: Real-time P&L tracking and trade history
- 🎨 **Modern UI**: Material Design 3 with light/dark mode support

---

## ✨ Features

### 📊 Trading Dashboard
- **Multi-Symbol Monitoring**: Track EURUSD, GBPUSD, USDJPY, AUDUSD and more
- **Trend Direction Indicators**: Visual bullish/bearish/neutral signals
- **Probability Analysis**: Color-coded trend continuation/reversal predictions
- **Signal History**: Complete entry and exit signal timeline
- **Trading Modes**: Toggle between Conservative and Aggressive strategies

### 🤖 Machine Learning
- **TFLite Integration**: Embedded ML inference on-device
- **Predictive Windows**: 3-8 candle ahead forecasting
- **Confidence Scoring**: Weighted decision support
- **JSON/CSV Import**: Load predictions from MT4 indicators

### 📱 Telegram Integration
- **Remote Trade Approval**: Accept/reject trades from anywhere
- **Real-time Alerts**: Push notifications for signals and P&L updates
- **Command Interface**: Full bot control with `/status`, `/approve`, `/deny`
- **Secure Authentication**: Token-based API access

### 📈 Portfolio View
- **Open Positions**: Real-time trade monitoring
- **P&L Tracking**: Live profit/loss calculations
- **Historical Logs**: Complete trade history
- **ML Predictions**: Highlight predictive trade zones

---

## 🚀 Installation

### Prerequisites
- Android device running Android 7.0 (API 24) or higher
- MT4 account and platform access
- (Optional) Telegram bot token for remote control

### Option 1: Download Pre-built APK

1. Go to the [Releases](https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases) page
2. Download `QuantumTraderPro.apk`
3. Enable "Install from Unknown Sources" in Android settings
4. Install the APK

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro

# Install Flutter dependencies
flutter pub get

# Build APK
flutter build apk --release

# APK will be located at: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📖 Usage

### Initial Setup

1. **Launch the app** and navigate to Settings
2. **Configure MT4 API endpoint**:
   - Enter your bridge server URL (e.g., `http://192.168.1.100:8080`)
   - Click "Test" to verify connection
3. **Setup Telegram** (optional):
   - Enter your Telegram bot token
   - Add your chat ID
   - Save settings

### Trading Dashboard

- **View Signals**: See real-time trading signals from MT4
- **Monitor Trends**: Check multi-symbol trend indicators
- **Switch Modes**: Toggle between Conservative/Aggressive trading

### Portfolio Management

- **Track Positions**: Monitor all open trades
- **View P&L**: Real-time profit/loss calculations
- **ML Insights**: See predictive windows for each trade

---

## 🔧 MT4 Bridge Setup

The app requires a bridge server to communicate with MT4. A sample Python Flask server is included:

### Running the Bridge Server

```bash
cd bridge

# Install dependencies
pip install -r requirements.txt

# Run the server
python mt4_bridge.py
```

The server will start on `http://localhost:8080` and provide these endpoints:

- `GET /api/health` - Health check
- `GET /api/signals` - Trading signals
- `GET /api/trades` - Open trades
- `GET /api/predictions` - ML predictions
- `POST /api/order` - Create order
- `POST /api/close/<id>` - Close position

### MT4 Integration

Place MQL4 scripts in your MT4 `Experts` and `Scripts` folders to:
1. Export signals to JSON files
2. Poll predictions from the ML model
3. Send data to the bridge server

---

## 📁 Project Structure

```
QuantumTrader-Pro/
├── lib/                    # Flutter app source code
│   ├── main.dart          # App entry point
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   ├── services/          # API services
│   └── widgets/           # Reusable components
├── android/               # Android-specific configuration
│   ├── app/
│   │   ├── build.gradle   # App build configuration
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/    # Native Android code
│   ├── build.gradle       # Project build configuration
│   └── settings.gradle    # Gradle settings
├── assets/                # App assets
│   ├── images/           # Image resources
│   ├── icons/            # App icons
│   └── samples/          # Sample data
├── bridge/                # MT4 API bridge
│   ├── mt4_bridge.py     # Flask server
│   └── requirements.txt  # Python dependencies
├── ml/                    # Machine learning models
├── predictions/           # Sample predictions
│   ├── signal_output.json
│   └── predictions.csv
├── .github/workflows/     # CI/CD automation
│   └── android.yml        # Build workflow
├── pubspec.yaml           # Flutter dependencies
├── README.md              # This file
└── LICENSE                # MIT License
```

---

## 🧪 Sample Data

The repository includes sample prediction files for testing:

- `predictions/signal_output.json` - JSON formatted trading signals
- `predictions/predictions.csv` - CSV formatted ML predictions

Load these in the app to see how signals and predictions are displayed.

---

## 🔐 Security

- **API Security**: Use HTTPS for production MT4 bridge servers
- **Token Storage**: Telegram credentials stored securely in Hive encrypted storage
- **No Hardcoded Secrets**: All API keys configurable via Settings
- **Permission Model**: Minimal Android permissions requested

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure all commits are GPG-signed.

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👩‍💻 Author

**Dezirae Stark**
📧 [clockwork.halo@tutanota.de](mailto:clockwork.halo@tutanota.de)
🔗 [GitHub](https://github.com/Dezirae-Stark)

---

## 🙏 Acknowledgments

- Flutter team for the excellent framework
- MetaTrader 4 for the trading platform
- The open-source community for inspiration

---

## 📱 Screenshots

*(Screenshots will be added in future releases)*

---

## 🗺️ Roadmap

- [ ] iOS version
- [ ] Custom ML model training interface
- [ ] Real-time chart visualization
- [ ] Multi-broker support
- [ ] Advanced risk management tools
- [ ] Cloud sync for settings

---

## ⚠️ Disclaimer

**Trading involves risk. This software is provided for educational and informational purposes only. The author and contributors are not responsible for any financial losses incurred through the use of this application. Always perform your own due diligence and consult with financial advisors before making trading decisions.**

---

<div align="center">

**Made with ❤️ and Flutter**

*"Let the probabilities speak."*

</div>
