import Foundation
import Postbox
import SwiftSignalKit

// Nerf Client: local-only "LARP" features.
//
// Everything here stays on this device. A LARP gift is never sent to the server: it is a local
// message in `Namespaces.Message.Local` plus a record shown in the recipient's profile gift list.
public final class NerfClient {
    public static let shared = NerfClient()

    /// What Streamer Mode shows in place of hidden values.
    public static let streamerMask = "•••"

    public struct Settings: Equatable {
        public var larpGiftsEnabled: Bool
        public var larpNumberEnabled: Bool
        public var larpNumber: String
        public var larpStarsEnabled: Bool
        public var larpStars: Int64
        public var larpTonEnabled: Bool
        /// In nanotons, as `StarsAmount.value` holds for a TON balance.
        public var larpTonNano: Int64
        public var streamerMode: Bool
        public var showUserId: Bool
        public var hideStories: Bool = false
        public var hideAds: Bool = false
        public var confirmCalls: Bool = false
        public var confirmStickers: Bool = false
        public var confirmVoice: Bool = false
        public var showSeconds: Bool = false
        public var larpPremium: Bool = false
        public var saveProtectedContent: Bool = false
        public var larpRatingEnabled: Bool = false
        public var larpRatingLevel: Int32 = 0
        public var larpChannelEnabled: Bool = false
        public var larpSubscribers: Int32 = 0
        public var larpViewsMultiplier: Int32 = 1
        public var larpBoostLevel: Int32 = 0
        public var larpWornGiftId: Int64 = 0
        public var unlockGramWallet: Bool = false
        public var hideEditedLabel: Bool = false
        public var hideViewCounts: Bool = false
        /// 0 is off; 1...7 are Telegram's preset colors.
        public var larpNameColor: Int32 = 0
        public var larpProfileColor: Int32 = 0
        public var squareAvatars: Bool = false
        public var unlockChatTranslation: Bool = false
        public var larpGramEnabled: Bool = false
        /// In nanotons.
        public var larpGramNano: Int64 = 0
        public var larpPremiumMonths: Int32 = 0
        public var larpPremiumSince: Int32 = 0
        public var larpUsernameEnabled: Bool = false
        public var larpUsername: String = ""
        /// More usernames shown under the main one, separated by spaces or commas.
        public var larpAdditionalUsernames: String = ""
        /// The Fragment price in TON as typed; empty means the item is not a collectible.
        public var larpUsernamePrice: String = ""
        /// The Fragment purchase date as typed (DD.MM.YYYY); empty means today.
        public var larpUsernamePurchaseDate: String = ""
        public var larpNumberPrice: String = ""
        public var larpNumberPurchaseDate: String = ""
        public var larpVerificationEnabled: Bool = false
        /// The username the verification mark was copied from, as typed.
        public var larpVerificationSource: String = ""
        public var larpVerificationIconFileId: Int64 = 0
        public var larpVerificationBotId: Int64 = 0
        public var larpVerificationDescription: String = ""

        public init(larpGiftsEnabled: Bool, larpNumberEnabled: Bool, larpNumber: String, larpStarsEnabled: Bool, larpStars: Int64, larpTonEnabled: Bool, larpTonNano: Int64, streamerMode: Bool, showUserId: Bool) {
            self.larpGiftsEnabled = larpGiftsEnabled
            self.larpNumberEnabled = larpNumberEnabled
            self.larpNumber = larpNumber
            self.larpStarsEnabled = larpStarsEnabled
            self.larpStars = larpStars
            self.larpTonEnabled = larpTonEnabled
            self.larpTonNano = larpTonNano
            self.streamerMode = streamerMode
            self.showUserId = showUserId
        }
    }

    public struct LarpGift: Codable, Equatable {
        public let accountPeerId: Int64
        public let peerId: Int64
        public let localMessageId: Int32
        public let gift: StarGift
        public let date: Int32
        public let text: String?
        public let pinnedToTop: Bool
        public let savedToProfile: Bool
        /// Whether the gift is also listed among the collectibles of the account's wallet.
        public let inWallet: Bool

        private enum CodingKeys: String, CodingKey {
            case accountPeerId
            case peerId
            case localMessageId
            case gift
            case date
            case text
            case pinnedToTop
            case savedToProfile
            case inWallet
        }

        public init(accountPeerId: Int64, peerId: Int64, localMessageId: Int32, gift: StarGift, date: Int32, text: String?, pinnedToTop: Bool = false, savedToProfile: Bool = true, inWallet: Bool = false) {
            self.accountPeerId = accountPeerId
            self.peerId = peerId
            self.localMessageId = localMessageId
            self.gift = gift
            self.date = date
            self.text = text
            self.pinnedToTop = pinnedToTop
            self.savedToProfile = savedToProfile
            self.inWallet = inWallet
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.accountPeerId = try container.decode(Int64.self, forKey: .accountPeerId)
            self.peerId = try container.decode(Int64.self, forKey: .peerId)
            self.localMessageId = try container.decode(Int32.self, forKey: .localMessageId)
            self.gift = try container.decode(StarGift.self, forKey: .gift)
            self.date = try container.decode(Int32.self, forKey: .date)
            self.text = try container.decodeIfPresent(String.self, forKey: .text)
            self.pinnedToTop = try container.decodeIfPresent(Bool.self, forKey: .pinnedToTop) ?? false
            self.savedToProfile = try container.decodeIfPresent(Bool.self, forKey: .savedToProfile) ?? true
            self.inWallet = try container.decodeIfPresent(Bool.self, forKey: .inWallet) ?? false
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.accountPeerId, forKey: .accountPeerId)
            try container.encode(self.peerId, forKey: .peerId)
            try container.encode(self.localMessageId, forKey: .localMessageId)
            try container.encode(self.gift, forKey: .gift)
            try container.encode(self.date, forKey: .date)
            try container.encodeIfPresent(self.text, forKey: .text)
            try container.encode(self.pinnedToTop, forKey: .pinnedToTop)
            try container.encode(self.savedToProfile, forKey: .savedToProfile)
            try container.encode(self.inWallet, forKey: .inWallet)
        }

        func withUpdated(gift: StarGift) -> LarpGift {
            return LarpGift(accountPeerId: self.accountPeerId, peerId: self.peerId, localMessageId: self.localMessageId, gift: gift, date: self.date, text: self.text, pinnedToTop: self.pinnedToTop, savedToProfile: self.savedToProfile, inWallet: self.inWallet)
        }

        func withUpdated(pinnedToTop: Bool) -> LarpGift {
            return LarpGift(accountPeerId: self.accountPeerId, peerId: self.peerId, localMessageId: self.localMessageId, gift: self.gift, date: self.date, text: self.text, pinnedToTop: pinnedToTop, savedToProfile: self.savedToProfile, inWallet: self.inWallet)
        }

        func withUpdated(savedToProfile: Bool) -> LarpGift {
            return LarpGift(accountPeerId: self.accountPeerId, peerId: self.peerId, localMessageId: self.localMessageId, gift: self.gift, date: self.date, text: self.text, pinnedToTop: self.pinnedToTop, savedToProfile: savedToProfile, inWallet: self.inWallet)
        }

        func withUpdated(inWallet: Bool) -> LarpGift {
            return LarpGift(accountPeerId: self.accountPeerId, peerId: self.peerId, localMessageId: self.localMessageId, gift: self.gift, date: self.date, text: self.text, pinnedToTop: self.pinnedToTop, savedToProfile: self.savedToProfile, inWallet: inWallet)
        }

