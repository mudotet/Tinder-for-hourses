import Foundation
import SharedModels

/// Rich lifestyle, hobby, photo gallery caption, and Tinder prompt metadata for every horse profile.
public struct HorsePhotoShowcaseItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public let categoryBadge: String
    public let caption: String
    public let photoURL: String?

    public init(id: Int, categoryBadge: String, caption: String, photoURL: String?) {
        self.id = id
        self.categoryBadge = categoryBadge
        self.caption = caption
        self.photoURL = photoURL
    }
}

public struct HorsePromptCard: Sendable, Equatable, Identifiable {
    public var id: String { promptTitle }
    public let icon: String
    public let promptTitle: String
    public let answer: String

    public init(icon: String, promptTitle: String, answer: String) {
        self.icon = icon
        self.promptTitle = promptTitle
        self.answer = answer
    }
}

public struct HorseLifestyleBadge: Sendable, Equatable, Identifiable {
    public var id: String { label }
    public let icon: String
    public let category: String
    public let label: String

    public init(icon: String, category: String, label: String) {
        self.icon = icon
        self.category = category
        self.label = label
    }
}

public struct HorseLifestyleProfile: Sendable, Equatable {
    public let handlerName: String
    public let handlerTitle: String
    public let verifiedBarnName: String
    public let badges: [HorseLifestyleBadge]
    public let prompts: [HorsePromptCard]
    public let galleryCaptions: [(badge: String, caption: String)]

