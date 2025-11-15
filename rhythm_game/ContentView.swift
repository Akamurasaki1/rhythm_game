import SwiftUI
import AVFoundation

/// メイン画面：仕組みは整理したまま（spawn/clear/delete をキレイにスケジュール）、
/// 表示の見た目とフリック後のアニメーションは以前の v12 っぽい感触に戻しました。
/// - データは SheetData.SampleData.samples (10個) を利用します。
struct ContentView: View {
    // ActiveNote: 表示用インスタンス（spawn 時に id が決まる）
    private struct ActiveNote: Identifiable {
        let id: UUID
        let angleDegrees: Double
        var position: CGPoint
        let targetPosition: CGPoint
        let hitTime: Double
        let spawnTime: Double
        var isClear: Bool
    }
    

    // サンプルデータ（SheetData に定義）
    private let sampleDataSets = SampleData.samples
    private var sampleCount: Int { sampleDataSets.count }

    // UI / 状態
    @State private var selectedSampleIndex: Int = 0 // 残す
    @State private var notesToPlay: [Note] = []

    @State private var activeNotes: [ActiveNote] = []
    @State private var isPlaying = false
    @State private var startDate: Date?
    @State private var showingEditor = false
    
    // paste into ContentView's properties area (near other @State vars)
    @State private var isShowingShare = false
    @State private var shareURL: URL? = nil

    @State private var isShowingImportPicker = false
    // optional: temp URL from document picker callback
    @State private var importErrorMessage: String? = nil
    
    @State private var sampleEntries: [SampleEntry] = []

    // audio player
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var currentlyPlayingAudioFilename: String? = nil
    

    // スケジュール管理
    @State private var scheduledWorkItems: [DispatchWorkItem] = []
    @State private var autoDeleteWorkItems: [UUID: DispatchWorkItem] = [:]

    // 重複カウント防止
    @State private var flickedNoteIDs: Set<UUID> = []

    // スコア / コンボ
    @State private var score: Int = 0
    @State private var combo: Int = 0

    // パラメータ（プレイ中は隠す）
    @State private var approachDistanceFraction: Double = 0.25
    @State private var approachSpeed: Double = 800.0

    // 判定窓
    private let perfectWindow: Double = 0.5
    private let goodWindowBefore: Double = 0.8
    private let goodWindowAfter: Double = 1.0

    // ノーツの寿命（spawn からの秒）
    private let lifeDuration: Double = 2.5

    // フリック判定パラメータ
    private let speedThreshold: CGFloat = 35.0
    private let hitRadius: CGFloat = 110.0

    // 見た目
    private let rodWidth: CGFloat = 160
    private let rodHeight: CGFloat = 10

    // 判定フィードバック
    @State private var lastJudgement: String = ""
    @State private var lastJudgementColor: Color = .white
    @State private var showJudgementUntil: Date? = nil

    // Carousel settings (reuse earlier cylinder-like UI)
    private let repeatFactor = 3
    @State private var initialScrollPerformed = false
    private let carouselItemWidth: CGFloat = 100
    private let carouselItemSpacing: CGFloat = 12
    