        func withUpdated(peerId: Int64, localMessageId: Int32, date: Int32) -> LarpGift {
            return LarpGift(accountPeerId: self.accountPeerId, peerId: peerId, localMessageId: localMessageId, gift: self.gift, date: date, text: self.text, pinnedToTop: self.pinnedToTop, savedToProfile: self.savedToProfile)
        }
    }

    private struct StoredLarpGifts: Codable {
        var gifts: [LarpGift]
    }

    private enum Keys {
        static let larpGiftsEnabled = "nerf.larpGiftsEnabled"
        static let larpNumberEnabled = "nerf.larpNumberEnabled"
        static let larpNumber = "nerf.larpNumber"
        static let larpGifts = "nerf.larpGifts"
        static let larpWalletCard = "nerf.larpWalletCard"
        static let larpStarsEnabled = "nerf.larpStarsEnabled"
        static let larpStars = "nerf.larpStars"
        static let larpTonEnabled = "nerf.larpTonEnabled"
        static let larpTonNano = "nerf.larpTonNano"
        static let streamerMode = "nerf.streamerMode"
        // Stored inverted so that a missing value means "shown".
        static let hideUserId = "nerf.hideUserId"
        static let hideStories = "nerf.hideStories"
        static let hideAds = "nerf.hideAds"
        static let confirmCalls = "nerf.confirmCalls"
        static let confirmStickers = "nerf.confirmStickers"
        static let confirmVoice = "nerf.confirmVoice"
        static let showSeconds = "nerf.showSeconds"
        static let larpPremium = "nerf.larpPremium"
        static let saveProtectedContent = "nerf.saveProtectedContent"
        static let larpRatingEnabled = "nerf.larpRatingEnabled"
        static let larpRatingLevel = "nerf.larpRatingLevel"
        static let larpChannelEnabled = "nerf.larpChannelEnabled"
        static let larpSubscribers = "nerf.larpSubscribers"
        static let larpViewsMultiplier = "nerf.larpViewsMultiplier"
        static let larpBoostLevel = "nerf.larpBoostLevel"
        static let larpWornGiftId = "nerf.larpWornGiftId"
        static let unlockGramWallet = "nerf.unlockGramWallet"
        static let hideEditedLabel = "nerf.hideEditedLabel"
        static let hideViewCounts = "nerf.hideViewCounts"
        static let larpNameColor = "nerf.larpNameColor"
        static let larpProfileColor = "nerf.larpProfileColor"
        static let squareAvatars = "nerf.squareAvatars"
        static let unlockChatTranslation = "nerf.unlockChatTranslation"
        static let larpGramEnabled = "nerf.larpGramEnabled"
        static let larpGramNano = "nerf.larpGramNano"
        static let larpPremiumMonths = "nerf.larpPremiumMonths"
        static let larpPremiumSince = "nerf.larpPremiumSince"
        static let larpUsernameEnabled = "nerf.larpUsernameEnabled"
        static let larpUsername = "nerf.larpUsername"
        static let larpAdditionalUsernames = "nerf.larpAdditionalUsernames"
        static let larpUsernamePrice = "nerf.larpUsernamePrice"
        static let larpUsernamePurchaseDate = "nerf.larpUsernamePurchaseDate"
        static let larpNumberPrice = "nerf.larpNumberPrice"
        static let larpNumberPurchaseDate = "nerf.larpNumberPurchaseDate"
        static let larpVerificationEnabled = "nerf.larpVerificationEnabled"
        static let larpVerificationSource = "nerf.larpVerificationSource"
        static let larpVerificationIconFileId = "nerf.larpVerificationIconFileId"
        static let larpVerificationBotId = "nerf.larpVerificationBotId"
        static let larpVerificationDescription = "nerf.larpVerificationDescription"
    }

    private let defaults = UserDefaults.standard
    private let lock = NSLock()
    private var currentSettings: Settings
    private var currentLarpGifts: [LarpGift]
    private let settingsPromise: ValuePromise<Settings>
    private let larpGiftsPromise: ValuePromise<[LarpGift]>
    private var larpWalletCardRevision: Int = 0
    private let larpWalletCardPromise = ValuePromise<Int>(0, ignoreRepeated: true)

    private init() {
        let defaults = UserDefaults.standard
        let settings = Settings(
            larpGiftsEnabled: defaults.bool(forKey: Keys.larpGiftsEnabled),
            larpNumberEnabled: defaults.bool(forKey: Keys.larpNumberEnabled),
            larpNumber: defaults.string(forKey: Keys.larpNumber) ?? "",
            larpStarsEnabled: defaults.bool(forKey: Keys.larpStarsEnabled),
            larpStars: (defaults.object(forKey: Keys.larpStars) as? NSNumber)?.int64Value ?? 0,
            larpTonEnabled: defaults.bool(forKey: Keys.larpTonEnabled),
            larpTonNano: (defaults.object(forKey: Keys.larpTonNano) as? NSNumber)?.int64Value ?? 0,
            streamerMode: defaults.bool(forKey: Keys.streamerMode),
            showUserId: !defaults.bool(forKey: Keys.hideUserId)
        )
        var settingsValue = settings
        settingsValue.hideStories = defaults.bool(forKey: Keys.hideStories)
        settingsValue.hideAds = defaults.bool(forKey: Keys.hideAds)
        settingsValue.confirmCalls = defaults.bool(forKey: Keys.confirmCalls)
        settingsValue.confirmStickers = defaults.bool(forKey: Keys.confirmStickers)
        settingsValue.confirmVoice = defaults.bool(forKey: Keys.confirmVoice)
        settingsValue.showSeconds = defaults.bool(forKey: Keys.showSeconds)
        settingsValue.larpPremium = defaults.bool(forKey: Keys.larpPremium)
        settingsValue.saveProtectedContent = defaults.bool(forKey: Keys.saveProtectedContent)
        settingsValue.larpRatingEnabled = defaults.bool(forKey: Keys.larpRatingEnabled)
        settingsValue.larpRatingLevel = Int32(defaults.integer(forKey: Keys.larpRatingLevel))
        settingsValue.larpChannelEnabled = defaults.bool(forKey: Keys.larpChannelEnabled)
        settingsValue.larpSubscribers = Int32(clamping: defaults.integer(forKey: Keys.larpSubscribers))
        settingsValue.larpViewsMultiplier = max(1, Int32(clamping: defaults.integer(forKey: Keys.larpViewsMultiplier)))
        settingsValue.larpBoostLevel = Int32(clamping: defaults.integer(forKey: Keys.larpBoostLevel))
        settingsValue.larpWornGiftId = Int64(defaults.string(forKey: Keys.larpWornGiftId) ?? "") ?? 0
        settingsValue.unlockGramWallet = defaults.bool(forKey: Keys.unlockGramWallet)
        settingsValue.hideEditedLabel = defaults.bool(forKey: Keys.hideEditedLabel)
        settingsValue.hideViewCounts = defaults.bool(forKey: Keys.hideViewCounts)
        settingsValue.larpNameColor = Int32(clamping: defaults.integer(forKey: Keys.larpNameColor))
        settingsValue.larpProfileColor = Int32(clamping: defaults.integer(forKey: Keys.larpProfileColor))
        settingsValue.squareAvatars = defaults.bool(forKey: Keys.squareAvatars)
        settingsValue.unlockChatTranslation = defaults.bool(forKey: Keys.unlockChatTranslation)
        settingsValue.larpGramEnabled = defaults.bool(forKey: Keys.larpGramEnabled)
        settingsValue.larpGramNano = (defaults.object(forKey: Keys.larpGramNano) as? NSNumber)?.int64Value ?? 0
        settingsValue.larpPremiumMonths = Int32(clamping: defaults.integer(forKey: Keys.larpPremiumMonths))
        settingsValue.larpPremiumSince = Int32(clamping: defaults.integer(forKey: Keys.larpPremiumSince))
        settingsValue.larpUsernameEnabled = defaults.bool(forKey: Keys.larpUsernameEnabled)
        settingsValue.larpUsername = defaults.string(forKey: Keys.larpUsername) ?? ""
        settingsValue.larpAdditionalUsernames = defaults.string(forKey: Keys.larpAdditionalUsernames) ?? ""
        settingsValue.larpUsernamePrice = defaults.string(forKey: Keys.larpUsernamePrice) ?? ""
        settingsValue.larpUsernamePurchaseDate = defaults.string(forKey: Keys.larpUsernamePurchaseDate) ?? ""
        settingsValue.larpNumberPrice = defaults.string(forKey: Keys.larpNumberPrice) ?? ""
        settingsValue.larpNumberPurchaseDate = defaults.string(forKey: Keys.larpNumberPurchaseDate) ?? ""
        settingsValue.larpVerificationEnabled = defaults.bool(forKey: Keys.larpVerificationEnabled)
        settingsValue.larpVerificationSource = defaults.string(forKey: Keys.larpVerificationSource) ?? ""
        settingsValue.larpVerificationIconFileId = (defaults.object(forKey: Keys.larpVerificationIconFileId) as? NSNumber)?.int64Value ?? 0
        settingsValue.larpVerificationBotId = (defaults.object(forKey: Keys.larpVerificationBotId) as? NSNumber)?.int64Value ?? 0
        settingsValue.larpVerificationDescription = defaults.string(forKey: Keys.larpVerificationDescription) ?? ""
        var larpGifts: [LarpGift] = []
        if let data = defaults.data(forKey: Keys.larpGifts), let value = try? AdaptedPostboxDecoder().decode(StoredLarpGifts.self, from: data) {
            larpGifts = value.gifts
        }
        self.currentSettings = settingsValue
        self.currentLarpGifts = larpGifts
        self.settingsPromise = ValuePromise(settingsValue, ignoreRepeated: true)
        self.larpGiftsPromise = ValuePromise(larpGifts, ignoreRepeated: true)
    }

    public var settings: Settings {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.currentSettings
    }

    public var settingsSignal: Signal<Settings, NoError> {
        return self.settingsPromise.get()
    }

    public func updateSettings(_ f: (Settings) -> Settings) {
        self.lock.lock()
        let updated = f(self.currentSettings)
        self.currentSettings = updated
        self.lock.unlock()

        self.defaults.set(updated.larpGiftsEnabled, forKey: Keys.larpGiftsEnabled)
        self.defaults.set(updated.larpNumberEnabled, forKey: Keys.larpNumberEnabled)
        self.defaults.set(updated.larpNumber, forKey: Keys.larpNumber)
        self.defaults.set(updated.larpStarsEnabled, forKey: Keys.larpStarsEnabled)
        self.defaults.set(NSNumber(value: updated.larpStars), forKey: Keys.larpStars)
        self.defaults.set(updated.larpTonEnabled, forKey: Keys.larpTonEnabled)
        self.defaults.set(NSNumber(value: updated.larpTonNano), forKey: Keys.larpTonNano)
        self.defaults.set(updated.streamerMode, forKey: Keys.streamerMode)
        self.defaults.set(!updated.showUserId, forKey: Keys.hideUserId)
        self.defaults.set(updated.hideStories, forKey: Keys.hideStories)
        self.defaults.set(updated.hideAds, forKey: Keys.hideAds)
        self.defaults.set(updated.confirmCalls, forKey: Keys.confirmCalls)
        self.defaults.set(updated.confirmStickers, forKey: Keys.confirmStickers)
        self.defaults.set(updated.confirmVoice, forKey: Keys.confirmVoice)
        self.defaults.set(updated.showSeconds, forKey: Keys.showSeconds)
        self.defaults.set(updated.larpPremium, forKey: Keys.larpPremium)
        self.defaults.set(updated.saveProtectedContent, forKey: Keys.saveProtectedContent)
        self.defaults.set(updated.larpRatingEnabled, forKey: Keys.larpRatingEnabled)
        self.defaults.set(Int(updated.larpRatingLevel), forKey: Keys.larpRatingLevel)
        self.defaults.set(updated.larpChannelEnabled, forKey: Keys.larpChannelEnabled)
        self.defaults.set(Int(updated.larpSubscribers), forKey: Keys.larpSubscribers)
        self.defaults.set(Int(updated.larpViewsMultiplier), forKey: Keys.larpViewsMultiplier)
        self.defaults.set(Int(updated.larpBoostLevel), forKey: Keys.larpBoostLevel)
        self.defaults.set("\(updated.larpWornGiftId)", forKey: Keys.larpWornGiftId)
        self.defaults.set(updated.unlockGramWallet, forKey: Keys.unlockGramWallet)
        self.defaults.set(updated.hideEditedLabel, forKey: Keys.hideEditedLabel)
        self.defaults.set(updated.hideViewCounts, forKey: Keys.hideViewCounts)
        self.defaults.set(Int(updated.larpNameColor), forKey: Keys.larpNameColor)
        self.defaults.set(Int(updated.larpProfileColor), forKey: Keys.larpProfileColor)
        self.defaults.set(updated.squareAvatars, forKey: Keys.squareAvatars)
        self.defaults.set(updated.unlockChatTranslation, forKey: Keys.unlockChatTranslation)
        self.defaults.set(updated.larpGramEnabled, forKey: Keys.larpGramEnabled)
        self.defaults.set(NSNumber(value: updated.larpGramNano), forKey: Keys.larpGramNano)
        self.defaults.set(Int(updated.larpPremiumMonths), forKey: Keys.larpPremiumMonths)
        self.defaults.set(Int(updated.larpPremiumSince), forKey: Keys.larpPremiumSince)
        self.defaults.set(updated.larpUsernameEnabled, forKey: Keys.larpUsernameEnabled)
        self.defaults.set(updated.larpUsername, forKey: Keys.larpUsername)
        self.defaults.set(updated.larpAdditionalUsernames, forKey: Keys.larpAdditionalUsernames)
        self.defaults.set(updated.larpUsernamePrice, forKey: Keys.larpUsernamePrice)
        self.defaults.set(updated.larpUsernamePurchaseDate, forKey: Keys.larpUsernamePurchaseDate)
        self.defaults.set(updated.larpNumberPrice, forKey: Keys.larpNumberPrice)
        self.defaults.set(updated.larpNumberPurchaseDate, forKey: Keys.larpNumberPurchaseDate)
        self.defaults.set(updated.larpVerificationEnabled, forKey: Keys.larpVerificationEnabled)
        self.defaults.set(updated.larpVerificationSource, forKey: Keys.larpVerificationSource)
        self.defaults.set(NSNumber(value: updated.larpVerificationIconFileId), forKey: Keys.larpVerificationIconFileId)
        self.defaults.set(NSNumber(value: updated.larpVerificationBotId), forKey: Keys.larpVerificationBotId)
        self.defaults.set(updated.larpVerificationDescription, forKey: Keys.larpVerificationDescription)
        self.settingsPromise.set(updated)
    }

    /// The LARP Gram balance in nanotons, shown in the wallet instead of the real one, or nil when it is off.
    public var larpGramBalance: Int64? {
        let settings = self.settings
        return settings.larpGramEnabled ? settings.larpGramNano : nil
    }

    /// The end of the LARP Premium period, or nil when LARP Premium has no duration set.
    public var larpPremiumUntil: Int32? {
        let settings = self.settings
        guard settings.larpPremium, settings.larpPremiumMonths > 0 else {
            return nil
        }
        let (duration, durationOverflow) = settings.larpPremiumMonths.multipliedReportingOverflow(by: 30 * 24 * 60 * 60)
        let (until, overflow) = settings.larpPremiumSince.addingReportingOverflow(duration)
        return durationOverflow || overflow ? Int32.max : until
    }

    /// The account as its own profile header shows it: with the worn LARP gift (which also gives
    /// the gift's backdrop and sparkles) and the LARP name and profile colors.
    public func larpPresentedAccountPeer(_ peer: EnginePeer?, accountPeerId: EnginePeer.Id) -> EnginePeer? {
        guard case let .user(user) = peer, user.id == accountPeerId, !self.isStreamerMode else {
            return peer
        }
        var updated = user
        if let status = self.larpWornEmojiStatus(accountPeerId: accountPeerId) {
            updated = updated.withUpdatedEmojiStatus(status)
        }
        let settings = self.settings
        if settings.larpNameColor > 0 {
            updated = updated.withUpdatedNameColor(.preset(PeerNameColor(rawValue: settings.larpNameColor - 1)))
        }
        if settings.larpProfileColor > 0 {
            updated = updated.withUpdatedProfileColor(PeerNameColor(rawValue: settings.larpProfileColor - 1))
        }
        if let verification = self.larpVerification {
            updated = TelegramUser(id: updated.id, accessHash: updated.accessHash, firstName: updated.firstName, lastName: updated.lastName, username: updated.username, phone: updated.phone, photo: updated.photo, botInfo: updated.botInfo, restrictionInfo: updated.restrictionInfo, flags: updated.flags, emojiStatus: updated.emojiStatus, usernames: updated.usernames, storiesHidden: updated.storiesHidden, nameColor: updated.nameColor, backgroundEmojiId: updated.backgroundEmojiId, profileColor: updated.profileColor, profileBackgroundEmojiId: updated.profileBackgroundEmojiId, subscriberCount: updated.subscriberCount, verificationIconFileId: verification.iconFileId, linkedCommunityId: updated.linkedCommunityId)
        }
        return .user(updated)
    }

    /// The LARP third-party verification of the account: the mark before its name and the line in its profile,
    /// shown only on this device. Nil when it is off, not loaded yet, or Streamer Mode is on.
    public var larpVerification: PeerVerification? {
        let settings = self.settings
        guard settings.larpVerificationEnabled, settings.larpVerificationIconFileId != 0, !settings.streamerMode else {
            return nil
        }
        return PeerVerification(
            botId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(settings.larpVerificationBotId)),
            iconFileId: settings.larpVerificationIconFileId,
            description: settings.larpVerificationDescription,
            descriptionEntities: []
        )
    }

    public var isStreamerMode: Bool {
        return self.settings.streamerMode
    }

    /// The LARP balance shown instead of the real one (Stars, or nanotons for TON), or nil when it is off.
    public func larpBalance(ton: Bool) -> Int64? {
        let settings = self.settings
        if ton {
            return settings.larpTonEnabled ? settings.larpTonNano : nil
        } else {
            return settings.larpStarsEnabled ? settings.larpStars : nil
        }
    }

    /// Takes `amount` from the LARP balance when it is on. Returns false, changing nothing, when it is
    /// on and too low. The real balance is never touched.
    public func spendLarpBalance(ton: Bool, amount: Int64) -> Bool {
        var result = true
        self.updateSettings { current in
            var current = current
            if ton, current.larpTonEnabled {
                if current.larpTonNano < amount {
                    result = false
                } else {
                    current.larpTonNano -= amount
                }
            } else if !ton, current.larpStarsEnabled {
                if current.larpStars < amount {
                    result = false
                } else {
                    current.larpStars -= amount
                }
            }
            return current
        }
        return result
    }

    /// Gives back what `spendLarpBalance` took, when the LARP gift it paid for could not be created.
    public func refundLarpBalance(ton: Bool, amount: Int64) {
        self.updateSettings { current in
            var current = current
            if ton, current.larpTonEnabled {
                let (sum, overflow) = current.larpTonNano.addingReportingOverflow(amount)
                current.larpTonNano = overflow ? Int64.max : sum
            } else if !ton, current.larpStarsEnabled {
                let (sum, overflow) = current.larpStars.addingReportingOverflow(amount)
                current.larpStars = overflow ? Int64.max : sum
            }
            return current
        }
    }

    /// The custom number to show instead of the account's own phone, or nil when the feature is off.
    public var larpNumber: String? {
        let settings = self.settings
        let number = settings.larpNumber.trimmingCharacters(in: .whitespaces)
        if settings.larpNumberEnabled && !number.isEmpty {
            return number
        }
        return nil
    }

    /// The custom username (without "@") to show instead of the account's own, or nil when the feature is off.
    public var larpUsername: String? {
        let settings = self.settings
        let username = settings.larpUsername.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        if settings.larpUsernameEnabled && !username.isEmpty {
            return username
        }
        return nil
    }

    /// The extra LARP usernames (without "@") listed under the main one.
    public var larpAdditionalUsernames: [String] {
        guard let mainUsername = self.larpUsername else {
            return []
        }
        var result: [String] = []
        for part in self.settings.larpAdditionalUsernames.components(separatedBy: CharacterSet(charactersIn: " ,;@\n")) {
            if !part.isEmpty, part.lowercased() != mainUsername.lowercased(), !result.contains(where: { $0.lowercased() == part.lowercased() }) {
                result.append(part)
            }
        }
        return result
    }

    /// The Fragment info of a LARP username that has a price, or nil when it is not a LARP collectible.
    public func larpCollectibleInfo(username: String, tonUsdRate: Double) -> TelegramCollectibleItemInfo? {
        guard !self.isStreamerMode, let mainUsername = self.larpUsername else {
            return nil
        }
        let name = username.lowercased()
        guard name == mainUsername.lowercased() || self.larpAdditionalUsernames.contains(where: { $0.lowercased() == name }) else {
            return nil
        }
        let settings = self.settings
        return NerfClient.larpCollectibleInfo(subject: .username(username), price: settings.larpUsernamePrice, purchaseDate: settings.larpUsernamePurchaseDate, tonUsdRate: tonUsdRate, url: "https://fragment.com/username/\(name)")
    }

    /// The Fragment info of the +888 LARP number when it has a price, or nil.
    public func larpCollectibleInfo(phoneNumber: String, tonUsdRate: Double) -> TelegramCollectibleItemInfo? {
        guard !self.isStreamerMode, let larpNumber = self.larpNumber else {
            return nil
        }
        let digits = phoneNumber.filter { $0.isASCII && $0.isNumber }
        guard digits.hasPrefix("888"), digits == larpNumber.filter({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        let settings = self.settings
        return NerfClient.larpCollectibleInfo(subject: .phoneNumber(phoneNumber), price: settings.larpNumberPrice, purchaseDate: settings.larpNumberPurchaseDate, tonUsdRate: tonUsdRate, url: "https://fragment.com/number/\(digits)")
    }

    private static func larpCollectibleInfo(subject: TelegramCollectibleItemInfo.Subject, price: String, purchaseDate: String, tonUsdRate: Double, url: String) -> TelegramCollectibleItemInfo? {
        let nano = NerfClient.nanotons(text: price)
        guard nano > 0 else {
            return nil
        }
        let usdCents = Double(nano) / 1_000_000_000.0 * tonUsdRate * 100.0
        return TelegramCollectibleItemInfo(
            subject: subject,
            purchaseDate: NerfClient.timestamp(dateText: purchaseDate) ?? Int32(Date().timeIntervalSince1970),
            currency: "USD",
            currencyAmount: usdCents.isFinite && usdCents < Double(Int64.max) ? Int64(max(0.0, usdCents)) : Int64.max,
            cryptoCurrency: "TON",
            cryptoCurrencyAmount: nano,
            url: url
        )
    }

    /// Parses a typed TON amount ("1 250,5") into nanotons, saturating instead of overflowing.
    public static func nanotons(text: String) -> Int64 {
        let normalized = text.replacingOccurrences(of: ",", with: ".").filter { ($0.isASCII && $0.isNumber) || $0 == "." }
        let parts = normalized.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let integerText = parts.first else {
            return 0
        }
        let integer: Int64
        if integerText.isEmpty {
            integer = 0
        } else if let value = Int64(integerText) {
            integer = value
        } else {
            return Int64.max
        }
        var fractionText = parts.count > 1 ? String(parts[1].filter { $0 != "." }.prefix(9)) : ""
        fractionText += String(repeating: "0", count: 9 - fractionText.count)
        let fraction = Int64(fractionText) ?? 0
        let (product, multiplyOverflow) = integer.multipliedReportingOverflow(by: 1_000_000_000)
        if multiplyOverflow {
            return Int64.max
        }
        let (sum, addOverflow) = product.addingReportingOverflow(fraction)
        return addOverflow ? Int64.max : sum
    }

    /// Parses "DD.MM.YYYY" (also with "/" or "-") into a timestamp at noon, or nil when it is not a past date.
    public static func timestamp(dateText: String) -> Int32? {
        let parts = dateText.components(separatedBy: CharacterSet(charactersIn: "./- ")).filter { !$0.isEmpty }
        guard parts.count == 3, let day = Int(parts[0]), let month = Int(parts[1]), var year = Int(parts[2]) else {
            return nil
        }
        if year < 100 {
            year += 2000
        }
        guard (1 ... 31).contains(day), (1 ... 12).contains(month), (2013 ... 2037).contains(year) else {
            return nil
        }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        components.hour = 12
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components), calendar.component(.day, from: date) == day else {
            return nil
        }
        let now = Date()
        return Int32(min(date, now).timeIntervalSince1970)
    }

    /// The LARP star rating to show in the account's own profile, or nil when it is off.
    public var larpStarRating: TelegramStarRating? {
        let settings = self.settings
        guard settings.larpRatingEnabled else {
            return nil
        }
        let level = max(1, settings.larpRatingLevel)
        let currentLevelStars = Int64(level) * 1000
        return TelegramStarRating(level: level, currentLevelStars: currentLevelStars, stars: currentLevelStars + 500, nextLevelStars: currentLevelStars + 1000)
    }

    /// LARP Channel applies only to broadcast channels this account created.
    public func isLarpChannel(_ peer: Peer?) -> Bool {
        guard self.settings.larpChannelEnabled, let channel = peer as? TelegramChannel, case .broadcast = channel.info, channel.flags.contains(.isCreator) else {
            return false
        }
        return true
    }

    public func isLarpChannel(_ peer: EnginePeer?) -> Bool {
        return self.isLarpChannel(peer?._asPeer())
    }

    /// The LARP subscriber count for one of the account's own channels, or nil when it does not apply.
    public func larpSubscriberCount(_ peer: Peer?) -> Int32? {
        guard self.isLarpChannel(peer) else {
            return nil
        }
        return self.settings.larpSubscribers
    }

    /// A post's view count, multiplied in the account's own channels while LARP Channel is on.
    public static func larpViewCount(_ count: Int, message: Message) -> Int {
        // Hide View Counts: a zero count is not shown at all.
        if NerfClient.shared.settings.hideViewCounts {
            return 0
        }
        guard NerfClient.shared.isLarpChannel(message.peers[message.id.peerId]) else {
            return count
        }
        let multiplier = Int(max(1, NerfClient.shared.settings.larpViewsMultiplier))
        let (product, overflow) = count.multipliedReportingOverflow(by: multiplier)
        return overflow ? Int.max : product
    }

    public var larpGifts: [LarpGift] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.currentLarpGifts
    }

    public var larpGiftsSignal: Signal<[LarpGift], NoError> {
        return self.larpGiftsPromise.get()
    }

    fileprivate func updateLarpGifts(_ f: ([LarpGift]) -> [LarpGift]) {
        self.lock.lock()
        let updated = f(self.currentLarpGifts)
        self.currentLarpGifts = updated
        self.lock.unlock()

        if let data = try? AdaptedPostboxEncoder().encode(StoredLarpGifts(gifts: updated)) {
            self.defaults.set(data, forKey: Keys.larpGifts)
        }
        self.larpGiftsPromise.set(updated)
    }

    /// The account's own unique LARP gifts that were moved to its wallet. They are listed there only on this device.
    public func larpWalletGifts(accountPeerId: EnginePeer.Id) -> [StarGift.UniqueGift] {
        guard self.settings.larpGiftsEnabled else {
            return []
        }
        let accountId = accountPeerId.toInt64()
        return self.larpGifts.compactMap { record -> StarGift.UniqueGift? in
            guard record.inWallet, record.accountPeerId == accountId, record.peerId == accountId else {
                return nil
            }
            if case let .unique(gift) = nerfPresentedLarpGift(record.gift, ownerPeerId: accountPeerId) {
                return gift
            }
            return nil
        }
    }

    /// Whether one of the account's own unique LARP gifts is in its wallet; nil when the slug is not such a gift.
    public func isLarpGiftInWallet(slug: String, accountPeerId: EnginePeer.Id) -> Bool? {
        let accountId = accountPeerId.toInt64()
        for record in self.larpGifts {
            if record.accountPeerId == accountId, record.peerId == accountId, case let .unique(gift) = record.gift, gift.slug == slug {
                return record.inWallet
            }
        }
        return nil
    }

    public func setLarpGiftInWallet(slug: String, accountPeerId: EnginePeer.Id, inWallet: Bool) {
        let accountId = accountPeerId.toInt64()
        self.updateLarpGifts { current in
            return current.map { record in
                if record.accountPeerId == accountId, record.peerId == accountId, case let .unique(gift) = record.gift, gift.slug == slug {
                    return record.withUpdated(inWallet: inWallet)
                }
                return record
            }
        }
    }

    /// The LARP gifts stuck on the account's wallet card, as the wallet encodes them. Telegram never receives them.
    public func larpWalletCardData(accountPeerId: EnginePeer.Id) -> Data? {
        return self.defaults.data(forKey: "\(Keys.larpWalletCard).\(accountPeerId.toInt64())")
    }

    public func setLarpWalletCardData(_ data: Data?, accountPeerId: EnginePeer.Id) {
        let key = "\(Keys.larpWalletCard).\(accountPeerId.toInt64())"
        if let data {
            self.defaults.set(data, forKey: key)
        } else {
            self.defaults.removeObject(forKey: key)
        }
        self.lock.lock()
        self.larpWalletCardRevision += 1
        let revision = self.larpWalletCardRevision
        self.lock.unlock()
        // The wallet saves its card in the middle of a gesture, so observers are told after it returns.
        DispatchQueue.main.async {
            self.larpWalletCardPromise.set(revision)
        }
    }

    /// Changes whenever the LARP card stickers are saved.
    public var larpWalletCardSignal: Signal<Int, NoError> {
        return self.larpWalletCardPromise.get()
    }

    public func hasLarpGifts(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id) -> Bool {
        guard self.settings.larpGiftsEnabled else {
            return false
        }
        return self.larpGifts.contains(where: { $0.accountPeerId == accountPeerId.toInt64() && $0.peerId == peerId.toInt64() })
    }

    /// Finds the LARP gift shown by a gift screen: by its local message, or by owner, gift and date.
    public func larpGiftRecord(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id?, messageId: EngineMessage.Id?, gift: StarGift, date: Int32) -> LarpGift? {
        let gifts = self.larpGifts.filter { $0.accountPeerId == accountPeerId.toInt64() }
        if let messageId, messageId.namespace == Namespaces.Message.Local {
            return gifts.first(where: { $0.peerId == messageId.peerId.toInt64() && $0.localMessageId == messageId.id })
        }
        guard let peerId else {
            return nil
        }
        let giftId = NerfClient.giftId(gift)
        return gifts.first(where: { $0.peerId == peerId.toInt64() && $0.date == date && NerfClient.giftId($0.gift) == giftId })
    }

    /// Unique LARP gifts are made with a "larp-" slug, which no real gift has.
    public static func isLarpUniqueGift(_ gift: StarGift.UniqueGift) -> Bool {
        return gift.slug.hasPrefix("larp-")
    }

    /// The unique LARP gift worn as the account's emoji status, shown only on this device.
    public func larpWornGift(accountPeerId: EnginePeer.Id? = nil) -> StarGift.UniqueGift? {
        let wornId = self.settings.larpWornGiftId
        guard wornId != 0 else {
            return nil
        }
        for record in self.larpGifts {
            if let accountPeerId, record.accountPeerId != accountPeerId.toInt64() {
                continue
            }
            if case let .unique(uniqueGift) = record.gift, uniqueGift.id == wornId {
                return uniqueGift
            }
        }
        return nil
    }

    public func setLarpWornGift(_ gift: StarGift.UniqueGift?) {
        self.updateSettings { current in
            var current = current
            current.larpWornGiftId = gift?.id ?? 0
            return current
        }
    }

    /// The worn LARP gift as an emoji status, built as a real collectible status is.
    public func larpWornEmojiStatus(accountPeerId: EnginePeer.Id? = nil) -> PeerEmojiStatus? {
        guard let gift = self.larpWornGift(accountPeerId: accountPeerId) else {
            return nil
        }
        var fileId: Int64?
        var patternFileId: Int64?
        var colors: (Int32, Int32, Int32, Int32)?
        for attribute in gift.attributes {
            switch attribute {
            case let .model(_, file, _, _):
                fileId = file.fileId.id
            case let .pattern(_, file, _):
                patternFileId = file.fileId.id
            case let .backdrop(_, _, innerColor, outerColor, patternColor, textColor, _):
                colors = (innerColor, outerColor, patternColor, textColor)
            default:
                break
            }
        }
        guard let fileId, let patternFileId, let colors else {
            return nil
        }
        return PeerEmojiStatus(content: .starGift(id: gift.id, fileId: fileId, title: gift.title, slug: gift.slug, patternFileId: patternFileId, innerColor: colors.0, outerColor: colors.1, patternColor: colors.2, textColor: colors.3), expirationDate: nil)
    }

    public func isLarpProfileGift(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id, gift: StarGift, date: Int32) -> Bool {
        let giftId = NerfClient.giftId(gift)
        return self.larpGifts.contains(where: { $0.accountPeerId == accountPeerId.toInt64() && $0.peerId == peerId.toInt64() && $0.date == date && NerfClient.giftId($0.gift) == giftId })
    }

    fileprivate static func giftId(_ gift: StarGift) -> Int64 {
        switch gift {
        case let .generic(gift):
            return gift.id
        case let .unique(gift):
            return gift.id
        }
    }
}

