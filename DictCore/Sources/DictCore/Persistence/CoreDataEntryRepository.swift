import Foundation
import CoreData

/// Core Data implementation of EntryRepository for iOS 16.
public final class CoreDataEntryRepository: EntryRepository, @unchecked Sendable {
    public static let maxCachedEntries = 1000
    private let container: NSPersistentContainer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "lexykon.entryrepo.coredata")

    public init(storeURL: URL? = nil) {
        let model = Self.createModel()
        let container = NSPersistentContainer(name: "CachedEntryModel", managedObjectModel: model)
        if let url = storeURL {
            let desc = NSPersistentStoreDescription(url: url)
            desc.type = NSSQLiteStoreType
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data load failed: \(error)")
            }
        }
        self.container = container
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "CachedEntry"
        entity.properties = [
            NSAttributeDescription(name: "entryId", attributeType: .stringAttributeType).then { $0.isOptional = false },
            NSAttributeDescription(name: "lemma", attributeType: .stringAttributeType).then { $0.isOptional = true },
            NSAttributeDescription(name: "pos", attributeType: .stringAttributeType).then { $0.isOptional = true },
            NSAttributeDescription(name: "tier", attributeType: .stringAttributeType).then { $0.isOptional = true },
            NSAttributeDescription(name: "cachedJSON", attributeType: .binaryDataAttributeType).then { $0.isOptional = false },
            NSAttributeDescription(name: "lastAccessedAt", attributeType: .dateAttributeType).then { $0.isOptional = false },
            NSAttributeDescription(name: "isFavorited", attributeType: .booleanAttributeType).then { $0.isOptional = true; $0.defaultValue = false },
        ]
        model.entities = [entity]
        return model
    }

    public func fetchEntry(id: String) async throws -> EntryDetail? {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<EntryDetail?, Error>) in
            queue.async { [weak self] in
                guard let self = self else { return cont.resume(returning: nil) }
                let ctx = self.container.newBackgroundContext()
                ctx.perform {
                    let req = NSFetchRequest<NSManagedObject>(entityName: "CachedEntry")
                    req.predicate = NSPredicate(format: "entryId == %@", id)
                    req.fetchLimit = 1
                    do {
                        let results = try ctx.fetch(req)
                        guard let obj = results.first,
                              let data = obj.value(forKey: "cachedJSON") as? Data else {
                            return cont.resume(returning: nil)
                        }
                        try self.recordAccessSync(ctx: ctx, entryId: id)
                        let entry = try? self.decoder.decode(EntryDetail.self, from: data)
                        cont.resume(returning: entry)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func saveEntry(_ entry: EntryDetail, isFavorited: Bool = false) async throws {
        let data = try encoder.encode(entry)
        let id = entry.id ?? ""
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else { return cont.resume() }
                let ctx = self.container.newBackgroundContext()
                ctx.perform {
                    do {
                        let req = NSFetchRequest<NSManagedObject>(entityName: "CachedEntry")
                        req.predicate = NSPredicate(format: "entryId == %@", id)
                        req.fetchLimit = 1
                        let results = try ctx.fetch(req)
                        let obj: NSManagedObject
                        if let existing = results.first {
                            obj = existing
                        } else {
                            obj = NSManagedObject(entity: NSEntityDescription.entity(forEntityName: "CachedEntry", in: ctx)!, insertInto: ctx)
                            obj.setValue(id, forKey: "entryId")
                        }
                        obj.setValue(entry.lemma?.lemma, forKey: "lemma")
                        obj.setValue(entry.lemma?.pos, forKey: "pos")
                        obj.setValue(entry.tier, forKey: "tier")
                        obj.setValue(data, forKey: "cachedJSON")
                        obj.setValue(Date(), forKey: "lastAccessedAt")
                        obj.setValue(isFavorited, forKey: "isFavorited")
                        try ctx.save()
                        self.evictIfNeeded(ctx: ctx)
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func recordAccess(entryId: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else { return cont.resume() }
                let ctx = self.container.newBackgroundContext()
                ctx.perform {
                    do {
                        try self.recordAccessSync(ctx: ctx, entryId: entryId)
                        try ctx.save()
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func recordAccessSync(ctx: NSManagedObjectContext, entryId: String) throws {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CachedEntry")
        req.predicate = NSPredicate(format: "entryId == %@", entryId)
        req.fetchLimit = 1
        let results = try ctx.fetch(req)
        results.first?.setValue(Date(), forKey: "lastAccessedAt")
    }

    public func removeAllEntries() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else { return cont.resume() }
                let ctx = self.container.newBackgroundContext()
                ctx.perform {
                    do {
                        let req = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedEntry")
                        let del = NSBatchDeleteRequest(fetchRequest: req)
                        try ctx.execute(del)
                        try ctx.save()
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func evictIfNeeded(ctx: NSManagedObjectContext) {
        let req = NSFetchRequest<NSManagedObject>(entityName: "CachedEntry")
        req.sortDescriptors = [NSSortDescriptor(key: "lastAccessedAt", ascending: true)]
        req.fetchBatchSize = 1
        do {
            let countReq = NSFetchRequest<NSManagedObject>(entityName: "CachedEntry")
            let count = try ctx.count(for: countReq)
            if count > Self.maxCachedEntries {
                req.fetchLimit = count - Self.maxCachedEntries
                let toDelete = try ctx.fetch(req)
                toDelete.forEach { ctx.delete($0) }
                try? ctx.save()
            }
        } catch {}
    }
}

private extension NSAttributeDescription {
    func then(_ block: (NSAttributeDescription) -> Void) -> NSAttributeDescription {
        block(self)
        return self
    }
}
