import Foundation

/// Writes the NumPy .npy v1.0 format directly so `np.load()` on the Python
/// side needs no conversion step. Only single-channel 2D float32/uint8
/// arrays are needed here (depth in metres, confidence level per pixel).
enum NPYWriter {

    static func writeFloat32(_ values: [Float32], shape: (rows: Int, cols: Int), to url: URL) throws {
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        try write(data: data, dtype: "<f4", shape: shape, to: url)
    }

    static func writeUInt8(_ values: [UInt8], shape: (rows: Int, cols: Int), to url: URL) throws {
        try write(data: Data(values), dtype: "|u1", shape: shape, to: url)
    }

    private static func write(data: Data, dtype: String, shape: (rows: Int, cols: Int), to url: URL) throws {
        let dict = "{'descr': '\(dtype)', 'fortran_order': False, 'shape': (\(shape.rows), \(shape.cols)), }"
        let magic: [UInt8] = [0x93] + Array("NUMPY".utf8)
        let version: [UInt8] = [1, 0]

        var headerBytes = Array(dict.utf8)
        // Total preamble+header length must be a multiple of 64 bytes and end in '\n' (NPY v1.0 spec).
        let preambleLength = magic.count + version.count + 2 // 2-byte header-length field for v1.0
        let unpaddedTotal = preambleLength + headerBytes.count + 1
        let padding = (64 - (unpaddedTotal % 64)) % 64
        headerBytes.append(contentsOf: Array(repeating: UInt8(ascii: " "), count: padding))
        headerBytes.append(UInt8(ascii: "\n"))

        let headerLen = UInt16(headerBytes.count)
        var fileData = Data(magic)
        fileData.append(contentsOf: version)
        fileData.append(UInt8(headerLen & 0xFF))
        fileData.append(UInt8((headerLen >> 8) & 0xFF))
        fileData.append(contentsOf: headerBytes)
        fileData.append(data)

        try fileData.write(to: url, options: .atomic)
    }
}