func _internal_addLarpGift(account: Account, peerId: EnginePeer.Id, gift: StarGift, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, isCrafted: Bool = false) -> Signal<EngineMessage.Id?, NoError> {
    let accountPeerId = account.peerId
    return account.postbox.transaction { transaction -> EngineMessage.Id? in
        guard peerId.namespace == Namespaces.Peer.CloudUser, transaction.getPeer(peerId) != nil else {
            return nil
        }
        let timestamp = Int32(Date().timeIntervalSince1970)
        let randomId = Int64.random(in: Int64.min ... Int64.max)

        // A market gift bought as a LARP gift belongs to the recipient and is not listed for sale.
        var purchaseAmount: CurrencyAmount?
        if case let .unique(uniqueGift) = gift {
            purchaseAmount = uniqueGift.resellAmounts?.first(where: { $0.currency == .stars }) ?? uniqueGift.resellAmounts?.first
        }
        var gift = gift
        if case let .unique(uniqueGift) = gift {
            gift = .unique(nerfUniqueGift(uniqueGift, owner: .peerId(peerId), resellAmounts: nil, valueAmount: uniqueGift.valueAmount, craftChancePermille: uniqueGift.craftChancePermille ?? nerfDefaultCraftChancePermille))
        }

        let action: TelegramMediaActionType
        switch gift {
        case let .generic(genericGift):
            action = .starGift(gift: gift, convertStars: genericGift.convertStars, text: text, entities: entities, nameHidden: nameHidden, savedToProfile: false, converted: false, upgraded: false, canUpgrade: peerId == accountPeerId, upgradeStars: nil, isRefunded: false, isPrepaidUpgrade: false, upgradeMessageId: nil, peerId: nil, senderId: nil, savedId: nil, prepaidUpgradeHash: nil, giftMessageId: nil, upgradeSeparate: false, isAuctionAcquired: false, toPeerId: nil, number: nil)
        case .unique:
            // The purchase price makes the service line read "You bought <gift> for N Stars", as for a real market purchase.
            action = .starGiftUnique(gift: gift, isUpgrade: false, isTransferred: false, savedToProfile: false, canExportDate: nil, transferStars: nil, isRefunded: false, isPrepaidUpgrade: false, peerId: nil, senderId: accountPeerId, savedId: nil, resaleAmount: isCrafted ? nil : purchaseAmount, canTransferDate: nil, canResaleDate: nil, dropOriginalDetailsStars: nil, assigned: false, fromOffer: false, canCraftAt: peerId == accountPeerId ? 0 : nil, isCrafted: isCrafted, text: text, entities: entities, nameHidden: nameHidden)
        }

        let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: accountPeerId, text: "", attributes: [], media: [TelegramMediaAction(action: action)])
        guard let id = transaction.addMessages([message], location: .Random)[randomId] else {
            return nil
        }
        updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: peerId, minTimestamp: timestamp, forceRootGroupIfNotExists: true)

        NerfClient.shared.updateLarpGifts { current in
            return [NerfClient.LarpGift(accountPeerId: accountPeerId.toInt64(), peerId: peerId.toInt64(), localMessageId: id.id, gift: gift, date: timestamp, text: text)] + current
        }
        return id
    }
}

