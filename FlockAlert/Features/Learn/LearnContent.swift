import Foundation

struct Article: Identifiable {
    let id: String
    let title: String
    let category: Category
    let readMinutes: Int
    let intro: String
    let sections: [Section]

    struct Section {
        let heading: String
        let body: String
    }

    enum Category: String, CaseIterable {
        case whatIsFlock   = "What Is Flock?"
        case yourData      = "Your Data"
        case civilLiberties = "Civil Liberties"
        case takeAction    = "Take Action"

        var icon: String {
            switch self {
            case .whatIsFlock: return "camera.circle.fill"
            case .yourData: return "doc.badge.gearshape"
            case .civilLiberties: return "scale.3d"
            case .takeAction: return "megaphone.fill"
            }
        }
    }
}

// MARK: - Article Library

struct LearnContent {
    static let articles: [Article] = [
        Article(
            id: "unconstitutional",
            title: "The Constitutional Case Against Flock",
            category: .civilLiberties,
            readMinutes: 7,
            intro: "Always-on, warrantless, mass license plate surveillance collides head-on with the Constitution. It tracks every driver — not suspects, everyone — with no warrant, no probable cause, and no consent. Here is the case that it violates your rights.",
            sections: [
                Article.Section(
                    heading: "The Fourth Amendment",
                    body: "\"The right of the people to be secure in their persons, houses, papers, and effects, against unreasonable searches and seizures, shall not be violated.\"\n\nThat is the Fourth Amendment. It was written by people who had lived under \"general warrants\" — blanket authority for the government to search anyone, anytime, without individualized suspicion. They found it so tyrannical they built a revolution around ending it.\n\nA Flock network is a general warrant made of cameras. It records the movements of every vehicle that passes — the overwhelming majority belonging to people suspected of nothing. No judge signs off. No probable cause is required. You are searched simply for existing on a public road."
                ),
                Article.Section(
                    heading: "Carpenter and the Mosaic Theory",
                    body: "The government argues each photo is legal because you have \"no expectation of privacy\" on a public street. But the Supreme Court has repeatedly signaled that the WHOLE is different from the parts.\n\nIn Carpenter v. United States (2018), the Court held that police need a warrant to obtain long-term cell phone location data — because tracking someone's movements over time reveals \"the privacies of life.\"\n\nIn United States v. Jones (2012), five Justices agreed that long-term GPS tracking is a search, even though each individual location is public.\n\nThis is the \"mosaic theory\": one snapshot may reveal little, but thousands of time-stamped locations, aggregated, expose where you sleep, work, worship, protest, and seek medical care. Flock builds exactly that mosaic — on everyone, continuously."
                ),
                Article.Section(
                    heading: "The First Amendment",
                    body: "The Constitution doesn't just protect privacy — it protects the freedom to assemble, associate, and speak without government monitoring.\n\nA camera that logs every car outside a house of worship, a union hall, a protest, an abortion clinic, or a political meeting creates a record of your associations. Courts have long recognized that surveillance of protected activity produces a \"chilling effect\" — people stop showing up when they know they are being logged.\n\nWhen a Texas sheriff used a plate-reader network to hunt a woman who had an abortion, that was not a hypothetical. Mass surveillance turns your movements into evidence against your freedoms."
                ),
                Article.Section(
                    heading: "No Warrant. No Suspicion. No Consent.",
                    body: "Strip away the marketing and this is what remains:\n\n• NO WARRANT — a judge never authorizes tracking you.\n• NO SUSPICION — you don't have to do anything wrong to be recorded.\n• NO CONSENT — you were never asked, and usually never told.\n• NO OPT-OUT — there is no way to remove yourself.\n• NO LIMITS — the data is shared across thousands of agencies, and \"30-day deletion\" is a sales setting, not a law.\n\nEvery one of those is a principle the Fourth Amendment was written to protect. This is not law and order. It is surveillance without a warrant, sold by the camera."
                ),
                Article.Section(
                    heading: "The Fight in the Courts",
                    body: "The legal battle is live and growing:\n\n• In Norfolk, Virginia, residents backed by the Institute for Justice sued to tear down a 172-camera Flock network, arguing it is warrantless mass surveillance in violation of the Fourth Amendment.\n• The EFF and ACLU are challenging ALPR programs across the country and pushing for warrant requirements.\n• Dozens of cities have cancelled contracts after residents demanded accountability.\n\nCourts remain split, and the technology is outrunning the law — which is exactly why public pressure matters. The Constitution is not self-enforcing. It is defended by people who refuse to be tracked in silence."
                )
            ]
        ),

        Article(
            id: "what-is-flock",
            title: "What Is Flock Safety?",
            category: .whatIsFlock,
            readMinutes: 4,
            intro: "Flock Safety is a private company that manufactures and operates one of the largest networks of automated license plate reader cameras in the United States.",
            sections: [
                Article.Section(
                    heading: "Company Overview",
                    body: "Founded in 2017 and headquartered in Atlanta, Georgia, Flock Safety markets its cameras primarily to homeowners associations, cities, police departments, and private businesses. As of 2024, the company reports operating over 100,000 cameras across all 50 states.\n\nThe company has raised over $380 million in venture capital funding and positions itself as a crime-reduction tool. Its cameras capture license plates, vehicle descriptions, timestamps, and surrounding video footage."
                ),
                Article.Section(
                    heading: "How Flock Cameras Work",
                    body: "Flock cameras use optical character recognition (OCR) to read license plates passing within their field of view. Each capture is logged with a timestamp, GPS coordinates, and vehicle attributes including make, model, color, and visible damage.\n\nThis data is uploaded to Flock's cloud platform, where it can be searched and shared with law enforcement agencies. The cameras operate 24/7 regardless of weather conditions and typically process hundreds to thousands of plate reads per day."
                ),
                Article.Section(
                    heading: "Where Are They Deployed?",
                    body: "Flock cameras are commonly found at:\n• Neighborhood entrances (HOA installations)\n• Highway on/off ramps\n• Intersections and arterial roads\n• School and university campuses\n• Business and retail parking lots\n• City and county government contracts\n• Apartment complex entrances\n\nMany cameras are installed with minimal public notice, and residents often have no formal mechanism to learn whether cameras exist in their community."
                )
            ]
        ),

        Article(
            id: "alpr-explained",
            title: "How ALPR Technology Works",
            category: .whatIsFlock,
            readMinutes: 5,
            intro: "Automated License Plate Readers (ALPRs) are specialized cameras that use computer vision to capture and log vehicle identification data at scale.",
            sections: [
                Article.Section(
                    heading: "The Technology",
                    body: "An ALPR camera contains:\n1. High-speed cameras (often multiple angles)\n2. Infrared illumination for nighttime capture\n3. Onboard processors running OCR software\n4. Cellular or wifi uplink for cloud transmission\n\nModern systems like Flock's Falcon model claim 99%+ accuracy rates under normal conditions. The system logs data even when vehicles are not under investigation — creating a comprehensive movement record of all vehicles in an area."
                ),
                Article.Section(
                    heading: "Data Captured Per Read",
                    body: "Each license plate capture typically includes:\n• Full plate number and state\n• Vehicle make, model, and color\n• Timestamp (millisecond precision)\n• GPS coordinates of the camera\n• Camera identifier\n• Surrounding video clip\n• Vehicle attributes (body type, stickers, damage)\n\nThis creates a de facto vehicle movement database that can reconstruct where any vehicle has been over time."
                ),
                Article.Section(
                    heading: "Hot List Matching",
                    body: "Flock cameras check each captured plate against \"hot lists\" in real time — databases of stolen vehicles, AMBER alerts, and law enforcement watchlists. When a match occurs, police are notified automatically.\n\nCritics note that hot list errors can lead to dangerous encounters between police and innocent drivers. Additionally, the definition of who ends up on watchlists is not always transparent to the public."
                )
            ]
        ),

        Article(
            id: "data-retention",
            title: "Your Data: What's Kept and For How Long",
            category: .yourData,
            readMinutes: 4,
            intro: "When a Flock camera captures your vehicle, that data enters a retention system — but the rules around how long it's kept vary widely and are often unclear to the public.",
            sections: [
                Article.Section(
                    heading: "Retention Policies",
                    body: "Flock Safety's standard contract offers 30-day data retention, after which footage and plate reads are deleted from their servers. However:\n\n• Some agencies negotiate longer retention periods\n• Third-party data sharing may extend effective retention\n• Law enforcement holds may preserve data indefinitely\n• Some jurisdictions have no statutory limits on ALPR retention\n\nA 2022 ACLU analysis found that retention periods varied from 30 days to 5+ years across different Flock customers."
                ),
                Article.Section(
                    heading: "Who Can Access Your Data",
                    body: "Flock's platform allows data sharing between agencies through its LEARN Network — a web of police departments, HOAs, and private customers who can query each other's camera data.\n\nAs of 2023, the LEARN Network reportedly connected thousands of agencies. A single plate query can return data from cameras across multiple states, operated by dozens of different entities — without formal legal process in many cases."
                ),
                Article.Section(
                    heading: "Your Rights",
                    body: "Current protections for ALPR data vary significantly by state:\n\n• California: SB 34 limits retention and requires public disclosure\n• New Hampshire: Prohibits storing data on innocent motorists beyond 3 minutes\n• Most states: No specific ALPR legislation; gaps create unlimited collection\n\nFederal law does not currently regulate ALPR data collection or retention. The Electronic Frontier Foundation and ACLU advocate for federal standards."
                )
            ]
        ),

        Article(
            id: "civil-liberties",
            title: "Civil Liberties and Surveillance",
            category: .civilLiberties,
            readMinutes: 6,
            intro: "The growth of mass vehicle surveillance raises foundational questions about privacy, the Fourth Amendment, and the chilling effect of being watched.",
            sections: [
                Article.Section(
                    heading: "The Privacy Question",
                    body: "The Supreme Court has not directly ruled on ALPR data collection. However, the 2018 Carpenter v. United States decision — which required warrants for extended cell phone location data — suggests the Court is moving toward recognizing that aggregated location data creates a constitutionally protected privacy interest.\n\nMany legal scholars argue that tracking a vehicle's movements across time and geography amounts to a de facto government search, even if each individual observation occurs in public."
                ),
                Article.Section(
                    heading: "The Chilling Effect",
                    body: "Research on surveillance suggests that knowing you are being watched changes behavior — even when that behavior is lawful. This \"chilling effect\" may:\n\n• Discourage attendance at political rallies or protests\n• Reduce visits to medical, religious, or legal facilities\n• Affect freedom of association\n• Create a self-censoring public sphere\n\nA 2023 study from the University of Massachusetts found that ALPR deployment correlates with reduced participation in civic activities among privacy-aware residents."
                ),
                Article.Section(
                    heading: "Mission Creep",
                    body: "ALPR systems initially marketed as crime-fighting tools are increasingly used for:\n\n• Civil debt collection\n• Immigration enforcement\n• Locating individuals for civil processes\n• Revenue generation through traffic enforcement\n• Insurance investigation\n\nOnce surveillance infrastructure exists, its use tends to expand beyond the original justification — a pattern documented across the history of law enforcement technology."
                )
            ]
        ),

        Article(
            id: "take-action",
            title: "Know Your Rights and Take Action",
            category: .takeAction,
            readMinutes: 5,
            intro: "There are concrete steps you can take — individually and collectively — to advocate for transparency and accountability in your community.",
            sections: [
                Article.Section(
                    heading: "File a FOIA Request",
                    body: "The Freedom of Information Act (federal) and state equivalents give you the right to request government records about ALPR camera contracts, policies, and data-sharing agreements.\n\nEffective FOIA requests ask for:\n• All contracts with Flock Safety\n• Camera location maps\n• Data retention and sharing policies\n• Number of plate reads and searches\n• List of agencies with data access\n\nMuckRock.com and ACLU state offices provide templates and filing assistance."
                ),
                Article.Section(
                    heading: "Engage Your Local Government",
                    body: "City councils and county boards approve law enforcement technology purchases. Attending meetings, speaking during public comment, and contacting your representatives are effective means of influence.\n\nSome cities — including Somerville MA, Oakland CA, and Portland OR — have passed ordinances requiring community approval before surveillance technology is deployed."
                ),
                Article.Section(
                    heading: "Organizations to Support",
                    body: "• Electronic Frontier Foundation (eff.org) — digital rights advocacy\n• ACLU — constitutional rights litigation\n• Electronic Privacy Information Center (EPIC) — federal policy advocacy\n• Atlas of Surveillance (atlasofsurveillance.org) — tracking police tech\n• Fight for the Future — grassroots digital rights campaigns\n\nThese organizations work on ALPR legislation, litigation, and public education."
                )
            ]
        )
    ]
}