    public static func forHorse(_ horse: HorseProfileDTO) -> HorseLifestyleProfile {
        let lower = horse.name.lowercased()
        if lower.contains("luna") {
            return HorseLifestyleProfile(
                handlerName: "Elena Rostova",
                handlerTitle: "FEI Dressage Rider",
                verifiedBarnName: "Silver Birch Equestrian",
                badges: [
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Honeycrisp Apples & Sugar Cubes"),
                    HorseLifestyleBadge(icon: "figure.equestrian.sports", category: "Favorite Hobby", label: "Classical Dressage & Piaffe"),
                    HorseLifestyleBadge(icon: "sun.max.fill", category: "Time of Day", label: "Golden Hour Morning Hacks"),
                    HorseLifestyleBadge(icon: "music.note", category: "Barn Playlist", label: "Spanish Guitar & Classical"),
                    HorseLifestyleBadge(icon: "sparkles", category: "Grooming", label: "Loves Braided Manes & Spa Baths"),
                    HorseLifestyleBadge(icon: "heart.fill", category: "Herd Vibe", label: "Gentle Mare — Loves Nose Boops")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "quote.bubble.fill",
                        promptTitle: "The fastest way to my heart is...",
                        answer: "A warm wither scratch after dressage schooling and a slice of crisp red apple."
                    ),
                    HorsePromptCard(
                        icon: "map.fill",
                        promptTitle: "My ideal Sunday trail date...",
                        answer: "A relaxed canter along the shaded bluegrass bridle paths followed by clover grazing."
                    )
                ],
                galleryCaptions: [
                    ("Portrait", "Golden hour in the Versailles pasture"),
                    ("Hobby • Dressage", "Practicing extended trot in the covered arena"),
                    ("Barn Life", "Morning apple & carrot treat break in the stall"),
                    ("Social Life", "Saying hello to pasture neighbors over the fence")
                ]
            )
        } else if lower.contains("dakota") {
            return HorseLifestyleProfile(
                handlerName: "Marcus Vance",
                handlerTitle: "Backcountry Trail Guide",
                verifiedBarnName: "Red River Trail Stables",
                badges: [
                    HorseLifestyleBadge(icon: "water.waves", category: "Superpower", label: "Loves River & Creek Crossings"),
                    HorseLifestyleBadge(icon: "mountain.2.fill", category: "Favorite Hobby", label: "All-Day Mountain Trail Rides"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Crunchy Baby Carrots & Molasses"),
                    HorseLifestyleBadge(icon: "guitars.fill", category: "Barn Playlist", label: "Acoustic Country & Bluegrass"),
                    HorseLifestyleBadge(icon: "shield.checkered", category: "Spook Level", label: "100% Bombproof (Even Around Deer!)"),
                    HorseLifestyleBadge(icon: "dog.fill", category: "Barn Friends", label: "Best Friends with the Barn Golden Retriever")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "compass.drawing",
                        promptTitle: "Green flag I look for in a trail buddy...",
                        answer: "Willing to splash through shallow creeks with me and share a hay net at the summit!"
                    ),
                    HorsePromptCard(
                        icon: "sparkles",
                        promptTitle: "Two truths and a lie...",
                        answer: "I can unlatch my own stall door, I've camped overnight in Daniel Boone Forest, and I hate carrots."
                    )
                ],
                galleryCaptions: [
                    ("Portrait", "Sunrise lookout on the alpine ridge trail"),
                    ("Hobby • Water", "Splashing through the creek at golden hour"),
                    ("Trail Vista", "Ears forward overlooking the mountain lake"),
                    ("Barn Life", "Post-ride bubble bath and grooming session")
                ]
            )
        } else if lower.contains("saffron") {
            return HorseLifestyleProfile(
                handlerName: "Nadia Al-Mansoor",
                handlerTitle: "AERC Endurance Competitor",
                verifiedBarnName: "Bluegrass Arabian Stud",
                badges: [
                    HorseLifestyleBadge(icon: "bolt.heart.fill", category: "Stamina", label: "50-Mile Endurance Finisher"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Watermelon Rinds & Peppermints"),
                    HorseLifestyleBadge(icon: "wind", category: "Favorite Hobby", label: "Hill Canters & Sunset Gallops"),
                    HorseLifestyleBadge(icon: "sparkles", category: "Coat Care", label: "Golden Shimmer Brushouts"),
                    HorseLifestyleBadge(icon: "person.2.fill", category: "Social Style", label: "Curious & Expressive Alpha Mare"),
                    HorseLifestyleBadge(icon: "truck.box.fill", category: "Travel", label: "Self-Loads into the Trailer in 5 Seconds")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "flame.fill",
                        promptTitle: "You should swipe right if...",
                        answer: "You have forward energy, love covering miles on scenic trails, and never skip electrolyte mash!"
                    ),
                    HorsePromptCard(
                        icon: "sun.haze.fill",
                        promptTitle: "After a long conditioning ride I...",
                        answer: "Roll in the softest patch of pasture grass and nap in the afternoon sun."
                    )
                ],
                galleryCaptions: [
                    ("Portrait", "Posing by the white paddock fence in Paris, KY"),
                    ("Hobby • Trail", "Scouting the ridge trail between conditioning loops"),
                    ("Social Life", "Meeting new pasture friends at sunrise"),
                    ("Spa Day", "Warm courtyard bath after a 25-mile training ride")
                ]
            )
        } else if lower.contains("thunder") {
            return HorseLifestyleProfile(
                handlerName: "Hendrik Van Der Berg",
                handlerTitle: "Classical Baroque Trainer",
                verifiedBarnName: "Royal Friesian Manor",
                badges: [
                    HorseLifestyleBadge(icon: "crown.fill", category: "Signature Look", label: "36-Inch Flowing Wavy Mane"),
                    HorseLifestyleBadge(icon: "figure.equestrian.sports", category: "Favorite Hobby", label: "Liberty Work & Collected Canter"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Warm Beet Pulp & Green Apples"),
                    HorseLifestyleBadge(icon: "music.quarternote.3", category: "Barn Playlist", label: "Epic Orchestral Soundtracks"),
                    HorseLifestyleBadge(icon: "heart.circle.fill", category: "Personality", label: "Dramatic Look, Total Puppy-Dog Heart"),
                    HorseLifestyleBadge(icon: "camera.fill", category: "Secret Talent", label: "Always Poses When He Sees a Camera")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "sparkles",
                        promptTitle: "Don't be intimidated by my stallion look...",
                        answer: "I'm actually a huge cuddle bug who will rest my chin on your shoulder for forehead rubs."
                    ),
                    HorsePromptCard(
                        icon: "moon.stars.fill",
                        promptTitle: "My favorite daily ritual...",
                        answer: "Galloping across the misty meadow at sunset with my mane flying in the wind."
                    )
                ],
                galleryCaptions: [
                    ("Portrait", "Galloping across the misty Frankfort meadow at dusk"),
                    ("Courtyard", "Braided and ready for classical dressage exhibition"),
                    ("Hobby • Trail", "Morning hack overlooking the river valley"),
                    ("Barn Life", "Waiting politely by the stall door for green apples")
                ]
            )
        } else if lower.contains("bella") {
            return HorseLifestyleProfile(
                handlerName: "Sophie Laurent",
                handlerTitle: "Grand Prix Show Jumper",
                verifiedBarnName: "Keeneland Jumping Academy",
                badges: [
                    HorseLifestyleBadge(icon: "trophy.fill", category: "Favorite Hobby", label: "1.40m Show Jumping & Gymnastic Grids"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Bucket of Apples & Carrots"),
                    HorseLifestyleBadge(icon: "sparkles", category: "Barn Nickname", label: "The Flying Marshmallow"),
                    HorseLifestyleBadge(icon: "sun.max.fill", category: "Day Off Vibe", label: "Hacking Out on the Grass Derby Field"),
                    HorseLifestyleBadge(icon: "bubbles.and.sparkles.fill", category: "Spa Routine", label: "Purple Whitening Shampoo & Solarium"),
                    HorseLifestyleBadge(icon: "heart.fill", category: "Personality", label: "Brave at the Jumps, Sweet in the Barn")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "flag.checkered",
                        promptTitle: "When the jump-off buzzer sounds...",
                        answer: "My ears prick forward, I lock onto Fence 1, and we fly clear inside the time allowed!"
                    ),
                    HorsePromptCard(
                        icon: "house.fill",
                        promptTitle: "In my stall you'll always find me...",
                        answer: "Munching on fresh red apples in a sunbeam and watching everything happening in the barn aisle."
                    )
                ],
                galleryCaptions: [
                    ("Hobby • Jumping", "Clearing the red-and-white oxer in the grass arena"),
                    ("Barn Lifestyle", "Enjoying my morning bucket of apples & carrots"),
                    ("Spa & Grooming", "Post-competition warm bubble bath in the courtyard"),
                    ("Social Life", "Paddock turnout with my favorite stablemates")
                ]
            )
        } else if lower.contains("maverick") {
            return HorseLifestyleProfile(
                handlerName: "Cole Sterling",
                handlerTitle: "NRHA Reining & Ranch Rider",
                verifiedBarnName: "Twin Oaks Western Ranch",
                badges: [
                    HorseLifestyleBadge(icon: "drop.fill", category: "Favorite Hobby", label: "Galloping Through Shallow Rivers"),
                    HorseLifestyleBadge(icon: "lasso", category: "Discipline", label: "Western Reining & Ranch Trail"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Oat Cookies & Sweet Feed"),
                    HorseLifestyleBadge(icon: "flame.fill", category: "Signature Move", label: "Sliding Stops & 360 Spins"),
                    HorseLifestyleBadge(icon: "sun.dust.fill", category: "Personality", label: "Flashy Paint Coat, Cool-Headed Mind"),
                    HorseLifestyleBadge(icon: "person.2.fill", category: "Looking For", label: "Adventurous Trail & River Buddies")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "water.waves",
                        promptTitle: "If there's a creek on our trail ride...",
                        answer: "Fair warning: I WILL splash through it at a canter and have the time of my life!"
                    ),
                    HorsePromptCard(
                        icon: "star.fill",
                        promptTitle: "Best compliment I've ever received...",
                        answer: "That my tobiano markings look like a hand-painted western sunset."
                    )
                ],
                galleryCaptions: [
                    ("Hobby • River Splash", "Cantering through crystal-clear river water at golden hour"),
                    ("Trail Adventure", "Climbing the wooded ridge trail in Midway"),
                    ("Social Life", "Nose-to-nose greeting over the ranch fence"),
                    ("Barn Life", "Relaxing after a morning reining session")
                ]
            )
        } else if lower.contains("duchess") {
            return HorseLifestyleProfile(
                handlerName: "Fiona Gallagher",
                handlerTitle: "Heritage Cob & Pleasure Handler",
                verifiedBarnName: "Cloverfield Vanner Estate",
                badges: [
                    HorseLifestyleBadge(icon: "beach.umbrella.fill", category: "Favorite Hobby", label: "Sunset Beach & Coastal Trail Rides"),
                    HorseLifestyleBadge(icon: "comb.fill", category: "Signature Style", label: "Silky Feathered Hooves & Braids"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Pear Slices & Cinnamon Horse Treats"),
                    HorseLifestyleBadge(icon: "heart.fill", category: "Temperament", label: "Calm Enough for Kids & Beginners"),
                    HorseLifestyleBadge(icon: "sparkles", category: "Photo Ready", label: "Fairy-Tale Piebald Markings"),
                    HorseLifestyleBadge(icon: "music.note", category: "Barn Vibe", label: "Celtic Fiddle & Peaceful Mornings")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "sparkles",
                        promptTitle: "My grooming routine takes longer than yours because...",
                        answer: "Keeping four snow-white feathered legs and a waist-length tail silky takes dedication!"
                    ),
                    HorsePromptCard(
                        icon: "heart.circle.fill",
                        promptTitle: "I get along best with horses who...",
                        answer: "Enjoy unhurried scenic walks, mutual wither grooming, and zero herd drama."
                    )
                ],
                galleryCaptions: [
                    ("Lifestyle • Beach", "Strolling along the shoreline at sunset"),
                    ("Barn Life", "Freshly braided mane and apple snack time"),
                    ("Social Life", "Making friends across the white paddock fence"),
                    ("Hobby • Trail", "Peaceful afternoon hack through the valley")
                ]
            )
        } else if lower.contains("atlas") {
            return HorseLifestyleProfile(
                handlerName: "Arthur Pendelton",
                handlerTitle: "Heavy Horse & Driving Master",
                verifiedBarnName: "Oakridge Shire Sanctuary",
                badges: [
                    HorseLifestyleBadge(icon: "leaf.fill", category: "Favorite Season", label: "Crisp Autumn Forest Rides"),
                    HorseLifestyleBadge(icon: "scalemass.fill", category: "Size", label: "18.1 Hands of Pure Gentle Giant"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Whole Carrots & Warm Bran Mash"),
                    HorseLifestyleBadge(icon: "face.smiling.fill", category: "Temperament", label: "Calmest Horse in the County"),
                    HorseLifestyleBadge(icon: "pawprint.fill", category: "Barn Friends", label: "Lets Barn Cats Nap on His Back"),
                    HorseLifestyleBadge(icon: "figure.walk", category: "Favorite Pace", label: "Rhythmic, Ground-Covering Walk")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "heart.fill",
                        promptTitle: "Biggest misconception about draft horses...",
                        answer: "People see 18.1 hands and think I'm intimidating—until I rest my giant head in their lap for chin scratches."
                    ),
                    HorsePromptCard(
                        icon: "tree.fill",
                        promptTitle: "Take me somewhere with...",
                        answer: "Wide forest trails, crunching autumn leaves, and a creek where I can cool my feathered hooves."
                    )
                ],
                galleryCaptions: [
                    ("Portrait", "Standing among golden autumn leaves in Winchester"),
                    ("Social Life", "Gentle nose greeting with my smaller pasture buddies"),
                    ("Hobby • Trail", "Leading the group out on the mountain lake trail"),
                    ("Barn Life", "Enjoying a bucket of carrots after harness work")
                ]
            )
        } else if lower.contains("cleo") {
            return HorseLifestyleProfile(
                handlerName: "Camila Monteiro",
                handlerTitle: "Working Equitation & Classical Trainer",
                verifiedBarnName: "Sol de Ouro Lusitanos",
                badges: [
                    HorseLifestyleBadge(icon: "Rosette", category: "Coat", label: "Golden Buckskin with Black Points"),
                    HorseLifestyleBadge(icon: "figure.equestrian.sports", category: "Favorite Hobby", label: "Working Equitation & Obstacle Bridges"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Fresh Mango Bits & Alfalfa Cubes"),
                    HorseLifestyleBadge(icon: "bolt.fill", category: "Agility", label: "Can Turn on a Dime at the Canter"),
                    HorseLifestyleBadge(icon: "sun.max.fill", category: "Favorite Weather", label: "Sunny 72°F Arena Days"),
                    HorseLifestyleBadge(icon: "heart.fill", category: "Vibe", label: "Smart, Sensitive & Eager to Please")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "sparkles",
                        promptTitle: "My favorite arena exercise...",
                        answer: "Flying changes and weaving through Working Equitation slalom poles one-handed!"
                    ),
                    HorsePromptCard(
                        icon: "carrot.fill",
                        promptTitle: "After a great schooling session...",
                        answer: "I love a cool hosedown, a roll in the sand paddock, and sharing hay with a friendly neighbor."
                    )
                ],
                galleryCaptions: [
                    ("Hobby • Dressage", "Elevated trot in the flower-bordered outdoor arena"),
                    ("Spa & Grooming", "Golden buckskin coat shining after a courtyard bath"),
                    ("Barn Life", "Morning apple & carrot bucket in the sunny stall"),
                    ("Trail Day", "Relaxing hack through the Kentucky hills")
                ]
            )
        } else {
            return HorseLifestyleProfile(
                handlerName: "Liam O'Connor",
                handlerTitle: "Three-Day Eventing Rider",
                verifiedBarnName: "Emerald Isle Eventing",
                badges: [
                    HorseLifestyleBadge(icon: "tree.fill", category: "Favorite Hobby", label: "Cross-Country Log Jumps & Gallops"),
                    HorseLifestyleBadge(icon: "carrot.fill", category: "Favorite Treat", label: "Guinness Bran Mash & Red Apples"),
                    HorseLifestyleBadge(icon: "flame.fill", category: "Heart", label: "Bold, Honest & Never Refuses a Fence"),
                    HorseLifestyleBadge(icon: "water.waves", category: "Water Complex", label: "Leaps Straight In with Ears Pricked"),
                    HorseLifestyleBadge(icon: "person.2.fill", category: "Herd Vibe", label: "Playful Gelding Who Loves Group Hacks"),
                    HorseLifestyleBadge(icon: "medal.fill", category: "Weekend Goal", label: "Clean & Fast Cross-Country Rounds")
                ],
                prompts: [
                    HorsePromptCard(
                        icon: "bolt.fill",
                        promptTitle: "Nothing makes my ears prick faster than...",
                        answer: "Hearing the starter count down '5, 4, 3, 2, 1, Have a great ride!' in the start box."
                    ),
                    HorsePromptCard(
                        icon: "heart.fill",
                        promptTitle: "On my recovery days I love...",
                        answer: "Easy bareback hacks through the woods with a friendly mare or gelding by my side."
                    )
                ],
                galleryCaptions: [
                    ("Hobby • Cross-Country", "Soaring over the mossy forest log jump"),
                    ("Trail Vista", "Looking out over the lake on our cool-down hack"),
                    ("Spa Day", "Courtyard bubble bath after cross-country schooling"),
                    ("Barn Life", "Digging into fresh apples and carrots in my stall")
                ]
            )
        }
    }
}