func _internal_clearLarpGifts(account: Account) -> Signal<Void, NoError> {
    let accountPeerId = account.peerId.toInt64()
    return account.postbox.transaction { transaction -> Void in
        let records = NerfClient.shared.larpGifts.filter { $0.accountPeerId == accountPeerId }
        let ids = records.map { MessageId(peerId: PeerId($0.peerId), namespace: Namespaces.Message.Local, id: $0.localMessageId) }
        transaction.deleteMessages(ids, forEachMedia: nil)
        NerfClient.shared.updateLarpGifts { current in
            return current.filter { $0.accountPeerId != accountPeerId }
        }
    }
}

func nerfProfileGifts(account: Account, peerId: EnginePeer.Id) -> Signal<[ProfileGiftsContext.State.StarGift], NoError> {
    let accountPeerId = account.peerId
    return combineLatest(
        NerfClient.shared.settingsSignal |> map { $0.larpGiftsEnabled } |> distinctUntilChanged,
        NerfClient.shared.larpGiftsSignal,
        account.postbox.transaction { transaction -> EnginePeer? in
            return transaction.getPeer(accountPeerId).flatMap { EnginePeer($0) }
        }
    )
    |> map { enabled, records, accountPeer -> [ProfileGiftsContext.State.StarGift] in
        guard enabled else {
            return []
        }
        return records.filter { $0.accountPeerId == accountPeerId.toInt64() && $0.peerId == peerId.toInt64() }.map { record in
            var reference: StarGiftReference?
            if case let .unique(uniqueGift) = record.gift {
                reference = .slug(slug: uniqueGift.slug)
            } else {
                reference = .message(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: record.localMessageId))
            }
            return ProfileGiftsContext.State.StarGift(
                gift: nerfPresentedLarpGift(record.gift, ownerPeerId: peerId),
                reference: reference,
                fromPeer: accountPeer,
                date: record.date,
                text: record.text,
                entities: nil,
                nameHidden: false,
                savedToProfile: record.savedToProfile,
                pinnedToTop: record.pinnedToTop,
                convertStars: nil,
                canUpgrade: record.peerId == accountPeerId.toInt64() && nerfIsGeneric(record.gift),
                canExportDate: nil,
                upgradeStars: nil,
                transferStars: reference == nil ? nil : 0,
                canTransferDate: nil,
                canResaleDate: nil,
                collectionIds: nil,
                prepaidUpgradeHash: nil,
                upgradeSeparate: false,
                dropOriginalDetailsStars: nil,
                number: nil,
                isRefunded: false,
                canCraftAt: record.peerId == accountPeerId.toInt64() && !nerfIsGeneric(record.gift) ? 0 : nil
            )
        }
    }
}

