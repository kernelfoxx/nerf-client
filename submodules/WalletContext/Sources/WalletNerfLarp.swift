import Foundation
import TelegramCore

// Nerf Client: LARP gifts in the wallet exist only on this device. They are added to the wallet state
// when a screen shows it, and are never part of what the wallet stores, signs or sends to Telegram.

@available(macOS 10.15, *)
private struct WalletLarpCardLayout: Codable {
    /// Addresses of every sticker on the card, bottom to top, real gifts included.
    let order: [String]
    let stickers: [WalletContext.CardSticker]
}

@available(macOS 10.15, *)
private func walletLarpCardLayout(accountPeerId: EnginePeer.Id) -> WalletLarpCardLayout? {
    guard let data = NerfClient.shared.larpWalletCardData(accountPeerId: accountPeerId) else {
        return nil
    }
    return try? JSONDecoder().decode(WalletLarpCardLayout.self, from: data)
}

@available(macOS 10.15, *)
public extension WalletContext.Collectible {
    /// LARP gifts use their slug in place of a TON address.
    var isLarp: Bool {
        return self.address.hasPrefix("larp-")
    }

    init(larpGift gift: StarGift.UniqueGift, ownerAddress: String) {
        self.init(nft: WalletNftItem(
            collectionAddress: nil,
            address: gift.slug,
            ownerAddress: ownerAddress,
            index: "\(gift.number)",
            name: "\(gift.title) #\(gift.number)",
            description: nil,
            image: nil,
            imageSmall: nil,
            contentUrl: nil,
            lottie: nil,
            attributes: nil,
            extra: nil,
            gift: gift
        ))
    }
}

@available(macOS 10.15, *)
public extension WalletContext.State {
    /// The state with the account's LARP wallet gifts and its LARP card stickers added.
    func withLarp(accountPeerId: EnginePeer.Id) -> WalletContext.State {
        guard case .wallet = self.phase, let walletAddress = self.walletAddress else {
            return self
        }
        let gifts = NerfClient.shared.larpWalletGifts(accountPeerId: accountPeerId)
        if gifts.isEmpty {
            return self
        }
        let existing = Set(self.collectibles.items.map { $0.address })
        let larpItems = gifts.map { WalletContext.Collectible(larpGift: $0, ownerAddress: walletAddress) }.filter { !existing.contains($0.address) }
        let collectibles = WalletContext.CollectiblesState(
            items: larpItems + self.collectibles.items,
            nextOffset: self.collectibles.nextOffset,
            generation: self.collectibles.generation,
            isRefreshing: self.collectibles.isRefreshing,
            isLoadingMore: self.collectibles.isLoadingMore,
            error: self.collectibles.error
        )

        var cardStickers = self.cardStickers
        if let layout = walletLarpCardLayout(accountPeerId: accountPeerId) {
            let owned = Set(larpItems.map { $0.address })
            let larpStickers = layout.stickers.filter { owned.contains($0.gift.address) }
            if !larpStickers.isEmpty {
                var rank: [String: Int] = [:]
                for (index, address) in layout.order.enumerated() {
                    rank[address] = index
                }
                let merged = (self.cardStickers + larpStickers).enumerated().sorted { lhs, rhs in
                    let lhsRank = rank[lhs.element.gift.address] ?? Int.max
                    let rhsRank = rank[rhs.element.gift.address] ?? Int.max
                    if lhsRank != rhsRank {
                        return lhsRank < rhsRank
                    }
                    return lhs.offset < rhs.offset
                }
                cardStickers = WalletContext.CardSticker.validated(merged.map { $0.element })
            }
        }

        return WalletContext.State(
            phase: self.phase,
            walletAddress: self.walletAddress,
            balance: self.balance,
            transactions: self.transactions,
            collectibles: collectibles,
            pendingTransfers: self.pendingTransfers,
            activeOperation: self.activeOperation,
            fiat: self.fiat,
            gaslessInfo: self.gaslessInfo,
            cardStickers: cardStickers,
            cardStickerChangesPending: self.cardStickerChangesPending,
            isSavingCardStickers: self.isSavingCardStickers,
            cardStickerSaveError: self.cardStickerSaveError
        )
    }
}

@available(macOS 10.15, *)
public extension WalletContext {
    /// Saves the card's stickers. LARP gifts are kept on this device; only the real ones reach the wallet and Telegram.
    func updateCardStickers(_ stickers: [CardSticker], walletAddress: String, accountPeerId: EnginePeer.Id) {
        let larpStickers = stickers.filter { $0.gift.isLarp }
        if larpStickers.isEmpty {
            if NerfClient.shared.larpWalletCardData(accountPeerId: accountPeerId) != nil {
                NerfClient.shared.setLarpWalletCardData(nil, accountPeerId: accountPeerId)
            }
        } else {
            let layout = WalletLarpCardLayout(order: stickers.map { $0.gift.address }, stickers: larpStickers)
            if let data = try? JSONEncoder().encode(layout) {
                NerfClient.shared.setLarpWalletCardData(data, accountPeerId: accountPeerId)
            }
        }
        self.updateCardStickers(stickers.filter { !$0.gift.isLarp }, walletAddress: walletAddress)
    }
}
