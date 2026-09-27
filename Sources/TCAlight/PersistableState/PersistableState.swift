//
//  PersistableState.swift
//  TCAlight
//
//  Created by Yann Bonafons on 26/09/2026.
//

/// Conform your State to PersistableState to make it persistent if needed. To load the data, use the function `loadState()`of the corresponding Store
public protocol PersistableState {
    associatedtype DataModelType: DataModel

    /// Value own by the State. Must be conformed to DataModel
    var dataModel: DataModelType { get set }
    /// Provide the key to save and load data
    var storageKey: String { get }
    /// Data can be saved (ie `persistData` will do something)
    var canBePersisted: Bool { get }
    /// Data should be loaded when app enter foreground (logic is not providedin the module)
    var canBeAutoloaded: Bool { get }
    /// Data can be retrived (ie `getSavedData can return a value)
    var canRetrieveSavedData: Bool { get }
    
    /// Save the Data. Use persistedDTO which is codable
    func persistData() async throws
    /// Retrieve the saved data. It should be a dto so use the computed dataModel
    func getSavedData() async throws -> DataModelType?
    /// Delete the saved data
    func deleteSavedData() async
}

/// Default values
public extension PersistableState {
    var persistedDTO: DataModelType.DTOType {
        dataModel.dto
    }
    
    var canBePersisted: Bool {
        true
    }
    
    var canBeAutoloaded: Bool {
        false
    }
    
    var canRetrieveSavedData: Bool {
        true
    }
}