/// Resolves a gift reference to a local LARP record. A nil result means the reference is not LARP.
func nerfLarpRecord(account: Account, reference: StarGiftReference) -> NerfClient.LarpGift? {
    let accountPeerId = account.peerId.toInt64()
    switch reference {
    case let .slug(slug):
        guard slug.hasPrefix("larp-") else {
            return nil
        }
        return NerfClient.shared.larpGifts.first { record in
            guard record.accountPeerId == accountPeerId, case let .unique(uniqueGift) = record.gift else {
                return false
            }
            return uniqueGift.slug == slug
        }
    case let .message(messageId):
        guard messageId.namespace == Namespaces.Message.Local else {
            return nil
        }
        return NerfClient.shared.larpGifts.first { record in
            return record.accountPeerId == accountPeerId && record.peerId == messageId.peerId.toInt64() && record.localMessageId == messageId.id
        }
    case let .peer(peerId, id):
        return NerfClient.shared.larpGifts.first { record in
            return record.accountPeerId == accountPeerId && record.peerId == peerId.toInt64() && NerfClient.giftId(record.gift) == id
        }
    }
}

/// Moves a LARP gift to another peer entirely on this device. Nothing is sent to Telegram.
func _internal_transferLarpGift(account: Account, reference: StarGiftReference, peerId: EnginePeer.Id) -> Signal<Never, TransferStarGiftError>? {
    guard let record = nerfLarpRecord(account: account, reference: reference), case let .unique(uniqueGift) = record.gift else {
        return nil
    }
    return account.postbox.transaction { transaction -> Bool in
        guard transaction.getPeer(peerId) != nil else {
            return false
        }
        let timestamp = Int32(Date().timeIntervalSince1970)
        let randomId = Int64.random(in: Int64.min ... Int64.max)
        let transferred = StarGift.unique(nerfUniqueGift(uniqueGift, owner: .peerId(peerId), resellAmounts: nil, valueAmount: uniqueGift.valueAmount, craftChancePermille: uniqueGift.craftChancePermille ?? nerfDefaultCraftChancePermille))
        let action = TelegramMediaAction(action: .starGiftUnique(
            gift: transferred,
            isUpgrade: false,
            isTransferred: true,
            savedToProfile: true,
            canExportDate: nil,
            transferStars: nil,
            isRefunded: false,
            isPrepaidUpgrade: false,
            peerId: nil,
            senderId: account.peerId,
            savedId: nil,
            resaleAmount: nil,
            canTransferDate: nil,
            canResaleDate: nil,
            dropOriginalDetailsStars: nil,
            assigned: false,
            fromOffer: false,
            canCraftAt: peerId == account.peerId ? 0 : nil,
            isCrafted: false,
            text: nil,
            entities: nil,
            nameHidden: false
        ))
        let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: randomId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: account.peerId, text: "", attributes: [], media: [action])
        guard let id = transaction.addMessages([message], location: .Random)[randomId] else {
            return false
        }
        updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: peerId, minTimestamp: timestamp, forceRootGroupIfNotExists: true)

        let oldId = MessageId(peerId: EnginePeer.Id(record.peerId), namespace: Namespaces.Message.Local, id: record.localMessageId)
        transaction.deleteMessages([oldId], forEachMedia: nil)
        NerfClient.shared.updateLarpGifts { current in
            return current.map { item in
                if item.accountPeerId == record.accountPeerId && item.peerId == record.peerId && item.localMessageId == record.localMessageId {
                    return item.withUpdated(peerId: peerId.toInt64(), localMessageId: id.id, date: timestamp)
                }
                return item
            }
        }
        if record.accountPeerId == account.peerId.toInt64(), record.peerId == account.peerId.toInt64(), NerfClient.shared.settings.larpWornGiftId == uniqueGift.id {
            NerfClient.shared.setLarpWornGift(nil)
        }
        return true
    }
    |> castError(TransferStarGiftError.self)
    |> mapToSignal { success -> Signal<Never, TransferStarGiftError> in
        return success ? .complete() : .fail(.generic)
    }
}