/// Context-aware AI Equestrian Persona Engine that generates realistic, character-specific match icebreakers and chat replies.
public enum AIEquestrianPersonaEngine {
    public static func openingIcebreaker(from otherHorse: HorseProfileDTO, to myHorse: HorseProfileDTO) -> String {
        let profile = HorseLifestyleProfile.forHorse(otherHorse)
        let lower = otherHorse.name.lowercased()
        if lower.contains("luna") {
            return "Hi! I'm \(profile.handlerName) (\(otherHorse.name)'s rider) 🐴✨ \(otherHorse.name) saw \(myHorse.name)'s profile and gave the sweetest nicker! Do you two ever hack out near the Kentucky Horse Park?"
        } else if lower.contains("dakota") {
            return "Hey there! \(profile.handlerName) & \(otherHorse.name) here 🤠🌲 \(myHorse.name) looks like an awesome trail partner! We're planning a creek-crossing trail ride this weekend—would \(myHorse.name) want to join?"
        } else if lower.contains("saffron") {
            return "Hi from \(profile.handlerName) & \(otherHorse.name)! ☀️🐎 \(myHorse.name) has such an athletic build! How many miles do you two usually cover on your weekend rides?"
        } else if lower.contains("thunder") {
            return "Greetings from \(profile.handlerName) and \(otherHorse.name) 🖤✨ \(otherHorse.name) was showing off his big Friesian trot in the paddock today—he'd love to meet \(myHorse.name) for an arena session or sunset hack!"
        } else if lower.contains("bella") {
            return "Hi!! \(profile.handlerName) & \(otherHorse.name) here 🏆🍎 \(otherHorse.name) just finished her jumping grid and is currently demanding apples. Would \(myHorse.name) like to hack out on the grass field with us this week?"
        } else if lower.contains("maverick") {
            return "Howdy! \(profile.handlerName) & \(otherHorse.name) here 🌊🐎 If \(myHorse.name) likes splashing through shallow rivers and cantering open trails, our horses are going to be best friends!"
        } else if lower.contains("duchess") {
            return "Hello from \(profile.handlerName) & \(otherHorse.name)! 🌸🐴 \(otherHorse.name) just had her feathers washed and braided—she's looking for a gentle companion for a scenic afternoon trail walk!"
        } else if lower.contains("atlas") {
            return "Hello! \(profile.handlerName) & \(otherHorse.name) (our 18.1hh gentle giant!) here 🍂🐴 Don't let his size fool you—he's the sweetest boy in the barn and would love a friendly pasture or trail buddy like \(myHorse.name)!"
        } else if lower.contains("cleo") {
            return "Olá & hello from \(profile.handlerName) & \(otherHorse.name)! ✨🐎 \(myHorse.name) looks wonderful—do you enjoy dressage schooling, obstacle bridges, or relaxed trail hacks?"
        } else {
            return "Hey! \(profile.handlerName) & \(otherHorse.name) here 🌲🏅 \(myHorse.name) looks like a fantastic match! What's your favorite trail or arena spot around \(myHorse.location.city)?"
        }
    }

