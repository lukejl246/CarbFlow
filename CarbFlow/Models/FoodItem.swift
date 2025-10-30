import CoreData

@objc(FoodItem)
final class FoodItem: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FoodItem> {
        NSFetchRequest<FoodItem>(entityName: "FoodItem")
    }

    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var brand: String?
    @NSManaged var servingSizeGrams: NSNumber?
    @NSManaged var carbs: Double
    @NSManaged var netCarbs: Double
    @NSManaged var fat: Double
    @NSManaged var protein: Double
    @NSManaged var kcal: Double
    @NSManaged var upc: String?
    @NSManaged var isUserCreated: Bool
    @NSManaged var isVerified: Bool
    @NSManaged var internalReviewNote: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    var servingSize: Double? {
        get { servingSizeGrams?.doubleValue }
        set { servingSizeGrams = newValue.map(NSNumber.init(value:)) }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        id = UUID()
        createdAt = now
        updatedAt = now
        isUserCreated = false
        isVerified = false
    }

    override func willSave() {
        super.willSave()
        if hasChanges && !changedValues().keys.contains("updatedAt") {
            setPrimitiveValue(Date(), forKey: "updatedAt")
        }
    }

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        servingSize: Double? = nil,
        carbs: Double,
        netCarbs: Double,
        fat: Double,
        protein: Double,
        kcal: Double,
        upc: String? = nil,
        isVerified: Bool = false,
        internalReviewNote: String? = nil,
        isUserCreated: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "FoodItem", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.name = name
        self.brand = brand
        self.servingSize = servingSize
        self.carbs = carbs
        self.netCarbs = netCarbs
        self.fat = fat
        self.protein = protein
        self.kcal = kcal
        self.upc = upc
        self.isVerified = isVerified
        self.internalReviewNote = internalReviewNote
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
