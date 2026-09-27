import Testing
import Combine
import Dispatch
import Foundation
@testable import TCAlight

// MARK: - PersistableState Test Fixtures

private actor MockPersistenceStorage {
    private var storage: [String: Data] = [:]

    func save(_ data: Data, key: String) {
        storage[key] = data
    }

    func load(key: String) -> Data? {
        storage[key]
    }

    func delete(key: String) {
        storage.removeValue(forKey: key)
    }
}

private let mockPersistenceStorage = MockPersistenceStorage()

private nonisolated struct StoredValueDataModel: DataModel {
    var value: Int

    init(value: Int) {
        self.value = value
    }

    init(dto: StoredValueDTO) {
        value = dto.value
    }
}

private nonisolated struct StoredValueDTO: DTO {
    var value: Int

    init(dataModel: StoredValueDataModel) {
        value = dataModel.value
    }
}

private nonisolated struct PersistableCounterState: StateWithActionProtocol, PersistableState {
    typealias ActionType = PersistableCounterAction
    typealias DataModelType = StoredValueDataModel

    var dataModel: StoredValueDataModel
    let storageKey: String

    func persistData() async throws {
        let data = try JSONEncoder().encode(persistedDTO)
        await mockPersistenceStorage.save(data, key: storageKey)
    }

    func getSavedData() async throws -> StoredValueDataModel? {
        guard let data = await mockPersistenceStorage.load(key: storageKey) else {
            return nil
        }
        return try JSONDecoder().decode(StoredValueDTO.self, from: data).dataModel
    }

    func deleteSavedData() async {
        await mockPersistenceStorage.delete(key: storageKey)
    }
}

private nonisolated enum PersistableCounterAction: ActionProtocol {
    typealias StateType = PersistableCounterState
    case increment

    static func reducer(state: inout PersistableCounterState, with action: Self) {
        switch action {
        case .increment:
            state.dataModel.value += 1
        }
    }
}

// MARK: - PersistableState Tests
@Suite("PersistableState")
struct PersistableStateTests {
    @Test("Default canBePersisted is true")
    func defaultCanBePersisted() {
        let state = PersistableCounterState(dataModel: .init(value: 0), storageKey: "test")
        #expect(state.canBePersisted)
    }

    @Test("Default canBeAutoloaded is false")
    func defaultCanBeAutoloaded() {
        let state = PersistableCounterState(dataModel: .init(value: 0), storageKey: "test")
        #expect(!state.canBeAutoloaded)
    }

    @Test("Default canRetrieveSavedData is true")
    func defaultCanRetrieveSavedData() {
        let state = PersistableCounterState(dataModel: .init(value: 0), storageKey: "test")
        #expect(state.canRetrieveSavedData)
    }

    @Test("persistedDTO mirrors the current dataModel")
    func persistedDTO() {
        let state = PersistableCounterState(dataModel: .init(value: 7), storageKey: "test")
        #expect(state.persistedDTO.value == 7)
    }

    @Test("Saved data can be retrieved with the same value")
    func saveAndRetrieveRoundTrip() async throws {
        let key = UUID().uuidString
        let state = PersistableCounterState(dataModel: .init(value: 99), storageKey: key)

        try await state.persistData()
        let retrieved = try await state.getSavedData()

        #expect(retrieved?.value == 99)
    }

    @Test("Deleting saved data clears it from storage")
    func deleteRemovesSavedValue() async throws {
        let key = UUID().uuidString
        let state = PersistableCounterState(dataModel: .init(value: 5), storageKey: key)

        try await state.persistData()
        await state.deleteSavedData()
        let retrieved = try await state.getSavedData()

        #expect(retrieved == nil)
    }

    @Test("Retrieving without saving returns nil")
    func retrieveWithoutSave() async throws {
        let key = UUID().uuidString
        let state = PersistableCounterState(dataModel: .init(value: 0), storageKey: key)

        let retrieved = try await state.getSavedData()

        #expect(retrieved == nil)
    }
}

// MARK: - Store.loadState Tests
@MainActor
@Suite("Store.loadState")
struct StoreLoadStateTests {
    @Test("loadState applies previously saved data")
    func loadsSavedData() async throws {
        let key = UUID().uuidString
        let state = PersistableCounterState(dataModel: .init(value: 1), storageKey: key)
        try await state.persistData()

        let store = Store(PersistableCounterState(dataModel: .init(value: 0), storageKey: key))
        await store.loadState()

        #expect(store.state.dataModel.value == 1)
    }

    @Test("loadState is a no-op when nothing was saved")
    func noSavedData() async {
        let key = UUID().uuidString
        let store = Store(PersistableCounterState(dataModel: .init(value: 3), storageKey: key))
        await store.loadState()

        #expect(store.state.dataModel.value == 3)
    }

    @Test("loadState notifies observers when the loaded value differs")
    func loadStateNotifiesObservers() async throws {
        let key = UUID().uuidString
        let state = PersistableCounterState(dataModel: .init(value: 10), storageKey: key)
        try await state.persistData()

        let store = Store(PersistableCounterState(dataModel: .init(value: 0), storageKey: key))
        var received: [Int] = []
        let cancellable = store.observe { received.append($0.dataModel.value) }

        await store.loadState()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(received == [0, 10])
        _ = cancellable
    }

    @Test("trigger still mutates state normally for a PersistableState")
    func triggerStillWorks() {
        let store = Store(PersistableCounterState(dataModel: .init(value: 0), storageKey: "trigger-test"))
        store.trigger(.increment)
        #expect(store.state.dataModel.value == 1)
    }
}
