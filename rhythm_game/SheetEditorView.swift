import SwiftUI
import UniformTypeIdentifiers

/// Minimal, safe Sheet editor — simplified so compiler typecheck won't explode.
/// Replace your existing rhythm_game/SheetEditorView.swift with this to restore a working build.
struct SheetEditorView: View {
    @State private var sheet: Sheet = Sheet()
    @State private var filename: String = "my_sheet"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Info")) {
                        TextField("Filename", text: $filename)
                            .autocapitalization(.none)
                        // simple title binding
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
                        // simple index-based list to avoid complex ForEach bindings
                        List {
                            ForEach(Array(sheet.notes.enumerated()), id: \.0) { idx, note in
                                NavigationLink(destination: SimpleNoteEditor(noteIndex: idx, sheet: $sheet)) {
                                    NoteRowView(note: note)
                                }
                            }
                            .onDelete { indices in
                                // indices is IndexSet for positions in the enumerated array
                                for i in indices.sorted(by: >) {
                                    if sheet.notes.indices.contains(i) {
                                        sheet.notes.remove(at: i)
                                    }
                                }
                            }
                        }
                        Button("Add Note") {
                            let nextTime = (sheet.notes.map { $0.time }.max() ?? 0.8) + 0.5
                            let n = SheetNote(id: UUID().uuidString, time: nextTime, angle: 0.0, x: 0.5, y: 0.5)
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
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

// Simple note editor that edits by index to avoid Binding-for-each complications
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
                TextField("time", value: $note.time, formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
            }
        }
        Section(header: Text("Transform")) {
            HStack {
                Text("Angle")
                Spacer()
                TextField("angle", value: $note.angle, formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("X")
                Spacer()
                TextField("x", value: $note.x, formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Y")
                Spacer()
                TextField("y", value: $note.y, formatter: Self.nf)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct NoteRowView: View {
    var note: SheetNote

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(String(format: "t: %.3f s  angle: %.1f°", note.time, note.angle))
                    .font(.subheadline)
                // build formatted substrings outside the main literal to avoid escaping issues
                let xStr = String(format: "%.2f", note.x)
                let yStr = String(format: "%.2f", note.y)
                let idPrefix = String(note.id.prefix(8))
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
