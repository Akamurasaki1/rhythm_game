//
//  ShareSheet.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/11.
//


import SwiftUI
import UIKit

/// SwiftUI から呼べる UIActivityViewController ラッパー
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}