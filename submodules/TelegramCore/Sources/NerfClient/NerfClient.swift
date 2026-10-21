import Foundation
import Postbox
import SwiftSignalKit

// Nerf Client: local-only "LARP" features.
//
// Everything here stays on this device. A LARP gift is never sent to the server: it is a local
// message in `Namespaces.Message.Local` plus a record shown in the recipient's profile gift list,
// and both are always rendered with a "LARP" mark (see `NerfClient.larpMark`).
public final class NerfClient {
    public static let shared = NerfClient()

    public static let larpMark = "LARP"
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
        public var larpGramEnabled: Bool = false
        /// In nanotons.
        public var larpGramNano: Int64 = 0
        public var larpPremiumMonths: Int32 = 0
        public var larpPremiumSince: Int32 = 0
        public var larpUsernameEnabled: Bool = false
        public var larpUsername: String = ""

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
    }

    private struct StoredLarpGifts: Codable {
        var gifts: [LarpGift]
    }

    private enum Keys {
        static let larpGiftsEnabled = "nerf.larpGiftsEnabled"
        static let larpNumberEnabled = "nerf.larpNumberEnabled"
        static let larpNumber = "nerf.larpNumber"
        static let larpGifts = "nerf.larpGifts"
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
        static let larpGramEnabled = "nerf.larpGramEnabled"
        static let larpGramNano = "nerf.larpGramNano"
        static let larpPremiumMonths = "nerf.larpPremiumMonths"
        static let larpPremiumSince = "nerf.larpPremiumSince"
        static let larpUsernameEnabled = "nerf.larpUsernameEnabled"
        static let larpUsername = "nerf.larpUsername"
    }

    private let defaults = UserDefaults.standard
    private let lock = NSLock()
    private var currentSettings: Settings
    private var currentLarpGifts: [LarpGift]
    private let settingsPromise: ValuePromise<Settings>
    private let larpGiftsPromise: ValuePromise<[LarpGift]>

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
        settingsValue.larpGramEnabled = defaults.bool(forKey: Keys.larpGramEnabled)
        settingsValue.larpGramNano = (defaults.object(forKey: Keys.larpGramNano) as? NSNumber)?.int64Value ?? 0
        settingsValue.larpPremiumMonths = Int32(clamping: defaults.integer(forKey: Keys.larpPremiumMonths))
        settingsValue.larpPremiumSince = Int32(clamping: defaults.integer(forKey: Keys.larpPremiumSince))
        settingsValue.larpUsernameEnabled = defaults.bool(forKey: Keys.larpUsernameEnabled)
        settingsValue.larpUsername = defaults.string(forKey: Keys.larpUsername) ?? ""
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
        self.defaults.set(updated.larpGramEnabled, forKey: Keys.larpGramEnabled)
        self.defaults.set(NSNumber(value: updated.larpGramNano), forKey: Keys.larpGramNano)
        self.defaults.set(Int(updated.larpPremiumMonths), forKey: Keys.larpPremiumMonths)
        self.defaults.set(Int(updated.larpPremiumSince), forKey: Keys.larpPremiumSince)
        self.defaults.set(updated.larpUsernameEnabled, forKey: Keys.larpUsernameEnabled)
        self.defaults.set(updated.larpUsername, forKey: Keys.larpUsername)
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
        let (until, overflow) = settings.larpPremiumSince.addingReportingOverflow(settings.larpPremiumMonths.multipliedReportingOverflow(by: 30 * 24 * 60 * 60).partialValue)
        return overflow ? Int32.max : until
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
    public var larpWornGift: StarGift.UniqueGift? {
        let wornId = self.settings.larpWornGiftId
        guard wornId != 0 else {
            return nil
        }
        for record in self.larpGifts {
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
    public var larpWornEmojiStatus: PeerEmojiStatus? {
        guard let gift = self.larpWornGift else {
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

    public func isLarpProfileGift(peerId: EnginePeer.Id, gift: StarGift, date: Int32) -> Bool {
        let giftId = NerfClient.giftId(gift)
        return self.larpGifts.contains(where: { $0.peerId == peerId.toInt64() && $0.date == date && NerfClient.giftId($0.gift) == giftId })
    }

    /// Real gift messages always come from the server, so a gift action in the local namespace is a LARP one.
    public static func isLarpMessage(_ message: Message) -> Bool {
        guard message.id.namespace == Namespaces.Message.Local else {
            return false
        }
        for media in message.media {
            if let action = media as? TelegramMediaAction {
                switch action.action {
                case .starGift, .starGiftUnique:
                    return true
                default:
                    break
                }
            }
        }
        return false
    }

    public static func isLarpMessage(_ message: EngineMessage) -> Bool {
        return isLarpMessage(message._asMessage())
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
            }
            return ProfileGiftsContext.State.StarGift(
                gift: nerfPresentedLarpGift(record.gift, ownerPeerId: peerId),
                reference: reference,
                fromPeer: accountPeer,
                date: record.date,
                text: record.text,
                entities: nil,
                nameHidden: false,
                savedToProfile: true,
                pinnedToTop: false,
                convertStars: nil,
                canUpgrade: record.peerId == accountPeerId.toInt64() && nerfIsGeneric(record.gift),
                canExportDate: nil,
                upgradeStars: nil,
                transferStars: nil,
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
                        return NerfClient.LarpGift(accountPeerId: item.accountPeerId, peerId: item.peerId, localMessageId: item.localMessageId, gift: gift, date: item.date, text: item.text)
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
        return removeInputs
        |> mapToSignal { _ -> Signal<LarpGiftUpgradeResult, NoError> in
            return _internal_addLarpGift(account: account, peerId: accountPeerId, gift: .unique(crafted), text: nil, entities: nil, nameHidden: false, isCrafted: true)
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
        owner: gift.owner,
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
    func larpUniqueGift(slug: String) -> StarGift.UniqueGift? {
        guard slug.hasPrefix("larp-") else {
            return nil
        }
        for record in self.larpGifts {
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
                if let action = item as? TelegramMediaAction, case let .starGiftUnique(_, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, isRefunded, isPrepaidUpgrade, peerIdValue, senderId, savedId, _, canTransferDate, canResaleDate, dropOriginalDetailsStars, assigned, fromOffer, canCraftAt, isCrafted, text, entities, nameHidden) = action.action {
                    media.append(TelegramMediaAction(action: .starGiftUnique(gift: updatedGift, isUpgrade: isUpgrade, isTransferred: isTransferred, savedToProfile: savedToProfile, canExportDate: canExportDate, transferStars: transferStars, isRefunded: isRefunded, isPrepaidUpgrade: isPrepaidUpgrade, peerId: peerIdValue, senderId: senderId, savedId: savedId, resaleAmount: nil, canTransferDate: canTransferDate, canResaleDate: canResaleDate, dropOriginalDetailsStars: dropOriginalDetailsStars, assigned: assigned, fromOffer: fromOffer, canCraftAt: canCraftAt, isCrafted: isCrafted, text: text, entities: entities, nameHidden: nameHidden)))
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
                    return NerfClient.LarpGift(accountPeerId: item.accountPeerId, peerId: item.peerId, localMessageId: item.localMessageId, gift: updatedGift, date: item.date, text: item.text)
                }
                return item
            }
        }
        return true
    }
}

/// The value screen of a unique LARP gift, built from its LARP value instead of the server.
func nerfLarpValueInfo(slug: String) -> StarGift.UniqueGift.ValueInfo? {
    guard slug.hasPrefix("larp-") else {
        return nil
    }
    for record in NerfClient.shared.larpGifts {
        if case let .unique(uniqueGift) = record.gift, uniqueGift.slug == slug, let value = uniqueGift.valueAmount, value > 0 {
            return StarGift.UniqueGift.ValueInfo(
                isLastSaleOnFragment: false,
                valueIsAverage: false,
                value: value,
                currency: "USD",
                initialSaleDate: record.date,
                initialSaleStars: max(1, value * 100 / 150),
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
        return removeInputs
        |> mapToSignal { _ -> Signal<EngineMessage.Id?, NoError> in
            return _internal_addLarpGift(account: account, peerId: accountPeerId, gift: .unique(crafted), text: nil, entities: nil, nameHidden: false, isCrafted: true)
        }
        |> castError(CraftStarGiftError.self)
        |> map { _ -> ProfileGiftsContext.State.StarGift in
            return ProfileGiftsContext.State.StarGift(gift: .unique(crafted), reference: .slug(slug: crafted.slug), fromPeer: nil, date: Int32(Date().timeIntervalSince1970), text: nil, entities: nil, nameHidden: false, savedToProfile: true, pinnedToTop: false, convertStars: nil, canUpgrade: false, canExportDate: nil, upgradeStars: nil, transferStars: nil, canTransferDate: nil, canResaleDate: nil, collectionIds: nil, prepaidUpgradeHash: nil, upgradeSeparate: false, dropOriginalDetailsStars: nil, number: nil, isRefunded: false, canCraftAt: 0)
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
        return ProfileGiftsContext.State.StarGift(gift: nerfPresentedLarpGift(record.gift, ownerPeerId: accountPeerId), reference: .slug(slug: uniqueGift.slug), fromPeer: nil, date: record.date, text: record.text, entities: nil, nameHidden: false, savedToProfile: true, pinnedToTop: false, convertStars: nil, canUpgrade: false, canExportDate: nil, upgradeStars: nil, transferStars: nil, canTransferDate: nil, canResaleDate: nil, collectionIds: nil, prepaidUpgradeHash: nil, upgradeSeparate: false, dropOriginalDetailsStars: nil, number: nil, isRefunded: false, canCraftAt: 0)
    }
}
