import SwiftUI
import UniformTypeIdentifiers



class EZIO { 
    
    private init() {}
    
    //    root local
    public static func documents(fileName: String = "") -> URL {
        var doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if fileName != "" { doc = doc.appendingPathComponent(fileName) }
        return doc
    }
    
    //    String <-> URL
    @discardableResult
    public static func saveStringToURL(string: String, url: URL, encoding: String.Encoding = .utf8) -> Bool {
        do {
            try string.write(to: url, atomically: true, encoding: encoding)
            return true
        } catch {
            print("failed writing string to file")
            return false
        }
    }
    public static func getStringFromURL(url: URL, encoding: String.Encoding = .utf8) -> String? { 
        do {
            return try String(contentsOf: url, encoding: encoding)
        } catch {
            print("failed getting string from file")
            return nil
        }
    }
    
    //    Data <-> URL
    @discardableResult
    public static func saveDataToURL(data: Data, url: URL) -> Bool {
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            print("failed writing data to file")
            return false
        }
    }
    public static func getDataFromURL(url: URL) -> Data? { 
        do {
            return try Data(contentsOf: url)
        } catch {
            print("failed getting data from file")
            return nil
        }
    }
    
    //    Codable <-> URL
    @discardableResult
    public static func saveCodableToURL<T: Encodable>(obj: T, url: URL, pretty: Bool = false) -> Bool {
        do {
            let encoder = JSONEncoder()
            if pretty { encoder.outputFormatting = .prettyPrinted }
            let data = try encoder.encode(obj)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            print("failed writing codable to file")
            return false
        }
    }
    public static func getCodableFromURL<T: Decodable>(url: URL, type: T.Type) -> T? { 
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("failed getting codable from file")
            return nil
        }
    }
    
    //    Codable <-> Data
    public static func transformCodableToData<T: Encodable>(obj: T, pretty: Bool = false) -> Data? {
        do {
            let encoder = JSONEncoder()
            if pretty { encoder.outputFormatting = .prettyPrinted }
            return try encoder.encode(obj)
        } catch {
            print("failed transforming codable to data")
            return nil
        }
    }
    public static func transformDataToCodable<T: Decodable>(data: Data, type: T.Type) -> T? {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("failed transforming data to codable")
            return nil
        }
    }
    
    //    URL <-> bookmark Data (assume security access)
    public static func makeBookmark(url: URL) -> Data? { 
        do {
            return try url.bookmarkData(
                options: .minimalBookmark, 
                includingResourceValuesForKeys: nil, 
                relativeTo: nil)
        } catch {
            print("failed making bookmark")
            return nil
        }
    }
    public static func loadBookmark(data: Data) -> (url: URL?, stale: Bool)  {
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
            return (url: url, stale: stale)
        } catch {
            print("failed loading url from bookmark data")
            return (url: nil, stale: false)
        }
    }
    
    //    Data <-> UserDefaults
    public static func saveDataToUserDefault(data: Data, key: String) {
        UserDefaults.standard.set(data, forKey: key)
    }
    public static func getDataFromUserDefault(key: String) -> Data? { 
        UserDefaults.standard.data(forKey: key)
    }
    
    //    URL <-> UserDefaults (bookmark convenience)
    @discardableResult
    public static func saveURLToUserDefaults(url: URL, key: String) -> Bool {
        guard let bmData = EZIO.makeBookmark(url: url) else { return false }
        EZIO.saveDataToUserDefault(data: bmData, key: key) 
        return true
    }
    public static func getURLFromUserDefaults(key: String) -> (url: URL?, stale: Bool) {
        guard let bmData = EZIO.getDataFromUserDefault(key: key) else { return (nil, false) }
        return EZIO.loadBookmark(data: bmData)
    }
    
    //    security access
    public static func accessSecure(url: URL, action: () -> (), failedAccess: (() -> ())? = nil ) {
        guard url.startAccessingSecurityScopedResource() else { failedAccess?(); return }
        action()
        url.stopAccessingSecurityScopedResource()
    }
    
//    url info/actions
    public static func exists(url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    @discardableResult
    public static func delete(url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("failed deleting")
            return false
        }
    }
    public static func byteSize(url: URL) -> Int64 { 
        guard let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
        else { print("couldn't get attributes"); return -1 }
        guard let bytes = attr[.size] as? Int64 
        else { print("no size???"); return -1 }
        return bytes
    }
    public static func isFolder(url: URL) -> Bool { 
        do {
            let rValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            return rValues.isDirectory ?? false
        } catch {
            return false
        }
    }
    
}



//============================================================
//============================================================
//============================================================

    

public struct EZIOLoadButton: View {
    
    private let title: LocalizedStringKey
    private let bookmarkKey: String
    private let allowedTypes: [UTType]
    private let action: (URL) -> ()
    
    init(
        _ title: LocalizedStringKey, 
        bookmarkKey: String = "", 
        types: [UTType] = [.folder], 
        action: @escaping (URL) -> ()
    ) {
        self.title = title
        self.bookmarkKey = bookmarkKey
        self.allowedTypes = types
        self.action = action
    }
    