/// Changes the local sale price of a LARP gift. The server is never asked to list or unlist it.
func _internal_resellLarpGift(account: Account, reference: StarGiftReference, price: CurrencyAmount?) -> Signal<Never, UpdateStarGiftPriceError>? {
    guard let record = nerfLarpRecord(account: account, reference: reference), record.peerId == account.peerId.toInt64(), case let .unique(uniqueGift) = record.gift else {
        return nil
    }
    guard price == nil || price?.currency == .stars else {
        return .fail(.generic)
    }
    return _internal_updateLarpUniqueGift(account: account, peerId: EnginePeer.Id(record.peerId), localMessageId: record.localMessageId, salePriceStars: price?.amount.value, valueCents: uniqueGift.valueAmount)
    |> castError(UpdateStarGiftPriceError.self)
    |> mapToSignal { success -> Signal<Never, UpdateStarGiftPriceError> in
        return success ? .complete() : .fail(.generic)
    }
}

/// Pins or unpins a LARP gift in its owner's profile, on this device only.
func _internal_setLarpGiftPinned(account: Account, reference: StarGiftReference, pinnedToTop: Bool) -> Bool? {
    guard let record = nerfLarpRecord(account: account, reference: reference) else {
        return nil
    }
    NerfClient.shared.updateLarpGifts { current in
        let updated = current.map { item -> NerfClient.LarpGift in
            if item.accountPeerId == record.accountPeerId && item.peerId == record.peerId && item.localMessageId == record.localMessageId {
                return item.withUpdated(pinnedToTop: pinnedToTop)
            }
            return item
        }
        return updated.sorted { lhs, rhs in
            if lhs.pinnedToTop != rhs.pinnedToTop {
                return lhs.pinnedToTop && !rhs.pinnedToTop
            }
            return lhs.date > rhs.date
        }
    }
    return true
}

/// Applies the pinned gift order to local LARP records and reports whether there were any.
func nerfApplyLarpPinnedReferences(account: Account, references: [StarGiftReference]) -> Bool {
    let accountPeerId = account.peerId.toInt64()
    let pinned = Set(references.compactMap { reference -> String? in
        guard let record = nerfLarpRecord(account: account, reference: reference) else {
            return nil
        }
        return "\(record.peerId):\(record.localMessageId)"
    })
    let found = NerfClient.shared.larpGifts.contains { $0.accountPeerId == accountPeerId }
    NerfClient.shared.updateLarpGifts { current in
        return current.map { item -> NerfClient.LarpGift in
            guard item.accountPeerId == accountPeerId else {
                return item
            }
            return item.withUpdated(pinnedToTop: pinned.contains("\(item.peerId):\(item.localMessageId)"))
        }
    }
    return found
}

/// Shows or hides a LARP gift in its owner's profile, on this device only.
func _internal_setLarpGiftSaved(account: Account, reference: StarGiftReference, added: Bool) -> Bool? {
    guard let record = nerfLarpRecord(account: account, reference: reference) else {
        return nil
    }
    NerfClient.shared.updateLarpGifts { current in
        return current.map { item -> NerfClient.LarpGift in
            if item.accountPeerId == record.accountPeerId && item.peerId == record.peerId && item.localMessageId == record.localMessageId {
                return item.withUpdated(savedToProfile: added)
            }
            return item
        }
    }
    return true
}

func nerfApplyLarpBalance(_ state: StarsContext.State?, ton: Bool) -> StarsContext.State? {
    guard var state = state, let value = NerfClient.shared.larpBalance(ton: ton) else {
        return state
    }
    state.balance = StarsAmount(value: value, nanos: 0)
    return state
}

public enum LarpGiftUpgradeResult {
    case upgraded(StarGift)
    case notEnoughBalance
    case unavailable
}

private func nerfStoreMessage(_ message: Message, media: [Media]) -> StoreMessage {
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: nil, authorId: message.author?.id, text: message.text, attributes: message.attributes, media: media)
}

/// Picks one attribute, rarer ones less often, as a real upgrade does.
private func nerfPickAttribute(_ attributes: [StarGift.UniqueGift.Attribute], tierBoost: Int = 1) -> StarGift.UniqueGift.Attribute? {
    let boost = max(1, tierBoost)
    func weight(_ rarity: StarGift.UniqueGift.Attribute.Rarity) -> Int {
        switch rarity {
        case let .permille(value):
            return max(1, Int(value))
        case .uncommon:
            return 80
        case .rare:
            return 30 * boost
        case .epic:
            return 10 * boost * boost
        case .legendary:
            return 3 * boost * boost * boost
        }
    }
    let weighted: [(StarGift.UniqueGift.Attribute, Int)] = attributes.compactMap { attribute in
        switch attribute {
        case let .model(_, _, rarity, _), let .pattern(_, _, rarity):
            return (attribute, weight(rarity))
        case let .backdrop(_, _, _, _, _, _, rarity):
            return (attribute, weight(rarity))
        case .originalInfo:
            return nil
        }
    }
    let total = weighted.reduce(0, { $0 + $1.1 })
    guard total > 0 else {
        return nil
    }
    var value = Int.random(in: 0 ..< total)
    for (attribute, weight) in weighted {
        if value < weight {
            return attribute
        }
        value -= weight
    }
    return weighted.last?.0
}

/// Turns a LARP gift into a unique one built from the gift's real upgrade variants. `spend` is
/// asked for the upgrade price and returns false when the balance is too low.
func _internal_upgradeLarpGift(account: Account, peerId: EnginePeer.Id, localMessageId: Int32, spend: @escaping (Int64) -> Bool) -> Signal<LarpGiftUpgradeResult, NoError> {
    let accountPeerId = account.peerId.toInt64()
    guard let record = NerfClient.shared.larpGifts.first(where: { $0.accountPeerId == accountPeerId && $0.peerId == peerId.toInt64() && $0.localMessageId == localMessageId }), case let .generic(genericGift) = record.gift else {
        return .single(.unavailable)
    }
    return _internal_starGiftUpgradePreview(account: account, giftId: genericGift.id)
    |> mapToSignal { preview -> Signal<LarpGiftUpgradeResult, NoError> in
        guard let preview else {
            return .single(.unavailable)
        }
        let models = preview.attributes.filter { if case .model = $0 { return true } else { return false } }
        let patterns = preview.attributes.filter { if case .pattern = $0 { return true } else { return false } }
        let backdrops = preview.attributes.filter { if case .backdrop = $0 { return true } else { return false } }
        guard let model = nerfPickAttribute(models), let pattern = nerfPickAttribute(patterns), let backdrop = nerfPickAttribute(backdrops) else {
            return .single(.unavailable)
        }
        let price = genericGift.upgradeStars ?? preview.prices.first?.stars ?? 0
        if !spend(price) {
            return .single(.notEnoughBalance)
        }

        let total = max(1, genericGift.availability?.total ?? 100_000)
        let number = Int32.random(in: 1 ... total)
        let uniqueId = Int64.random(in: 1 ... Int64.max)
        let uniqueGift = StarGift.UniqueGift(
            id: uniqueId,
            giftId: genericGift.id,
            title: genericGift.title ?? "Gift",
            number: number,
            slug: "larp-\(uniqueId)",
            owner: .peerId(peerId),
            attributes: [model, pattern, backdrop],
            availability: StarGift.UniqueGift.Availability(issued: total, total: total),
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: genericGift.releasedBy,
            valueAmount: nil,
            valueCurrency: nil,
            valueUsdAmount: nil,
            flags: [],
            themePeerId: nil,
            peerColor: nil,
            hostPeerId: nil,
            minOfferStars: nil,
            craftChancePermille: nil
        )
        let gift: StarGift = .unique(uniqueGift)

        return account.postbox.transaction { transaction -> LarpGiftUpgradeResult in
            let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: localMessageId)
            if let message = transaction.getMessage(messageId) {
                let action = TelegramMediaAction(action: .starGiftUnique(gift: gift, isUpgrade: true, isTransferred: false, savedToProfile: false, canExportDate: nil, transferStars: nil, isRefunded: false, isPrepaidUpgrade: false, peerId: nil, senderId: account.peerId, savedId: nil, resaleAmount: nil, canTransferDate: nil, canResaleDate: nil, dropOriginalDetailsStars: nil, assigned: false, fromOffer: false, canCraftAt: peerId == account.peerId ? 0 : nil, isCrafted: false, text: record.text, entities: nil, nameHidden: false))
                transaction.updateMessage(messageId, update: { _ in
                    return .update(nerfStoreMessage(message, media: [action]))
                })
            }
            NerfClient.shared.updateLarpGifts { current in
                return current.map { item in
                    if item.accountPeerId == accountPeerId && item.peerId == peerId.toInt64() && item.localMessageId == localMessageId {
                        return item.withUpdated(gift: gift)
                    }
                    return item
                }
            }
            return .upgraded(gift)
        }
    }
}


