import Foundation

/// 第二批新增100种家具。稳定造型ID用于保存，分类与同义词只负责筛选。
nonisolated enum FurnitureExpansionCatalog {
    private static func item(_ id: String, _ name: String, _ category: FurnitureCategory,
                             _ width: Int = 1, _ depth: Int = 1, keywords: [String] = []) -> FurnitureConfig {
        let icon: String
        switch category {
        case .bedroom: icon = "bed.double"
        case .livingRoom: icon = "sofa"
        case .study: icon = "books.vertical"
        case .kitchen: icon = "table.furniture"
        case .bathroom: icon = "washer"
        case .storage: icon = "cabinet"
        case .appliances: icon = "tv"
        case .childrenAndPets: icon = "pawprint"
        case .outdoor: icon = "leaf"
        case .lighting: icon = "lamp.floor"
        }
        return FurnitureConfig(name: name, icon: icon, imageName: id, width: width, depth: depth,
                               category: category, searchKeywords: keywords, isNew: true)
    }

    static let all: [FurnitureConfig] = [
        // 卧室：床型、衣物整理与床边收纳（12种）。
        item("single-bed", "单人床", .bedroom, 1, 2),
        item("bunk-bed", "上下铺", .bedroom, 1, 2, keywords: ["双层床", "高低床"]),
        item("loft-bed", "高架床", .bedroom, 1, 2, keywords: ["上床下桌"]),
        item("tatami-bed", "榻榻米", .bedroom, 2, 2, keywords: ["地台床"]),
        item("crib", "婴儿床", .bedroom, 1, 2, keywords: ["宝宝床"]),
        item("daybed", "贵妃榻", .bedroom, 2, 1, keywords: ["躺椅", "休息床"]),
        item("bedroom-bench", "床尾凳", .bedroom, 2, 1),
        item("blanket-chest", "被褥箱", .bedroom, 2, 1, keywords: ["被子", "床品"]),
        item("fabric-wardrobe", "布衣柜", .bedroom, 2, 1),
        item("sliding-wardrobe", "推拉门衣柜", .bedroom, 2, 1),
        item("clothes-rack", "落地衣架", .bedroom, 2, 1, keywords: ["挂衣架"]),
        item("bedside-shelf", "床边置物架", .bedroom),
        // 客厅：不同座椅、桌几与空间组合（12种）。
        item("sectional-sofa", "转角沙发", .livingRoom, 2, 2, keywords: ["L型沙发"]),
        item("recliner", "休闲躺椅", .livingRoom, 1, 2),
        item("rocking-chair", "摇椅", .livingRoom, 1, 2),
        item("beanbag", "懒人沙发", .livingRoom, keywords: ["豆袋"]),
        item("ottoman", "脚凳", .livingRoom),
        item("low-stool", "矮凳", .livingRoom),
        item("round-coffee-table", "圆茶几", .livingRoom, 2, 2),
        item("nesting-tables", "组合茶几", .livingRoom, 2, 1, keywords: ["套几"]),
        item("console-table", "玄关桌", .livingRoom, 2, 1),
        item("fireplace", "壁炉", .livingRoom, 2, 1),
        item("room-divider", "折叠屏风", .livingRoom, 2, 1, keywords: ["隔断"]),
        item("bar-cart", "酒水推车", .livingRoom),
        // 书房办公：工作、阅读与手作（12种）。
        item("corner-desk", "转角书桌", .study, 2, 2),
        item("standing-desk", "升降桌", .study, 2, 1, keywords: ["站立办公"]),
        item("office-chair", "办公椅", .study, keywords: ["电脑椅"]),
        item("drafting-table", "绘图桌", .study, 2, 1),
        item("filing-cabinet", "文件柜", .study),
        item("wall-bookcase", "壁挂书架", .study, 2, 1),
        item("ladder-bookcase", "梯形书架", .study, 1, 1),
        item("printer", "打印机", .study),
        item("floor-globe", "立式地球仪", .study),
        item("easel", "画架", .study),
        item("piano", "立式钢琴", .study, 2, 1, keywords: ["音乐"]),
        item("sewing-machine", "缝纫机", .study, keywords: ["手工", "裁缝"]),
        // 厨房餐厅：就餐、烹饪与厨房小家电（12种）。
        item("round-dining-table", "圆餐桌", .kitchen, 2, 2),
        item("breakfast-bar", "早餐吧台", .kitchen, 2, 1),
        item("bar-stool", "吧台椅", .kitchen),
        item("kitchen-island", "厨房岛台", .kitchen, 2, 2),
        item("kitchen-shelf", "厨房置物架", .kitchen, 2, 1),
        item("microwave", "微波炉", .kitchen),
        item("rice-cooker", "电饭煲", .kitchen, keywords: ["煮饭"]),
        item("electric-kettle", "电热水壶", .kitchen, keywords: ["烧水"]),
        item("coffee-machine", "咖啡机", .kitchen),
        item("toaster", "烤面包机", .kitchen, keywords: ["吐司机"]),
        item("dishwasher", "洗碗机", .kitchen),
        item("chest-freezer", "卧式冰柜", .kitchen, 2, 1, keywords: ["冷柜"]),
        // 卫浴洗护：洗浴、衣物清洗与晾晒（10种）。
        item("bathtub", "浴缸", .bathroom, 2, 1),
        item("shower-stall", "淋浴房", .bathroom, 1, 1),
        item("toilet", "马桶", .bathroom),
        item("pedestal-sink", "立柱洗手盆", .bathroom, keywords: ["洗脸盆"]),
        item("vanity-sink", "浴室洗手柜", .bathroom, 2, 1, keywords: ["洗漱台"]),
        item("towel-rack", "毛巾架", .bathroom),
        item("laundry-hamper", "脏衣篮", .bathroom),
        item("drying-rack", "折叠晾衣架", .bathroom, 2, 1),
        item("dryer", "烘干机", .bathroom),
        item("ironing-board", "熨衣板", .bathroom, 2, 1),
        // 收纳：不同门面、结构与用途（12种）。
        item("drawer-chest", "五斗柜", .storage, 2, 1, keywords: ["抽屉柜"]),
        item("cube-shelf", "格子收纳架", .storage, 2, 1),
        item("sideboard", "餐边柜", .storage, 2, 1),
        item("glass-cabinet", "玻璃展示柜", .storage),
        item("corner-cabinet", "转角柜", .storage),
        item("floating-cabinet", "壁挂柜", .storage, 2, 1),
        item("entry-bench", "换鞋凳", .storage, 2, 1),
        item("coat-tree", "挂衣帽架", .storage),
        item("umbrella-stand", "雨伞架", .storage),
        item("storage-trunk", "旅行收纳箱", .storage, 2, 1),
        item("tool-cabinet", "工具柜", .storage, 2, 1),
        item("wicker-basket", "藤编收纳篮", .storage),
        // 家电影音：空气、清洁、饮水与影音（10种）。
        item("tower-fan", "塔式风扇", .appliances),
        item("pedestal-fan", "落地风扇", .appliances),
        item("desk-fan", "桌面风扇", .appliances),
        item("space-heater", "取暖器", .appliances),
        item("air-purifier", "空气净化器", .appliances),
        item("humidifier", "加湿器", .appliances),
        item("robot-vacuum", "扫地机器人", .appliances),
        item("water-dispenser", "饮水机", .appliances),
        item("projector", "投影仪", .appliances),
        item("floor-speakers", "落地音响", .appliances, 2, 1, keywords: ["音箱"]),
        // 儿童宠物：游戏、小尺寸家具和宠物用品（10种）。
        item("kids-table", "儿童活动桌", .childrenAndPets, 2, 1),
        item("kids-chair", "儿童椅", .childrenAndPets),
        item("toy-chest", "玩具箱", .childrenAndPets),
        item("play-kitchen", "玩具厨房", .childrenAndPets, 2, 1),
        item("dollhouse", "娃娃屋", .childrenAndPets),
        item("kids-slide", "儿童滑梯", .childrenAndPets, 1, 2),
        item("rocking-horse", "木马", .childrenAndPets, 1, 2),
        item("cat-tree", "猫爬架", .childrenAndPets),
        item("pet-crate", "宠物笼", .childrenAndPets),
        item("fish-tank-stand", "水族箱柜", .childrenAndPets, 2, 1, keywords: ["鱼缸"]),
        // 阳台户外：休闲、园艺与出行（10种）。
        item("picnic-table", "野餐桌", .outdoor, 2, 2),
        item("garden-bench", "花园长椅", .outdoor, 2, 1),
        item("folding-chair", "折叠露营椅", .outdoor),
        item("patio-table", "庭院小圆桌", .outdoor),
        item("parasol", "遮阳伞", .outdoor, 2, 2),
        item("barbecue-grill", "烧烤炉", .outdoor, 2, 1),
        item("porch-swing", "庭院秋千", .outdoor, 2, 2),
        item("raised-planter", "高脚种植箱", .outdoor, 2, 1),
        item("greenhouse-shelf", "花房置物架", .outdoor, 2, 1),
        item("bicycle", "自行车", .outdoor, 2, 1)
    ]

    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
