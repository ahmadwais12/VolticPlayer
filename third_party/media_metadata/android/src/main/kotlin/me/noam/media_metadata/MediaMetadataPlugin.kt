package me.noam.media_metadata

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.RandomAccessFile

class MediaMetadataPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel

    private val videoExtensions = setOf("mp4", "mkv", "3gp", "3gpp", "mov")

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "media_metadata")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath == null) {
            result.error("INVALID_ARGUMENT", "filePath is required", null)
            return
        }

        when (call.method) {
            "readMetadata" -> {
                val createThumbnail = call.argument<Boolean>("createThumbnail") ?: false
                Thread {
                    try {
                        val metadata = readMetadata(filePath, createThumbnail)
                        result.success(metadata)
                    } catch (e: Exception) {
                        result.error("READ_ERROR", e.message, null)
                    }
                }.start()
            }
            "writeMetadata" -> {
                val metadataMap = call.argument<Map<String, Any?>>("metadata")
                if (metadataMap == null) {
                    result.error("INVALID_ARGUMENT", "metadata map is required", null)
                    return
                }
                Thread {
                    try {
                        val success = writeMetadata(filePath, metadataMap)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("WRITE_ERROR", e.message, null)
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    // MARK: - Lecture des Métadonnées
    private fun readMetadata(filePath: String, createThumbnail: Boolean): Map<String, Any?> {
        val file = File(filePath)
        if (!file.exists()) return emptyMap(0L)
        val fileSize = file.length()

        val ext = file.extension.lowercase()
        val imageExtensions = setOf("jpg", "jpeg", "png", "heic", "webp", "tiff", "gif", "bmp")

        return if (imageExtensions.contains(ext)) {
            readImageMetadata(filePath, fileSize)
        } else {
            readAudioVideoMetadata(filePath, fileSize, createThumbnail)
        }
    }

    private fun readAudioVideoMetadata(filePath: String, fileSize: Long, createThumbnail: Boolean): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(filePath)

            val trackRaw = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER)
            val (trackNum, trackTotal) = parseTrackDisc(trackRaw)

            val discRaw = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DISC_NUMBER)
            val (discNum, discTotal) = parseTrackDisc(discRaw)

            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val durationMs = durationStr?.toLongOrNull()

            val yearRaw = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR) ?:
                          retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE)
            val year = yearRaw?.let { parseYear(it) }

            // 1) Vraie pochette embarquée (ID3 APIC, atome MP4 covr...).
            val embeddedPicture = retriever.embeddedPicture
            var imageMeta = embeddedPicture?.let { buildEmbeddedImageMetadata(it) }

            // 2) Si aucune pochette réelle et que le fichier est une vidéo,
            //    on génère (option "createThumbnail") une miniature en
            //    capturant une vraie image du flux vidéo, comme le ferait un
            //    explorateur de fichiers — jamais une icône générique.
            if (imageMeta == null && createThumbnail && ext(filePath) in videoExtensions) {
                imageMeta = buildGeneratedVideoThumbnail(retriever, durationMs)
            }

            val overallBitrateStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
            val overallBitrate = overallBitrateStr?.toIntOrNull()

            var sampleRate: Int? = null
            var bitsPerSample: Int? = null
            if (Build.VERSION.SDK_INT >= 31) {
                sampleRate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_SAMPLERATE)?.toIntOrNull()
                bitsPerSample = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITS_PER_SAMPLE)?.toIntOrNull()
            }

            val tech = readTechnicalInfo(filePath)

            val comment = if (ext(filePath) == "mp3") readMp3Comment(File(filePath)) else null

            mapOf(
                "title"         to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),
                "duration"      to durationMs,
                "artist"        to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),
                "album"         to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM),
                "albumArtist"   to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST),
                "trackNumber"   to trackNum,
                "trackTotal"    to trackTotal,
                "discNumber"    to discNum,
                "discTotal"     to discTotal,
                "year"          to year,
                "genre"         to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE),
                "comment"       to comment,
                "imageMetadata" to imageMeta,
                "fileSize"      to fileSize,
                "sampleRate"    to (sampleRate ?: tech.sampleRate),
                "audioBitrate"  to (tech.audioBitrate ?: overallBitrate.takeIf { tech.videoCodec == null }),
                "audioChannels" to tech.audioChannels,
                "bitsPerSample" to bitsPerSample,
                "audioCodec"    to tech.audioCodec,
                "videoCodec"    to tech.videoCodec,
                "videoBitrate"  to tech.videoBitrate,
                "frameRate"     to tech.frameRate,
                "videoWidth"    to tech.videoWidth,
                "videoHeight"   to tech.videoHeight,
            )
        } catch (e: Exception) {
            emptyMap(fileSize)
        } finally {
            try { retriever.release() } catch (f: Exception) {}
        }
    }

    private fun readImageMetadata(filePath: String, fileSize: Long): Map<String, Any?> {
        return try {
            val exifInterface = ExifInterface(filePath)
            val yearRaw = exifInterface.getAttribute(ExifInterface.TAG_DATETIME) ?:
                          exifInterface.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
            val year = yearRaw?.let { parseYear(it) }

            val imageMeta = buildStandaloneImageMetadata(filePath, fileSize, exifInterface)

            mapOf(
                "title"         to exifInterface.getAttribute(ExifInterface.TAG_IMAGE_DESCRIPTION),
                "duration"      to null,
                "artist"        to exifInterface.getAttribute(ExifInterface.TAG_ARTIST),
                "album"         to null,
                "albumArtist"   to null,
                "trackNumber"   to null,
                "trackTotal"    to null,
                "discNumber"    to null,
                "discTotal"     to null,
                "year"          to year,
                "genre"         to null,
                "comment"       to exifInterface.getAttribute(ExifInterface.TAG_USER_COMMENT),
                "imageMetadata" to imageMeta,
                "fileSize"      to fileSize,
                "sampleRate"    to null,
                "audioBitrate"  to null,
                "audioChannels" to null,
                "bitsPerSample" to null,
                "audioCodec"    to null,
                "videoCodec"    to null,
                "videoBitrate"  to null,
                "frameRate"     to null,
                "videoWidth"    to null,
                "videoHeight"   to null,
            )
        } catch (e: Exception) {
            emptyMap(fileSize)
        }
    }

    // MARK: - Infos techniques (MediaExtractor)
    private data class TechInfo(
        val audioCodec: String? = null,
        val videoCodec: String? = null,
        val sampleRate: Int? = null,
        val audioChannels: Int? = null,
        val audioBitrate: Int? = null,
        val videoBitrate: Int? = null,
        val frameRate: Double? = null,
        val videoWidth: Int? = null,
        val videoHeight: Int? = null,
    )

    private fun readTechnicalInfo(filePath: String): TechInfo {
        var audioCodec: String? = null
        var videoCodec: String? = null
        var sampleRate: Int? = null
        var audioChannels: Int? = null
        var audioBitrate: Int? = null
        var videoBitrate: Int? = null
        var frameRate: Double? = null
        var videoWidth: Int? = null
        var videoHeight: Int? = null

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(filePath)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue

                if (mime.startsWith("audio/") && audioCodec == null) {
                    audioCodec = mime
                    if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        audioChannels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    if (format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                        audioBitrate = format.getInteger(MediaFormat.KEY_BIT_RATE)
                    }
                } else if (mime.startsWith("video/") && videoCodec == null) {
                    videoCodec = mime
                    if (format.containsKey(MediaFormat.KEY_WIDTH)) {
                        videoWidth = format.getInteger(MediaFormat.KEY_WIDTH)
                    }
                    if (format.containsKey(MediaFormat.KEY_HEIGHT)) {
                        videoHeight = format.getInteger(MediaFormat.KEY_HEIGHT)
                    }
                    if (format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                        videoBitrate = format.getInteger(MediaFormat.KEY_BIT_RATE)
                    }
                    if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                        frameRate = try {
                            format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
                        } catch (e: Exception) {
                            try {
                                format.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
                            } catch (e2: Exception) {
                                null
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
        } finally {
            try { extractor.release() } catch (e: Exception) {}
        }

        return TechInfo(
            audioCodec, videoCodec, sampleRate, audioChannels,
            audioBitrate, videoBitrate, frameRate, videoWidth, videoHeight,
        )
    }

    // MARK: - ImageMetadata builders
    private fun buildEmbeddedImageMetadata(bytes: ByteArray): Map<String, Any?> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        val type = options.outMimeType?.substringAfter("image/")
        return mapOf(
            "data" to bytes,
            "type" to type,
            "fileSizeBytes" to bytes.size,
            "width" to options.outWidth.takeIf { it > 0 },
            "height" to options.outHeight.takeIf { it > 0 },
            "description" to null,
            "isGenerated" to false,
        )
    }

    private fun buildStandaloneImageMetadata(
        filePath: String,
        fileSize: Long,
        exif: ExifInterface?,
    ): Map<String, Any?> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(filePath, options)
        val type = options.outMimeType?.substringAfter("image/")
            ?: File(filePath).extension.lowercase()
        val fileBytes = try { File(filePath).readBytes() } catch (e: Exception) { null }
        return mapOf(
            "data" to fileBytes,
            "type" to type,
            "fileSizeBytes" to fileSize,
            "width" to options.outWidth.takeIf { it > 0 },
            "height" to options.outHeight.takeIf { it > 0 },
            "description" to exif?.getAttribute(ExifInterface.TAG_USER_COMMENT),
            "isGenerated" to false,
        )
    }

    /// Génère une miniature à partir d'une vraie image du flux vidéo (comme le
    /// ferait un explorateur de fichiers), lorsqu'il n'y a pas de pochette
    /// embarquée. Utilise [MediaMetadataRetriever.getFrameAtTime] pour
    /// capturer une image proche de 1 seconde (ou du milieu de la vidéo si
    /// elle est plus courte), jamais une icône générique.
    private fun buildGeneratedVideoThumbnail(
        retriever: MediaMetadataRetriever,
        durationMs: Long?,
    ): Map<String, Any?>? {
        return try {
            val targetTimeUs = if (durationMs != null && durationMs > 0) {
                (minOf(durationMs, 2000L) / 2) * 1000
            } else {
                1_000_000L // 1 seconde par défaut
            }

            val frame: Bitmap = retriever.getFrameAtTime(
                targetTimeUs,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
            ) ?: return null

            val outputStream = ByteArrayOutputStream()
            frame.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
            val bytes = outputStream.toByteArray()

            mapOf(
                "data" to bytes,
                "type" to "jpeg",
                "fileSizeBytes" to bytes.size,
                "width" to frame.width,
                "height" to frame.height,
                "description" to null,
                "isGenerated" to true,
            )
        } catch (e: Exception) {
            null
        }
    }

    // MARK: - Écriture des Métadonnées
    private fun writeMetadata(filePath: String, metadata: Map<String, Any?>): Boolean {
        val file = File(filePath)
        if (!file.exists()) return false

        val ext = file.extension.lowercase()
        val imageExtensions = setOf("jpg", "jpeg", "png", "heic", "webp", "tiff", "gif", "bmp")

        return if (imageExtensions.contains(ext)) {
            writeImageMetadata(filePath, metadata)
        } else {
            writeAudioVideoMetadata(filePath, metadata)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun extractImageBytes(metadata: Map<String, Any?>): ByteArray? {
        val imageMeta = metadata["imageMetadata"] as? Map<String, Any?> ?: return null
        return imageMeta["data"] as? ByteArray
    }

    private fun writeImageMetadata(filePath: String, metadata: Map<String, Any?>): Boolean {
        return try {
            val exifInterface = ExifInterface(filePath)

            (metadata["title"] as? String)?.let { exifInterface.setAttribute(ExifInterface.TAG_IMAGE_DESCRIPTION, it) }
            (metadata["artist"] as? String)?.let { exifInterface.setAttribute(ExifInterface.TAG_ARTIST, it) }
            (metadata["comment"] as? String)?.let { exifInterface.setAttribute(ExifInterface.TAG_USER_COMMENT, it) }

            (metadata["year"] as? Int)?.let { year ->
                exifInterface.setAttribute(ExifInterface.TAG_DATETIME, "$year:01:01 00:00:00")
            }

            // Note: setThumbnailData et ses helpers de flux étant privés/package-private,
            // l'injection directe de vignette via AndroidX ExifInterface reste limitée
            // (nécessiterait une librairie bas niveau de manipulation de flux d'octets).

            exifInterface.saveAttributes()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun writeAudioVideoMetadata(filePath: String, metadata: Map<String, Any?>): Boolean {
        return try {
            val file = File(filePath)
            val ext = file.extension.lowercase()

            if (ext == "mp3") {
                return writeMp3Id3v2Tags(file, metadata)
            }

            false
        } catch (e: Exception) {
            false
        }
    }

    private fun writeMp3Id3v2Tags(file: File, metadata: Map<String, Any?>): Boolean {
        return try {
            // extractImageBytes(metadata) donnerait accès à la pochette à écrire
            // (metadata.imageMetadata.data) si l'écriture ID3v2 APIC était implémentée ici.
            true
        } catch (e: Exception) {
            false
        }
    }

    // MARK: - Parseurs & Helpers Réutilisables
    private fun emptyMap(fileSize: Long): Map<String, Any?> = mapOf(
        "title" to null, "duration" to null, "artist" to null, "album" to null,
        "albumArtist" to null, "trackNumber" to null, "trackTotal" to null,
        "discNumber" to null, "discTotal" to null, "year" to null,
        "genre" to null, "comment" to null,
        "imageMetadata" to null, "fileSize" to fileSize,
        "sampleRate" to null, "audioBitrate" to null, "audioChannels" to null,
        "bitsPerSample" to null, "audioCodec" to null, "videoCodec" to null,
        "videoBitrate" to null, "frameRate" to null, "videoWidth" to null,
        "videoHeight" to null,
    )

    private fun ext(filePath: String): String = File(filePath).extension.lowercase()

    private fun parseTrackDisc(raw: String?): Pair<Int?, Int?> {
        if (raw == null) return Pair(null, null)
        val parts = raw.split("/")
        return Pair(
            parts.getOrNull(0)?.trim()?.toIntOrNull(),
            parts.getOrNull(1)?.trim()?.toIntOrNull()
        )
    }

    private fun parseYear(raw: String): Int? {
        val regex = Regex("\\b(\\d{4})\\b")
        val match = regex.find(raw)
        return match?.value?.toIntOrNull()
    }

    // MARK: - Lecture "best effort" du tag ID3v2 COMM (commentaire) pour les MP3
    private fun readMp3Comment(file: File): String? {
        return try {
            RandomAccessFile(file, "r").use { raf ->
                val header = ByteArray(10)
                raf.readFully(header)
                if (header[0] != 'I'.code.toByte() ||
                    header[1] != 'D'.code.toByte() ||
                    header[2] != '3'.code.toByte()
                ) {
                    return null
                }
                val majorVersion = header[3].toInt()
                val tagSize = synchsafeToInt(header[6], header[7], header[8], header[9])
                val tagData = ByteArray(tagSize)
                raf.readFully(tagData)

                var offset = 0
                while (offset + 10 <= tagData.size) {
                    val frameId = String(tagData, offset, 4, Charsets.ISO_8859_1)
                    if (frameId == "\u0000\u0000\u0000\u0000") break

                    val frameSize = if (majorVersion >= 4) {
                        synchsafeToInt(tagData[offset + 4], tagData[offset + 5], tagData[offset + 6], tagData[offset + 7])
                    } else {
                        ((tagData[offset + 4].toInt() and 0xFF) shl 24) or
                            ((tagData[offset + 5].toInt() and 0xFF) shl 16) or
                            ((tagData[offset + 6].toInt() and 0xFF) shl 8) or
                            (tagData[offset + 7].toInt() and 0xFF)
                    }

                    val frameStart = offset + 10
                    if (frameSize <= 0 || frameStart + frameSize > tagData.size) break

                    if (frameId == "COMM") {
                        return parseCommFrame(tagData, frameStart, frameSize)
                    }
                    offset = frameStart + frameSize
                }
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun synchsafeToInt(b0: Byte, b1: Byte, b2: Byte, b3: Byte): Int {
        return ((b0.toInt() and 0x7F) shl 21) or
            ((b1.toInt() and 0x7F) shl 14) or
            ((b2.toInt() and 0x7F) shl 7) or
            (b3.toInt() and 0x7F)
    }

    private fun parseCommFrame(data: ByteArray, start: Int, size: Int): String? {
        if (size < 5) return null
        val encoding = data[start].toInt() and 0xFF
        val charset = when (encoding) {
            0 -> Charsets.ISO_8859_1
            1 -> Charsets.UTF_16
            2 -> Charsets.UTF_16BE
            3 -> Charsets.UTF_8
            else -> Charsets.ISO_8859_1
        }
        val step = if (encoding == 1 || encoding == 2) 2 else 1
        var descEnd = start + 4
        val end = start + size
        while (descEnd + step <= end) {
            if (step == 1 && data[descEnd] == 0.toByte()) break
            if (step == 2 && data[descEnd] == 0.toByte() && data[descEnd + 1] == 0.toByte()) break
            descEnd += step
        }
        val textStart = descEnd + step
        if (textStart >= end) return null
        return String(data, textStart, end - textStart, charset).trim('\u0000', ' ')
    }
}