/// Crafts a new unique LARP gift from two or more of the account's own unique LARP gifts, which
/// are used up. Crafted models are preferred when the gift has any.
func _internal_craftLarpGifts(account: Account, localMessageIds: [Int32]) -> Signal<LarpGiftUpgradeResult, NoError> {
    let accountPeerId = account.peerId
    let inputs = NerfClient.shared.larpGifts.filter { record in
        guard record.accountPeerId == accountPeerId.toInt64(), record.peerId == accountPeerId.toInt64(), localMessageIds.contains(record.localMessageId) else {
            return false
        }
        if case .unique = record.gift {
            return true
        }
        return false
    }
    guard inputs.count >= 2, let base = inputs.randomElement(), case let .unique(baseGift) = base.gift else {
        return .single(.unavailable)
    }
    return _internal_starGiftUpgradePreview(account: account, giftId: baseGift.giftId)
    |> mapToSignal { preview -> Signal<LarpGiftUpgradeResult, NoError> in
        guard let preview else {
            return .single(.unavailable)
        }
        let models = preview.attributes.filter { if case .model = $0 { return true } else { return false } }
        let craftedModels = models.filter { if case .model(_, _, _, true) = $0 { return true } else { return false } }
        let patterns = preview.attributes.filter { if case .pattern = $0 { return true } else { return false } }
        let backdrops = preview.attributes.filter { if case .backdrop = $0 { return true } else { return false } }
        // Two gifts craft at the base odds; each extra gift raises the odds of rarer tiers.
        let tierBoost = inputs.count - 1
        guard let model = nerfPickAttribute(craftedModels.isEmpty ? models : craftedModels, tierBoost: tierBoost), let pattern = nerfPickAttribute(patterns), let backdrop = nerfPickAttribute(backdrops) else {
            return .single(.unavailable)
        }
        let total = max(1, baseGift.availability.total)
        let number = Int32.random(in: 1 ... total)
        let uniqueId = Int64.random(in: 1 ... Int64.max)
        let crafted = StarGift.UniqueGift(
            id: uniqueId,
            giftId: baseGift.giftId,
            title: baseGift.title,
            number: number,
            slug: "larp-\(uniqueId)",
            owner: .peerId(accountPeerId),
            attributes: [model, pattern, backdrop],
            availability: baseGift.availability,
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: baseGift.releasedBy,
            valueAmount: nil,
            valueCurrency: nil,
            valueUsdAmount: nil,
            flags: [],
            themePeerId: nil,
            peerColor: nil,
            hostPeerId: nil,
            minOfferStars: nil,
            craftChancePermille: nil
        )
        let inputIds = Set(inputs.map { $0.localMessageId })
        let removeInputs = account.postbox.transaction { transaction -> Void in
            transaction.deleteMessages(inputIds.map { MessageId(peerId: accountPeerId, namespace: Namespaces.Message.Local, id: $0) }, forEachMedia: nil)
            NerfClient.shared.updateLarpGifts { current in
                return current.filter { !($0.accountPeerId == accountPeerId.toInt64() && $0.peerId == accountPeerId.toInt64() && inputIds.contains($0.localMessageId)) }
            }
        }
        // Create the new gift first: if that fails, the inputs must stay in the profile.
        return _internal_addLarpGift(account: account, peerId: accountPeerId, gift: .unique(crafted), text: nil, entities: nil, nameHidden: false, isCrafted: true)
        |> mapToSignal { messageId -> Signal<LarpGiftUpgradeResult, NoError> in
            guard messageId != nil else {
                return .single(.unavailable)
            }
            return removeInputs
            |> map { _ -> LarpGiftUpgradeResult in
                return .upgraded(.unique(crafted))
            }
        }
    }
}

private func nerfIsGeneric(_ gift: StarGift) -> Bool {
    if case .generic = gift {
        return true
    }
    return false
}


private func nerfUniqueGift(_ gift: StarGift.UniqueGift, resellAmounts: [CurrencyAmount]?, valueAmount: Int64?) -> StarGift.UniqueGift {
    return nerfUniqueGift(gift, owner: gift.owner, resellAmounts: resellAmounts, valueAmount: valueAmount, craftChancePermille: gift.craftChancePermille)
}

/// Each LARP gift adds this to the odds of a successful craft, as real gifts do.
let nerfDefaultCraftChancePermille: Int32 = 250

func nerfUniqueGift(_ gift: StarGift.UniqueGift, owner: StarGift.UniqueGift.Owner?, resellAmounts: [CurrencyAmount]?, valueAmount: Int64?, craftChancePermille: Int32?) -> StarGift.UniqueGift {
    return StarGift.UniqueGift(
        id: gift.id,
        giftId: gift.giftId,
        title: gift.title,
        number: gift.number,
        slug: gift.slug,
        owner: owner,
        attributes: gift.attributes,
        availability: gift.availability,
        giftAddress: gift.giftAddress,
        resellAmounts: resellAmounts,
        resellForTonOnly: gift.resellForTonOnly,
        releasedBy: gift.releasedBy,
        valueAmount: valueAmount,
        valueCurrency: valueAmount == nil ? nil : (gift.valueCurrency ?? "USD"),
        valueUsdAmount: valueAmount,
        flags: gift.flags,
        themePeerId: gift.themePeerId,
        peerColor: gift.peerColor,
        hostPeerId: gift.hostPeerId,
        minOfferStars: gift.minOfferStars,
        craftChancePermille: craftChancePermille
    )
}

/// How a unique LARP gift is shown: owned by the peer it was given to, craftable when that is
/// the account itself.
func nerfPresentedLarpGift(_ gift: StarGift, ownerPeerId: EnginePeer.Id) -> StarGift {
    guard case let .unique(uniqueGift) = gift else {
        return gift
    }
    return .unique(nerfUniqueGift(uniqueGift, owner: .peerId(ownerPeerId), resellAmounts: uniqueGift.resellAmounts, valueAmount: uniqueGift.valueAmount, craftChancePermille: uniqueGift.craftChancePermille ?? nerfDefaultCraftChancePermille))
}

public extension NerfClient {
    /// The unique LARP gift with this slug, as it is shown.
    func larpUniqueGift(slug: String, accountPeerId: EnginePeer.Id? = nil) -> StarGift.UniqueGift? {
        guard slug.hasPrefix("larp-") else {
            return nil
        }
        for record in self.larpGifts {
            if let accountPeerId, record.accountPeerId != accountPeerId.toInt64() {
                continue
            }
            if case let .unique(uniqueGift) = record.gift, uniqueGift.slug == slug, case let .unique(presented) = nerfPresentedLarpGift(record.gift, ownerPeerId: EnginePeer.Id(record.peerId)) {
                return presented
            }
        }
        return nil
    }
}

/// Sets the LARP sale price (Stars, nil to unlist) and the LARP value (US cents, nil to clear)
/// of one of the account's unique LARP gifts, in its record and its local message.
func _internal_updateLarpUniqueGift(account: Account, peerId: EnginePeer.Id, localMessageId: Int32, salePriceStars: Int64?, valueCents: Int64?) -> Signal<Bool, NoError> {
    let accountPeerId = account.peerId.toInt64()
    return account.postbox.transaction { transaction -> Bool in
        guard let record = NerfClient.shared.larpGifts.first(where: { $0.accountPeerId == accountPeerId && $0.peerId == peerId.toInt64() && $0.localMessageId == localMessageId }), case let .unique(uniqueGift) = record.gift else {
            return false
        }
        let resellAmounts = salePriceStars.flatMap { $0 > 0 ? [CurrencyAmount(amount: StarsAmount(value: $0, nanos: 0), currency: .stars)] : nil }
        let updatedGift: StarGift = .unique(nerfUniqueGift(uniqueGift, resellAmounts: resellAmounts, valueAmount: valueCents.flatMap { $0 > 0 ? $0 : nil }))

        let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: localMessageId)
        if let message = transaction.getMessage(messageId) {
            var media: [Media] = []
            for item in message.media {
                if let action = item as? TelegramMediaAction, case let .starGiftUnique(_, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, isRefunded, isPrepaidUpgrade, peerIdValue, senderId, savedId, resaleAmount, canTransferDate, canResaleDate, dropOriginalDetailsStars, assigned, fromOffer, canCraftAt, isCrafted, text, entities, nameHidden) = action.action {
                    media.append(TelegramMediaAction(action: .starGiftUnique(gift: updatedGift, isUpgrade: isUpgrade, isTransferred: isTransferred, savedToProfile: savedToProfile, canExportDate: canExportDate, transferStars: transferStars, isRefunded: isRefunded, isPrepaidUpgrade: isPrepaidUpgrade, peerId: peerIdValue, senderId: senderId, savedId: savedId, resaleAmount: resaleAmount, canTransferDate: canTransferDate, canResaleDate: canResaleDate, dropOriginalDetailsStars: dropOriginalDetailsStars, assigned: assigned, fromOffer: fromOffer, canCraftAt: canCraftAt, isCrafted: isCrafted, text: text, entities: entities, nameHidden: nameHidden)))
                } else {
                    media.append(item)
                }
            }
            transaction.updateMessage(messageId, update: { _ in
                return .update(nerfStoreMessage(message, media: media))
            })
        }
        NerfClient.shared.updateLarpGifts { current in
            return current.map { item in
                if item.accountPeerId == accountPeerId && item.peerId == peerId.toInt64() && item.localMessageId == localMessageId {
                    return item.withUpdated(gift: updatedGift)
                }
                return item
            }
        }
        return true
    }
}

/// The value screen of a unique LARP gift, built from its LARP value instead of the server.
func nerfLarpValueInfo(slug: String, accountPeerId: EnginePeer.Id? = nil) -> StarGift.UniqueGift.ValueInfo? {
    guard slug.hasPrefix("larp-") else {
        return nil
    }
    for record in NerfClient.shared.larpGifts {
        if let accountPeerId, record.accountPeerId != accountPeerId.toInt64() {
            continue
        }
        if case let .unique(uniqueGift) = record.gift, uniqueGift.slug == slug, let value = uniqueGift.valueAmount, value > 0 {
            return StarGift.UniqueGift.ValueInfo(
                isLastSaleOnFragment: false,
                valueIsAverage: false,
                value: value,
                currency: "USD",
                initialSaleDate: record.date,
                initialSaleStars: max(1, value / 3 * 2),
                initialSalePrice: value,
                lastSaleDate: nil,
                lastSalePrice: nil,
                floorPrice: value,
                averagePrice: value,
                listedCount: nil,
                fragmentListedCount: nil,
                fragmentListedUrl: nil
            )
        }
    }
    return nil
}


