# VirtualCameraSample

## 概要

macOS用仮想カメラの最小実装です。

## 本リポジトリの使い方

1. Xcodeでプロジェクトを開き「VirtualCameraSample」スキーマを選択しビルド

2. 生成された `VirtualCameraSample.plugin`を`/Library/CoreMediaIO/Plug-Ins/DAL/`に配置

3. Xcodeで「VirtualCameraSampleController」スキーマを選択しビルドし実行

4. Zoomで`VirtualCameraSample`を選択し、コントローラアプリから文字列を入力しSend

## 参考リンク

- [macOS仮想カメラ「テロップカム」実装方法とその先](https://note.com/shm/n/nd5343d2a589a)
