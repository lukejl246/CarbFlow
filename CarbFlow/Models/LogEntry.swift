import CoreData

@objc(LogEntry)
final class LogEntry: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<LogEntry> {
        NSFetchRequest<LogEntry>(entityName: "LogEntry")
    }

    @NSManaged var id: UUID
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var date: Date
    @NSManaged var servings: Double
    @NSManaged var foodName: String
    @NSManaged var brand: String?
    @NSManaged var upc: String?
    @NSManaged var carbs: Double
    @NSManaged var netCarbs: Double
    @NSManaged var fat: Double
    @NSManaged var protein: Double
    @NSManaged var kcal: Double
    @NSManaged var servingSizeGrams: NSNumber?
    @NSManaged var food: FoodItem?

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
        servings = 1.0
        date = now
    }

    override func willSave() {
        super.willSave()
        if hasChanges {
            updatedAt = Date()
        }
    }

    convenience init(
        context: NSManagedObjectContext,
        food: FoodItem,
        servings: Double,
        date: Date = Date()
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "LogEntry", in: context)!
        self.init(entity: entity, insertInto: context)
        self.food = food
        self.foodName = food.name
        self.brand = food.brand
        self.upc = food.upc
        self.servings = servings
        self.date = date
        self.carbs = food.carbs * servings
        self.netCarbs = food.netCarbs * servings
        self.fat = food.fat * servings
        self.protein = food.protein * servings
        self.kcal = food.kcal * servings
        if let baseServing = food.servingSize {
            self.servingSize = baseServing * servings
        }
    }
}