private func nerfLarpCraftPick(account: Account, base: StarGift.UniqueGift, inputCount: Int) -> Signal<StarGift.UniqueGift?, NoError> {
    return _internal_starGiftUpgradePreview(account: account, giftId: base.giftId)
    |> map { preview -> StarGift.UniqueGift? in
        guard let preview else {
            return nil
        }
        let models = preview.attributes.filter { if case .model = $0 { return true } else { return false } }
        let craftedModels = models.filter { if case .model(_, _, _, true) = $0 { return true } else { return false } }
        let patterns = preview.attributes.filter { if case .pattern = $0 { return true } else { return false } }
        let backdrops = preview.attributes.filter { if case .backdrop = $0 { return true } else { return false } }
        guard let model = nerfPickAttribute(craftedModels.isEmpty ? models : craftedModels, tierBoost: inputCount - 1), let pattern = nerfPickAttribute(patterns), let backdrop = nerfPickAttribute(backdrops) else {
            return nil
        }
        let total = max(1, base.availability.total)
        let uniqueId = Int64.random(in: 1 ... Int64.max)
        return StarGift.UniqueGift(
            id: uniqueId,
            giftId: base.giftId,
            title: base.title,
            number: Int32.random(in: 1 ... total),
            slug: "larp-\(uniqueId)",
            owner: .peerId(account.peerId),
            attributes: [model, pattern, backdrop],
            availability: base.availability,
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: base.releasedBy,
            valueAmount: nil,
            valueCurrency: nil,
            valueUsdAmount: nil,
            flags: [],
            themePeerId: nil,
            peerColor: nil,
            hostPeerId: nil,
            minOfferStars: nil,
            craftChancePermille: nerfDefaultCraftChancePermille
        )
    }
}

/// Telegram's craft screen with LARP gifts: the odds are the sum of the gifts' craft chances, as
/// for real gifts. Success replaces them with a new unique LARP gift; failure burns them.
func _internal_craftLarpGiftsWithOdds(account: Account, slugs: [String]) -> Signal<ProfileGiftsContext.State.StarGift, CraftStarGiftError> {
    let accountPeerId = account.peerId
    let inputs = NerfClient.shared.larpGifts.filter { record in
        guard record.accountPeerId == accountPeerId.toInt64(), record.peerId == accountPeerId.toInt64(), case let .unique(uniqueGift) = record.gift else {
            return false
        }
        return slugs.contains(uniqueGift.slug)
    }
    guard inputs.count >= 2, inputs.count == slugs.count, let base = inputs.randomElement(), case let .unique(baseGift) = base.gift else {
        return .fail(.unavailable)
    }
    let chance = inputs.reduce(0, { total, record -> Int in
        if case let .unique(uniqueGift) = record.gift {
            return total + Int(uniqueGift.craftChancePermille ?? nerfDefaultCraftChancePermille)
        }
        return total
    })
    let succeeded = Int.random(in: 0 ..< 1000) < min(1000, chance)

    let inputIds = Set(inputs.map { $0.localMessageId })
    let removeInputs = account.postbox.transaction { transaction -> Void in
        transaction.deleteMessages(inputIds.map { MessageId(peerId: accountPeerId, namespace: Namespaces.Message.Local, id: $0) }, forEachMedia: nil)
        NerfClient.shared.updateLarpGifts { current in
            return current.filter { !($0.accountPeerId == accountPeerId.toInt64() && $0.peerId == accountPeerId.toInt64() && inputIds.contains($0.localMessageId)) }
        }
    }

    if !succeeded {
        return removeInputs
        |> castError(CraftStarGiftError.self)
        |> mapToSignal { _ -> Signal<ProfileGiftsContext.State.StarGift, CraftStarGiftError> in
            return .fail(.craftFailed)
        }
    }
    return nerfLarpCraftPick(account: account, base: baseGift, inputCount: inputs.count)
    |> castError(CraftStarGiftError.self)
    |> mapToSignal { crafted -> Signal<ProfileGiftsContext.State.StarGift, CraftStarGiftError> in
        guard let crafted else {
            return .fail(.unavailable)
        }
        // Only burn the inputs once the replacement exists.
        return _internal_addLarpGift(account: account, peerId: accountPeerId, gift: .unique(crafted), text: nil, entities: nil, nameHidden: false, isCrafted: true)
        |> castError(CraftStarGiftError.self)
        |> mapToSignal { messageId -> Signal<ProfileGiftsContext.State.StarGift, CraftStarGiftError> in
            guard messageId != nil else {
                return .fail(.unavailable)
            }
            return removeInputs
            |> castError(CraftStarGiftError.self)
            |> map { _ -> ProfileGiftsContext.State.StarGift in
                return ProfileGiftsContext.State.StarGift(gift: .unique(crafted), reference: .slug(slug: crafted.slug), fromPeer: nil, date: Int32(Date().timeIntervalSince1970), text: nil, entities: nil, nameHidden: false, savedToProfile: true, pinnedToTop: false, convertStars: nil, canUpgrade: false, canExportDate: nil, upgradeStars: nil, transferStars: 0, canTransferDate: nil, canResaleDate: nil, collectionIds: nil, prepaidUpgradeHash: nil, upgradeSeparate: false, dropOriginalDetailsStars: nil, number: nil, isRefunded: false, canCraftAt: 0)
            }
        }
    }
}

/// The account's unique LARP gifts that can go into a craft of this gift kind.
func nerfLarpCraftCandidates(account: Account, giftId: Int64) -> [ProfileGiftsContext.State.StarGift] {
    let accountPeerId = account.peerId
    return NerfClient.shared.larpGifts.compactMap { record -> ProfileGiftsContext.State.StarGift? in
        guard record.accountPeerId == accountPeerId.toInt64(), record.peerId == accountPeerId.toInt64(), case let .unique(uniqueGift) = record.gift, uniqueGift.giftId == giftId else {
            return nil
        }
        return ProfileGiftsContext.State.StarGift(gift: nerfPresentedLarpGift(record.gift, ownerPeerId: accountPeerId), reference: .slug(slug: uniqueGift.slug), fromPeer: nil, date: record.date, text: record.text, entities: nil, nameHidden: false, savedToProfile: true, pinnedToTop: record.pinnedToTop, convertStars: nil, canUpgrade: false, canExportDate: nil, upgradeStars: nil, transferStars: 0, canTransferDate: nil, canResaleDate: nil, collectionIds: nil, prepaidUpgradeHash: nil, upgradeSeparate: false, dropOriginalDetailsStars: nil, number: nil, isRefunded: false, canCraftAt: 0)
    }
}


/// Gives the account a unique LARP gift built from the chosen real upgrade variants and number.
func _internal_addCustomLarpUniqueGift(account: Account, gift: StarGift.Gift, model: StarGift.UniqueGift.Attribute, pattern: StarGift.UniqueGift.Attribute, backdrop: StarGift.UniqueGift.Attribute, number: Int32) -> Signal<EngineMessage.Id?, NoError> {
    let total = max(1, gift.availability?.total ?? 100_000)
    let uniqueId = Int64.random(in: 1 ... Int64.max)
    let uniqueGift = StarGift.UniqueGift(
        id: uniqueId,
        giftId: gift.id,
        title: gift.title ?? "Gift",
        number: max(1, number),
        slug: "larp-\(uniqueId)",
        owner: .peerId(account.peerId),
        attributes: [model, pattern, backdrop],
        availability: StarGift.UniqueGift.Availability(issued: total, total: total),
        giftAddress: nil,
        resellAmounts: nil,
        resellForTonOnly: false,
        releasedBy: gift.releasedBy,
        valueAmount: nil,
        valueCurrency: nil,
        valueUsdAmount: nil,
        flags: [],
        themePeerId: nil,
        peerColor: nil,
        hostPeerId: nil,
        minOfferStars: nil,
        craftChancePermille: nerfDefaultCraftChancePermille
    )
    return _internal_addLarpGift(account: account, peerId: account.peerId, gift: .unique(uniqueGift), text: nil, entities: nil, nameHidden: false)
}

/// Copies a verification mark into the LARP settings: from a verifier bot, or from an account or chat that
/// already has the mark. Only what Telegram shows about that username is read; the verifier is not contacted.
func _internal_loadLarpVerification(account: Account, name: String) -> Signal<Bool, NoError> {
    return _internal_resolvePeerByName(account: account, name: name, referrer: nil)
    |> mapToSignal { result -> Signal<PeerId?, NoError> in
        switch result {
        case .progress:
            return .complete()
        case let .result(peerId):
            return .single(peerId)
        }
    }
    |> take(1)
    |> mapToSignal { peerId -> Signal<Bool, NoError> in
        guard let peerId else {
            return .single(false)
        }
        return _internal_fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)
        |> mapToSignal { _ -> Signal<Bool, NoError> in
            return .complete()
        }
        |> then(
            account.postbox.transaction { transaction -> PeerVerification? in
                let cachedData = transaction.getPeerCachedData(peerId: peerId)
                if let cachedData = cachedData as? CachedUserData {
                    if let verifier = cachedData.botInfo?.verifierSettings {
                        return PeerVerification(botId: peerId, iconFileId: verifier.iconFileId, description: verifier.customDescription ?? "This user was verified by the organization \"\(verifier.companyName)\".", descriptionEntities: [])
                    }
                    return cachedData.verification
                } else if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.verification
                }
                return nil
            }
            |> map { verification -> Bool in
                guard let verification, verification.iconFileId != 0 else {
                    return false
                }
                NerfClient.shared.updateSettings { current in
                    var current = current
                    current.larpVerificationIconFileId = verification.iconFileId
                    current.larpVerificationBotId = verification.botId.id._internalGetInt64Value()
                    current.larpVerificationDescription = verification.description
                    return current
                }
                return true
            }
        )
    }
}
