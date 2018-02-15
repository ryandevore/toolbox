//  UUCoreData
//  Useful Utilities - Helpful methods for Core Data
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

import UIKit
import CoreData

public class UUCoreData: NSObject
{
    public var mainThreadContext : NSManagedObjectContext?
    public var storeCoordinator : NSPersistentStoreCoordinator?
    
    init(url: URL, modelDefinitionBundle: Bundle = Bundle.main)
    {
        super.init()
        configure(url: url, modelDefinitionBundle: modelDefinitionBundle)
    }
    
    init(url: URL, model: NSManagedObjectModel)
    {
        super.init()
        configure(url: url, model: model)
    }
    
    private func configure(url: URL, modelDefinitionBundle: Bundle = Bundle.main)
    {
        let mom : NSManagedObjectModel? = NSManagedObjectModel.mergedModel(from: [modelDefinitionBundle])
        if (mom == nil)
        {
            UUDebugLog("WARNING! Unable to create managed object model!")
            return
        }
        
        configure(url: url, model: mom!)
    }
    
    private func configure(url: URL, model: NSManagedObjectModel)
    {
        let options : [AnyHashable:Any] =
        [
            NSMigratePersistentStoresAutomaticallyOption : true,
            NSInferredMappingModelError: true
        ]
        
        storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        do
        {
            try storeCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
        }
        catch (let err)
        {
            UUDebugLog("Error setting up CoreData: %@", String(describing: err))
            
            do
            {
                try FileManager.default.removeItem(at: url)
                
                try storeCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
            }
            catch (let innerError)
            {
                UUDebugLog("Error Clearing CoreData: %@", String(describing: innerError))
            }
        }
        
        mainThreadContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainThreadContext?.persistentStoreCoordinator = storeCoordinator
        
        NotificationCenter.default.addObserver(self, selector: #selector(otherContextDidSave), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    func shutdown()
    {
        mainThreadContext = nil
        storeCoordinator = nil
    }
    
    @objc public func otherContextDidSave(notification: Notification)
    {
        let destContext : NSManagedObjectContext? = mainThreadContext
        
        if (destContext != nil)
        {
            let savedContext : NSManagedObjectContext? = notification.object as? NSManagedObjectContext
            if (savedContext != nil)
            {
                if (savedContext != destContext && savedContext!.persistentStoreCoordinator == mainThreadContext!.persistentStoreCoordinator)
                {
                    destContext!.perform
                    {
                        UUDebugLog("Merging changes from background context")
                        destContext!.mergeChanges(fromContextDidSave: notification)
                    }
                }
            }
        }
    }
    
    public func workerThreadContext() -> NSManagedObjectContext
    {
        let moc : NSManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        moc.persistentStoreCoordinator = storeCoordinator
        return moc
    }
}

public extension NSManagedObjectContext
{
    public func uuSubmitChanges() -> Error?
    {
        var error: Error? = nil
        
        if (hasChanges)
        {
            performAndWait
            {
                do
                {
                    try self.save()
                }
                catch (let err)
                {
                    error = err
                    UUDebugLog("Error saving core data: %@", String(describing: err))
                }
            }
        }
        
        return error
    }
    
    public func uuDeleteObjects(_ list: [Any])
    {
        performAndWait
        {
            for obj in list
            {
                if (obj is NSManagedObject)
                {
                    self.delete(obj as! NSManagedObject)
                }
            }
        }
    }
    
    public func uuDeleteAllObjects()
    {
        performAndWait
        {
            let entityList = self.persistentStoreCoordinator?.managedObjectModel.entitiesByName
            
            for entity in entityList!
            {
                let fr = NSFetchRequest<NSFetchRequestResult>()
                fr.entity = NSEntityDescription.entity(forEntityName: entity.key, in: self)
                
                do
                {
                    let objects = try self.fetch(fr)
                    for obj in objects
                    {
                        if (obj is NSManagedObject)
                        {
                            self.delete(obj as! NSManagedObject)
                        }
                    }
                }
                catch (let err)
                {
                    UUDebugLog("Error deleting all objects: %@", String(describing: err))
                }
            }
        }
    }
}

extension NSError
{
    func uuLogDetailedErrors()
    {
        UUDebugLog("ERROR: %@", localizedDescription)
        
        let detailedErrors = userInfo[NSDetailedErrorsKey] as? [NSError]
        if (detailedErrors != nil)
        {
            for de in detailedErrors!
            {
                UUDebugLog("  DetailedError: %@", de.userInfo)
            }
        }
        else
        {
            UUDebugLog("  %@", userInfo)
        }
    }
}

public extension NSManagedObject
{
    public static var uuEntityName : String
    {
        return String(describing: self)
    }
    
    public static func uuFetchRequest(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        offset: Int? = nil,
        limit: Int? = nil,
        context: NSManagedObjectContext) -> NSFetchRequest<NSFetchRequestResult>
    {
        let fr = NSFetchRequest<NSFetchRequestResult>()
        fr.entity = NSEntityDescription.entity(forEntityName: uuEntityName, in: context)
        fr.sortDescriptors = sortDescriptors
        fr.predicate = predicate
        
        if (offset != nil)
        {
            fr.fetchOffset = offset!
        }
        
        if (limit != nil)
        {
            fr.fetchLimit = limit!
        }
        
        return fr
    }
    
    public static func uuFetchObjects(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        offset: Int? = nil,
        limit: Int? = nil,
        context: NSManagedObjectContext) -> [Any]
    {
        let fr = uuFetchRequest(predicate: predicate, sortDescriptors: sortDescriptors, offset: offset, limit: limit, context: context)
        
        var results : [Any] = []
        
        context.performAndWait
        {
            do
            {
                results = try context.fetch(fr)
            }
            catch (let err)
            {
                (err as NSError).uuLogDetailedErrors()
            }
        }
        
        return results
    }
    
    public class func uuFetchSingleObject(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        context: NSManagedObjectContext) -> Self?
    {
        return uuFetchSingleObjectInternal(predicate: predicate,  sortDescriptors: sortDescriptors, context: context)
    }
    
    private class func uuFetchSingleObjectInternal<T>(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        context: NSManagedObjectContext) -> T?
    {
        let list = uuFetchObjects(predicate: predicate, sortDescriptors: sortDescriptors, offset: nil, limit: 1, context: context)
        
        var single : Any? = nil
        
        if (list.count > 0)
        {
            single = list[0]
        }
        
        return single as? T
    }
    
    public static func uuFetchOrCreate(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        context: NSManagedObjectContext) -> Self
    {
        var obj = uuFetchSingleObject(predicate: predicate, sortDescriptors: sortDescriptors, context: context)
        
        context.performAndWait
        {
            if (obj == nil)
            {
                obj = uuCreate(context: context)
            }
        }
        
        return obj!
    }
    
    public class func uuCreate(
        context: NSManagedObjectContext) -> Self
    {
        return uuCreateInternal(context: context)
    }
    
    private class func uuCreateInternal<T>(context: NSManagedObjectContext) -> T
    {
        var obj : T? = nil
        
        context.performAndWait
        {
            obj = NSEntityDescription.insertNewObject(forEntityName: uuEntityName, into: context) as? T
        }
        
        return obj!
        
    }
    
    public static func uuDeleteObjects(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext)
    {
        context.performAndWait
        {
            let list = uuFetchObjects(predicate: predicate, context: context)
            
            for obj in list
            {
                if (obj is NSManagedObject)
                {
                    context.delete(obj as! NSManagedObject)
                }
            }
        }
    }
    
    public static func uuCountObjects(
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext) -> Int
    {
        let fr = uuFetchRequest(predicate: predicate, context: context)
        
        var count : Int = 0
        
        context.performAndWait
        {
            do
            {
                count = try context.count(for: fr)
            }
            catch (let err)
            {
                (err as NSError).uuLogDetailedErrors()
            }
        }
        
        return count
    }
}


public extension UUCoreData
{
    private static var sharedStore : UUCoreData? = nil
    
    public static func configure(url: URL, modelDefinitionBundle: Bundle = Bundle.main)
    {
        sharedStore = UUCoreData(url: url, modelDefinitionBundle: modelDefinitionBundle)
    }
    
    public static var shared : UUCoreData?
    {
        return sharedStore
    }
    
    public static var mainThreadContext: NSManagedObjectContext?
    {
        return shared?.mainThreadContext
    }
    
    public static func workerThreadContext() -> NSManagedObjectContext?
    {
        return shared?.workerThreadContext()
    }
    
    public static func destroyStore(at url: URL)
    {
        do
        {
            try FileManager.default.removeItem(at: url)
        }
        catch (let err)
        {
            UUDebugLog("Error deleting store file: \(err)")
        }
        
        shared?.shutdown()
    }
}
