# Smart Farm Weather Predictor (Flutter)

![Language](https://img.shields.io/badge/Language-Dart-blue) ![Framework](https://img.shields.io/badge/Framework-Flutter-02569B) ![License](https://img.shields.io/badge/License-MIT-green)

A Flutter app that predicts the rolling 5-day probability of significant rainfall (≥15mm) using Weatherbit API forecasts blended with historical climate baselines.  
Adapted from the original [Smart-Farm-Weather-Predictor (CLI)](https://github.com/ruhneb2004/Smart-Farm-Weather-Predictor).

## Problem

- Standard forecasts don’t highlight crop-soaking rain.
- Accuracy drops for long-term predictions.
- Farmers need actionable rainfall probabilities, not generic “chance of rain.”

## Solution

- Builds a baseline from 5 years of rainfall history.
- Applies a decaying confidence model (trust near-term more, rely on history long-term).
- Outputs rolling 5-day probabilities for significant rainfall.

## Features

- Flutter app (Android + iOS).
- Uses Weatherbit API (forecast + history).
- DataTable output with rolling windows.
- Configurable rainfall threshold and confidence model.

## Installation

**Prerequisites**

- Flutter SDK (3.0+ recommended)
- Weatherbit API key

**Setup**

```bash
git clone <your-flutter-repo-url>
cd smart_farm_flutter
flutter pub get
```

Add API key in `main.dart` → `RainPredictor`:

```dart
final String apiKey = "YOUR_API_KEY";
```

## Run

```bash
flutter run
```

Default location: Kochi, India (10.0749, 76.2089).  
Edit `_fetchForecast()` in `main.dart` to change location.

## Output

| Column       | Description                                       |
| ------------ | ------------------------------------------------- |
| Index        | Rolling 5-day window number                       |
| Window Start | First day of the forecast window                  |
| Raw Chance   | Probability of any rainfall (Weatherbit)          |
| Adj. Chance  | Confidence-adjusted probability of ≥15mm rainfall |

## Configuration

Inside `RainPredictor`:

- `cutOffRainAmount` → threshold for “significant” rain (default: 15mm)
- `dailyConfidenceScores` → trust decay for days 1–16
- `noOfYears` → years of climate baseline (default: 5)

## License

MIT License
