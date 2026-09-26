//
//  Optional+DataModel.swift
//  TCAlight
//
//  Created by Yann Bonafons on 26/09/2026.
//

nonisolated extension Optional: DTO where Wrapped: DTO {
    public init(dataModel: Wrapped.DataModelType?) {
        self = dataModel.map({ $0.dto })
    }
    
    public var dataModel: Wrapped.DataModelType? {
        map(\.dataModel)
    }
}

nonisolated extension Optional: DataModel where Wrapped: DataModel {
    public init(dto: Wrapped.DTOType?) {
        self = dto.map({ $0.dataModel })
    }
    
    public var dto: Wrapped.DTOType? {
        map(\.dto)
    }
}