    public static func generateReply(
        for otherHorse: HorseProfileDTO,
        myHorse: HorseProfileDTO,
        userMessage: String,
        turnIndex: Int
    ) -> String {
        let profile = HorseLifestyleProfile.forHorse(otherHorse)
        let msg = userMessage.lowercased()

        if msg.contains("trail") || msg.contains("saturday") || msg.contains("sunday") || msg.contains("weekend") || msg.contains("ride") || msg.contains("hack") || msg.contains("park") {
            return "That sounds amazing! 🌲🐎 \(otherHorse.name) is happiest out on the trails around 9:30 AM before the sun gets high. We can meet by the North Trailhead parking area at the Kentucky Horse Park—\(profile.handlerName) will bring extra carrots for \(myHorse.name)!"
        }
        if msg.contains("apple") || msg.contains("carrot") || msg.contains("treat") || msg.contains("snack") || msg.contains("food") {
            return "Haha you just spoke \(otherHorse.name)'s love language! 🍎🥕 (\(profile.badges.first?.label ?? "Honeycrisp apples") are an instant 10/10 in our barn). If you bring a pocketful of treats, \(otherHorse.name) will follow \(myHorse.name) anywhere!"
        }
        if msg.contains("jump") || msg.contains("dressage") || msg.contains("arena") || msg.contains("train") || msg.contains("school") {
            return "We school 4 days a week at \(profile.verifiedBarnName)! 🏇✨ Having \(myHorse.name) join us for a flatwork or cavaletti session followed by a cool-down walk around the track would be so much fun."
        }
        if msg.contains("breed") || msg.contains("stallion") || msg.contains("mare") || msg.contains("pedigree") || msg.contains("foal") || msg.contains("coggins") || msg.contains("vet") {
            return "Absolutely—all of \(otherHorse.name)'s veterinary records, negative Coggins, and vaccinations are 100% up to date (\(otherHorse.pedigree ?? "registered bloodlines")). We'd love to arrange a calm barn visit at \(profile.verifiedBarnName) so you and \(myHorse.name) can meet in person!"
        }
        if msg.contains("photo") || msg.contains("picture") || msg.contains("cute") || msg.contains("beautiful") || msg.contains("gorgeous") || msg.contains("pretty") || msg.contains("handsome") || msg.contains("coat") {
            return "Aww thank you!! 🥰🐴 \(otherHorse.name) just got a warm courtyard bath and extra grooming session today—though knowing \(otherHorse.name), there's a 90% chance of rolling in the pasture right before meeting \(myHorse.name)!"
        }
        if msg.contains("where") || msg.contains("location") || msg.contains("city") || msg.contains("barn") || msg.contains("far") {
            return "We're stabled at \(profile.verifiedBarnName) in \(otherHorse.location.city) (only about \(Int(otherHorse.distanceKm ?? 18)) km from \(myHorse.location.city))! 🚚💨 \(otherHorse.name) self-loads into the trailer super easily so we're happy to haul over your way too."
        }

        let rotationalReplies = [
            "We'd love that! 🐴❤️ \(otherHorse.name) has such a calm, friendly temperament with new horses. What day this week works best for you and \(myHorse.name)?",
            "Haha \(otherHorse.name) just pricked both ears up at the barn! ✨ Do \(myHorse.name) and you prefer quiet wooded bridle paths or open pasture canters?",
            "Spot on! \(profile.handlerName) was just saying \(otherHorse.name) needs a consistent riding buddy. Let's definitely set up a meet-and-greet hack soon! 🥕🐎"
        ]
        return rotationalReplies[abs(turnIndex) % rotationalReplies.count]
    }

    public static let quickIcebreakers: [String] = [
        "Want to go for a Saturday morning trail ride? 🌲🐎",
        "I brought Honeycrisp apples & carrots for your horse! 🍎🥕",
        "Your horse's coat and photos look incredible! ✨",
        "Where is your favorite place to school or hack out? 🏇"
    ]
}

public enum MockSampleData {
    private static let demoDir = "/Users/tupt/Downloads/self_project/Tinder_for_horses/Server/Public/uploads/demo"

    public static let currentUserID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    public static let otherUser1ID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    public static let otherUser2ID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    public static let otherUser3ID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!

    public static let myHorseID = UUID(uuidString: "AAAAAAAA-1111-4111-8111-111111111111")!
    public static let lunaHorseID = UUID(uuidString: "BBBBBBBB-2222-4222-8222-222222222222")!
    public static let dakotaHorseID = UUID(uuidString: "CCCCCCCC-3333-4333-8333-333333333333")!
    public static let saffronHorseID = UUID(uuidString: "DDDDDDDD-4444-4444-8444-444444444444")!
    public static let thunderHorseID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
    public static let bellaHorseID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
    public static let maverickHorseID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
    public static let duchessHorseID = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!
    public static let atlasHorseID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
    public static let cleoHorseID = UUID(uuidString: "ABABABAB-1111-4111-8111-111111111111")!
    public static let blazeHorseID = UUID(uuidString: "CDCDCDCD-2222-4222-8222-222222222222")!

    public static let sampleMatchID = UUID(uuidString: "EEEEEEEE-5555-4555-8555-555555555555")!
    public static let sampleConversationID = UUID(uuidString: "FFFFFFFF-6666-4666-8666-666666666666")!

    private static func makePhotos(horseID: UUID, files: [String]) -> [HorsePhotoDTO] {
        files.enumerated().map { idx, file in
            HorsePhotoDTO(
                id: UUID(),
                horseID: horseID,
                url: "\(demoDir)/\(file)",
                position: idx,
                createdAt: Date()
            )
        }
    }

    public static let currentUser = UserDTO(
        id: currentUserID,
        email: "clara@bluegrassstables.com",
        displayName: "Clara Vance",
        isEmailVerified: true,
        notificationsNewMatch: true,
        notificationsNewMessage: true,
        acceptedTermsVersion: SafetyConstants.currentTermsVersion,
        createdAt: Date().addingTimeInterval(-86_400 * 14)
    )

    public static let myHorse = HorseProfileDTO(
        id: myHorseID,
        ownerID: currentUserID,
        name: "Apollo",
        age: 7,
        sex: .stallion,
        breed: "Hanoverian",
        color: "Dark Bay",
        heightHands: 16.3,
        disciplines: [.dressage, .jumping, .trail],
        temperamentTags: ["Steady", "Forward", "Affectionate"],
        bio: "FEI-prospect Hanoverian stallion with three expressive gaits, a love for weekend trail hacks, and a gentlemanly barn presence.",
        location: HorseLocationDTO(city: "Lexington, KY", coarseLatitude: 38.04, coarseLongitude: -84.50),
        lookingFor: [.breedingInquiry, .ridingCompanion, .trailBuddy],
        healthInfo: HorseHealthInfoDTO(
            cogginsTestDate: Date().addingTimeInterval(-86_400 * 30),
            vaccinationsUpToDate: true
        ),
        pedigree: "Sire: Donnerhall Line / Dam: De Niro Line",
        photos: makePhotos(horseID: myHorseID, files: ["apollo_1.jpg", "hobby_grooming.jpg", "hobby_trail.jpg", "hobby_pasture.jpg"]),
        distanceKm: 0.0,
        createdAt: Date().addingTimeInterval(-86_400 * 10),
        updatedAt: Date()
    )

