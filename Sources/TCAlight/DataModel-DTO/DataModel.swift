//
//  DataModel.swift
//  TCAlight
//
//  Created by Yann Bonafons on 26/09/2026.
//

import Foundation

// MARK: - DataModel
/// DataModel represents the data manipulated in your app. It can be initialized from a DTO and can be transformed into a DTO
public nonisolated protocol DataModel: Equatable, Hashable where Self == Self.DTOType.DataModelType {
    associatedtype DTOType: DTO
    
    init(dto: DTOType)
}

public nonisolated extension DataModel {
    var dto: DTOType {
        DTOType(dataModel: self)
    }
}

// MARK: - DTO
/// All DTO struct are a mirror of the API / Storage. It can be initialized from a DataModel and can be transformed into a DataModel
public nonisolated protocol DTO: Codable, Sendable where Self == Self.DataModelType.DTOType {
    associatedtype DataModelType: DataModel
    
    init(dataModel: DataModelType)
}

public nonisolated extension DTO {
    var dataModel: DataModelType {
        DataModelType(dto: self)
    }
}
