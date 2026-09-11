import Foundation

enum ProductCatalog {
    static let seed: [ProductApp] = [
        product("navokids", "NavoKids", "navokids", [.iOS, .android], .review, .review, "1.0", "12", .mixed, ready: true, tags: ["Kids", "Education"]),
        product("zweicheck", "ZweiCheck", "zweicheck", [.iOS, .android], .live, .internalTest, "1.0", "1", .subscription, ready: true, tags: ["Trust", "AI"]),
        product("arbeitsklar", "ArbeitsKlar", "arbeitsklar", [.iOS, .android], .review, .review, "1.0", "1", .subscription, ready: true, tags: ["Work", "Productivity"]),
        product("waermetakt", "WärmeTakt", "w-rmetakt", [.iOS, .android], .development, .development, "1.0", "1", .free, tags: ["SHK", "Heat Pump"]),
        product("reklaio", "Reklaio", "reklaio", [.iOS, .android], .live, .internalTest, "1.0", "1", .subscription, ready: true, tags: ["Business", "Complaints"]),
        product("maengelfix", "MängelFix", "maengelfix", [.iOS, .android], .live, .review, "1.0.4", "5", .subscription, ready: true, tags: ["Business", "Documentation"]),
        product("kintaroq", "Kintaroq", "kamilunavo", [.iOS], .review, .development, "1.0", "1", .mixed, ready: true, tags: ["Diagnostics", "AI"]),
        product("navopass", "NavoPass", "navopass", [.iOS, .android], .review, .development, "1.0", "5", .subscription, tags: ["Security", "Productivity"]),
        product("family-life-os", "Family Life OS", "appideenchatgpt", [.iOS, .android], .development, .development, "0.1", "1", .subscription, tags: ["Family", "Productivity"]),
        product("99-9", "99,9 %", "99-9", [.iOS, .android], .review, .review, "1.0.1", "2", .mixed, tags: ["Utility"]),
        product("kamilunavo-trace", "Kamilunavo Trace", "appideenchatgpt", [.iOS, .android], .development, .development, "0.1", "1", .free, tags: ["Utility"]),
        product("idle-handwerker", "Idle Handwerker", "appideenchatgpt", [.iOS, .android], .development, .attention, "1.3.0", "8", .mixed, notes: "Android-Build prüfen: native App statt WebView.", tags: ["Game", "SHK"]),
        product("kaeltecalc", "KälteCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "5", .paid, tags: ["SHK", "Calculator"], appleBundleID: "de.kamilunav.kaltecalc"),
        product("lueftungscalc", "LüftungsCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"]),
        product("rohrcalc", "RohrCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"]),
        product("heizkoerpercalc", "HeizkörperCalc", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"]),
        product("anlagenscheck", "AnlagenCheck", "SHK", [.iOS, .android], .review, .development, "1.0", "1", .paid, tags: ["SHK", "Inspection"]),
        product("volumecalc", "VolumeCalc", "AnlagenVolumen", [.iOS, .android], .development, .attention, "1.0", "1", .paid, notes: "Android Statusbar/Topbar und Kontrast prüfen.", tags: ["SHK", "Calculator"]),
        product("keepmeter", "KeepMeter", "keepmeter", [.iOS, .android], .review, .development, "1.0.3", "3", .free, tags: ["Utility"]),
        product("schonerledigt", "Schon erledigt?", "schonerledigt", [.iOS, .android], .review, .review, "1.0", "1", .mixed, tags: ["Productivity"]),
        product("brennercalc", "BrennerCalc", "BrennerCalc", [.android], .development, .review, "1.0", "1", .paid, tags: ["SHK", "Calculator"]),
        product("hydrocalc", "HydroCalc", "HydroCalc", [.android], .development, .attention, "1.0", "1", .paid, notes: "Store-Assets und EN-Metadaten vervollständigen.", tags: ["SHK", "Calculator"]),
        product("magcalc", "MAGCalc", "MAGCalc", [.android], .development, .development, "1.0", "1", .paid, tags: ["SHK", "Calculator"]),
        product("rapport-ai", "Rapport AI", "appideenchatgpt", [.iOS, .android], .review, .review, "1.0", "19", .subscription, tags: ["AI", "Business"])
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
