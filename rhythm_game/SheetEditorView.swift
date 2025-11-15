import SwiftUI
import UniformTypeIdentifiers

// Refactored Sheet editor: split large body into small subviews to avoid the
// "The compiler is unable to type-check this expression in reasonable time" error.

struct SheetEditorView: View {
    @State private var sheet: Sheet = Sheet()
    @State private var filename: String = "mysong"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var editMode: EditMode = .inactive
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    HeaderSection(sheet: $sheet, filename: $filename)
                    NotesSection(sheet: $sheet, editMode: $editMode)
                }
                BottomButtons(
                    sheet: sheet,
                    filename: filename,
                    onSave: saveAction,
                    onLoad: loadAction,
                    onListFiles: listFilesAction
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Sheet Editor")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveAction() {
        do {
            try SheetFileManager.save(sheet: sheet, filename: filename)
            alertMessage = "Saved to \(SheetFileManager.urlForFile(named: filename).lastPathComponent)"
        } catch {
            alertMessage = "Save failed: \(error.localizedDescription)"
        }
        showAlert = true
    }

    private func loadAction() {
        do {
            let loaded = try SheetFileManager.load(filename: filename)
            sheet = loaded
            alertMessage = "Loaded \(filename).json"
        } catch {
            alertMessage = "Load failed: \(error.localizedDescription)"
        }
        showAlert = true
    }

    private func listFilesAction() {
        let urls = SheetFileManager.listSavedFiles()
        alertMessage = urls.map { $0.lastPathComponent }.joined(separator: "\n")
        if alertMessage.isEmpty { alertMessage = "(no json files in Documents)" }
        showAlert = true
    }
}

// MARK: - HeaderSection

// Replace the existing HeaderSection with this version
private struct HeaderSection: View {
    @Binding var sheet: Sheet
    @Binding var filename: String

    var body: some View {
        Section(header: Text("Sheet Info")) {
            TextField("Filename (save/load)", text: $filename)
                .autocapitalization(.none)

            // Title binding created from the sheet binding
            TextField("Title", text: Binding(
                get: { sheet.title },
                set: { sheet.title = $0 }
            ))

            HStack {
                Text("BPM")
                Spacer()
                TextField("BPM", value: Binding(
                    get: { sheet.bpm ?? 120.0 },
                    set: { sheet.bpm = $0 }
                ), formatter: NumberFormatter())
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 100)
            }

            HStack {
                Text("Offset (s)")
                Spacer()
                TextField("Offset", value: Binding(
                    get: { sheet.offset ?? 0.0 },
                    set: { sheet.offset = $0 }
                ), formatter: NumberFormatter())
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 100)
            }

            HStack {
                Text("Audio")
                Spacer()
                Text(sheet.audioFilename ?? "—")
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - NotesSection

private struct NotesSection: View {
    @Binding var sheet: Sheet
    @Binding var editMode: EditMode

    var body: some View {
        Section(header: HStack {
            Text("Notes")
            Spacer()
            EditButton()
        }) {
            // Use Binding-based ForEach to give the compiler explicit types
            ForEach($sheet.notes) { $note in
                NavigationLink(destination: NoteEditView(note: $note)) {
                    NoteRowView(note: note)
                }
            }
            .onDelete { indices in
                sheet.notes.remove(atOffsets: indices)
            }
            .onMove { indices, newOffset in
                sheet.notes.move(fromOffsets: indices, toOffset: newOffset)
            }

            HStack {
                Spacer()
                Button(action: addNote) {
                    Label("Add Note", systemImage: "plus")
                }
                Spacer()
            }
        }
    }

    private func addNote() {
        let nextTime = (sheet.notes.map { $0.time }.max() ?? 0.8) + 0.5
        let n = SheetNote(id: "\(sheet.id)-\(String(format: "%04d", (sheet.notes.count + 1)))", time: nextTime, angle: 0.0, x: 0.5, y: 0.5)
        sheet.notes.append(n)
        sheet.notes.sort { $0.time < $1.time }
    }
}

// MARK: - NoteRowView

private struct NoteRowView: View {
    var note: SheetNote

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(String(format: "t: %.3f s  angle: %.1f°", note.time, note.angle))
                    .font(.subheadline)
                Text(String(format: "pos: (%.2f, %.2f) id: %@", note.x, note.y, String(note.id.prefix(8))))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
}

// MARK: - NoteEditView

struct NoteEditView: View {
    @Binding var note: SheetNote
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
                        note.id = UUID().uuidString
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - BottomButtons (Save / Load / List)

private struct BottomButtons: View {
    let sheet: Sheet
    let filename: String
    let onSave: () -> Void
    let onLoad: () -> Void
    let onListFiles: () -> Void

    var body: some View {
        HStack {
            Button("Save", action: onSave)
                .padding()
            Spacer()
            Button("Load", action: onLoad)
                .padding()
            Spacer()
            Button("List Files", action: onListFiles)
                .padding()
        }
    }
}

// MARK: - Bindings for optional numeric fields convenience

private extension Sheet {
    var bpmBinding: Binding<Double> {
        Binding(get: { self.bpm ?? 120.0 }, set: { self.bpm = $0 })
    }
    var offsetBinding: Binding<Double> {
        Binding(get: { self.offset ?? 0.0 }, set: { self.offset = $0 })
    }
    var titleBinding: Binding<String> {
        Binding(get: { self.title }, set: { self.title = $0 })
    }
}
