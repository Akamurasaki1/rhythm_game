//
//  DocumentPicker.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/11.
//


import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// SwiftUI で UIDocumentPicker を使うラッパー（JSON を開いて処理する）
/// completion: 選ばれたファイルのローカルセキュリティスコープ URL を返す
struct DocumentPicker: UIViewControllerRepresentable {
    var contentTypes: [UTType] = [UTType.json]
    var onPick: (_ urls: [URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (_ urls: [URL]) -> Void
        init(onPick: @escaping (_ urls: [URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // セキュリティスコープ付き URL の利用開始（必要な場合）
            var accessibleURLs: [URL] = []
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    accessibleURLs.append(url)
                    // アプリ側でファイルをコピーして Documents に保存した方が扱いやすい
                } else {
                    // startAccessing... が false の場合でもコピーは試みられる
                    accessibleURLs.append(url)
                }
            }
            onPick(accessibleURLs)
            // 呼び出し側で finishAccessingSecurityScopedResource するか、ここで処理が終わったら呼ぶ
            for url in accessibleURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // no-op
        }
    }
}