    @State private var showSheet = false
    
    public var body: some View {
        Button(title, action: clicked)
            .fileImporter(
                isPresented: $showSheet, 
                allowedContentTypes: allowedTypes,
                onCompletion: handleSheet)
    }
    
    private func clicked() {
        if bookmarkKey == "" {
            showSheet = true
        } else {
            let result = EZIO.getURLFromUserDefaults(key: bookmarkKey)
            if let url = result.url {
                callAction(url: url, storeBookmark: result.stale)
            } else {
                showSheet = true
            }
        }
    }
    
    private func handleSheet(result: Result<URL, Error>) {
        switch result {
        case .success(let url): callAction(url: url, storeBookmark: true)
        case .failure(let error): print("error: \(error)")
        }
    }
    
    private func callAction(url: URL, storeBookmark: Bool) {
        EZIO.accessSecure(url: url) { 
            action(url) 
            if (bookmarkKey != "") && storeBookmark {
                let success = EZIO.saveURLToUserDefaults(url: url, key: bookmarkKey)
                if !success { print("**** failed saving bookmark") }
            }
        }
    }
    
}


//============================================================


public struct EZIOSaveButton: View {
    
    private let title: LocalizedStringKey
    private let defaultFilename: String
    private let bookmarkKey: String
    private let docType: UTType
    private let action: (URL) -> ()
    
    init(
        _ title: LocalizedStringKey,
        defaultFilename: String,
        bookmarkKey: String = "", 
        type: UTType = .item, 
        action: @escaping (URL) -> ()
    ) {
        self.title = title
        self.defaultFilename = defaultFilename
        self.bookmarkKey = bookmarkKey
        self.docType = type
        self.action = action
    }
    
    @State private var showSheet = false
    private let doc = EZExporterDoc()
    
    public var body: some View {
        Button(title, action: clicked)
            .fileExporter(
                isPresented: $showSheet, 
                document: doc, 
                contentType: docType, 
                defaultFilename: defaultFilename,
                onCompletion: handleSheet)
    }
    
    private func clicked() {
        doc.prepForWriting(forType: docType)
        showSheet = true
    }
    
    private func handleSheet(result: Result<URL, Error>) {
        switch result {
        case .success(let url): callAction(url: url)
        case .failure(let error): print("error: \(error)")
        }
    }
    
    private func callAction(url: URL) {
        EZIO.accessSecure(url: url) { 
            action(url) 
            if (bookmarkKey != "") {
                let success = EZIO.saveURLToUserDefaults(url: url, key: bookmarkKey)
                if !success { print("**** failed saving bookmark") }
            }
        }
    }
    
    private struct EZExporterDoc: FileDocument {
        static var readableContentTypes = [UTType.item]
        init() {}
        init(configuration: ReadConfiguration) throws {}
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            if EZExporterDoc.readableContentTypes == [.folder] {
                return FileWrapper(directoryWithFileWrappers: [:])
            } else {
                return FileWrapper(regularFileWithContents: Data())
            }
        }
        func prepForWriting(forType: UTType) {
            EZExporterDoc.readableContentTypes = [forType]
        }
    }
    
}



//============================================================
//============================================================
//============================================================



class EZIOPasteboard {
    
    public static var hasText: Bool { UIPasteboard.general.hasStrings }
    public static var hasImage: Bool { UIPasteboard.general.hasImages }
    public static var hasColor: Bool { UIPasteboard.general.hasColors }
    public static var hasURL: Bool { UIPasteboard.general.hasURLs }
    
    public static var eztext: String { text ?? "" }
    public static var text: String? {
        get { UIPasteboard.general.string ?? nil }
        set { UIPasteboard.general.string = newValue }
    }
    public static var uiimage: UIImage? {
        get { UIPasteboard.general.image ?? nil }
        set { UIPasteboard.general.image = newValue }
    }
    public static var cgimage: CGImage? {
        get { 
            guard let uiimg = UIPasteboard.general.image else { return nil }
            return uiimg.cgImage
        }
        set {
            guard let cgimg = newValue else { return }
            UIPasteboard.general.image = UIImage(cgImage: cgimg)
        }
    }
    public static var image: Image? {
        get {
            guard let uiimg = UIPasteboard.general.image else { return nil }
            return Image(uiImage: uiimg)
        }
        //set { ? }
        //https://www.hackingwithswift.com/quick-start/swiftui/how-to-convert-a-swiftui-view-to-an-image
        //https://stackoverflow.com/questions/57028484/how-to-convert-a-image-to-uiimage
    }
    public static var uicolor: UIColor? {
        get { UIPasteboard.general.color ?? nil }
        set { UIPasteboard.general.color = newValue }
    }
    public static var color: Color? {
        get { 
            guard let uic = UIPasteboard.general.color else { return nil }
            return Color(uic)
        }
        set {
            if let c = newValue {
                UIPasteboard.general.color = UIColor(c) 
            } else {
                UIPasteboard.general.color = nil
            }
        }
    }
    public static var url: URL? {
        get { UIPasteboard.general.url ?? nil }
        set { UIPasteboard.general.url = newValue }
    }
}
