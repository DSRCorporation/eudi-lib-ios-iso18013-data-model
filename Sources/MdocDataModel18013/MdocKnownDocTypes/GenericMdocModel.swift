//
//  GenericMdocModel.swift

import Foundation

public struct GenericMdocModel: MdocDecodable {
	public var id: String = UUID().uuidString
	public var createdAt: Date = Date()
 	public var response: DeviceResponse?
	public var devicePrivateKey: CoseKeyPrivate?
	public var docType: String
	public var nameSpaces: [NameSpace]? 
	public var title: String
	public var ageOverXX = [Int: Bool]()
	public var displayStrings = [NameValue]()
	public var displayImages = [NameImage]()
    public var mandatoryElementKeys: [DataElementIdentifier] = []
}

extension GenericMdocModel {
	public init?(id: String, createdAt: Date, response: DeviceResponse, devicePrivateKey: CoseKeyPrivate, docType: String, title: String) {
		self.id = id; self.createdAt = createdAt
		self.response = response; self.devicePrivateKey = devicePrivateKey; self.docType = docType; self.title = title
		guard let nameSpaces = Self.getSignedItems(response, docType) else { return nil }
		Self.extractDisplayStrings(nameSpaces, &displayStrings, &displayImages)
	}
} // end extension
