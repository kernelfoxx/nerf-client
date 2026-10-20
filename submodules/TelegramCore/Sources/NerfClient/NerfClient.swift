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
        self.settingsPromise.set(updated)
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

    private static func giftId(_ gift: StarGift) -> Int64 {
        switch gift {
        case let .generic(gift):
            return gift.id
        case let .unique(gift):
            return gift.id
        }
    }
}

func _internal_addLarpGift(account: Account, peerId: EnginePeer.Id, gift: StarGift, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool) -> Signal<EngineMessage.Id?, NoError> {
    let accountPeerId = account.peerId
    return account.postbox.transaction { transaction -> EngineMessage.Id? in
        guard peerId.namespace == Namespaces.Peer.CloudUser, transaction.getPeer(peerId) != nil else {
            return nil
        }
        let timestamp = Int32(Date().timeIntervalSince1970)
        let randomId = Int64.random(in: Int64.min ... Int64.max)

        let action: TelegramMediaActionType
        switch gift {
        case let .generic(genericGift):
            action = .starGift(gift: gift, convertStars: genericGift.convertStars, text: text, entities: entities, nameHidden: nameHidden, savedToProfile: false, converted: false, upgraded: false, canUpgrade: false, upgradeStars: nil, isRefunded: false, isPrepaidUpgrade: false, upgradeMessageId: nil, peerId: nil, senderId: nil, savedId: nil, prepaidUpgradeHash: nil, giftMessageId: nil, upgradeSeparate: false, isAuctionAcquired: false, toPeerId: nil, number: nil)
        case let .unique(uniqueGift):
            // The resale price makes the service line read "You bought <gift> for N Stars", as for a real market purchase.
            let resaleAmount = uniqueGift.resellAmounts?.first(where: { $0.currency == .stars }) ?? uniqueGift.resellAmounts?.first
            action = .starGiftUnique(gift: gift, isUpgrade: false, isTransferred: false, savedToProfile: false, canExportDate: nil, transferStars: nil, isRefunded: false, isPrepaidUpgrade: false, peerId: nil, senderId: accountPeerId, savedId: nil, resaleAmount: resaleAmount, canTransferDate: nil, canResaleDate: nil, dropOriginalDetailsStars: nil, assigned: false, fromOffer: false, canCraftAt: nil, isCrafted: false, text: text, entities: entities, nameHidden: nameHidden)
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
    if peerId == accountPeerId {
        return .single([])
    }
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
            return ProfileGiftsContext.State.StarGift(
                gift: record.gift,
                reference: nil,
                fromPeer: accountPeer,
                date: record.date,
                text: record.text,
                entities: nil,
                nameHidden: false,
                savedToProfile: true,
                pinnedToTop: false,
                convertStars: nil,
                canUpgrade: false,
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
                canCraftAt: nil
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
