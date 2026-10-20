import Fluent
import FluentSQL
import Foundation

public struct CreateInitialSchema: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        // 1. Users
        try await database.schema(UserModel.schema)
            .id()
            .field("email", .string, .required)
            .field("password_hash", .string)
            .field("apple_subject", .string)
            .field("display_name", .string)
            .field("is_email_verified", .bool, .required)
            .field("email_verification_token_hash", .string)
            .field("notifications_new_match", .bool, .required)
            .field("notifications_new_message", .bool, .required)
            .field("accepted_terms_version", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "email")
            .unique(on: "apple_subject")
            .create()

        // 2. Refresh Tokens (hashed)
        try await database.schema(RefreshTokenModel.schema)
            .id()
            .field("user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("token_hash", .string, .required)
            .field("expires_at", .datetime, .required)
            .field("is_revoked", .bool, .required)
            .field("created_at", .datetime)
            .unique(on: "token_hash")
            .create()

        // 3. Device Tokens (APNs)
        try await database.schema(DeviceTokenModel.schema)
            .id()
            .field("user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("token", .string, .required)
            .field("platform", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "user_id", "token")
            .create()

        // 4. Horse Profiles
        try await database.schema(HorseProfileModel.schema)
            .id()
            .field("owner_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("age", .int, .required)
            .field("sex", .string, .required)
            .field("breed", .string, .required)
            .field("color", .string, .required)
            .field("height_hands", .double, .required)
            .field("disciplines", .array(of: .string), .required)
            .field("temperament_tags", .array(of: .string), .required)
            .field("bio", .string, .required)
            .field("city", .string, .required)
            .field("coarse_latitude", .double, .required)
            .field("coarse_longitude", .double, .required)
            .field("looking_for", .array(of: .string), .required)
            .field("coggins_test_date", .datetime)
            .field("vaccinations_up_to_date", .bool)
            .field("pedigree", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 5. Horse Photos
        try await database.schema(HorsePhotoModel.schema)
            .id()
            .field("horse_id", .uuid, .required, .references(HorseProfileModel.schema, "id", onDelete: .cascade))
            .field("storage_key", .string, .required)
            .field("url", .string, .required)
            .field("position", .int, .required)
            .field("created_at", .datetime)
            .create()

        // 6. Swipes
        try await database.schema(SwipeModel.schema)
            .id()
            .field("swiper_horse_id", .uuid, .required, .references(HorseProfileModel.schema, "id", onDelete: .cascade))
            .field("target_horse_id", .uuid, .required, .references(HorseProfileModel.schema, "id", onDelete: .cascade))
            .field("direction", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "swiper_horse_id", "target_horse_id")
            .create()

        // 7. Matches
        try await database.schema(MatchModel.schema)
            .id()
            .field("horse_a_id", .uuid, .required, .references(HorseProfileModel.schema, "id", onDelete: .cascade))
            .field("horse_b_id", .uuid, .required, .references(HorseProfileModel.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "horse_a_id", "horse_b_id")
            .create()

        // 8. Conversations
        try await database.schema(ConversationModel.schema)
            .id()
            .field("match_id", .uuid, .required, .references(MatchModel.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "match_id")
            .create()

        // 9. Messages
        try await database.schema(MessageModel.schema)
            .id()
            .field("conversation_id", .uuid, .required, .references(ConversationModel.schema, "id", onDelete: .cascade))
            .field("sender_user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("sender_horse_id", .uuid, .required, .references(HorseProfileModel.schema, "id", onDelete: .cascade))
            .field("body", .string, .required)
            .field("read_at", .datetime)
            .field("created_at", .datetime)
            .create()

        // 10. Blocks
        try await database.schema(BlockModel.schema)
            .id()
            .field("blocker_user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("blocked_user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("reason", .string)
            .field("created_at", .datetime)
            .unique(on: "blocker_user_id", "blocked_user_id")
            .create()

        // 11. Reports
        try await database.schema(ReportModel.schema)
            .id()
            .field("reporter_user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("target_type", .string, .required)
            .field("target_id", .uuid, .required)
            .field("reason", .string, .required)
            .field("details", .string)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .create()

        // 12. Moderation Queue
        try await database.schema(ModerationQueueModel.schema)
            .id()
            .field("report_id", .uuid, .references(ReportModel.schema, "id", onDelete: .setNull))
            .field("target_type", .string, .required)
            .field("target_id", .uuid, .required)
            .field("summary", .string, .required)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .field("reviewed_at", .datetime)
            .create()

        // Database-level indexes and CHECK constraints
        if let sql = database as? SQLDatabase {
            try await sql.raw("""
                CREATE INDEX IF NOT EXISTS idx_horse_profiles_location
                ON horse_profiles (coarse_latitude, coarse_longitude);
                """).run()

            try await sql.raw("""
                CREATE INDEX IF NOT EXISTS idx_horse_profiles_owner
                ON horse_profiles (owner_id);
                """).run()

            try await sql.raw("""
                CREATE INDEX IF NOT EXISTS idx_swipes_pair
                ON swipes (swiper_horse_id, target_horse_id);
                """).run()

            try await sql.raw("""
                CREATE INDEX IF NOT EXISTS idx_swipes_target_direction
                ON swipes (target_horse_id, swiper_horse_id, direction);
                """).run()

            try await sql.raw("""
                CREATE INDEX IF NOT EXISTS idx_matches_pair
                ON matches (horse_a_id, horse_b_id);
                """).run()

            try await sql.raw("""
                CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_at
                ON messages (conversation_id, created_at DESC);
                """).run()

            try await sql.raw("""
                ALTER TABLE horse_profiles
                ADD CONSTRAINT chk_horse_age CHECK (age >= 0 AND age <= 50),
                ADD CONSTRAINT chk_horse_bio_len CHECK (char_length(bio) <= 500);
                """).run()

            try await sql.raw("""
                ALTER TABLE swipes
                ADD CONSTRAINT chk_swipes_distinct_horses CHECK (swiper_horse_id <> target_horse_id);
                """).run()

            try await sql.raw("""
                ALTER TABLE matches
                ADD CONSTRAINT chk_matches_distinct_horses CHECK (horse_a_id <> horse_b_id);
                """).run()

            try await sql.raw("""
                ALTER TABLE blocks
                ADD CONSTRAINT chk_blocks_distinct_users CHECK (blocker_user_id <> blocked_user_id);
                """).run()
        }
    }

    public func revert(on database: Database) async throws {
        try await database.schema(ModerationQueueModel.schema).delete()
        try await database.schema(ReportModel.schema).delete()
        try await database.schema(BlockModel.schema).delete()
        try await database.schema(MessageModel.schema).delete()
        try await database.schema(ConversationModel.schema).delete()
        try await database.schema(MatchModel.schema).delete()
        try await database.schema(SwipeModel.schema).delete()
        try await database.schema(HorsePhotoModel.schema).delete()
        try await database.schema(HorseProfileModel.schema).delete()
        try await database.schema(DeviceTokenModel.schema).delete()
        try await database.schema(RefreshTokenModel.schema).delete()
        try await database.schema(UserModel.schema).delete()
    }
}
