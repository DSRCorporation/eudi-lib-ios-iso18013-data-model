//
//  Extensions.swift


import Foundation
import SwiftCBOR

extension String {
	public var hex_decimal: Int {
		return Int(self, radix: 16)!
	}
	
	subscript (bounds: CountableClosedRange<Int>) -> String {
		let start = index(startIndex, offsetBy: bounds.lowerBound)
		let end = index(startIndex, offsetBy: bounds.upperBound)
		return String(self[start...end])
	}
	
	subscript (bounds: CountableRange<Int>) -> String {
		let start = index(startIndex, offsetBy: bounds.lowerBound)
		let end = index(startIndex, offsetBy: bounds.upperBound)
		return String(self[start..<end])
	}
	
	public var byteArray: [UInt8] {
		var res = [UInt8]()
		for offset in stride(from: 0, to: count, by: 2) {
			let byte = self[offset..<offset+2].hex_decimal
			res.append(UInt8(byte))
		}
		return res
	}
	var fullDateEncoded: CBOR {
		CBOR.tagged(CBOR.Tag(rawValue: 1004), .utf8String(self))
	}
	
	public func toBytes() -> [UInt8]? {
		let length = count
		if length & 1 != 0 {
			return nil
		}
		var bytes = [UInt8]()
		bytes.reserveCapacity(length/2)
		var index = startIndex
		for _ in 0..<length/2 {
			let nextIndex = self.index(index, offsetBy: 2)
			if let b = UInt8(self[index..<nextIndex], radix: 16) {
				bytes.append(b)
			} else {
				return nil
			}
			index = nextIndex
		}
		return bytes
	}
}

extension Data {
	public var bytes: Array<UInt8> {
		Array(self)
	}
}

extension Array where Element == UInt8 {
	public func toHexString() -> String {
		`lazy`.reduce(into: "") {
			var s = String($1, radix: 16)
			if s.count == 1 {s = "0" + s }
			$0 += s
		}
	}
}

extension Array where Element == UInt8 {
	var hex: String {
		var str = ""
		for byte in self {
			str = str.appendingFormat("%02X", UInt(byte))
		}
		return str
	}
	public var taggedEncoded: CBOR {
		CBOR.tagged(.encodedCBORDataItem, .byteString(self))
	}
}

extension CBOREncodable {
	public func encode(options: SwiftCBOR.CBOROptions) -> [UInt8] {
		toCBOR(options: CBOROptions()).encode()
	}
	public var taggedEncoded: CBOR {
		CBOR.tagged(.encodedCBORDataItem, .byteString(CBOR.encode(self)))
	}
}

extension CBORDecodable {
	public init?(data: [UInt8]) {
		guard let obj = try? CBOR.decode(data) else { return nil }
		self.init(cbor: obj)
	}
}

extension CBOR {
	public func decodeTaggedBytes() -> [UInt8]? {
		guard case let CBOR.tagged(tag, cborEncoded) = self, tag == .encodedCBORDataItem, case let .byteString(bytes) = cborEncoded else {  return nil }
		return bytes
	}
	public func decodeTagged<T: CBORDecodable>(_ t: T.Type = T.self) -> T? {
		guard case let CBOR.tagged(tag, cborEncoded) = self, tag == .encodedCBORDataItem, case let .byteString(bytes) = cborEncoded else {  return nil }
		return .init(data: bytes)
	}
	
	public func decodeFullDate() -> String? {
		guard case let CBOR.tagged(tag, cborEncoded) = self, tag.rawValue == 1004, case let .utf8String(s) = cborEncoded else { return nil }
		return s
	}
}

extension CBOR {
	
	// ======================================================================
	// MARK: - Public
	// ======================================================================
	
	// MARK: - Public Methods
	
	public func unwrap() -> Any? {
		switch self {
		case .simple(let value): return value
		case .boolean(let value): return value
		case .byteString(let value): return value
		case .date(let value): return value
		case .double(let value): return value
		case .float(let value): return value
		case .half(let value): return value
		case .tagged(let tag, let cbor): return (tag, cbor)
		case .array(let array): return array
		case .map(let map): return map
		case .utf8String(let value): return value
		case .negativeInt(let value): return value
		case .unsignedInt(let value): return value
		default:
			return nil
		}
	}
	
