//EZIO 0.1.0, Apr 2022, https://github.com/trochoid/EZIO.git
import SwiftUI

public class EZIO {
    
    private static func makeData<T: Encodable>(obj: T, pretty: Bool = false) -> Data? {
        if let d = obj as? Data { return d }
        let encoder = JSONEncoder()
        if pretty { encoder.outputFormatting = .prettyPrinted }
        do { return try encoder.encode(obj) } 
        catch { return nil }
    }
    
    private static func makeObj<T: Decodable>(data: Data, type: T.Type) -> T? {
        if type == Data.self { 
            if let d = data as? T { return d } else { return nil }
        }
        do { return try JSONDecoder().decode(type, from: data) } 
        catch { return nil }
    }
    
    public static func storeObj<T: Encodable>(obj: T, key: String) {
        guard let data = makeData(obj: obj) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    public static func loadObj<T: Decodable>(type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { 
            print("didn't get data from UserDefaults"); return nil }
        guard let obj = makeObj(data: data, type: type) else { 
            print("didn't make obj from data"); return nil }
        return obj
    }
    
    public static func getJSONText<T: Encodable>(obj: T) -> String {
        guard let data = makeData(obj: obj, pretty: true) else { return "err" }
        guard let s = String(data: data, encoding: .utf8) else { return "err" }
        return s
    }
    
    //-- external file help
    
    fileprivate static func storeBookmarkData(url: URL, bookmarkKey: String) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { print("no start secure"); return false }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let bmData = try url.bookmarkData(
                options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bmData, forKey: bookmarkKey)
        } catch let err { print("couldn't create bookmark\n\(err)"); return false }
        return true
    }
    
    fileprivate static func getUnstaleFolder(bookmarkKey: String) -> URL? {
        guard let bmData = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        do {
            let folder = try URL(resolvingBookmarkData: bmData, bookmarkDataIsStale: &isStale)
            if isStale { return nil }
            return folder
        } catch { return nil }
    }
    
    fileprivate static func getObjFromSecuredFolder<T: Decodable>
    (folder: URL, fileName: String, type: T.Type) -> T? {
        guard folder.startAccessingSecurityScopedResource() else { print("not start secure"); return nil }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            let f = folder.appendingPathComponent(fileName)
            let d = try Data(contentsOf: f)
            let obj = try JSONDecoder().decode(type, from: d)
            return obj
        } catch { return nil }
    }
    
    fileprivate static func saveObjInSecuredFolder<T: Encodable>
    (folder: URL, fileName: String, obj: T) -> Bool {
        guard folder.startAccessingSecurityScopedResource() else { print("no start secure"); return false }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            let file = folder.appendingPathComponent(fileName)
            let d = try JSONEncoder().encode(obj)
            try d.write(to: file)
        } catch { return false }
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
    @State private var showDoc = false
    init(_ text: String, bookmark: String = "", fileName: String, type: T.Type, handler: @escaping (T) -> Void) {
        self.buttonText = text
        self.bookmark = bookmark == "" ? fileName : bookmark
        self.fileName = fileName
        self.type = type
        self.handler = handler
    }
    public var body: some View {
        Button(buttonText, action: clicked)
            .sheet(isPresented: $showDoc) { DocPicker(handleSelectedFolder) }
    }
    private func clicked() {
        guard let folder = EZIO.getUnstaleFolder(bookmarkKey: bookmark) else { showDoc = true; return }
        loadAndPass(folder: folder)
    }
    private func handleSelectedFolder(urls: [URL]) {
        if urls.count == 0 { print("empty urls array"); return }
        let folder = urls[0]
        if EZIO.storeBookmarkData(url: folder, bookmarkKey: bookmark) {
            loadAndPass(folder: folder)
        }
    }
    private func loadAndPass(folder: URL) {
        if let obj = EZIO.getObjFromSecuredFolder(folder: folder, fileName: fileName, type: type) {
            handler(obj)
        }
    }
}


public struct ButtonSave<T: Encodable>: View {
    private let buttonText: String
    private let bookmark: String
    private let fileName: String
    private let handler: () -> T?
    private let holder = ObjHolder<T>()
    @State private var showDoc = false
    init(_ text: String, bookmark: String = "", fileName: String, handler: @escaping () -> T?) {
        self.buttonText = text
        self.bookmark = bookmark == "" ? fileName : bookmark
        self.fileName = fileName
        self.handler = handler
    }
    public var body: some View {
        Button(buttonText, action: clicked)
            .sheet(isPresented: $showDoc) { DocPicker(handleSelectedFolder) }
    }
    private func clicked() {
        guard let obj = handler() else { return }
        holder.obj = obj
        if let folder = EZIO.getUnstaleFolder(bookmarkKey: bookmark) {
            getAndSave(folder: folder)
        } else { showDoc = true; return }
    }
    private func handleSelectedFolder(urls: [URL]) {
        defer { holder.obj = nil }
        guard urls.count > 0 else { print("empty urls array"); holder.obj = nil; return }
        let folder = urls[0]
        if EZIO.storeBookmarkData(url: folder, bookmarkKey: bookmark) {
            getAndSave(folder: folder)
        }
    }
    private func getAndSave(folder: URL) {
        defer { holder.obj = nil }
        if let obj = holder.obj {
            guard EZIO.saveObjInSecuredFolder(folder: folder, fileName: fileName, obj: obj) 
            else { print("didn't save, holder.obj nil"); return }
        }
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
    public static var eztext: String { text ?? "" }
    public static var text: String? {
        get { UIPasteboard.general.hasStrings ? UIPasteboard.general.string : nil }
        set { UIPasteboard.general.string = newValue }
    }
    public static var uiimage: UIImage? {
        get { UIPasteboard.general.hasImages ? UIPasteboard.general.image : nil }
        set { UIPasteboard.general.image = newValue }
    }
    public static var uicolor: UIColor? {
        get { UIPasteboard.general.hasColors ? UIPasteboard.general.color : nil }
        set { UIPasteboard.general.color = newValue }
    }
    public static var url: URL? {
        get { UIPasteboard.general.hasURLs ? UIPasteboard.general.url : nil }
        set { UIPasteboard.general.url = newValue }
    }
}


