import Foundation

enum ProductCatalog {
    static let seed: [ProductApp] = [
        product("navoops", "NavoOps", "navoOps", [.iOS], .development, .development, "1.1.0", "2", .free, ready: true, tags: ["Internal", "Operations"], appleBundleID: "com.kamilunavo.NavoOps"),
        product("navokids", "NavoKids", "navokids", [.iOS, .android], .review, .review, "1.0", "12", .mixed, ready: true, tags: ["Kids", "Education"], appleBundleID: "com.kamilunavo.navokids"),
        product("zweicheck", "ZweiCheck", "zweicheck", [.iOS, .android], .live, .internalTest, "1.0", "1", .subscription, ready: true, tags: ["Trust", "AI"], appleBundleID: "de.kamilunavo.zweicheck"),
        product("arbeitsklar", "ArbeitsKlar", "arbeitsklar", [.iOS, .android], .review, .review, "1.0", "1", .subscription, ready: true, tags: ["Work", "Productivity"], appleBundleID: "de.kamilunavo.arbeitsklar"),
        product("waermetakt", "WärmeTakt", "w-rmetakt", [.iOS, .android], .development, .development, "1.0", "1", .free, tags: ["SHK", "Heat Pump"], appleBundleID: "de.kamilunavo.waermetakt"),
        product("reklaio", "Reklaio", "reklaio", [.iOS, .android], .live, .internalTest, "1.0", "1", .subscription, ready: true, tags: ["Business", "Complaints"], appleBundleID: "de.kamilunavo.reklaio"),
        product("maengelfix", "MängelFix", "maengelfix", [.iOS, .android], .live, .review, "1.0.4", "5", .subscription, ready: true, tags: ["Business", "Documentation"], appleBundleID: "com.kamilunavo.maengelfix", androidPackageID: "com.kamilunavo.maengelfix"),
        product("kintaroq", "Kintaroq", "kamilunavo", [.iOS], .review, .development, "1.0", "1", .mixed, ready: true, tags: ["Diagnostics", "AI"], appleBundleID: "com.kamilunavo.kintaroq", androidPackageID: "com.kamilunavo.kintaroq"),
        product("navopass", "NavoPass", "navopass", [.iOS, .android], .review, .development, "1.0", "5", .subscription, tags: ["Security", "Productivity"], appleBundleID: "de.kamilunavo.navopass", androidPackageID: "de.kamilunavo.navopass"),
        product("family-life-os", "Family Life OS", "appideenchatgpt", [.iOS, .android], .development, .development, "0.1", "1", .subscription, tags: ["Family", "Productivity"], appleBundleID: "de.kamilunavo.familyprototype"),
        product("99-9", "99,9 %", "99-9", [.iOS, .android], .review, .review, "1.0.1", "2", .mixed, tags: ["Utility"], appleBundleID: "de.kamilunavo.ninenine"),
        product("kamilunavo-trace", "Kamilunavo Trace", "appideenchatgpt", [.iOS, .android], .development, .development, "0.1", "1", .free, tags: ["Utility"], appleBundleID: "de.kamilunavo.trace"),
        product("idle-handwerker", "Idle Handwerker", "appideenchatgpt", [.iOS, .android], .development, .attention, "1.3.0", "8", .mixed, notes: "Android-Build prüfen: native App statt WebView.", tags: ["Game", "SHK"], appleBundleID: "de.kamilunavo.idlehandwerker"),
        product("kaeltecalc", "KälteCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "5", .paid, tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunav.kaltecalc", androidPackageID: "de.kamilunav.kaltecalc"),
        product("lueftungscalc", "LüftungsCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunavo.luftungscalc"),
        product("rohrcalc", "RohrCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunavo.rohrcalc"),
        product("heizkoerpercalc", "HeizkörperCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunavo.heizkorpercalc"),
        product("anlagencheck", "AnlagenCheck", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Inspection"], appleBundleID: "de.kamilunavo.servicecheck"),
        product("volumecalc", "VolumeCalc", "AnlagenVolumen", [.iOS, .android], .development, .attention, "1.0", "1", .paid, notes: "Android Statusbar/Topbar und Kontrast prüfen.", tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunavo.volumecalc", androidPackageID: "de.kamilunavo.volumecalc"),
        product("keepmeter", "KeepMeter", "keepmeter", [.iOS, .android], .review, .development, "1.0.3", "3", .free, tags: ["Utility"], appleBundleID: "de.kamilunavo.keepmeter", androidPackageID: "de.kamilunavo.keepmeter"),
        product("schonerledigt", "Schon erledigt?", "schonerledigt", [.iOS, .android], .review, .review, "1.0", "1", .mixed, tags: ["Productivity"], appleBundleID: "com.kamilunavo.schon-erledigt", androidPackageID: "com.kamilunavo.schonerledigt"),
        product("brennercalc", "BrennerCalc", "BrennerCalc", [.iOS, .android], .live, .review, "1.0", "1", .paid, tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunavo.brennercalc", androidPackageID: "de.kamilunavo.brennercalc"),
        product("hydrocalc", "HydroCalc", "HydroCalc", [.iOS, .android], .live, .attention, "1.0", "1", .paid, notes: "Store-Assets und EN-Metadaten vervollständigen.", tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunavo.hydrocalc", androidPackageID: "de.kamilunavo.hydrocalc"),
        product("magcalc", "MAGCalc", "MAGCalc", [.iOS, .android], .live, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunavo.magcalc", androidPackageID: "de.kamilunavo.magcalc"),
        product("rapport-ai", "Rapport AI", "appideenchatgpt", [.iOS, .android], .live, .review, "1.0", "19", .subscription, tags: ["AI", "Business"], appleBundleID: "de.kamilunavo.rapportai")
    ].sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    private static func product(
        _ id: String,
        _ name: String,
        _ repository: String,
        _ platforms: Set<ProductApp.Platform>,
        _ apple: ProductApp.StoreState,
        _ google: ProductApp.StoreState,
        _ version: String,
        _ build: String,
        _ monetization: ProductApp.Monetization,
        ready: Bool = false,
        notes: String = "",
        tags: [String] = [],
        appleBundleID: String? = nil,
        androidPackageID: String? = nil
    ) -> ProductApp {
        var checklist = ready ? ReleaseChecklist.fullyReady : ReleaseChecklist()
        checklist.privacyURL = true

        return ProductApp(
            id: id,
            name: name,
            repository: repository,
            platforms: platforms,
            appleState: apple,
            googleState: google,
            version: version,
            build: build,
            notes: notes,
            checklist: checklist,
            storeInfo: .init(appleBundleID: appleBundleID, androidPackageID: androidPackageID),
            monetization: monetization,
            tags: tags
        )
    }
}