	public func asUInt64() -> UInt64? {
		return self.unwrap() as? UInt64
	}
	
	public func asDouble() -> Double? {
		return self.unwrap() as? Double
	}
	
	public func asInt64() -> Int64? {
		return self.unwrap() as? Int64
	}
	
	public func asString() -> String? {
		return self.unwrap() as? String
	}
	
	public func asList() -> [CBOR]? {
		return self.unwrap() as? [CBOR]
	}
	
	public func asMap() -> [CBOR:CBOR]? {
		return self.unwrap() as? [CBOR:CBOR]
	}
	
	public func asBytes() -> [UInt8]? {
		return self.unwrap() as? [UInt8]
	}
	
	public func asData() -> Data {
		return Data(self.encode())
	}
	
	public func asCose() -> (CBOR.Tag, [CBOR])? {
		guard let rawCose =  self.unwrap() as? (CBOR.Tag, CBOR),
			  let cosePayload = rawCose.1.asList() else {
			return nil
		}
		return (rawCose.0, cosePayload)
	}
	
	public func decodeBytestring() -> CBOR? {
		guard let bytestring = self.asBytes(),
			  let decoded = try? CBORDecoder(input: bytestring).decodeItem() else {
			return nil
		}
		return decoded
	}
}

/// Methods to cast collections of CBOR types in the form of the dictionary/list
extension CBOR {
	
	// ======================================================================
	// MARK: - Public
	// ======================================================================
	
	// MARK: - Public Properties
	
	public static func decodeList(_ list: [CBOR]) -> [Any] {
		var result = [Any]()
		
		for val in list {
			let unwrappedValue = val.unwrap()
			if let unwrappedValue = unwrappedValue as? [CBOR:CBOR] {
				result.append(decodeDictionary(unwrappedValue))
			} else if let unwrappedValue = unwrappedValue as? [CBOR] {
				result.append(decodeList(unwrappedValue))
			} else if let unwrappedValue = unwrappedValue {
				result.append(unwrappedValue)
			}
		}
		return result
	}
	
	public static func decodeDictionary(_ dictionary: [CBOR:CBOR]) -> [String: Any] {
		var payload = [String: Any]()
		
		for (key, val) in dictionary {
			if let key = key.asString() {
				let unwrappedValue = val.unwrap()
				if let unwrappedValue = unwrappedValue as? [CBOR:CBOR] {
					payload[key] = decodeDictionary(unwrappedValue)
				} else if let unwrappedValue = unwrappedValue as? [CBOR] {
					payload[key] = decodeList(unwrappedValue)
				} else if let unwrappedValue = unwrappedValue {
					payload[key] = unwrappedValue
				}
			}
		}
		return payload
	}
}

/// COSE Message Identification
extension CBOR.Tag {
	/// Tagged COSE Sign1 Structure
	public static let coseSign1Item = CBOR.Tag(rawValue: 18)
	/// Tagged COSE Mac0 Structure
	public static let coseMac0Item = CBOR.Tag(rawValue: 17)
}

// MARK: - Dictionary subscript extensions

extension Dictionary where Key == CBOR {
	public subscript<Index: RawRepresentable>(index: Index) -> Value? where Index.RawValue == String {
		self[CBOR(stringLiteral: index.rawValue)]
	}
	
	public subscript<Index: RawRepresentable>(index: Index) -> Value? where Index.RawValue == Int {
		self[CBOR(integerLiteral: index.rawValue)]
	}
}

public protocol CBORDecodable {
	init?(cbor: CBOR)
}

typealias DocType = String
typealias NameSpace = String
typealias DataElementIdentifier = String // Data element identifier
typealias DataElementValue = CBOR
typealias ErrorCode = UInt64
typealias DigestID = UInt64

public class BundleClass {}
