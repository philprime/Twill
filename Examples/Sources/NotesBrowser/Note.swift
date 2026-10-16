import Foundation

struct Note: Identifiable {
    let id: String
    var title: String
    var body: String

    var summary: String {
        let preview = body.prefix(44)
        return String(preview) + (body.count > preview.count ? "…" : "")
    }

    static let examples: [Note] = [
        Note(
            id: "welcome", title: "Welcome to Notes",
            body: "This notebook lives in memory. Search, switch panes, edit a note, or press n to create one."
        ),
        Note(
            id: "groceries", title: "Weekend groceries",
            body: "Pick up sourdough, tomatoes, basil, lemons, coffee beans, and oat milk. Check for olive oil."
        ),
        Note(
            id: "coast", title: "Coastal walk",
            body: "Take the early train. Walk the cliff path, stop at the lighthouse, and pack a warm layer."
        ),
        Note(
            id: "book-club", title: "Book club questions",
            body: "Which character changed their mind? Find a passage where the setting shaped a decision."
        ),
        Note(
            id: "garden", title: "Balcony garden",
            body: "Move the herbs into larger pots. Basil needs morning sun and mint needs its own container."
        ),
        Note(
            id: "pasta", title: "Lemon pasta",
            body: "Save pasta water. Toss the noodles with lemon zest, olive oil, parmesan, and a little water."
        ),
        Note(
            id: "meeting", title: "Team check-in",
            body: "Share the prototype on Thursday. Ask for navigation feedback and assign the release notes."
        ),
        Note(
            id: "ideas", title: "Small product ideas",
            body: "A reading list with gentle reminders. A map of walks. A shared family recipe box."
        ),
        Note(
            id: "packing", title: "Packing list",
            body: "Passport, charger, notebook, headphones, rain jacket, comfortable shoes, and medication."
        ),
        Note(
            id: "morning", title: "Morning routine",
            body: "Open the windows, make tea, list three important tasks, and spend ten minutes offline."
        ),
        Note(
            id: "reading", title: "Reading queue",
            body: "Finish the essay collection, borrow a bird field guide, and revisit design constraints."
        ),
        Note(
            id: "museum", title: "Museum afternoon",
            body: "Visit the ceramics exhibit on a quiet weekday. Sketch one object and see the photographs."
        ),
        Note(
            id: "budget", title: "Monthly budget",
            body: "Review subscriptions, save for the train trip, and compare the utility bill to last month."
        ),
        Note(
            id: "coffee", title: "Coffee experiment",
            body: "Try a coarser grind. Record the ratio, brew time, and whether the cup tastes balanced."
        ),
        Note(
            id: "plants", title: "Houseplant care",
            body: "Water the fern when the topsoil dries. Rotate the rubber plant and trim the pothos."
        ),
        Note(
            id: "birthday", title: "Birthday dinner",
            body: "Invite the neighbors, make mushroom risotto, and ask about dietary preferences."
        ),
        Note(
            id: "cycling", title: "Bike maintenance",
            body: "Check tire pressure and brake pads. Clean the chain and investigate the rear wheel click."
        ),
        Note(
            id: "learning", title: "Things to learn",
            body: "Practice perspective drawing, learn how tides work, and build a tiny terminal app."
        ),
        Note(
            id: "rainy-day", title: "Rainy day plans",
            body: "Visit the library, bake with the leftover apples, and sort photos from last spring."
        ),
        Note(
            id: "gratitude", title: "Good things this week",
            body: "A generous conversation, the first warm evening, a postcard, and a finished task."
        ),
        Note(
            id: "trip", title: "Rail trip notes",
            body: "Compare train times, reserve a window seat, pack lunch, and save the guesthouse address."
        ),
        Note(
            id: "next-week", title: "Next week",
            body: "Call the dentist, return library books, send the draft, and leave a free afternoon."
        ),
    ]
}
