//EZIO 0.0.5, April 27 2022
import SwiftUI

public class EZIO {
    
    public private(set) static var lastError: String?
    public static var lastErrorText: String { lastError ?? "no error" }
    fileprivate static func resetError() { lastError = nil }
    fileprivate static func appendError(_ errText: String) {
        if let s = lastError {
            lastError = s + "\n" + errText
        } else {
            lastError = errText
        }
    }
    
    private static func flatCodingPath(_ path: [CodingKey]) -> String {
        "path...\n" + path.map{ $0.debugDescription }.joined(separator: "\n")
    }
    
    private static func storeError(_ err: Error) {
        switch err {
        case let EncodingError.invalidValue(obj, context):
            var sa = ["EncodingError.invalidValue"]
            sa.append(err.localizedDescription)
            sa.append("value: \(obj), type: \(type(of: obj))")
            sa.append(flatCodingPath(context.codingPath))
            sa.append("debugDescription: \(context.debugDescription)")
            lastError = sa.joined(separator: "\n")
        case let DecodingError.dataCorrupted(context):
            var sa = ["DecodingError.dataCorrupted"]
            sa.append(err.localizedDescription)
            sa.append("debugDescription: \(context.debugDescription)")
            sa.append(flatCodingPath(context.codingPath))
            lastError = sa.joined(separator: "\n")
        case let DecodingError.keyNotFound(key, context):
            var sa = ["DecodingError.keyNotFound"]
            sa.append(err.localizedDescription)
            sa.append("key: \(key.debugDescription)")
            sa.append("debugDescription: \(context.debugDescription)")
            sa.append(flatCodingPath(context.codingPath))
            lastError = sa.joined(separator: "\n")
        case let DecodingError.typeMismatch(type, context):
            var sa = ["DecodingError.typeMismatch"]
            sa.append(err.localizedDescription)
            sa.append("type: \(type)")
            sa.append("debugDescription: \(context.debugDescription)")
            sa.append(flatCodingPath(context.codingPath))
            lastError = sa.joined(separator: "\n")
        case let DecodingError.valueNotFound(type, context):
            var sa = ["DecodingError.valueNotFound"]
            sa.append(err.localizedDescription)
            sa.append("type: \(type)")
            sa.append("debugDescription: \(context.debugDescription)")
            sa.append(flatCodingPath(context.codingPath))
            lastError = sa.joined(separator: "\n")
        default:
            lastError = "unknown error"
        }
    }
    
    private static func makeData<T: Encodable>(obj: T, pretty: Bool = false) -> Data? {
        resetError()
        if let d = obj as? Data { return d }
        let encoder = JSONEncoder()
        if pretty { encoder.outputFormatting = .prettyPrinted }
        do { return try encoder.encode(obj) } 
        catch { storeError(error); return nil }
    }
    
    private static func makeObj<T: Decodable>(data: Data, type: T.Type) -> T? {
        resetError()
        if type == Data.self { return data as? T }
        do { return try JSONDecoder().decode(type, from: data) } 
        catch { storeError(error); return nil }
    }
    
    public static func storeObj<T: Encodable>(obj: T, key: String) -> Bool {
        guard let data = makeData(obj: obj) else { return false }
        UserDefaults.standard.set(data, forKey: key)
        return true
    }
    
    public static func loadObj<T: Decodable>(type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { 
            lastError = "EZIO.loadObj Error: UserDefaults key not found"; return nil }
        guard let obj = makeObj(data: data, type: type) else { return nil }
        return obj
    }
    
    public static func toJSONText<T: Encodable>(obj: T, pretty: Bool = true) -> String {
        guard let data = makeData(obj: obj, pretty: pretty) else { return "toJSONText makeData err" }
        guard let s = String(data: data, encoding: .utf8) else { 
            lastError = "toJSONText String() err"; return lastErrorText }
        return s
    }
    
    public static func fromJSONText<T: Decodable>(type: T.Type, json: String) -> T? {
        guard let data = json.data(using: .utf8) else { 
            lastError = "fromJSONText Data() err"; return nil }
        return makeObj(data: data, type: type)
    }
    
    //-- external file help
    
    fileprivate static func storeBookmarkData(url: URL, bookmarkKey: String) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { appendError("no start secure"); return false }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let bmData = try url.bookmarkData(
                options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bmData, forKey: bookmarkKey)
        } catch let err { appendError("couldn't create bookmark\n\(err)"); return false }
        return true
    }
    
    public static func removeBookmark(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    fileprivate static func getUnstaleFolder(bookmarkKey: String) -> URL? {
        guard let bmData = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        let folder: URL
        do {
            folder = try URL(resolvingBookmarkData: bmData, bookmarkDataIsStale: &isStale)
        } catch { 
            EZIO.appendError("getUnstaleFolder: didn't resolve url"); return nil }
        if isStale { return nil }
        return folder
        
    }
    
    fileprivate static func getObjFromSecuredFolder<T: Decodable>
    (folder: URL, fileName: String, type: T.Type) -> T? {
        guard folder.startAccessingSecurityScopedResource() else { 
            appendError("getObjFromSecuredFolder: not start secure"); return nil }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            let f = folder.appendingPathComponent(fileName)
            let d = try Data(contentsOf: f)
            let obj = try JSONDecoder().decode(type, from: d)
            return obj
        } catch { appendError("getObjFromSecuredFolder: failed decoding"); return nil }
    }
    
    fileprivate static func saveObjInSecuredFolder<T: Encodable>
    (folder: URL, fileName: String, obj: T) -> Bool {
        guard folder.startAccessingSecurityScopedResource() else { 
            appendError("saveObjInSecuredFolder: no start secure"); return false }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            let file = folder.appendingPathComponent(fileName)
            let d = try JSONEncoder().encode(obj)
            try d.write(to: file)
        } catch { appendError("saveObjInSecuredFolder: failed encoding"); return false }
        return true
    }
    
}