    private func bundleURLForAudio(named audioFilename: String?) -> URL? {
        guard let audioFilename = audioFilename, !audioFilename.isEmpty else { return nil }
        // split name/ext
        let ext = (audioFilename as NSString).pathExtension
        let name = (audioFilename as NSString).deletingPathExtension

        // try subdirectory first
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "wav" : ext, subdirectory: "bundled-audio") {
            return url
        }
        // fallback to root
        if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "wav" : ext) {
            return url
        }
        return nil
    }
    // 選択中の SampleEntry が bundled sheet の場合は対応する Sheet の audioFilename を探して再生
    private func prepareAndPlayAudioIfAvailable(for sheetFilename: String?, sheetObject: Sheet?) {
        // sheetObject があれば優先してその audioFilename を使う
        var audioURL: URL? = nil
        if let audioName = sheetObject?.audioFilename {
            audioURL = bundleURLForAudio(named: audioName)
        } else if let sheetFilename = sheetFilename {
            // バンドル中のシートを探す（loadBundledSheets を使ってマップ）
            let bundled = loadBundledSheets()
            for (filename, sheet) in bundled {
                if filename.contains("115") {
                    // filename は String、sheet は Sheet として使える
                }
            }
            if let pair = bundled.first(where: { $0.filename == sheetFilename || $0.sheet.title == sheetFilename }) {
                audioURL = bundleURLForAudio(named: pair.sheet.audioFilename)
            }
        }

        if let url = audioURL {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                currentlyPlayingAudioFilename = url.lastPathComponent
            } catch {
                print("Audio playback failed: \(error)")
                audioPlayer = nil
                currentlyPlayingAudioFilename = nil
            }
        } else {
            // audio が見つからない場合は nil のまま（ビジュアルで知らせる実装を追加しても良い）
            currentlyPlayingAudioFilename = nil
        }
    }
    /// バンドル内 bundled-sheets フォルダ（またはルート）から JSON を読み込んで Sheet を返す
    private func loadBundledSheets() -> [(filename: String, sheet: Sheet)] {
        var results: [(String, Sheet)] = []
        let decoder = JSONDecoder()

        // 1) try subdirectory (if you added folder references)
        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "bundled-sheets") {
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let s = try decoder.decode(Sheet.self, from: data)
                    results.append((url.lastPathComponent, s))
                } catch {
                    print("Failed decode bundled sheet at \(url): \(error)")
                }
            }
        }

        // 2) fallback: try any json in bundle root (if you added files as group)
        // --- replace the fallback block inside loadBundledSheets() with this:
        if results.isEmpty {
            if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
                for url in urls {
                    // Skip hidden files and non-json (urls already filtered by extension, but be defensive)
                    let filename = url.lastPathComponent
                    if filename.hasPrefix(".") { continue }

                    do {
                        let data = try Data(contentsOf: url)
                        let s = try decoder.decode(Sheet.self, from: data)
                        // avoid duplicate filename entries (results contains tuples (String, Sheet))
                        if !results.contains(where: { $0.0 == filename }) {
                            results.append((filename, s))
                        }
                    } catch {
                        // ignore files that aren't valid Sheet JSON
                        // you can log for debugging:
                        // print("Skipping non-sheet or unreadable JSON at \(url): \(error)")
                    }
                }
            }
        }
        return results
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // 上段: スコア / コンボ / 判定表示
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Score: \(score)")
                                .foregroundColor(.white)
                                .font(.headline)
                            Text("Combo: \(combo)")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                        }
                        Spacer()
                        if shouldShowJudgement() {
                            Text(lastJudgement)
                                .font(.title2)
                                .bold()
                                .foregroundColor(lastJudgementColor)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Sample ラベル + カルーセル（再生中は非表示）
                    HStack(alignment: .center) {
                        Text("Sample:")
                            .foregroundColor(.white)
                            .padding(.leading, 10)

                        if !isPlaying {
                            carouselView(width: geo.size.width)
                                .frame(height: 120)
                                .padding(.trailing, 8)
                        } else {
                            Spacer().frame(height: 8)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)

                    // 調整 UI（再生中は隠す）
                    if !isPlaying {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Approach dist (fraction): \(String(format: "%.2f", approachDistanceFraction))")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            Slider(value: $approachDistanceFraction, in: 0.05...1.5)

                            HStack {
                                Text("Approach speed (pts/s): \(Int(approachSpeed))")
                                    .foregroundColor(.white)
                                Spacer()
                                let exampleDistance = approachDistanceFraction * min(geo.size.width, geo.size.height)
                                let derivedDuration = exampleDistance / max(approachSpeed, 1.0)
                                Text("例 dur: \(String(format: "%.2f", derivedDuration))s")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $approachSpeed, in: 100...3000)
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                    }

                    Spacer()
                }

                // 表示中のノーツ（v12 っぽいアニメーション感）
                ForEach(activeNotes) { a in
                    RodView(angleDegrees: a.angleDegrees)
                        .frame(width: rodWidth, height: rodHeight)
                        .opacity(a.isClear ? 1.0 : 0.35)
                        .position(a.position)
                        .zIndex(a.isClear ? 2 : 1)
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onEnded { value in
                                    handleFlick(for: a.id, dragValue: value, in: geo.size)
                                }
                        )
                }

                // ボトム操作類（Start/Stop と Reset は常時表示）
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if isPlaying {
                                stopPlayback()
                            } else {
                                notesToPlay = sampleDataSets[selectedSampleIndex]
                                startPlayback(in: geo.size)
                            }
                        }) {
                            Text(isPlaying ? "Stop" : "Start")
                                .font(.headline)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(isPlaying ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Spacer()
                            // ここに Editor ボタンを追加
                            Button(action: {
                                showingEditor = true
                            }) {
                                Text("Editor")
                                    .font(.subheadline)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.85))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            Spacer()
                        // inside the bottom HStack with Start/Editor/Reset, add Export and Import buttons
                        do {
                            Text("Export")
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.purple.opacity(0.85))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }

                        Spacer()

                        Button(action: {
                            isShowingImportPicker = true
                        }) {
                            Text("Import")
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.orange.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        Button(action: {
                            resetAll()
                        }) {
                            Text("Reset")
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                // end of ZStack
                .sheet(isPresented: $showingEditor) {
                    SheetEditorView()
                }
                    .padding(.bottom, 16)

                    if !isPlaying {
                        HStack {
                            Text("Selected: \(selectedSampleIndex + 1)")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    } else {
                        Spacer().frame(height: 20)
                    }
                }
            }
            // グローバルフリック検出
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        handleGlobalFlick(dragValue: value, in: geo.size)
                    }
            )
            // Add these modifiers to the root view (for example after .gesture(...) or on the ZStack)
            .sheet(isPresented: $isShowingShare, onDismiss: {
                // clear shareURL when dismissed
                shareURL = nil
            }) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                } else {
                    Text("No file to share.")
                }
            }
        
        }
    }

    // MARK: - Carousel (円柱風ループ)
    @ViewBuilder
    private func carouselView(width: CGFloat) -> some View {
        let total = sampleCount * repeatFactor
        let initialIndex = sampleCount * (repeatFactor / 2)

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: carouselItemSpacing) {
                    ForEach(0..<total, id: \.self) { i in
                        let sampleIndex = i % sampleCount
                        GeometryReader { itemGeo in
                            let frame = itemGeo.frame(in: .global)
                            let centerX = UIScreen.main.bounds.width / 2
                            let midX = frame.midX
                            let diff = midX - centerX
                            let normalized = max(-1.0, min(1.0, diff / (width * 0.5)))
                            let rotateDeg = -normalized * 30.0
                            let scale = 1.0 - abs(normalized) * 0.25
                            let opacity = 1.0 - abs(normalized) * 0.6

                            VStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedSampleIndex == sampleIndex ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: carouselItemWidth, height: 64)
                                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                                    Text("No.\(sampleIndex + 1)")
                                        .foregroundColor(.white)
                                        .bold()
                                }
                            }
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .rotation3DEffect(.degrees(rotateDeg), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                            .onTapGesture {
                                withAnimation {
                                    selectedSampleIndex = sampleIndex
                                    let target = sampleCount * (repeatFactor / 2) + sampleIndex
                                    proxy.scrollTo(target, anchor: .center)
                                }
                            }
                        }
                        .frame(width: carouselItemWidth, height: 80)
                        .id(i)
                    }
                }
                .padding(.horizontal, (UIScreen.main.bounds.width - carouselItemWidth) / 2 - carouselItemSpacing)
                .padding(.vertical, 8)
            }
            .onAppear {
                if !initialScrollPerformed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        let target = initialIndex
                        proxy.scrollTo(target, anchor: .center)
                        initialScrollPerformed = true
                    }
                }
            }

            
        }
    }

    private func shouldShowJudgement() -> Bool {
        if let until = showJudgementUntil {
            return Date() <= until
        }
        return false
    }
    // Paste these functions into ContentView (methods area)

    func handleImportedFile(url: URL) {
        // DocumentPicker may give security-scoped url (sandbox). We attempt to copy it into Documents.
        DispatchQueue.global(qos: .userInitiated).async {
            var didStart = false
            if url.startAccessingSecurityScopedResource() {
                didStart = true
            }
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let destURL = SheetFileManager.documentsURL.appendingPathComponent(url.lastPathComponent)
            do {
                // If file exists, append a numeric suffix to avoid overwrite
                var finalDest = destURL
                var idx = 1
                while FileManager.default.fileExists(atPath: finalDest.path) {
                    let base = destURL.deletingPathExtension().lastPathComponent
                    let ext = destURL.pathExtension
                    let newName = "\(base)_\(idx).\(ext)"
                    finalDest = SheetFileManager.documentsURL.appendingPathComponent(newName)
                    idx += 1
                }

                // Copy selected file to app Documents folder
                try FileManager.default.copyItem(at: url, to: finalDest)
                print("Imported file copied to: \(finalDest.path)")

                // reload samples/UI on main thread
            } catch {
                DispatchQueue.main.async {
                    importErrorMessage = "Import failed: \(error.localizedDescription)"
                }
                print("Import copy failed: \(error)")
            }
        }
    }

    // MARK: - Playback (spawn/clear/delete を整理してスケジュール)
    private func startPlayback(in size: CGSize) {
        guard !isPlaying else { return }

        // Try to prepare audio URL based on the currently selected sample entry (bundled/saved/builtin)
        var audioURL: URL? = nil
        var sheetForOffset: Sheet? = nil

        if sampleEntries.indices.contains(selectedSampleIndex) {
            let entry = sampleEntries[selectedSampleIndex]

            // 1) Prefer a Sheet object attached to the SampleEntry (most reliable)
            if let sheet = entry.sheetObject {
                sheetForOffset = sheet
                if let audioName = sheet.audioFilename {
                    // try bundle first
                    audioURL = bundleURLForAudio(named: audioName)
                    // fallback to Documents (user-imported audio)
                    if audioURL == nil {
                        let docCandidate = SheetFileManager.documentsURL.appendingPathComponent(audioName)
                        if FileManager.default.fileExists(atPath: docCandidate.path) {
                            audioURL = docCandidate
                        }
                    }
                }
            }

            // 2) If no sheetObject, but entry has bundledFilename or is a bundle-display, try to locate corresponding bundled Sheet
            if audioURL == nil {
                let bundled = loadBundledSheets() // returns array of (String, Sheet) tuples or similar
                // Normalize display name by removing " (bundle)" suffix for title match
                let displayTitle = entry.name.hasSuffix(" (bundle)") ? entry.name.replacingOccurrences(of: " (bundle)", with: "") : entry.name

                // Try to find by title match first
                for pair in bundled {
                    let filename = pair.0
                    let sheet = pair.1
                    if sheet.title == displayTitle || filename == entry.bundledFilename || displayTitle.contains(filename) {
                        sheetForOffset = sheet
                        if let audioName = sheet.audioFilename {
                            audioURL = bundleURLForAudio(named: audioName)
                            if audioURL == nil {
                                // try documents fallback for audio file with same filename
                                let docCandidate = SheetFileManager.documentsURL.appendingPathComponent(audioName)
                                if FileManager.default.fileExists(atPath: docCandidate.path) {
                                    audioURL = docCandidate
                                }
                            }
                        }
                        break
                    }
                }
            }

            // 3) As a last resort, if entry name itself looks like an audio filename (unlikely), try that
            if audioURL == nil {
                // attempt to treat entry.name as audio filename (strip " (bundle)" suffix)
                let possibleName = entry.name.replacingOccurrences(of: " (bundle)", with: "")
                if let testURL = bundleURLForAudio(named: possibleName) {
                    audioURL = testURL
                } else {
                    let docCandidate = SheetFileManager.documentsURL.appendingPathComponent(possibleName)
                    if FileManager.default.fileExists(atPath: docCandidate.path) {
                        audioURL = docCandidate
                    }
                }
            }
        }

        // set up AVAudioSession and AVAudioPlayer if we have audio
        if let url = audioURL {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()

                // apply sheet.offset if available
                if let sheet = sheetForOffset, let offset = sheet.offset {
                    audioPlayer?.currentTime = max(0, offset)
                }

                audioPlayer?.play()
                currentlyPlayingAudioFilename = url.lastPathComponent
            } catch {
                print("Audio playback prepare failed: \(error)")
                audioPlayer = nil
                currentlyPlayingAudioFilename = nil
            }
        } else {
            currentlyPlayingAudioFilename = nil
        }

        // Now schedule notes as before
        isPlaying = true
        startDate = Date()
        activeNotes.removeAll()
        flickedNoteIDs.removeAll()

        // cancel previous scheduled
        scheduledWorkItems.forEach { $0.cancel() }
        scheduledWorkItems.removeAll()
        autoDeleteWorkItems.values.forEach { $0.cancel() }
        autoDeleteWorkItems.removeAll()

        for note in notesToPlay {
            let approachDistance = approachDistanceFraction * min(size.width, size.height)
            let approachDuration = approachDistance / max(approachSpeed, 1.0)
            let spawnTime = max(0.0, note.time - approachDuration)

            let target = CGPoint(x: note.normalizedPosition.x * size.width,
                                 y: note.normalizedPosition.y * size.height)
            let theta = CGFloat(note.angleDegrees) * .pi / 180.0
            let rodDir = CGPoint(x: cos(theta), y: sin(theta))
            // ここは一方向から進入（v12 の感触）
            let n1 = CGPoint(x: -rodDir.y, y: rodDir.x)
            let startPos = CGPoint(x: target.x - n1.x * approachDistance,
                                   y: target.y - n1.y * approachDistance)

            // spawn: ノートを追加してアニメーションで移動開始
            let spawnWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    let newID = UUID()
                    let new = ActiveNote(
                        id: newID,
                        angleDegrees: note.angleDegrees,
                        position: startPos,
                        targetPosition: target,
                        hitTime: note.time,
                        spawnTime: spawnTime,
                        isClear: false
                    )
                    self.activeNotes.append(new)

                    // アプローチ移動は withAnimation(.linear(duration:))
                    if let idx = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                        withAnimation(.linear(duration: approachDuration)) {
                            self.activeNotes[idx].position = target
                        }
                    }

                    // spawn 実行時に deleteWork を生成して id に紐付け、spawn から lifeDuration 後に実行する
                    let deleteWork = DispatchWorkItem {
                        DispatchQueue.main.async {
                            // Miss 判定: まだフリックされていなければ消す
                            if let idx2 = self.activeNotes.firstIndex(where: { $0.id == newID }) {
                                if self.flickedNoteIDs.contains(newID) {
                                    self.autoDeleteWorkItems[newID] = nil
                                    return
                                }
                                withAnimation(.easeIn(duration: 0.18)) {
                                    self.activeNotes.removeAll { $0.id == newID }
                                }
                                // Miss の振る舞い
                                self.combo = 0
                                self.autoDeleteWorkItems[newID] = nil
                                self.showJudgement(text: "MISS", color: .red)
                            }
                        }
                    }
                    // store and schedule deleteWork relative to now (spawn moment)
                    self.autoDeleteWorkItems[newID] = deleteWork
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.lifeDuration, execute: deleteWork)
                }
            }

            // clear: hitTime に鮮明表示にする
            let clearWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    if let idx = self.activeNotes.firstIndex(where: { $0.hitTime == note.time && $0.targetPosition == target }) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            self.activeNotes[idx].isClear = true
                        }
                    }
                }
            }

            // schedule
            scheduledWorkItems.append(spawnWork)
            scheduledWorkItems.append(clearWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + spawnTime, execute: spawnWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + note.time, execute: clearWork)
        }

        // 最後のノート後に isPlaying を false に戻す（余裕タイム）
        if let last = notesToPlay.map({ $0.time }).max() {
            let finishDelay = last + lifeDuration + 0.5
            let finishWork = DispatchWorkItem {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.scheduledWorkItems.removeAll()
                    // cancel any auto-delete
                    self.autoDeleteWorkItems.values.forEach { $0.cancel() }
                    self.autoDeleteWorkItems.removeAll()

                    // stop audio when finished
                    if audioPlayer?.isPlaying == true {
                        audioPlayer?.stop()
                    }
                    audioPlayer = nil
                    currentlyPlayingAudioFilename = nil
                }
            }
            scheduledWorkItems.append(finishWork)
            DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay, execute: finishWork)
        }
    }

    private func stopPlayback() {
        // stop audio
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil
        currentlyPlayingAudioFilename = nil

        // existing cleanup
        for w in scheduledWorkItems { w.cancel() }
        scheduledWorkItems.removeAll()
        autoDeleteWorkItems.values.forEach { $0.cancel() }
        autoDeleteWorkItems.removeAll()
        isPlaying = false
        startDate = nil
    }
    private func stopAudioIfPlaying() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil
        currentlyPlayingAudioFilename = nil
    }
    private func resetAll() {
        stopPlayback()
        withAnimation(.easeOut(duration: 0.15)) {
            activeNotes.removeAll()
        }
        score = 0
        combo = 0
        flickedNoteIDs.removeAll()
        lastJudgement = ""
        showJudgementUntil = nil
    }

    // MARK: - フリック処理（v12 の見た目に近づける）
    private func handleFlick(for id: UUID, dragValue: DragGesture.Value, in size: CGSize) {
        // 既にフリック済みなら無視
        if flickedNoteIDs.contains(id) { return }

        let predicted = dragValue.predictedEndTranslation
        let flickVec = CGPoint(x: predicted.width, y: predicted.height)
        let flickSpeed = hypot(flickVec.x, flickVec.y)
        guard flickSpeed > speedThreshold else { return }

        guard let idx = activeNotes.firstIndex(where: { $0.id == id }) else { return }
        let note = activeNotes[idx]

        // 棒の向きから法線を作り、どっち側に飛ばすか判断
        let theta = CGFloat(note.angleDegrees) * .pi / 180.0
        let rodDir = CGPoint(x: cos(theta), y: sin(theta))
        let n1 = CGPoint(x: -rodDir.y, y: rodDir.x)
        let n2 = CGPoint(x: rodDir.y, y: -rodDir.x)
        let dot1 = n1.x * flickVec.x + n1.y * flickVec.y
        let dot2 = n2.x * flickVec.x + n2.y * flickVec.y
        let chosenNormal: CGPoint = (dot1 >= dot2) ? n1 : n2

        // 飛ばすターゲット（画面外へ）
        let distance = max(size.width, size.height) * 1.5
        let target = CGPoint(x: note.position.x + chosenNormal.x * distance,
                             y: note.position.y + chosenNormal.y * distance)

        // cancel auto-delete for this note
        if let work = autoDeleteWorkItems[id] {
            work.cancel()
            autoDeleteWorkItems[id] = nil
        }

        // mark flicked (prevent double)
        flickedNoteIDs.insert(id)

        // 判定（経過時間 vs hitTime）
        let elapsed = startDate.map { Date().timeIntervalSince($0) } ?? 0.0
        let dt = elapsed - note.hitTime

        var judgementText = "OK"
        var judgementColor: Color = .white
        if abs(dt) <= perfectWindow {
            judgementText = "PERFECT"; judgementColor = .green
        } else if (dt >= -goodWindowBefore && dt < -perfectWindow) || (dt > perfectWindow && dt <= goodWindowAfter) {
            judgementText = "GOOD"; judgementColor = .blue
        } else {
            judgementText = "OK"; judgementColor = .white
        }

        // スコア/コンボ
        score += 1
        combo += 1
        showJudgement(text: judgementText, color: judgementColor)

        // フリック後の飛翔は v12 っぽく easing で飛ばす
        let flyDuration: Double = 0.6
        withAnimation(.easeOut(duration: flyDuration)) {
            if let idx2 = activeNotes.firstIndex(where: { $0.id == id }) {
                activeNotes[idx2].position = target
            }
        }

        // 飛び切ったら削除
        DispatchQueue.main.asyncAfter(deadline: .now() + flyDuration + 0.05) {
            withAnimation(.easeIn(duration: 0.12)) {
                self.activeNotes.removeAll { $0.id == id }
            }
            // optional cleanup
            self.flickedNoteIDs.remove(id)
        }
    }

    // グローバルフリック: 開始位置に最も近いノーツが hitRadius 内なら処理
    private func handleGlobalFlick(dragValue: DragGesture.Value, in size: CGSize) {
        let predicted = dragValue.predictedEndTranslation
        let flickVec = CGPoint(x: predicted.width, y: predicted.height)
        let flickSpeed = hypot(flickVec.x, flickVec.y)
        guard flickSpeed > speedThreshold else { return }

        let start = dragValue.startLocation

        var closestId: UUID?
        var closestDist = CGFloat.greatestFiniteMagnitude
        for n in activeNotes {
            let d = hypot(n.position.x - start.x, n.position.y - start.y)
            if d < closestDist {
                closestDist = d
                closestId = n.id
            }
        }

        if let id = closestId, closestDist <= hitRadius {
            handleFlick(for: id, dragValue: dragValue, in: size)
        }
    }

    // 判定を一時表示
    private func showJudgement(text: String, color: Color) {
        lastJudgement = text
        lastJudgementColor = color
        showJudgementUntil = Date().addingTimeInterval(0.8)
    }
}

struct RodView: View {
    let angleDegrees: Double

    var body: some View {
        Rectangle()
            .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color.gray]),
                                 startPoint: .leading, endPoint: .trailing))
            .cornerRadius(5)
            .shadow(color: Color.white.opacity(0.2), radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(angleDegrees))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
