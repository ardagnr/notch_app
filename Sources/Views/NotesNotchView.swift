import SwiftUI

struct NotesNotchView: View {
    @ObservedObject var notesController: NotesController
    @State private var searchText = ""
    @State private var selectedNote: Note?
    @State private var editingNote: Note?
    @State private var editTitle = ""
    @State private var editContent = ""
    var onMenuSelection: ((NotchMenuOption) -> Void)?
    
    private var filteredNotes: [Note] {
        notesController.searchNotes(query: searchText)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top menu bar
            HStack(spacing: 12) {
                // Current notch indicator
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text("Notlar")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
                
                Spacer()
                
                // Menu buttons
                HStack(spacing: 8) {
                    // Gemini button
                    Button(action: { onMenuSelection?(.gemini) }) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                            .font(.caption)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Gemini AI")
                    
                    // Timer button
                    Button(action: { onMenuSelection?(.timer) }) {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Sayaç")
                    
                    // Refresh notes button
                    Button(action: notesController.refreshNotes) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Notları Yenile")
                    
                    // Open Notes app button
                    Button(action: notesController.openNotesApp) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Notlar Uygulamasında Aç")
                    
                    // Add new note button
                    Button(action: notesController.showNewNoteSheet) {
                        Image(systemName: "plus")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Yeni Not")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))
            
            if let note = selectedNote {
                // Note detail view
                noteDetailView(note: note)
            } else {
                // Notes list view
                notesListView
            }
        }
        .frame(width: 380, height: 380)
        .sheet(isPresented: $notesController.showingNewNoteSheet) {
            newNoteSheet
        }
    }
    
    private var notesListView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                
                TextField("Notlarda ara...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .font(.subheadline)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Error message
            if let errorMessage = notesController.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                    
                    Text("Hata")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    
                    Button("Tekrar Dene") {
                        notesController.refreshNotes()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.6))
                    )
                    .foregroundColor(.white)
                    .font(.subheadline.weight(.medium))
                }
                .padding(.top, 20)
            }
            // Notes list
            else if notesController.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Gerçek notlar yükleniyor...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: searchText.isEmpty ? "note" : "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(searchText.isEmpty ? "Henüz not yok" : "Not bulunamadı")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if searchText.isEmpty {
                        Text("İlk notunuzu oluşturmak için + düğmesine basın")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredNotes) { note in
                            NoteRowView(
                                note: note,
                                onTap: { selectedNote = note },
                                onDelete: { notesController.deleteNoteFromNotesApp(note) },
                                formattedDate: notesController.formattedDate(note.modifiedAt)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    private func noteDetailView(note: Note) -> some View {
        VStack(spacing: 0) {
            // Detail header
            HStack {
                Button(action: { selectedNote = nil }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.body)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Not Detayı")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { startEditing(note: note) }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        notesController.deleteNote(note)
                        selectedNote = nil
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.1))
            
            // Note content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(note.title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Date
                    Text(notesController.formattedDate(note.modifiedAt))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Content
                    if !note.content.isEmpty {
                        Text(note.content)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Bu not boş")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .sheet(item: $editingNote) { note in
            editNoteSheet(note: note)
        }
    }
    
    private var newNoteSheet: some View {
        VStack(spacing: 16) {
            Text("Yeni Not")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("Not başlığı", text: $notesController.newNoteTitle)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("İçerik")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                TextEditor(text: $notesController.newNoteContent)
                    .font(.body)
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .frame(height: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack(spacing: 12) {
                Button("İptal") {
                    notesController.hideNewNoteSheet()
                }
                .foregroundColor(.white.opacity(0.7))
                
                Button("Kaydet") {
                    notesController.saveNewNote()
                }
                .foregroundColor(.blue)
                .disabled(notesController.newNoteTitle.isEmpty && notesController.newNoteContent.isEmpty)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
        .frame(width: 300, height: 280)
    }
    
    private func editNoteSheet(note: Note) -> some View {
        VStack(spacing: 16) {
            Text("Notu Düzenle")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("Not başlığı", text: $editTitle)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("İçerik")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                TextEditor(text: $editContent)
                    .font(.body)
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .frame(height: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack(spacing: 12) {
                Button("İptal") {
                    editingNote = nil
                }
                .foregroundColor(.white.opacity(0.7))
                
                Button("Kaydet") {
                    notesController.updateNote(note, title: editTitle, content: editContent)
                    selectedNote = nil // Close detail view to refresh
                    editingNote = nil
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
        .frame(width: 300, height: 280)
        .onAppear {
            editTitle = note.title
            editContent = note.content
        }
    }
    
    private func startEditing(note: Note) {
        editTitle = note.title
        editContent = note.content
        editingNote = note
    }
}

struct NoteRowView: View {
    let note: Note
    let onTap: () -> Void
    let onDelete: () -> Void
    let formattedDate: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !note.content.isEmpty {
                        Text(note.content)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover(perform: { hovering in
            isHovered = hovering
        })
    }
}

#Preview {
    NotesNotchView(notesController: NotesController())
} 