    public static let discoveryHorses: [HorseProfileDTO] = [
        HorseProfileDTO(
            id: lunaHorseID,
            ownerID: otherUser1ID,
            name: "Luna",
            age: 6,
            sex: .mare,
            breed: "Andalusian",
            color: "Dapple Grey",
            heightHands: 15.3,
            disciplines: [.dressage, .trail, .pleasure],
            temperamentTags: ["Sensitive", "Loyal", "Sure-Footed"],
            bio: "Graceful Andalusian mare who loves peaceful morning trail rides, classical dressage schooling, and Honeycrisp apples.",
            location: HorseLocationDTO(city: "Versailles, KY", coarseLatitude: 38.05, coarseLongitude: -84.73),
            lookingFor: [.trailBuddy, .ridingCompanion, .breedingInquiry],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 20),
                vaccinationsUpToDate: true
            ),
            pedigree: "PRE Registered — Cartujano Bloodline",
            photos: makePhotos(horseID: lunaHorseID, files: ["luna_1.jpg", "luna_2.jpg", "bella_2.jpg", "hobby_pasture.jpg"]),
            distanceKm: 20.2,
            createdAt: Date().addingTimeInterval(-86_400 * 9),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: bellaHorseID,
            ownerID: otherUser2ID,
            name: "Bella",
            age: 6,
            sex: .mare,
            breed: "Holsteiner",
            color: "Dapple White",
            heightHands: 16.2,
            disciplines: [.jumping, .dressage, .trail],
            temperamentTags: ["Brave", "Athletic", "Sweet-Natured"],
            bio: "Grand Prix show-jumping Holsteiner mare ('The Flying Marshmallow'). Bold over 1.40m oxers and obsessed with apple & carrot buckets!",
            location: HorseLocationDTO(city: "Lexington, KY", coarseLatitude: 38.06, coarseLongitude: -84.53),
            lookingFor: [.ridingCompanion, .trailBuddy, .friendship],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 14),
                vaccinationsUpToDate: true
            ),
            pedigree: "Holsteiner Verband — Casall Ask / Corrado I",
            photos: makePhotos(horseID: bellaHorseID, files: ["bella_1.jpg", "bella_2.jpg", "hobby_grooming.jpg", "hobby_pasture.jpg"]),
            distanceKm: 4.8,
            createdAt: Date().addingTimeInterval(-86_400 * 8),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: maverickHorseID,
            ownerID: otherUser3ID,
            name: "Maverick",
            age: 5,
            sex: .stallion,
            breed: "American Paint",
            color: "Tobiano Brown & White",
            heightHands: 15.2,
            disciplines: [.western, .trail, .pleasure],
            temperamentTags: ["Adventurous", "Flashy", "Water-Lover"],
            bio: "Tobiano Paint stallion who lives for splashing through crystal-clear rivers, western reining spins, and golden-hour trail adventures.",
            location: HorseLocationDTO(city: "Midway, KY", coarseLatitude: 38.15, coarseLongitude: -84.68),
            lookingFor: [.trailBuddy, .ridingCompanion, .breedingInquiry],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 18),
                vaccinationsUpToDate: true
            ),
            pedigree: "APHA Champion — Gunner / Colonels Smoking Gun",
            photos: makePhotos(horseID: maverickHorseID, files: ["maverick_1.jpg", "hobby_trail.jpg", "hobby_pasture.jpg", "bella_2.jpg"]),
            distanceKm: 16.4,
            createdAt: Date().addingTimeInterval(-86_400 * 7),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: dakotaHorseID,
            ownerID: otherUser2ID,
            name: "Dakota",
            age: 8,
            sex: .gelding,
            breed: "Quarter Horse",
            color: "Chestnut Blaze",
            heightHands: 15.1,
            disciplines: [.western, .trail, .endurance],
            temperamentTags: ["Bombproof", "Easygoing", "Social"],
            bio: "Seasoned mountain-trail gelding who crosses water, bridges, and alpine ridges without batting an eye. Best friend on four hooves!",
            location: HorseLocationDTO(city: "Georgetown, KY", coarseLatitude: 38.21, coarseLongitude: -84.56),
            lookingFor: [.trailBuddy, .friendship],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 45),
                vaccinationsUpToDate: true
            ),
            pedigree: "AQHA Doc Bar / Poco Bueno Lines",
            photos: makePhotos(horseID: dakotaHorseID, files: ["dakota_1.jpg", "maverick_1.jpg", "hobby_trail.jpg", "hobby_grooming.jpg"]),
            distanceKm: 19.6,
            createdAt: Date().addingTimeInterval(-86_400 * 6),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: duchessHorseID,
            ownerID: otherUser1ID,
            name: "Duchess",
            age: 7,
            sex: .mare,
            breed: "Gypsy Vanner",
            color: "Piebald Black & White",
            heightHands: 15.0,
            disciplines: [.pleasure, .trail, .dressage],
            temperamentTags: ["Fairy-Tale", "Gentle", "Cuddly"],
            bio: "Storybook Gypsy Vanner mare with silky feathered hooves and a braided mane. Loves beach walks, spa grooming days, and pear slices.",
            location: HorseLocationDTO(city: "Nicholasville, KY", coarseLatitude: 37.88, coarseLongitude: -84.57),
            lookingFor: [.trailBuddy, .friendship, .stablemate],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 25),
                vaccinationsUpToDate: true
            ),
            pedigree: "TGCA Registered — The Lion King Bloodline",
            photos: makePhotos(horseID: duchessHorseID, files: ["duchess_1.jpg", "bella_2.jpg", "hobby_pasture.jpg", "hobby_trail.jpg"]),
            distanceKm: 18.8,
            createdAt: Date().addingTimeInterval(-86_400 * 5),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: thunderHorseID,
            ownerID: otherUser2ID,
            name: "Thunder",
            age: 7,
            sex: .stallion,
            breed: "Friesian",
            color: "Jet Black",
            heightHands: 16.2,
            disciplines: [.dressage, .pleasure, .trail],
            temperamentTags: ["Majestic", "Expressive", "Puppy-Dog Heart"],
            bio: "Baroque KFPS Friesian stallion with lofty knee action and a flowing wavy mane. Loves sunset meadow gallops and forehead scratches.",
            location: HorseLocationDTO(city: "Frankfort, KY", coarseLatitude: 38.20, coarseLongitude: -84.87),
            lookingFor: [.breedingInquiry, .ridingCompanion, .trailBuddy],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 12),
                vaccinationsUpToDate: true
            ),
            pedigree: "KFPS Ster Stallion — Jasper 366 Line",
            photos: makePhotos(horseID: thunderHorseID, files: ["thunder_1.jpg", "apollo_1.jpg", "hobby_trail.jpg", "bella_2.jpg"]),
            distanceKm: 32.4,
            createdAt: Date().addingTimeInterval(-86_400 * 4),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: saffronHorseID,
            ownerID: otherUser3ID,
            name: "Saffron",
            age: 5,
            sex: .mare,
            breed: "Arabian",
            color: "Golden Palomino",
            heightHands: 15.1,
            disciplines: [.endurance, .trail],
            temperamentTags: ["Spirited", "Intelligent", "Brave"],
            bio: "50-mile endurance mare with a shimmering cream mane. Loves brisk conditioning rides in the Bluegrass hills and watermelon treats.",
            location: HorseLocationDTO(city: "Paris, KY", coarseLatitude: 38.21, coarseLongitude: -84.25),
            lookingFor: [.ridingCompanion, .trailBuddy, .stablemate],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 15),
                vaccinationsUpToDate: true
            ),
            pedigree: "AHA Crabbet / Egyptian Lines",
            photos: makePhotos(horseID: saffronHorseID, files: ["saffron_1.jpg", "hobby_trail.jpg", "hobby_pasture.jpg", "hobby_grooming.jpg"]),
            distanceKm: 28.9,
            createdAt: Date().addingTimeInterval(-86_400 * 3),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: atlasHorseID,
            ownerID: otherUser1ID,
            name: "Atlas",
            age: 9,
            sex: .gelding,
            breed: "Shire Draft",
            color: "Dapple Bay",
            heightHands: 18.1,
            disciplines: [.trail, .pleasure, .other],
            temperamentTags: ["Gentle Giant", "Calm", "Affectionate"],
            bio: "18.1-hand Shire gentle giant who lets barn cats nap on his back and loves crunching through autumn forest trails with friends.",
            location: HorseLocationDTO(city: "Winchester, KY", coarseLatitude: 37.99, coarseLongitude: -84.18),
            lookingFor: [.trailBuddy, .friendship, .stablemate],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 22),
                vaccinationsUpToDate: true
            ),
            pedigree: "Shire Horse Society — Ladbrook Bloodline",
            photos: makePhotos(horseID: atlasHorseID, files: ["atlas_1.jpg", "hobby_pasture.jpg", "hobby_trail.jpg", "bella_2.jpg"]),
            distanceKm: 29.1,
            createdAt: Date().addingTimeInterval(-86_400 * 2),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: cleoHorseID,
            ownerID: otherUser2ID,
            name: "Cleo",
            age: 6,
            sex: .mare,
            breed: "Lusitano",
            color: "Golden Buckskin",
            heightHands: 15.3,
            disciplines: [.dressage, .other, .trail],
            temperamentTags: ["Agile", "Smart", "Expressive"],
            bio: "Golden buckskin Lusitano mare specializing in Working Equitation and classical dressage in flower-lined outdoor arenas.",
            location: HorseLocationDTO(city: "Shelbyville, KY", coarseLatitude: 38.21, coarseLongitude: -85.22),
            lookingFor: [.ridingCompanion, .breedingInquiry, .trailBuddy],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 10),
                vaccinationsUpToDate: true
            ),
            pedigree: "APSL Registered — Novilheiro Bloodline",
            photos: makePhotos(horseID: cleoHorseID, files: ["cleo_1.jpg", "hobby_grooming.jpg", "bella_2.jpg", "hobby_pasture.jpg"]),
            distanceKm: 48.0,
            createdAt: Date().addingTimeInterval(-86_400 * 1),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: blazeHorseID,
            ownerID: otherUser3ID,
            name: "Blaze",
            age: 7,
            sex: .gelding,
            breed: "Irish Sport Horse",
            color: "Dappled Chestnut",
            heightHands: 16.2,
            disciplines: [.jumping, .endurance, .trail],
            temperamentTags: ["Bold", "Honest", "Playful"],
            bio: "Three-day eventing Irish Sport Horse who loves soaring over mossy forest logs on cross-country courses and relaxing lake hacks.",
            location: HorseLocationDTO(city: "Keeneland, KY", coarseLatitude: 38.05, coarseLongitude: -84.60),
            lookingFor: [.ridingCompanion, .trailBuddy, .friendship],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 8),
                vaccinationsUpToDate: true
            ),
            pedigree: "ISH Studbook — King of Diamonds / Cruising",
            photos: makePhotos(horseID: blazeHorseID, files: ["blaze_1.jpg", "hobby_trail.jpg", "hobby_grooming.jpg", "bella_2.jpg"]),
            distanceKm: 8.7,
            createdAt: Date().addingTimeInterval(-3600 * 12),
            updatedAt: Date()
        )
    ]

    public static let sampleMatch = MatchDTO(
        id: sampleMatchID,
        horseA: myHorse,
        horseB: discoveryHorses[0],
        conversationID: sampleConversationID,
        createdAt: Date().addingTimeInterval(-3600 * 5)
    )

    public static let sampleMessages: [MessageDTO] = [
        MessageDTO(
            id: UUID(uuidString: "70000000-0000-4000-8000-000000000001")!,
            conversationID: sampleConversationID,
            senderUserID: otherUser1ID,
            senderHorseID: lunaHorseID,
            body: "Hi Clara! Apollo has such wonderful movement. Luna and I ride at the Kentucky Horse Park trails on Saturday mornings!",
            readAt: Date().addingTimeInterval(-1800),
            createdAt: Date().addingTimeInterval(-3600)
        ),
        MessageDTO(
            id: UUID(uuidString: "70000000-0000-4000-8000-000000000002")!,
            conversationID: sampleConversationID,
            senderUserID: currentUserID,
            senderHorseID: myHorseID,
            body: "Thank you! Apollo would love to join Luna for a morning hack around the park.",
            readAt: Date().addingTimeInterval(-900),
            createdAt: Date().addingTimeInterval(-1200)
        )
    ]

    public static let sampleConversationSummary = ConversationSummaryDTO(
        id: sampleConversationID,
        matchID: sampleMatchID,
        myHorse: myHorse,
        otherHorse: discoveryHorses[0],
        lastMessage: sampleMessages.last,
        unreadCount: 0,
        updatedAt: Date().addingTimeInterval(-1200)
    )
}

