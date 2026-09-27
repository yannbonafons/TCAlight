//
//  Array+DataModel.swift
//  TCAlight
//
//  Created by Yann Bonafons on 26/09/2026.
//

nonisolated extension Array: DTO where Element: DTO {
    public init(dataModel: [Element.DataModelType]) {
        self = dataModel.map({ $0.dto })
    }
    
    public var dataModel: [Element.DataModelType] {
        map(\.dataModel)
    }
}

nonisolated extension Array: DataModel where Element: DataModel {
    public init(dto: [Element.DTOType]) {
        self = dto.map({ $0.dataModel })
    }
    
    public var dto: [Element.DTOType] {
        map(\.dto)
    }
}
