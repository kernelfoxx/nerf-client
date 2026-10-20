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

    public struct Settings: Equatable {
        public var larpGiftsEnabled: Bool
        public var larpNumberEnabled: Bool
        public var larpNumber: String

        public init(larpGiftsEnabled: Bool, larpNumberEnabled: Bool, larpNumber: String) {
            self.larpGiftsEnabled = larpGiftsEnabled
            self.larpNumberEnabled = larpNumberEnabled
            self.larpNumber = larpNumber
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
            larpNumber: defaults.string(forKey: Keys.larpNumber) ?? ""
        )
        var larpGifts: [LarpGift] = []
        if let data = defaults.data(forKey: Keys.larpGifts), let value = try? AdaptedPostboxDecoder().decode(StoredLarpGifts.self, from: data) {
            larpGifts = value.gifts
        }
        self.currentSettings = settings
        self.currentLarpGifts = larpGifts
        self.settingsPromise = ValuePromise(settings, ignoreRepeated: true)
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
        self.settingsPromise.set(updated)
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
