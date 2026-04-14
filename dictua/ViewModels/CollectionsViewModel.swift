import Foundation
import DictCore

final class CollectionsViewModel: ObservableObject {
    @Published var collections: [CollectionSummary] = []
    @Published var selectedCollection: CollectionDetail?
    @Published var isLoading = false
    @Published var error: String?
    @Published var successMessage: String?

    var isLoggedIn: Bool {
        tokenStorage.getAccessToken() != nil
    }

    private let apiClient: DictAPIClient
    private let tokenStorage: TokenStorage

    init(apiClient: DictAPIClient, tokenStorage: TokenStorage) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
    }

    func loadCollections() async {
        guard isLoggedIn else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let payload: CollectionListPayload = try await apiClient.request(
                path: "collections",
                method: .get,
                requiresAuth: true
            )
            collections = payload.items
        } catch let e as DictAPIError {
            error = e.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadDetail(id: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let detail: CollectionDetail = try await apiClient.request(
                path: "collections/\(id)",
                method: .get,
                requiresAuth: true
            )
            selectedCollection = detail
        } catch let e as DictAPIError {
            error = e.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    @discardableResult
    func createCollection(name: String, description: String? = nil) async -> CollectionSummary? {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let body = CreateCollectionRequest(name: name, description: description)
            let created: CollectionSummary = try await apiClient.request(
                path: "collections",
                method: .post,
                body: body,
                requiresAuth: true
            )
            await loadCollections()
            return created
        } catch let e as DictAPIError {
            error = e.message
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func addItem(collectionId: String, entryId: String) async -> Bool {
        error = nil
        do {
            let body = AddCollectionItemRequest(itemType: "entry", itemId: entryId)
            let _: CollectionOkResponse = try await apiClient.request(
                path: "collections/\(collectionId)/items",
                method: .post,
                body: body,
                requiresAuth: true
            )
            return true
        } catch let e as DictAPIError {
            error = e.message
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func removeItem(collectionId: String, itemId: String) async {
        error = nil
        do {
            let _: CollectionOkResponse = try await apiClient.request(
                path: "collections/\(collectionId)/items/\(itemId)",
                method: .delete,
                requiresAuth: true
            )
            // Refresh detail
            await loadDetail(id: collectionId)
        } catch let e as DictAPIError {
            error = e.message
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCollection(id: String) async {
        error = nil
        do {
            let _: CollectionOkResponse = try await apiClient.request(
                path: "collections/\(id)",
                method: .delete,
                requiresAuth: true
            )
            await loadCollections()
        } catch let e as DictAPIError {
            error = e.message
        } catch {
            self.error = error.localizedDescription
        }
    }
}
