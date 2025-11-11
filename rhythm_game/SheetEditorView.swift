//
//  SheetEditorView.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/11.
//


import SwiftUI

/// シンプルな譜面エディタ（ローカル Documents に JSON 保存/読み込み）
struct SheetEditorView: View {
    @State private var sheet = Sheet()
    @State private var filename: String = "my_sheet"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Sheet Info")) {
                        TextField("Filename (save/load)", text: $filename)
                            .autocapitalization(.none)
                        TextField("Title", text: $sheet.title)
                        HStack {
                            Text("BPM")
                            Spacer()
                            TextField("BPM", value: Binding(get: { sheet.bpm ?? 120.0 }, set: { sheet.bpm = $0 }), formatter: NumberFormatter())
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 100)
                        }
                        HStack {
                            Text("Offset (s)")
                            Spacer()
                            TextField("Offset", value: Binding(get: { sheet.offset ?? 0.0 }, set: { sheet.offset = $0 }), formatter: NumberFormatter())
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 100)
                        }
                    }

                    Section(header: HStack {
                        Text("Notes")
                        Spacer()
                        EditButton()
                    }) {
                        List {
                            ForEach(sheet.notes.indices, id: \.self) { i in
                                NavigationLink(destination: NoteEditView(note: $sheet.notes[i])) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(String(format: "t: %.3f s  angle: %.1f°", sheet.notes[i].time, sheet.notes[i].angle))
                                                .font(.subheadline)
                                            Text(String(format: "pos: (%.2f, %.2f) id: %@", sheet.notes[i].x, sheet.notes[i].y, sheet.notes[i].id.uuidString.prefix(8) as CVarArg))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .onMove { indices, newOffset in
                                sheet.notes.move(fromOffsets: indices, toOffset: newOffset)
                            }
                            .onDelete { indices in
                                sheet.notes.remove(atOffsets: indices)
                            }
                        }
                        HStack {
                            Spacer()
                            Button(action: {
                                // 新ノートを追加（time は最後の + 0.5 秒推定）
                                let nextTime = (sheet.notes.map { $0.time }.max() ?? 0.8) + 0.5
                                let n = SheetNote(time: nextTime, angle: 0.0, x: 0.5, y: 0.5)
                                sheet.notes.append(n)
                                // keep sorted by time for convenience
                                sheet.notes.sort { $0.time < $1.time }
                            }) {
                                Label("Add Note", systemImage: "plus")
                            }
                            Spacer()
                        }
                    }
                }
                HStack {
                    Button("Save") {
                        do {
                            try SheetFileManager.save(sheet: sheet, filename: filename)
                            alertMessage = "Saved to \(SheetFileManager.urlForFile(named: filename).lastPathComponent)"
                        } catch {
                            alertMessage = "Save failed: \(error.localizedDescription)"
                        }
                        showAlert = true
                    }
                    .padding()
                    Spacer()
                    Button("Load") {
                        do {
                            let loaded = try SheetFileManager.load(filename: filename)
                            sheet = loaded
                            alertMessage = "Loaded \(filename).json"
                        } catch {
                            alertMessage = "Load failed: \(error.localizedDescription)"
                        }
                        showAlert = true
                    }
                    .padding()
                    Spacer()
                    Button("List Files") {
                        let urls = SheetFileManager.listSavedFiles()
                        alertMessage = urls.map { $0.lastPathComponent }.joined(separator: "\n")
                        if alertMessage.isEmpty { alertMessage = "(no json files in Documents)" }
                        showAlert = true
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Sheet Editor")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

/// ノート編集ビュー（Binding としてノートを直接編集）
struct NoteEditView: View {
    @Binding var note: SheetNote
    // helper number formatter
    private static let nf: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        f.numberStyle = .decimal
        return f
    }()

    var body: some View {
        Form {
            Section(header: Text("Timing")) {
                HStack {
                    Text("Time (s)")
                    Spacer()
                    TextField("time", value: $note.time, formatter: Self.nf)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                }
            }
            Section(header: Text("Transform")) {
                HStack {
                    Text("Angle (deg)")
                    Spacer()
                    TextField("angle", value: $note.angle, formatter: Self.nf)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                }
                HStack {
                    Text("X (0..1)")
                    Spacer()
                    TextField("x", value: $note.x, formatter: Self.nf)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                }
                HStack {
                    Text("Y (0..1)")
                    Spacer()
                    TextField("y", value: $note.y, formatter: Self.nf)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 120)
                }
            }
            Section(header: Text("Advanced")) {
                TextField("Type (optional)", text: Binding(get: { note.type ?? "" }, set: { note.type = $0.isEmpty ? nil : $0 }))
                HStack {
                    Spacer()
                    Button("Regenerate ID") {
                        note.id = UUID()
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Preview helper
struct SheetEditorView_Previews: PreviewProvider {
    static var previews: some View {
        SheetEditorView()
    }
}
