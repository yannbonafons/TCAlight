import Testing
import Combine
import Dispatch
import Foundation
@testable import TCAlight

// MARK: - DataModel/DTO Test Fixtures

private nonisolated struct UserDataModel: DataModel {
    var name: String
    var age: Int

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    init(dto: UserDTO) {
        name = dto.name
        age = dto.age
    }
}

private nonisolated struct UserDTO: DTO {
    var name: String
    var age: Int

    init(dataModel: UserDataModel) {
        name = dataModel.name
        age = dataModel.age
    }
}

// MARK: - DataModel/DTO Tests

@Suite("DataModel & DTO")
struct DataModelDTOTests {
    @Test("DataModel exposes a matching DTO")
    func dataModelToDTO() {
        let model = UserDataModel(name: "Ada", age: 30)
        #expect(model.dto.name == "Ada")
        #expect(model.dto.age == 30)
    }

    @Test("DTO exposes a matching DataModel")
    func dtoToDataModel() {
        let dto = UserDTO(dataModel: UserDataModel(name: "Grace", age: 40))
        #expect(dto.dataModel.name == "Grace")
        #expect(dto.dataModel.age == 40)
    }

    @Test("DataModel -> DTO -> DataModel round trip preserves equality")
    func roundTrip() {
        let original = UserDataModel(name: "Alan", age: 25)
        #expect(original.dto.dataModel == original)
    }

    @Test("Array of DataModel computes matching array of DTO")
    func arrayDataModelToDTO() {
        let models = [UserDataModel(name: "A", age: 1), UserDataModel(name: "B", age: 2)]
        #expect(models.dto.map(\.name) == ["A", "B"])
    }

    @Test("Array of DTO computes matching array of DataModel")
    func arrayDTOToDataModel() {
        let dtos = [UserDTO(dataModel: UserDataModel(name: "A", age: 1))]
        #expect(dtos.dataModel == [UserDataModel(name: "A", age: 1)])
    }

    @Test("Array DTO initializer builds DTOs from DataModels")
    func arrayDTOInitializer() {
        let dtos = [UserDTO](dataModel: [UserDataModel(name: "A", age: 1)])
        #expect(dtos.map(\.name) == ["A"])
    }

    @Test("Array DataModel initializer builds DataModels from DTOs")
    func arrayDataModelInitializer() {
        let models = [UserDataModel](dto: [UserDTO(dataModel: UserDataModel(name: "A", age: 1))])
        #expect(models == [UserDataModel(name: "A", age: 1)])
    }

    @Test("Empty array of DataModel maps to empty array of DTO")
    func emptyArrayRoundTrip() {
        let models: [UserDataModel] = []
        #expect(models.dto.isEmpty)
    }

    @Test("Optional DataModel with value computes optional DTO")
    func optionalSomeDataModelToDTO() {
        let model: UserDataModel? = UserDataModel(name: "Ada", age: 30)
        #expect(model.dto?.name == "Ada")
    }

    @Test("Optional DataModel nil computes nil DTO")
    func optionalNoneDataModelToDTO() {
        let model: UserDataModel? = nil
        #expect(model.dto == nil)
    }

    @Test("Optional DTO with value computes optional DataModel")
    func optionalSomeDTOToDataModel() {
        let dto: UserDTO? = UserDTO(dataModel: UserDataModel(name: "Ada", age: 30))
        #expect(dto.dataModel?.name == "Ada")
    }

    @Test("Optional DTO nil computes nil DataModel")
    func optionalNoneDTOToDataModel() {
        let dto: UserDTO? = nil
        #expect(dto.dataModel == nil)
    }

    @Test("Optional DTO initializer builds a DTO from a DataModel")
    func optionalDTOInitializer() {
        let dto = UserDTO?(dataModel: UserDataModel(name: "Ada", age: 30))
        #expect(dto?.name == "Ada")
    }

    @Test("Optional DataModel initializer builds a DataModel from a DTO")
    func optionalDataModelInitializer() {
        let model = UserDataModel?(dto: UserDTO(dataModel: UserDataModel(name: "Ada", age: 30)))
        #expect(model?.name == "Ada")
    }
}