//====================================================================
//==================================================( Button IO )=====
//====================================================================

public struct ButtonLoad<T: Decodable>: View {
    private let buttonText: String
    private let bookmark: String
    private let fileName: String
    private let type: T.Type
    private let handler: (T) -> Void
    private let errHandler: (() -> Void)?
    @State private var showDoc = false
    public init(_ text: String, bookmark: String = "", fileName: String, type: T.Type, 
                handler: @escaping (T) -> Void, error: (() -> Void)? = nil) {
        self.buttonText = text
        self.bookmark = bookmark == "" ? fileName : bookmark
        self.fileName = fileName
        self.type = type
        self.handler = handler
        self.errHandler = error
    }
    public var body: some View {
        Button(buttonText, action: clicked)
            .sheet(isPresented: $showDoc) { DocPicker(handleSelectedFolder) }
    }
    private func clicked() {
        EZIO.resetError()
        guard let folder = EZIO.getUnstaleFolder(bookmarkKey: bookmark) else { showDoc = true; return }
        loadAndPass(folder: folder)
    }
    private func handleSelectedFolder(urls: [URL]) {
        if urls.count == 0 { return } //cancelled
        let folder = urls[0]
        loadAndPass(folder: folder)
    }
    private func loadAndPass(folder: URL) {
        guard let obj = EZIO.getObjFromSecuredFolder(folder: folder, fileName: fileName, type: type)
        else { invokeError("failed loading obj from folder"); return }
        handler(obj)
        guard EZIO.storeBookmarkData(url: folder, bookmarkKey: bookmark) 
        else { invokeError("failed storing bookmark"); return }
    }
    private func invokeError(_ msg: String) {
        EZIO.appendError(msg)
        if let err = errHandler { err() }
    }
    
}


public struct ButtonSave<T: Encodable>: View {
    private let buttonText: String
    private let bookmark: String
    private let fileName: String
    private let handler: () -> T?
    private let errHandler: (() -> Void)?
    private let holder = ObjHolder<T>()
    @State private var showDoc = false
    public init(_ text: String, bookmark: String = "", fileName: String, 
                handler: @escaping () -> T?, error: (() -> Void)? = nil) {
        self.buttonText = text
        self.bookmark = bookmark == "" ? fileName : bookmark
        self.fileName = fileName
        self.handler = handler
        self.errHandler = error
    }
    public var body: some View {
        Button(buttonText, action: clicked)
            .sheet(isPresented: $showDoc) { DocPicker(handleSelectedFolder) }
    }
    private func clicked() {
        EZIO.resetError()
        guard let obj = handler() else { return } //user skipped
        if let folder = EZIO.getUnstaleFolder(bookmarkKey: bookmark) {
            getAndSave(obj: obj, folder: folder)
        } else {
            holder.obj = obj //retain, only needed when using sheet
            showDoc = true
        }
    }
    private func handleSelectedFolder(urls: [URL]) {
        defer { holder.obj = nil } //nil this when all over
        if urls.count == 0 { return } //user cancelled
        guard let obj = holder.obj else { invokeError("holder.obj nil somehow"); return }
        let folder = urls[0]
        getAndSave(obj: obj, folder: folder) //try to save it
    }
    private func getAndSave(obj: T, folder: URL) {
        guard EZIO.saveObjInSecuredFolder(folder: folder, fileName: fileName, obj: obj) 
        else { invokeError("didn't save in folder"); return }
        guard EZIO.storeBookmarkData(url: folder, bookmarkKey: bookmark) 
        else { invokeError("didn't store bookmark"); return }
    }
    private func invokeError(_ msg: String) {
        EZIO.appendError(msg)
        if let err = errHandler { err() }
    }
    private class ObjHolder<T: Encodable> { var obj: T? }
}

//====================================================================
//=============================( UIDocumentPickerViewController )=====
//====================================================================

private typealias Context = UIViewControllerRepresentableContext
private typealias Controller = UIDocumentPickerViewController

private struct DocPicker: UIViewControllerRepresentable {
    private var docDel: DocDelegate
    init(_ callBack: @escaping ([URL]) -> Void) { 
        docDel = DocDelegate(callBack) }
    func makeUIViewController(context: Context<DocPicker>) -> Controller {
        let controller = Controller(forOpeningContentTypes: [.folder])
        controller.delegate = docDel
        return controller }
    func updateUIViewController(_ uiViewController: Controller, context: Context<DocPicker>) {}
}

private class DocDelegate: NSObject, UIDocumentPickerDelegate {
    private let callBack: ([URL]) -> Void
    init(_ callBack: @escaping ([URL]) -> Void) { 
        self.callBack = callBack }
    func documentPicker(_ controller: Controller, didPickDocumentsAt urls: [URL]) {
        callBack(urls) }
    func documentPickerWasCancelled(_ controller: Controller) {
        callBack([]) }
}

//====================================================================
//=================================================( Pasteboard )=====
//====================================================================

public class Pasteboard {
    
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


