//
//  GameLoop.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/11.
//


import Foundation
import QuartzCore
import Combine

/// 高精度なゲームループ（CADisplayLink を使って毎フレーム現在経過秒を発行）
final class GameLoop: ObservableObject {
    @Published private(set) var time: CFTimeInterval = 0.0   // 再生開始からの経過秒
    private var displayLink: CADisplayLink?
    private var startTimestamp: CFTimeInterval = 0.0
    private(set) var isRunning: Bool = false

    /// start: 経過時間を 0 にして開始
    func start() {
        stop() // 既存があれば止める
        startTimestamp = CACurrentMediaTime()
        time = 0.0
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        // main runloop の common モードに登録して UI との共存を優先
        displayLink?.add(to: .main, forMode: .common)
        isRunning = true
    }

    /// stop: ループ停止
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    /// 再生を一時停止（time を保持）
    func pause() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    /// 再開（time を保持して startTimestamp を補正）
    func resume() {
        guard !isRunning else { return }
        let now = CACurrentMediaTime()
        startTimestamp = now - time
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .main, forMode: .common)
        isRunning = true
    }

    @objc private func step() {
        // CACurrentMediaTime はモノトニックなクロック
        let now = CACurrentMediaTime()
        time = now - startTimestamp
    }
}