/// Complete standalone `MockAPIClient` actor allowing the iOS app, previews, and UI tests to run without the server.
public actor MockAPIClient: APIClientProtocol {
    private var currentUser: UserDTO
    private var myHorses: [HorseProfileDTO]
    private var candidateHorses: [HorseProfileDTO]
    private var swipedHorseIDs: Set<UUID> = []
    private var matches: [MatchDTO]
    private var conversations: [ConversationSummaryDTO]
    private var messagesByConversation: [UUID: [MessageDTO]]
    private var blocks: [BlockDTO] = []
    private var reports: [ReportDTO] = []
    private let tokenStore: any TokenStore

    public init(
        currentUser: UserDTO = MockSampleData.currentUser,
        myHorses: [HorseProfileDTO] = [MockSampleData.myHorse],
        candidateHorses: [HorseProfileDTO] = MockSampleData.discoveryHorses,
        matches: [MatchDTO] = [MockSampleData.sampleMatch],
        conversations: [ConversationSummaryDTO] = [MockSampleData.sampleConversationSummary],
        messagesByConversation: [UUID: [MessageDTO]] = [
            MockSampleData.sampleConversationID: MockSampleData.sampleMessages
        ],
        tokenStore: any TokenStore = InMemoryTokenStore()
    ) {
        self.currentUser = currentUser
        self.myHorses = myHorses
        self.candidateHorses = candidateHorses
        self.matches = matches
        self.conversations = conversations
        self.messagesByConversation = messagesByConversation
        self.tokenStore = tokenStore
    }

    public func signUp(_ request: SignUpRequest) async throws -> AuthTokenResponse {
        currentUser = UserDTO(
            id: MockSampleData.currentUserID,
            email: request.email,
            displayName: request.displayName ?? "Horse Handler",
            isEmailVerified: false,
            notificationsNewMatch: true,
            notificationsNewMessage: true,
            acceptedTermsVersion: SafetyConstants.currentTermsVersion,
            createdAt: Date()
        )
        let pair = StoredTokenPair(accessToken: "mock-access-token", refreshToken: "mock-refresh-token")
        try await tokenStore.saveTokens(pair)
        return AuthTokenResponse(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresIn: 900,
            user: currentUser
        )
    }

    public func login(_ request: LoginRequest) async throws -> AuthTokenResponse {
        currentUser = UserDTO(
            id: currentUser.id,
            email: request.email,
            displayName: currentUser.displayName ?? "Clara Vance",
            isEmailVerified: true,
            notificationsNewMatch: currentUser.notificationsNewMatch,
            notificationsNewMessage: currentUser.notificationsNewMessage,
            acceptedTermsVersion: currentUser.acceptedTermsVersion,
            createdAt: currentUser.createdAt
        )
        let pair = StoredTokenPair(accessToken: "mock-access-token", refreshToken: "mock-refresh-token")
        try await tokenStore.saveTokens(pair)
        return AuthTokenResponse(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresIn: 900,
            user: currentUser
        )
    }

    public func signInWithApple(_ request: AppleSignInRequest) async throws -> AuthTokenResponse {
        currentUser = UserDTO(
            id: currentUser.id,
            email: request.email ?? currentUser.email,
            displayName: request.fullName ?? currentUser.displayName ?? "Apple Equestrian",
            isEmailVerified: true,
            notificationsNewMatch: true,
            notificationsNewMessage: true,
            acceptedTermsVersion: SafetyConstants.currentTermsVersion,
            createdAt: Date()
        )
        let pair = StoredTokenPair(accessToken: "mock-apple-access-token", refreshToken: "mock-apple-refresh-token")
        try await tokenStore.saveTokens(pair)
        return AuthTokenResponse(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresIn: 900,
            user: currentUser
        )
    }

    public func logout() async throws {
        try await tokenStore.clearTokens()
    }

    public func getMe() async throws -> UserDTO {
        currentUser
    }

    public func updateMe(_ request: UpdateUserSettingsRequest) async throws -> UserDTO {
        currentUser = UserDTO(
            id: currentUser.id,
            email: currentUser.email,
            displayName: request.displayName ?? currentUser.displayName,
            isEmailVerified: currentUser.isEmailVerified,
            notificationsNewMatch: request.notificationsNewMatch ?? currentUser.notificationsNewMatch,
            notificationsNewMessage: request.notificationsNewMessage ?? currentUser.notificationsNewMessage,
            acceptedTermsVersion: request.acceptedTermsVersion ?? currentUser.acceptedTermsVersion,
            createdAt: currentUser.createdAt
        )
        return currentUser
    }

    public func registerDeviceToken(_ request: RegisterDeviceTokenRequest) async throws -> DeviceTokenDTO {
        DeviceTokenDTO(
            id: UUID(),
            userID: currentUser.id,
            token: request.token,
            platform: request.platform,
            createdAt: Date()
        )
    }

    public func deleteAccount() async throws {
        myHorses.removeAll()
        matches.removeAll()
        conversations.removeAll()
        messagesByConversation.removeAll()
        try await tokenStore.clearTokens()
    }

    public func listMyHorses() async throws -> [HorseProfileDTO] {
        myHorses
    }

    public func createHorse(_ request: CreateHorseProfileRequest) async throws -> HorseProfileDTO {
        if case .objectionableContent = ObjectionableContentFilter.validateBio(request.bio) {
            throw APIClientError.serverError(
                statusCode: 400,
                response: APIErrorResponse(code: .contentRejected, message: "Bio contains prohibited content.")
            )
        }
        let horseID = UUID()
        let horse = HorseProfileDTO(
            id: horseID,
            ownerID: currentUser.id,
            name: request.name,
            age: request.age,
            sex: request.sex,
            breed: request.breed,
            color: request.color,
            heightHands: request.heightHands,
            disciplines: request.disciplines,
            temperamentTags: request.temperamentTags,
            bio: request.bio,
            location: request.location,
            lookingFor: request.lookingFor,
            healthInfo: request.healthInfo,
            pedigree: request.pedigree,
            photos: [
                HorsePhotoDTO(
                    id: UUID(),
                    horseID: horseID,
                    url: "/Users/tupt/Downloads/self_project/Tinder_for_horses/Server/Public/uploads/demo/apollo_1.jpg",
                    position: 0,
                    createdAt: Date()
                ),
                HorsePhotoDTO(
                    id: UUID(),
                    horseID: horseID,
                    url: "/Users/tupt/Downloads/self_project/Tinder_for_horses/Server/Public/uploads/demo/hobby_grooming.jpg",
                    position: 1,
                    createdAt: Date()
                )
            ],
            distanceKm: 0.0,
            createdAt: Date(),
            updatedAt: Date()
        )
        myHorses.append(horse)
        return horse
    }

    public func updateHorse(id: UUID, _ request: UpdateHorseProfileRequest) async throws -> HorseProfileDTO {
        guard let idx = myHorses.firstIndex(where: { $0.id == id }) else {
            throw APIClientError.serverError(
                statusCode: 404,
                response: APIErrorResponse(code: .notFound, message: "Horse not found")
            )
        }
        let existing = myHorses[idx]
        let updated = HorseProfileDTO(
            id: existing.id,
            ownerID: existing.ownerID,
            name: request.name ?? existing.name,
            age: request.age ?? existing.age,
            sex: request.sex ?? existing.sex,
            breed: request.breed ?? existing.breed,
            color: request.color ?? existing.color,
            heightHands: request.heightHands ?? existing.heightHands,
            disciplines: request.disciplines ?? existing.disciplines,
            temperamentTags: request.temperamentTags ?? existing.temperamentTags,
            bio: request.bio ?? existing.bio,
            location: request.location ?? existing.location,
            lookingFor: request.lookingFor ?? existing.lookingFor,
            healthInfo: request.healthInfo ?? existing.healthInfo,
            pedigree: request.pedigree ?? existing.pedigree,
            photos: existing.photos,
            distanceKm: existing.distanceKm,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        myHorses[idx] = updated
        return updated
    }

    public func deleteHorse(id: UUID) async throws {
        myHorses.removeAll { $0.id == id }
    }

    public func uploadHorsePhoto(horseID: UUID, jpegData: Data) async throws -> HorsePhotoDTO {
        HorsePhotoDTO(
            id: UUID(),
            horseID: horseID,
            url: "/Users/tupt/Downloads/self_project/Tinder_for_horses/Server/Public/uploads/demo/apollo_1.jpg",
            position: 0,
            createdAt: Date()
        )
    }

    public func reorderHorsePhotos(horseID: UUID, photoIDs: [UUID]) async throws -> [HorsePhotoDTO] {
        guard let horse = myHorses.first(where: { $0.id == horseID }) else { return [] }
        return horse.photos
    }

    public func deleteHorsePhoto(horseID: UUID, photoID: UUID) async throws {}

    public func discoverHorses(query: DiscoveryFilterQuery) async throws -> CursorPage<HorseProfileDTO> {
        let blockedUserIDs = Set(blocks.map(\.blockedUserID))
        if swipedHorseIDs.count >= candidateHorses.count {
            swipedHorseIDs.removeAll()
        }
        let filtered = candidateHorses.filter { horse in
            guard !swipedHorseIDs.contains(horse.id) else { return false }
            guard !blockedUserIDs.contains(horse.ownerID) else { return false }
            if let sex = query.sex, horse.sex != sex { return false }
            if let breed = query.breed, !breed.isEmpty,
               !horse.breed.localizedCaseInsensitiveContains(breed)
            {
                return false
            }
            if let minAge = query.minAge, horse.age < minAge { return false }
            if let maxAge = query.maxAge, horse.age > maxAge { return false }
            if let discipline = query.discipline, !horse.disciplines.contains(discipline) { return false }
            if let lookingFor = query.lookingFor, !horse.lookingFor.contains(lookingFor) { return false }
            if let maxDist = query.maxDistanceKm, let dist = horse.distanceKm, dist > maxDist { return false }
            return true
        }
        return CursorPage(items: filtered, nextCursor: nil)
    }

    public func recordSwipe(_ request: SwipeRequest) async throws -> SwipeResponse {
        swipedHorseIDs.insert(request.targetHorseID)
        let swipeID = UUID()

        guard request.direction == .like,
              let targetHorse = candidateHorses.first(where: { $0.id == request.targetHorseID })
        else {
            return SwipeResponse(swipeID: swipeID, direction: request.direction, isMatch: false, match: nil)
        }

        let myHorse = myHorses.first(where: { $0.id == request.swiperHorseID }) ?? MockSampleData.myHorse
        let conversationID = UUID()
        let match = MatchDTO(
            id: UUID(),
            horseA: myHorse,
            horseB: targetHorse,
            conversationID: conversationID,
            createdAt: Date()
        )
        matches.insert(match, at: 0)

        // Generate an instant AI opening icebreaker from the matched horse!
        let aiGreetingText = AIEquestrianPersonaEngine.openingIcebreaker(from: targetHorse, to: myHorse)
        let aiOpeningMessage = MessageDTO(
            id: UUID(),
            conversationID: conversationID,
            senderUserID: targetHorse.ownerID,
            senderHorseID: targetHorse.id,
            body: aiGreetingText,
            readAt: nil,
            createdAt: Date()
        )
        messagesByConversation[conversationID] = [aiOpeningMessage]

        let summary = ConversationSummaryDTO(
            id: conversationID,
            matchID: match.id,
            myHorse: myHorse,
            otherHorse: targetHorse,
            lastMessage: aiOpeningMessage,
            unreadCount: 1,
            updatedAt: Date()
        )
        conversations.insert(summary, at: 0)

        return SwipeResponse(swipeID: swipeID, direction: .like, isMatch: true, match: match)
    }

    /// Appends an AI-generated reply from `otherHorse` into the conversation store and returns the created `MessageDTO`.
    public func appendAIReply(
        conversationID: UUID,
        otherHorse: HorseProfileDTO,
        myHorse: HorseProfileDTO,
        userMessage: String
    ) -> MessageDTO {
        let existingMessages = messagesByConversation[conversationID] ?? []
        let replyBody = AIEquestrianPersonaEngine.generateReply(
            for: otherHorse,
            myHorse: myHorse,
            userMessage: userMessage,
            turnIndex: existingMessages.count
        )
        let reply = MessageDTO(
            id: UUID(),
            conversationID: conversationID,
            senderUserID: otherHorse.ownerID,
            senderHorseID: otherHorse.id,
            body: replyBody,
            readAt: Date(),
            createdAt: Date()
        )
        messagesByConversation[conversationID, default: []].append(reply)
        if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
            let existing = conversations[idx]
            conversations[idx] = ConversationSummaryDTO(
                id: existing.id,
                matchID: existing.matchID,
                myHorse: existing.myHorse,
                otherHorse: existing.otherHorse,
                lastMessage: reply,
                unreadCount: 0,
                updatedAt: Date()
            )
        }
        return reply
    }

    public func listMatches() async throws -> [MatchDTO] {
        let blockedUserIDs = Set(blocks.map(\.blockedUserID))
        return matches.filter {
            !blockedUserIDs.contains($0.horseA.ownerID) && !blockedUserIDs.contains($0.horseB.ownerID)
        }
    }

    public func listConversations() async throws -> [ConversationSummaryDTO] {
        let blockedUserIDs = Set(blocks.map(\.blockedUserID))
        return conversations.filter { !blockedUserIDs.contains($0.otherHorse.ownerID) }
    }

    public func listMessages(
        conversationID: UUID,
        cursor: String?,
        limit: Int
    ) async throws -> CursorPage<MessageDTO> {
        let msgs = messagesByConversation[conversationID] ?? []
        return CursorPage(items: msgs, nextCursor: nil)
    }

    public func sendMessage(conversationID: UUID, request: SendMessageRequest) async throws -> MessageDTO {
        if case .objectionableContent = ObjectionableContentFilter.validateMessage(request.body) {
            throw APIClientError.serverError(
                statusCode: 400,
                response: APIErrorResponse(code: .contentRejected, message: "Message contains prohibited language.")
            )
        }
        let message = MessageDTO(
            id: UUID(),
            conversationID: conversationID,
            senderUserID: currentUser.id,
            senderHorseID: request.senderHorseID,
            body: request.body,
            readAt: Date(),
            createdAt: Date()
        )
        messagesByConversation[conversationID, default: []].append(message)
        if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
            let existing = conversations[idx]
            conversations[idx] = ConversationSummaryDTO(
                id: existing.id,
                matchID: existing.matchID,
                myHorse: existing.myHorse,
                otherHorse: existing.otherHorse,
                lastMessage: message,
                unreadCount: 0,
                updatedAt: Date()
            )
        }
        return message
    }

    public func markMessagesRead(
        conversationID: UUID,
        upToMessageID: UUID?
    ) async throws -> MarkMessagesReadResponse {
        let now = Date()
        if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
            let existing = conversations[idx]
            conversations[idx] = ConversationSummaryDTO(
                id: existing.id,
                matchID: existing.matchID,
                myHorse: existing.myHorse,
                otherHorse: existing.otherHorse,
                lastMessage: existing.lastMessage,
                unreadCount: 0,
                updatedAt: existing.updatedAt
            )
        }
        if var msgs = messagesByConversation[conversationID] {
            msgs = msgs.map {
                MessageDTO(
                    id: $0.id,
                    conversationID: $0.conversationID,
                    senderUserID: $0.senderUserID,
                    senderHorseID: $0.senderHorseID,
                    body: $0.body,
                    readAt: $0.readAt ?? now,
                    createdAt: $0.createdAt
                )
            }
            messagesByConversation[conversationID] = msgs
        }
        return MarkMessagesReadResponse(conversationID: conversationID, readCount: 1, readAt: now)
    }

    public func createReport(_ request: CreateReportRequest) async throws -> ReportDTO {
        let report = ReportDTO(
            id: UUID(),
            reporterUserID: currentUser.id,
            targetType: request.targetType,
            targetID: request.targetID,
            reason: request.reason,
            details: request.details,
            status: .pending,
            createdAt: Date()
        )
        reports.append(report)
        return report
    }

    public func listBlocks() async throws -> [BlockDTO] {
        blocks
    }

    public func blockUser(_ request: BlockUserRequest) async throws -> BlockDTO {
        let block = BlockDTO(
            id: UUID(),
            blockerUserID: currentUser.id,
            blockedUserID: request.blockedUserID,
            createdAt: Date()
        )
        blocks.append(block)
        return block
    }

    public func unblockUser(blockedUserID: UUID) async throws {
        blocks.removeAll { $0.blockedUserID == blockedUserID }
    }

    public func fetchTermsOfUse() async throws -> LegalDocumentDTO {
        LegalDocumentDTO(
            title: "Stallion Match Terms of Use",
            version: SafetyConstants.currentTermsVersion,
            effectiveDate: "2026-01-01",
            contentMarkdown: "All users must comply with local animal-welfare laws. No in-app payments or animal sales."
        )
    }

    public func fetchPrivacyPolicy() async throws -> LegalDocumentDTO {
        LegalDocumentDTO(
            title: "Stallion Match Privacy Policy",
            version: SafetyConstants.currentTermsVersion,
            effectiveDate: "2026-01-01",
            contentMarkdown: "Location is coarsened to city level (~1.1 km). Account deletion removes all data."
        )
    }
}
