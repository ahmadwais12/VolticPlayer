import Flutter
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

public class MediaMetadataPlugin: NSObject, FlutterPlugin {

    private let videoExtensions: Set<String> = ["mp4", "mkv", "3gp", "3gpp", "mov"]

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let channel = FlutterMethodChannel(
            name: "media_metadata",
            binaryMessenger: registrar.messenger()
        )
        #else
        let channel = FlutterMethodChannel(
            name: "media_metadata",
            binaryMessenger: registrar.messenger
        )
        #endif
        let instance = MediaMetadataPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "filePath is required", details: nil))
            return
        }

        if call.method == "readMetadata" {
            let createThumbnail = args["createThumbnail"] as? Bool ?? false
            DispatchQueue.global(qos: .userInitiated).async {
                let metadata = self.readMetadata(filePath: filePath, createThumbnail: createThumbnail)
                DispatchQueue.main.async {
                    result(metadata)
                }
            }
        } else if call.method == "writeMetadata" {
            guard let metadataMap = args["metadata"] as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "metadata map is required", details: nil))
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let success = self.writeMetadata(filePath: filePath, metadata: metadataMap)
                DispatchQueue.main.async {
                    result(success)
                }
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Lecture des Métadonnées
    private func readMetadata(filePath: String, createThumbnail: Bool) -> [String: Any?] {
        let url = URL(fileURLWithPath: filePath)
        let ext = url.pathExtension.lowercased()

        let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp", "tiff", "gif", "bmp"]
        if imageExtensions.contains(ext) {
            return readImageMetadata(url: url)
        } else {
            return readAudioVideoMetadata(url: url, createThumbnail: createThumbnail)
        }
    }

    private func readAudioVideoMetadata(url: URL, createThumbnail: Bool) -> [String: Any?] {
        var result: [String: Any?] = [
            "title": nil, "duration": nil, "artist": nil, "album": nil,
            "albumArtist": nil, "trackNumber": nil, "trackTotal": nil,
            "discNumber": nil, "discTotal": nil, "year": nil, "genre": nil,
            "comment": nil, "imageMetadata": nil, "fileSize": nil,
            "sampleRate": nil, "audioBitrate": nil, "audioChannels": nil,
            "bitsPerSample": nil, "audioCodec": nil,
            "videoCodec": nil, "videoBitrate": nil, "frameRate": nil,
            "videoWidth": nil, "videoHeight": nil,
        ]

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            result["fileSize"] = size
        }

        let asset = AVAsset(url: url)
        let duration = asset.duration
        if duration.isNumeric && duration.value > 0 {
            result["duration"] = Int64(CMTimeGetSeconds(duration) * 1000)
        }

        let formats = asset.availableMetadataFormats
        for format in formats {
            let items = asset.metadata(forFormat: format)
            for item in items {
                guard let key = item.commonKey?.rawValue ?? item.key?.description else { continue }

                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue, "title", "©nam":
                    result["title"] = item.stringValue
                case AVMetadataKey.commonKeyArtist.rawValue, "artist", "©ART":
                    result["artist"] = item.stringValue
                case AVMetadataKey.commonKeyAlbumName.rawValue, "album", "©alb":
                    result["album"] = item.stringValue
                case "albumArtist", "aART":
                    result["albumArtist"] = item.stringValue
                case AVMetadataKey.commonKeyType.rawValue, "genre", "©gen", "gnre":
                    result["genre"] = item.stringValue
                case "©cmt", "comment", "cmt ":
                    result["comment"] = item.stringValue
                case AVMetadataKey.commonKeyCreationDate.rawValue, "year", "©day", "tyer":
                    if let dateStr = item.stringValue {
                        result["year"] = parseYear(dateStr)
                    }
                case "trkn", "trackNumber":
                    if let data = item.dataValue {
                        let (num, total) = parseITunesTrackGroup(data)
                        result["trackNumber"] = num
                        result["trackTotal"] = total
                    } else if let str = item.stringValue {
                        let (num, total) = parseTrackDiscString(str)
                        result["trackNumber"] = num
                        result["trackTotal"] = total
                    }
                case "disk", "discNumber":
                    if let data = item.dataValue {
                        let (num, total) = parseITunesTrackGroup(data)
                        result["discNumber"] = num
                        result["discTotal"] = total
                    } else if let str = item.stringValue {
                        let (num, total) = parseTrackDiscString(str)
                        result["discNumber"] = num
                        result["discTotal"] = total
                    }
                case AVMetadataKey.commonKeyArtwork.rawValue, "covr":
                    // Toute l'information image (octets bruts + type + dimensions)
                    // est désormais regroupée dans "imageMetadata".
                    if let data = item.dataValue {
                        result["imageMetadata"] = buildImageMetadata(fromData: data, isGenerated: false)
                    }
                default:
                    break
                }
            }
        }

        // --- Infos techniques audio ---
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            if audioTrack.estimatedDataRate > 0 {
                result["audioBitrate"] = Int(audioTrack.estimatedDataRate)
            }
            if let formatDescriptions = audioTrack.formatDescriptions as? [CMFormatDescription],
               let formatDesc = formatDescriptions.first {
                result["audioCodec"] = fourCCToString(CMFormatDescriptionGetMediaSubType(formatDesc))
                if let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
                    let asbd = asbdPointer.pointee
                    if asbd.mSampleRate > 0 {
                        result["sampleRate"] = Int(asbd.mSampleRate)
                    }
                    if asbd.mChannelsPerFrame > 0 {
                        result["audioChannels"] = Int(asbd.mChannelsPerFrame)
                    }
                    if asbd.mBitsPerChannel > 0 {
                        result["bitsPerSample"] = Int(asbd.mBitsPerChannel)
                    }
                }
            }
        }

        // --- Infos techniques vidéo ---
        var isVideo = false
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            isVideo = true
            if videoTrack.estimatedDataRate > 0 {
                result["videoBitrate"] = Int(videoTrack.estimatedDataRate)
            }
            if videoTrack.nominalFrameRate > 0 {
                result["frameRate"] = Double(videoTrack.nominalFrameRate)
            }
            let size = videoTrack.naturalSize
            if size.width > 0 { result["videoWidth"] = Int(size.width) }
            if size.height > 0 { result["videoHeight"] = Int(size.height) }
            if let formatDescriptions = videoTrack.formatDescriptions as? [CMFormatDescription],
               let formatDesc = formatDescriptions.first {
                result["videoCodec"] = fourCCToString(CMFormatDescriptionGetMediaSubType(formatDesc))
            }
        }

        // Si aucune pochette réelle n'a été trouvée et que le fichier est une
        // vidéo, on génère (option "createThumbnail") une miniature en
        // capturant une vraie image du flux vidéo, comme le ferait un lecteur
        // ou un explorateur de fichiers — jamais une icône générique.
        if result["imageMetadata"] == nil, createThumbnail, isVideo {
            if let generated = generateVideoThumbnail(asset: asset, duration: duration) {
                result["imageMetadata"] = generated
            }
        }

        return result
    }

    private func readImageMetadata(url: URL) -> [String: Any?] {
        var result: [String: Any?] = [
            "title": nil, "duration": nil, "artist": nil, "album": nil,
            "albumArtist": nil, "trackNumber": nil, "trackTotal": nil,
            "discNumber": nil, "discTotal": nil, "year": nil, "genre": nil,
            "comment": nil, "imageMetadata": nil, "fileSize": nil,
            "sampleRate": nil, "audioBitrate": nil, "audioChannels": nil,
            "bitsPerSample": nil, "audioCodec": nil,
            "videoCodec": nil, "videoBitrate": nil, "frameRate": nil,
            "videoWidth": nil, "videoHeight": nil,
        ]

        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
            result["fileSize"] = size
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return result
        }

        var description: String? = nil

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            result["title"] = tiff[kCGImagePropertyTIFFImageDescription as String] as? String
            result["artist"] = tiff[kCGImagePropertyTIFFArtist as String] as? String
            if let dateStr = tiff[kCGImagePropertyTIFFDateTime as String] as? String {
                result["year"] = parseYear(dateStr)
            }
        }

        if let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            if result["title"] == nil { result["title"] = iptc[kCGImagePropertyIPTCObjectName as String] as? String }
            if result["artist"] == nil { result["artist"] = iptc[kCGImagePropertyIPTCByline as String] as? String }
            result["genre"] = iptc[kCGImagePropertyIPTCCategory as String] as? String
            if description == nil {
                description = iptc[kCGImagePropertyIPTCCaptionAbstract as String] as? String
            }
        }

        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if description == nil {
                description = exif[kCGImagePropertyExifUserComment as String] as? String
            }
        }

        result["comment"] = description

        var typeName: String? = url.pathExtension.lowercased()
        if let utType = CGImageSourceGetType(source) {
            typeName = imageTypeName(from: utType as String)
        }

        // Pour un fichier image autonome, "data" correspond au contenu brut du
        // fichier lui-même (permet à Flutter de l'afficher directement).
        let rawData = try? Data(contentsOf: url)

        result["imageMetadata"] = [
            "data": rawData != nil ? FlutterStandardTypedData(bytes: rawData!) : nil,
            "type": typeName,
            "fileSizeBytes": fileSize,
            "width": properties[kCGImagePropertyPixelWidth as String] as? Int,
            "height": properties[kCGImagePropertyPixelHeight as String] as? Int,
            "description": description,
            "isGenerated": false,
        ]

        return result
    }

    // MARK: - Écriture des Métadonnées
    private func writeMetadata(filePath: String, metadata: [String: Any]) -> Bool {
        let url = URL(fileURLWithPath: filePath)
        let asset = AVAsset(url: url)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            return false
        }

        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "." + url.pathExtension)
        exportSession.outputURL = tempUrl
        exportSession.outputFileType = AVFileType.fromExtension(url.pathExtension)
        exportSession.shouldOptimizeForNetworkUse = true

        var newMetadata: [AVMetadataItem] = []

        let mappings: [(String, AVMetadataKey, String)] = [
            ("title", .commonKeyTitle, "©nam"),
            ("artist", .commonKeyArtist, "©ART"),
            ("album", .commonKeyAlbumName, "©alb"),
            ("albumArtist", .mainITunesKey("aART"), "aART"),
            ("genre", .commonKeyType, "©gen"),
            ("comment", .mainITunesKey("©cmt"), "©cmt"),
        ]

        for (mapKey, commonKey, legacyKey) in mappings {
            if let val = metadata[mapKey] as? String {
                let item = AVMutableMetadataItem()
                item.keySpace = .common
                item.key = commonKey.rawValue as NSCopying & NSObjectProtocol
                item.value = val as NSString
                newMetadata.append(item)

                let iTunesItem = AVMutableMetadataItem()
                iTunesItem.keySpace = .iTunes
                iTunesItem.key = legacyKey as NSCopying & NSObjectProtocol
                iTunesItem.value = val as NSString
                newMetadata.append(iTunesItem)
            }
        }

        if let year = metadata["year"] as? Int {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyCreationDate.rawValue as NSCopying & NSObjectProtocol
            item.value = String(year) as NSString
            newMetadata.append(item)
        }

        // Track Number Builder (trkn)
        if let trackNum = metadata["trackNumber"] as? Int {
            let trackTotal = metadata["trackTotal"] as? Int ?? 0
            let item = AVMutableMetadataItem()
            item.keySpace = .iTunes
            item.key = "trkn" as NSCopying & NSObjectProtocol
            item.value = buildITunesTrackGroupData(num: trackNum, total: trackTotal) as NSData
            newMetadata.append(item)
        }

        // Disc Number Builder (disk)
        if let discNum = metadata["discNumber"] as? Int {
            let discTotal = metadata["discTotal"] as? Int ?? 0
            let item = AVMutableMetadataItem()
            item.keySpace = .iTunes
            item.key = "disk" as NSCopying & NSObjectProtocol
            item.value = buildITunesTrackGroupData(num: discNum, total: discTotal) as NSData
            newMetadata.append(item)
        }

        // Injection Image / Vignette (covr) : les octets viennent désormais de
        // metadata["imageMetadata"]["data"]. On n'écrit jamais une miniature
        // générée (isGenerated == true) comme si c'était une vraie pochette.
        if let imageMeta = metadata["imageMetadata"] as? [String: Any],
           (imageMeta["isGenerated"] as? Bool) != true,
           let flutterData = imageMeta["data"] as? FlutterStandardTypedData {
            let imgData = flutterData.data
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyArtwork.rawValue as NSCopying & NSObjectProtocol
            item.value = imgData as NSData
            newMetadata.append(item)

            let iTunesItem = AVMutableMetadataItem()
            iTunesItem.keySpace = .iTunes
            iTunesItem.key = "covr" as NSCopying & NSObjectProtocol
            iTunesItem.value = imgData as NSData
            newMetadata.append(iTunesItem)
        }

        exportSession.metadata = newMetadata

        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                success = true
            } else {
                print("[MediaMetadata] Export failed: \(String(describing: exportSession.error))")
            }
            semaphore.signal()
        }

        semaphore.wait()

        if success {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try FileManager.default.moveItem(at: tempUrl, to: url)
                return true
            } catch {
                print("[MediaMetadata] File replacement error: \(error)")
                return false
            }
        }
        return false
    }

    // MARK: - Parseurs & Helpers Réutilisables
    private func parseTrackDiscString(_ raw: String) -> (Int?, Int?) {
        let parts = raw.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        let num = parts.first.flatMap { Int($0) }
        let total = parts.count > 1 ? Int(parts[1]) : nil
        return (num, total)
    }

    private func parseITunesTrackGroup(_ data: Data) -> (Int?, Int?) {
        guard data.count >= 6 else { return (nil, nil) }
        let num = Int(data[2]) << 8 | Int(data[3])
        let total = Int(data[4]) << 8 | Int(data[5])
        return (num > 0 ? num : nil, total > 0 ? total : nil)
    }

    private func buildITunesTrackGroupData(num: Int, total: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: 8)
        bytes[2] = UInt8((num >> 8) & 0xFF)
        bytes[3] = UInt8(num & 0xFF)
        bytes[4] = UInt8((total >> 8) & 0xFF)
        bytes[5] = UInt8(total & 0xFF)
        return Data(bytes)
    }

    private func parseYear(_ raw: String) -> Int? {
        let pattern = #"\b(\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: raw, options: [], range: NSRange(raw.startIndex..., in: raw)),
              let range = Range(match.range(at: 1), in: raw) else {
            return nil
        }
        return Int(raw[range])
    }

    /// Convertit un FourCharCode (ex: type de sous-média `avc1`, `mp4a`) en chaîne lisible.
    private func fourCCToString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff),
        ]
        let scalars = bytes.compactMap { UnicodeScalar($0) }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Construit un [ImageMetadata] (octets bruts, type, dimensions, description,
    /// isGenerated) à partir des données brutes d'une image embarquée
    /// (pochette d'album, vignette).
    private func buildImageMetadata(fromData data: Data, isGenerated: Bool) -> [String: Any?] {
        var meta: [String: Any?] = [
            "data": FlutterStandardTypedData(bytes: data),
            "type": nil, "fileSizeBytes": data.count, "width": nil, "height": nil,
            "description": nil, "isGenerated": isGenerated,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return meta }

        if let utType = CGImageSourceGetType(source) {
            meta["type"] = imageTypeName(from: utType as String)
        }

        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            meta["width"] = properties[kCGImagePropertyPixelWidth as String] as? Int
            meta["height"] = properties[kCGImagePropertyPixelHeight as String] as? Int
            if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                meta["description"] = exif[kCGImagePropertyExifUserComment as String] as? String
            }
        }
        return meta
    }

    /// Génère une miniature en capturant une vraie image du flux vidéo (comme
    /// le ferait Aperçu / le Finder), lorsqu'aucune pochette n'est embarquée.
    private func generateVideoThumbnail(asset: AVAsset, duration: CMTime) -> [String: Any?]? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let durationSeconds = duration.isNumeric ? CMTimeGetSeconds(duration) : 0
        let targetSeconds = durationSeconds > 2 ? 1.0 : durationSeconds / 2.0
        let time = CMTime(seconds: max(targetSeconds, 0), preferredTimescale: 600)

        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        let data = mutableData as Data
        return [
            "data": FlutterStandardTypedData(bytes: data),
            "type": "jpeg",
            "fileSizeBytes": data.count,
            "width": cgImage.width,
            "height": cgImage.height,
            "description": nil,
            "isGenerated": true,
        ]
    }

    private func imageTypeName(from utTypeIdentifier: String) -> String {
        if #available(iOS 14.0, *) {
            if let utType = UTType(utTypeIdentifier), let ext = utType.preferredFilenameExtension {
                return ext
            }
        }
        switch utTypeIdentifier {
        case "public.jpeg": return "jpeg"
        case "public.png": return "png"
        case "public.heic": return "heic"
        case "com.compuserve.gif": return "gif"
        case "public.tiff": return "tiff"
        case "com.microsoft.bmp": return "bmp"
        case "org.webmproject.webp": return "webp"
        default: return utTypeIdentifier
        }
    }
}

extension AVMetadataKey {
    static func mainITunesKey(_ key: String) -> AVMetadataKey {
        return AVMetadataKey(rawValue: key)
    }
}

extension AVFileType {
    static func fromExtension(_ ext: String) -> AVFileType {
        switch ext.lowercased() {
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "mov": return .mov
        case "mkv": return .mov
        default: return .mp4
        }
    }
}
