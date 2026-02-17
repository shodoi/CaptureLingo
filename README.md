# Capture Lingo

MacOS上で画面の英語テキストを範囲選択し、即座に日本語訳を表示するツール。

## 📋 ドキュメント

- [要件定義書](./docs/requirements.md)

## 🚀 開発環境

- macOS 12.3+
- Xcode 15.0+
- Swift 5.9+

## 🔧 セットアップ

1. Xcode でプロジェクトを開く
2. Google Cloud で `Cloud Translation API` と `Cloud Vision API` を有効化したAPIキーを作成
   - Translation: https://cloud.google.com/translate/docs
   - Vision: https://cloud.google.com/vision/docs
3. ビルド & 実行

## 📦 `.app` 生成

1. `swift build -c release`
2. `./scripts/build_app_bundle.sh`
3. 生成物: `.build/release/CaptureLingo.app`

## 📦 依存関係

- Vision Framework (OCR)
- ScreenCaptureKit (画面キャプチャ)
- Keychain Services (APIキー管理)

## 🏗️ アーキテクチャ

MVVM + Service Layer パターンを採用。
詳細は `docs/requirements.md` を参照。
