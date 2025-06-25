import Foundation
import SwiftUI

struct Note: Identifiable, Codable {
    let id: String  // AppleScript'ten gelen ID
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var folder: String
    
    init(id: String, title: String, content: String, createdAt: Date, modifiedAt: Date, folder: String = "Notes") {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.folder = folder
    }
}

class NotesController: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var selectedNote: Note?
    @Published var showingNewNoteSheet = false
    @Published var newNoteTitle = ""
    @Published var newNoteContent = ""
    @Published var errorMessage: String?
    
    // Performance optimization - cache last load time
    private var lastLoadTime: Date?
    private let cacheValidDuration: TimeInterval = 30 // 30 seconds cache
    
    init() {
        loadRealNotes()
    }
    
    // MARK: - AppleScript Integration
    private func executeAppleScript(_ script: String) -> String? {
        guard let scriptObject = NSAppleScript(source: script) else {
            return nil
        }
        
        var error: NSDictionary?
        let result = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ AppleScript Error: \(error)")
            return nil
        }
        
        return result.stringValue
    }
    
    // MARK: - Real Notes Operations
    func loadRealNotes() {
        // Performance optimization - check cache validity
        if let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheValidDuration,
           !notes.isEmpty {
            print("📝 Using cached notes (loaded \(Int(Date().timeIntervalSince(lastLoad))) seconds ago)")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // AppleScript ile Notes uygulamasından notları al (error-safe format)
        let script = """
        tell application "Notes"
            set notesList to ""
            set noteCount to count of notes
            if noteCount > 0 then
                repeat with i from 1 to noteCount
                    try
                        set currentNote to note i
                        set noteId to id of currentNote as string
                        set noteName to name of currentNote
                        set noteBody to body of currentNote
                        set noteCreationDate to creation date of currentNote
                        set noteModificationDate to modification date of currentNote
                        
                        -- Folder bilgisini güvenli şekilde al
                        try
                            set noteFolder to name of folder of currentNote
                        on error
                            set noteFolder to "Notes"
                        end try
                        
                        -- Özel karakterleri temizle
                        set noteName to my replaceText(noteName, "~~", "-")
                        set noteBody to my replaceText(noteBody, "~~", "-")
                        set noteFolder to my replaceText(noteFolder, "~~", "-")
                        
                        -- Basit ayırıcı format kullan
                        set noteData to noteId & "~~TITLE~~" & noteName & "~~CONTENT~~" & noteBody & "~~CREATED~~" & (noteCreationDate as string) & "~~MODIFIED~~" & (noteModificationDate as string) & "~~FOLDER~~" & noteFolder
                        
                        if i = 1 then
                            set notesList to noteData
                        else
                            set notesList to notesList & "~~~NOTEEND~~~" & noteData
                        end if
                    on error errorMsg
                        -- Bu notu atla, diğerleriyle devam et
                        log "Skipping note " & i & ": " & errorMsg
                    end try
                end repeat
            end if
            return notesList
        end tell
        
        -- Helper function to replace text
        on replaceText(sourceText, findText, replaceText)
            set AppleScript's text item delimiters to findText
            set textItems to text items of sourceText
            set AppleScript's text item delimiters to replaceText
            set newText to textItems as string
            set AppleScript's text item delimiters to ""
            return newText
        end replaceText
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let result = self.executeAppleScript(script) {
                self.parseNotesResult(result)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Notes uygulamasına erişim sağlanamadı"
                    self.isLoading = false
                    self.createFallbackNotes()
                }
            }
        }
    }
    
    private func parseNotesResult(_ result: String) {
        guard !result.isEmpty else {
            DispatchQueue.main.async {
                self.notes = []
                self.isLoading = false
            }
            return
        }
        
        let noteStrings = result.components(separatedBy: "~~~NOTEEND~~~")
        var parsedNotes: [Note] = []
        
        for noteString in noteStrings {
            if let note = parseNoteString(noteString) {
                parsedNotes.append(note)
            }
        }
        
        DispatchQueue.main.async {
            self.notes = parsedNotes.sorted { $0.modifiedAt > $1.modifiedAt }
            self.isLoading = false
            self.lastLoadTime = Date() // Update cache time
            print("📝 Loaded \(self.notes.count) real notes from Notes app")
        }
    }
    
    private func parseNoteString(_ noteString: String) -> Note? {
        // Basit separator parsing (AppleScript'ten gelen veri için)
        let components = noteString.components(separatedBy: "~~")
        
        // Format: id~~TITLE~~title~~CONTENT~~content~~CREATED~~date~~MODIFIED~~date~~FOLDER~~folder
        guard components.count >= 11,
              components[1] == "TITLE",
              components[3] == "CONTENT",
              components[5] == "CREATED",
              components[7] == "MODIFIED",
              components[9] == "FOLDER" else {
            print("❌ Invalid note format: \(components.count) components")
            return nil
        }
        
        let id = components[0]
        let title = components[2]
        let content = components[4]
        let createdString = components[6]
        let modifiedString = components[8]
        let folder = components[10]
        
        // macOS date string'ini Date'e çevir
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Apple date format için
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
        
        // Alternatif format dene
        let altFormatter = DateFormatter()
        altFormatter.locale = Locale(identifier: "en_US_POSIX")
        altFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        
        let createdDate = dateFormatter.date(from: createdString) ?? 
                          altFormatter.date(from: createdString) ?? 
                          Date()
        let modifiedDate = dateFormatter.date(from: modifiedString) ?? 
                           altFormatter.date(from: modifiedString) ?? 
                           Date()
        
        return Note(
            id: id,
            title: title.isEmpty ? "Başlıksız Not" : title,
            content: content,
            createdAt: createdDate,
            modifiedAt: modifiedDate,
            folder: folder
        )
    }
    
    // MARK: - Note Management
    func createNoteInNotesApp(title: String, content: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else {
            return
        }
        
        let finalTitle = trimmedTitle.isEmpty ? "Başlıksız Not" : trimmedTitle
        let finalContent = trimmedContent.isEmpty ? "" : trimmedContent
        
        let script = """
        tell application "Notes"
            set newNote to make new note with properties {name:"\(finalTitle)", body:"\(finalContent)"}
            return id of newNote as string
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let _ = self.executeAppleScript(script) {
                DispatchQueue.main.async {
                    print("✅ Created new note in Notes app: \(finalTitle)")
                    // Notları yeniden yükle
                    self.loadRealNotes()
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Not oluşturulamadı"
                }
            }
        }
    }
    
    func deleteNoteFromNotesApp(_ note: Note) {
        let script = """
        tell application "Notes"
            delete note id "\(note.id)"
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let _ = self.executeAppleScript(script) {
                DispatchQueue.main.async {
                    print("🗑️ Deleted note from Notes app: \(note.title)")
                    // Notları yeniden yükle
                    self.loadRealNotes()
                    
                    if self.selectedNote?.id == note.id {
                        self.selectedNote = nil
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Not silinemedi"
                }
            }
        }
    }
    
    // Backward compatibility için eski fonksiyon adı
    func deleteNote(_ note: Note) {
        deleteNoteFromNotesApp(note)
    }
    
    func updateNoteInNotesApp(_ note: Note, title: String, content: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let finalTitle = trimmedTitle.isEmpty ? "Başlıksız Not" : trimmedTitle
        let finalContent = trimmedContent.isEmpty ? "" : trimmedContent
        
        // AppleScript'te özel karakterleri escape et
        let escapedTitle = finalTitle.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedContent = finalContent.replacingOccurrences(of: "\"", with: "\\\"")
        
        let script = """
        tell application "Notes"
            set targetNote to note id "\(note.id)"
            set name of targetNote to "\(escapedTitle)"
            set body of targetNote to "\(escapedContent)"
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let _ = self.executeAppleScript(script) {
                DispatchQueue.main.async {
                    print("📝 Updated note in Notes app: \(finalTitle)")
                    // Notları yeniden yükle
                    self.loadRealNotes()
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Not güncellenemedi"
                }
            }
        }
    }
    
    // Backward compatibility için eski fonksiyon adı
    func updateNote(_ note: Note, title: String, content: String) {
        updateNoteInNotesApp(note, title: title, content: content)
    }
    
    // MARK: - Search & Filter
    func searchNotes(query: String) -> [Note] {
        guard !query.isEmpty else { return notes }
        
        let lowercaseQuery = query.lowercased()
        return notes.filter { note in
            note.title.lowercased().contains(lowercaseQuery) ||
            note.content.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Utility
    private func createFallbackNotes() {
        // Eğer Notes uygulamasına erişim yoksa fallback notlar göster
        let fallbackNotes = [
            Note(
                id: "fallback-1",
                title: "Notes Uygulamasına Erişim Gerekli",
                content: "Gerçek notlarınızı görmek için Notes uygulamasına erişim izni vermeniz gerekiyor. Sistem Tercihleri > Güvenlik ve Gizlilik > Gizlilik > Otomasyon bölümünden NotchApp'e Notes erişimi verin.",
                createdAt: Date(),
                modifiedAt: Date(),
                folder: "System"
            )
        ]
        
        notes = fallbackNotes
    }
    
    func openNotesApp() {
        // macOS Notes uygulamasını aç
        let script = """
        tell application "Notes"
            activate
        end tell
        """
        
        if let _ = executeAppleScript(script) {
            print("📱 Opening Notes app")
        } else {
            // Alternatif yöntem (modern API)
            if let notesURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
                NSWorkspace.shared.openApplication(at: notesURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            }
        }
    }
    
    func refreshNotes() {
        // Force refresh by clearing cache
        lastLoadTime = nil
        loadRealNotes()
    }
    
    // MARK: - New Note Sheet
    func showNewNoteSheet() {
        newNoteTitle = ""
        newNoteContent = ""
        showingNewNoteSheet = true
    }
    
    func hideNewNoteSheet() {
        showingNewNoteSheet = false
        newNoteTitle = ""
        newNoteContent = ""
    }
    
    func saveNewNote() {
        createNoteInNotesApp(title: newNoteTitle, content: newNoteContent)
        hideNewNoteSheet()
    }
    
    // MARK: - Formatted Dates
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Bugün \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "Dün \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "dd/MM/yyyy"
            return formatter.string(from: date)
        }
    }
} 