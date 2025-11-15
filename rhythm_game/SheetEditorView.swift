import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Minimal editor that matches your SheetModel.swift:
/// - SheetNote uses `angleDegrees` and `normalizedPosition: Position`.
/// - Uses safe index-based editing to avoid ForEach binding pitfalls.

struct SheetEditorView: View {
    @State private var sheet: Sheet = Sheet(title: "untitled", notes: [])
    @State private var filename: String = "untitled"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Info")) {
                        TextField("Filename", text: $filename)
                            .autocapitalization(.none)

                        TextField("Title", text: Binding(
                            get: { sheet.title },
                            set: { sheet.title = $0 }
                        ))

                        HStack {
                            Text("BPM")
                            Spacer()
                            Text(String(format: "%.1f", sheet.bpm ?? 120.0))
                                .foregroundColor(.secondary)
                        }
                    }

                    Section(header: Text("Notes")) {
                        List {
                            ForEach(Array(sheet.notes.enumerated()), id: \.0) { idx, note in
                                NavigationLink(destination: SimpleNoteEditor(noteIndex: idx, sheet: $sheet)) {
                                    NoteRowView(note: note)
                                }
                            }
                            .onDelete { indices in
                                for i in indices.sorted(by: >) {
                                    if sheet.notes.indices.contains(i) {
                                        sheet.notes.remove(at: i)
                                    }
                                }
                            }
                        }

                        Button("Add Note") {
                            let nextTime = (sheet.notes.map { $0.time }.max() ?? 0.8) + 0.5
                            let n = SheetNote(
                                id: UUID().uuidString,
                                time: nextTime,
                                angleDegrees: 0.0,
                                normalizedPosition: Position(x: 0.5, y: 0.5)
                            )
                            sheet.notes.append(n)
                        }
                    }
                }

                HStack {
                    Button("Save") {
                        do {
                            try SheetFileManager.save(sheet: sheet, filename: filename)
                            alertMessage = "Saved."
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
                            alertMessage = "Loaded."
                        } catch {
                            alertMessage = "Load failed: \(error.localizedDescription)"
                        }
                        showAlert = true
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Sheet Editor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

// MARK: - Note editor by index

private struct SimpleNoteEditor: View {
    let noteIndex: Int
    @Binding var sheet: Sheet

    var body: some View {
        Form {
            if sheet.notes.indices.contains(noteIndex) {
                NoteEditorFields(note: Binding(
                    get: { sheet.notes[noteIndex] },
                    set: { sheet.notes[noteIndex] = $0 }
                ))
            } else {
                Text("Note not found")
            }
        }
        .navigationTitle("Edit Note")
    }
}

private struct NoteEditorFields: View {
    @Binding var note: SheetNote
    private static let nf: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 6
        return f
    }()

    var body: some View {
        Section(header: Text("Timing")) {
            HStack {
                Text("Time")
                Spacer()
                TextField("time", value: Binding(
                    get: { note.time },
                    set: { v in var n = note; n.time = v; note = n }
                ), formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }
        }

        Section(header: Text("Transform")) {
            HStack {
                Text("Angle")
                Spacer()
                TextField("angle", value: Binding(
                    get: { note.angleDegrees },
                    set: { v in var n = note; n.angleDegrees = v; note = n }
                ), formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }

            HStack {
                Text("X")
                Spacer()
                TextField("x", value: Binding(
                    get: { note.normalizedPosition.x },
                    set: { v in var n = note; n.normalizedPosition.x = v; note = n }
                ), formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }

            HStack {
                Text("Y")
                Spacer()
                TextField("y", value: Binding(
                    get: { note.normalizedPosition.y },
                    set: { v in var n = note; n.normalizedPosition.y = v; note = n }
                ), formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }
        }
    }
}

private struct NoteRowView: View {
    var note: SheetNote

    var body: some View {
        let xStr = String(format: "%.2f", note.normalizedPosition.x)
        let yStr = String(format: "%.2f", note.normalizedPosition.y)
        let idPrefix = String(note.id?.prefix(8) ?? "--------")

        return HStack {
            VStack(alignment: .leading) {
                Text(String(format: "t: %.3f s  angle: %.1f°", note.time, note.angleDegrees))
                    .font(.subheadline)
                Text("pos: (\(xStr), \(yStr)) id: \(idPrefix)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
}

struct SheetEditorView_Previews: PreviewProvider {
    static var previews: some View {
        SheetEditorView()
    }
}
