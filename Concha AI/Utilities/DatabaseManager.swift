//
//  DatabaseManager.swift
//  Concha AI
//
//  SQLite database setup and queries for memories
//

import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbName = "memories.sqlite"
    
    private init() {
        openDatabase()
        createTables()
        logTableCounts()
    }
    
    private func logTableCounts() {
        var statement: OpaquePointer?
        
        // Count chats
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM chats;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                print("📊 Current chat count in database: \(count)")
            }
        }
        sqlite3_finalize(statement)
        
        // Count messages
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM messages;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                print("📊 Current message count in database: \(count)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Setup
    
    private func openDatabase() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not find documents directory")
            return
        }
        
        let dbURL = documentsURL.appendingPathComponent(dbName)
        print("📂 Database location: \(dbURL.path)")
        
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            print("✅ Database opened successfully")
        } else {
            print("❌ Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    private func createTables() {
        print("🏗️ Creating database tables...")
        
        let createMemoriesTable = """
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                text TEXT NOT NULL,
                embedding BLOB NOT NULL,
                created_at REAL NOT NULL
            );
        """
        
        let createChatsTable = """
            CREATE TABLE IF NOT EXISTS chats (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                model_id TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
        """
        
        let createMessagesTable = """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                chat_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp REAL NOT NULL,
                FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE
            );
        """
        
        var statement: OpaquePointer?
        
        // Create memories table
        if sqlite3_prepare_v2(db, createMemoriesTable, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Memories table created/verified")
            } else {
                print("❌ Error creating memories table: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(statement)
        
        // Create chats table
        if sqlite3_prepare_v2(db, createChatsTable, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Chats table created/verified")
            } else {
                print("❌ Error creating chats table: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(statement)
        
        // Create messages table
        if sqlite3_prepare_v2(db, createMessagesTable, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Messages table created/verified")
            } else {
                print("❌ Error creating messages table: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Memory Operations
    
    func insertMemory(_ memory: Memory) -> Bool {
        let insertSQL = "INSERT INTO memories (id, text, embedding, created_at) VALUES (?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing insert: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_text(statement, 1, (memory.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (memory.text as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        // Convert embedding array to data
        let embeddingData = memory.embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        _ = embeddingData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(embeddingData.count), nil)
        }
        
        sqlite3_bind_double(statement, 4, memory.createdAt.timeIntervalSince1970)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            print("Error inserting memory: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        return true
    }
    
    func getAllMemories() -> [Memory] {
        var memories: [Memory] = []
        let querySQL = "SELECT id, text, embedding, created_at FROM memories ORDER BY created_at DESC;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing query: \(String(cString: sqlite3_errmsg(db)))")
            return memories
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idCString = sqlite3_column_text(statement, 0),
                  let textCString = sqlite3_column_text(statement, 1),
                  let id = UUID(uuidString: String(cString: idCString)) else {
                continue
            }
            
            let text = String(cString: textCString)
            
            // Get embedding blob
            var embedding: [Float] = []
            if let blob = sqlite3_column_blob(statement, 2) {
                let blobSize = sqlite3_column_bytes(statement, 2)
                let floatCount = Int(blobSize) / MemoryLayout<Float>.size
                let floatPtr = blob.assumingMemoryBound(to: Float.self)
                embedding = Array(UnsafeBufferPointer(start: floatPtr, count: floatCount))
            }
            
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            
            let memory = Memory(id: id, text: text, embedding: embedding, createdAt: createdAt)
            memories.append(memory)
        }
        
        return memories
    }
    
    func deleteMemory(id: UUID) -> Bool {
        let deleteSQL = "DELETE FROM memories WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func deleteAllMemories() -> Bool {
        let deleteSQL = "DELETE FROM memories;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func getMemoryCount() -> Int {
        let countSQL = "SELECT COUNT(*) FROM memories;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        
        return 0
    }
    
    // MARK: - Database Maintenance
    
    func clearAllChats() {
        var statement: OpaquePointer?
        
        // Delete all messages first (due to foreign key)
        if sqlite3_prepare_v2(db, "DELETE FROM messages;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("🗑️ Cleared all messages")
            }
        }
        sqlite3_finalize(statement)
        
        // Delete all chats
        if sqlite3_prepare_v2(db, "DELETE FROM chats;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("🗑️ Cleared all chats")
            }
        }
        sqlite3_finalize(statement)
        
        logTableCounts()
    }
    
    // MARK: - Chat Operations
    
    func insertChat(_ chat: Chat) -> Bool {
        let insertSQL = "INSERT INTO chats (id, title, model_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare insert chat statement: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Use SQLITE_TRANSIENT to force SQLite to make a copy of the strings immediately
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_text(statement, 1, (chat.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (chat.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (chat.modelId as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 4, chat.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 5, chat.updatedAt.timeIntervalSince1970)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        if result {
            print("✅ Inserted chat: \(chat.title) [\(chat.id)]")
        } else {
            print("❌ Failed to insert chat: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
    
    func getAllChats() -> [Chat] {
        var chats: [Chat] = []
        let querySQL = "SELECT id, title, model_id, created_at, updated_at FROM chats ORDER BY updated_at DESC;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare getAllChats query: \(String(cString: sqlite3_errmsg(db)))")
            return chats
        }
        
        defer { sqlite3_finalize(statement) }
        
        var rowCount = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            rowCount += 1
            
            // Debug each column individually
            let idCString = sqlite3_column_text(statement, 0)
            let titleCString = sqlite3_column_text(statement, 1)
            let modelIdCString = sqlite3_column_text(statement, 2)
            let createdAtDouble = sqlite3_column_double(statement, 3)
            let updatedAtDouble = sqlite3_column_double(statement, 4)
            
            print("📋 Row \(rowCount) raw data:")
            print("   - ID: \(idCString != nil ? String(cString: idCString!) : "NULL")")
            print("   - Title: \(titleCString != nil ? String(cString: titleCString!) : "NULL")")
            print("   - ModelId: \(modelIdCString != nil ? String(cString: modelIdCString!) : "NULL")")
            print("   - CreatedAt: \(createdAtDouble)")
            print("   - UpdatedAt: \(updatedAtDouble)")
            
            guard let idCString = idCString,
                  let titleCString = titleCString,
                  let modelIdCString = modelIdCString else {
                print("⚠️ Failed to parse chat row - NULL column detected")
                continue
            }
            
            let idString = String(cString: idCString)
            guard let id = UUID(uuidString: idString) else {
                print("⚠️ Failed to parse UUID from: '\(idString)'")
                continue
            }
            
            let title = String(cString: titleCString)
            let modelId = String(cString: modelIdCString)
            let createdAt = Date(timeIntervalSince1970: createdAtDouble)
            let updatedAt = Date(timeIntervalSince1970: updatedAtDouble)
            
            // Get messages for this chat
            let messages = getMessages(forChatId: id)
            
            let chat = Chat(id: id, title: title, modelId: modelId, messages: messages, createdAt: createdAt, updatedAt: updatedAt)
            chats.append(chat)
            print("✅ Loaded chat '\(title)' with \(messages.count) messages")
        }
        
        print("📊 Database query returned \(rowCount) chat rows, loaded \(chats.count) chats")
        
        return chats
    }
    
    func updateChat(_ chat: Chat) -> Bool {
        let updateSQL = "UPDATE chats SET title = ?, updated_at = ? WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_text(statement, 1, (chat.title as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, chat.updatedAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, (chat.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    func deleteChat(id: UUID) -> Bool {
        // Delete messages first (handled by CASCADE)
        let deleteSQL = "DELETE FROM chats WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        return sqlite3_step(statement) == SQLITE_DONE
    }
    
    // MARK: - Message Operations
    
    func insertMessage(_ message: Message, chatId: UUID) -> Bool {
        let insertSQL = "INSERT INTO messages (id, chat_id, role, content, timestamp) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare insert message statement: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        sqlite3_bind_text(statement, 1, (message.id.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (chatId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (message.role.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, (message.content as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 5, message.timestamp.timeIntervalSince1970)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        if result {
            print("💾 Saved message: [\(message.role)] \(message.content.prefix(50))... to chat \(chatId)")
        } else {
            print("❌ Failed to insert message: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
    
    func getMessages(forChatId chatId: UUID) -> [Message] {
        var messages: [Message] = []
        let querySQL = "SELECT id, role, content, timestamp FROM messages WHERE chat_id = ? ORDER BY timestamp ASC;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return messages
        }
        
        defer { sqlite3_finalize(statement) }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, (chatId.uuidString as NSString).utf8String, -1, SQLITE_TRANSIENT)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idCString = sqlite3_column_text(statement, 0),
                  let roleCString = sqlite3_column_text(statement, 1),
                  let contentCString = sqlite3_column_text(statement, 2),
                  let id = UUID(uuidString: String(cString: idCString)),
                  let role = Message.Role(rawValue: String(cString: roleCString)) else {
                continue
            }
            
            let content = String(cString: contentCString)
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            
            let message = Message(id: id, role: role, content: content, timestamp: timestamp)
            messages.append(message)
        }
        
        return messages
    }
}

