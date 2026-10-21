import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class NerfClientControllerArguments {
    let updateLarpGiftsEnabled: (Bool) -> Void
    let clearLarpGifts: () -> Void
    let updateLarpNumberEnabled: (Bool) -> Void
    let updateLarpNumber: (String) -> Void
    let updateLarpStarsEnabled: (Bool) -> Void
    let updateLarpStars: (String) -> Void
    let updateLarpTonEnabled: (Bool) -> Void
    let updateLarpTon: (String) -> Void
    let updateFeature: (NerfFeature, Bool) -> Void
    let updateLarpPremium: (Bool) -> Void
    let updateLarpUsernameEnabled: (Bool) -> Void
    let updateLarpUsername: (String) -> Void
    let openLarpGift: (NerfLarpGiftRow) -> Void
    let openGiveGift: () -> Void
    let openCraft: () -> Void
    let updateLarpToggle: (NerfLarpToggle, Bool) -> Void
    let updateLarpNumberSetting: (NerfNumberSetting, String) -> Void
    let updateLarpGram: (String) -> Void
    let openMode: (NerfClientMode) -> Void

    init(updateLarpGiftsEnabled: @escaping (Bool) -> Void, clearLarpGifts: @escaping () -> Void, updateLarpNumberEnabled: @escaping (Bool) -> Void, updateLarpNumber: @escaping (String) -> Void, updateLarpStarsEnabled: @escaping (Bool) -> Void, updateLarpStars: @escaping (String) -> Void, updateLarpTonEnabled: @escaping (Bool) -> Void, updateLarpTon: @escaping (String) -> Void, updateFeature: @escaping (NerfFeature, Bool) -> Void, updateLarpPremium: @escaping (Bool) -> Void, updateLarpUsernameEnabled: @escaping (Bool) -> Void, updateLarpUsername: @escaping (String) -> Void, openLarpGift: @escaping (NerfLarpGiftRow) -> Void, openGiveGift: @escaping () -> Void, openCraft: @escaping () -> Void, updateLarpToggle: @escaping (NerfLarpToggle, Bool) -> Void, updateLarpNumberSetting: @escaping (NerfNumberSetting, String) -> Void, updateLarpGram: @escaping (String) -> Void, openMode: @escaping (NerfClientMode) -> Void) {
        self.updateLarpGiftsEnabled = updateLarpGiftsEnabled
        self.clearLarpGifts = clearLarpGifts
        self.updateLarpNumberEnabled = updateLarpNumberEnabled
        self.updateLarpNumber = updateLarpNumber
        self.updateLarpStarsEnabled = updateLarpStarsEnabled
        self.updateLarpStars = updateLarpStars
        self.updateLarpTonEnabled = updateLarpTonEnabled
        self.updateLarpTon = updateLarpTon
        self.updateFeature = updateFeature
        self.updateLarpPremium = updateLarpPremium
        self.updateLarpUsernameEnabled = updateLarpUsernameEnabled
        self.updateLarpUsername = updateLarpUsername
        self.openLarpGift = openLarpGift
        self.openGiveGift = openGiveGift
        self.openCraft = openCraft
        self.updateLarpToggle = updateLarpToggle
        self.updateLarpNumberSetting = updateLarpNumberSetting
        self.updateLarpGram = updateLarpGram
        self.openMode = openMode
    }
}

private enum NerfFeature: Int32, CaseIterable {
    case streamerMode
    case showUserId
    case hideStories
    case hideAds
    case confirmCalls
    case confirmStickers
    case confirmVoice
    case showSeconds
    case saveProtectedContent
    case unlockGramWallet
    case hideEditedLabel
    case hideViewCounts
    case squareAvatars
    case unlockChatTranslation

    /// Visual toggles go under "Визуал", the rest under "Функции".
    var isVisual: Bool {
        switch self {
        case .hideStories, .hideAds, .showSeconds, .hideEditedLabel, .hideViewCounts, .squareAvatars:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .streamerMode:
            return "Режим стримера"
        case .showUserId:
            return "ID, DC и дата регистрации"
        case .hideStories:
            return "Скрыть истории"
        case .hideAds:
            return "Скрыть рекламу"
        case .confirmCalls:
            return "Подтверждать звонки"
        case .confirmStickers:
            return "Подтверждать стикеры"
        case .confirmVoice:
            return "Голосовые через превью"
        case .showSeconds:
            return "Секунды во времени"
        case .saveProtectedContent:
            return "Сохранять защищённое"
        case .unlockGramWallet:
            return "Unlock Gram Wallet"
        case .hideEditedLabel:
            return "Скрыть «изменено»"
        case .hideViewCounts:
            return "Скрыть просмотры"
        case .squareAvatars:
            return "Квадратные аватарки"
        case .unlockChatTranslation:
            return "Перевод чатов без Premium"
        }
    }

    var keyPath: WritableKeyPath<NerfClient.Settings, Bool> {
        switch self {
        case .streamerMode:
            return \.streamerMode
        case .showUserId:
            return \.showUserId
        case .hideStories:
            return \.hideStories
        case .hideAds:
            return \.hideAds
        case .confirmCalls:
            return \.confirmCalls
        case .confirmStickers:
            return \.confirmStickers
        case .confirmVoice:
            return \.confirmVoice
        case .showSeconds:
            return \.showSeconds
        case .saveProtectedContent:
            return \.saveProtectedContent
        case .unlockGramWallet:
            return \.unlockGramWallet
        case .hideEditedLabel:
            return \.hideEditedLabel
        case .hideViewCounts:
            return \.hideViewCounts
        case .squareAvatars:
            return \.squareAvatars
        case .unlockChatTranslation:
            return \.unlockChatTranslation
        }
    }
}

private enum NerfLarpToggle: Int32 {
    case rating
    case channel
    case gram

    var title: String {
        switch self {
        case .rating:
            return "LARP Rating"
        case .channel:
            return "LARP Channel"
        case .gram:
            return "LARP Gram"
        }
    }

    var keyPath: WritableKeyPath<NerfClient.Settings, Bool> {
        switch self {
        case .rating:
            return \.larpRatingEnabled
        case .channel:
            return \.larpChannelEnabled
        case .gram:
            return \.larpGramEnabled
        }
    }
}

private enum NerfNumberSetting: Int32 {
    case ratingLevel
    case subscribers
    case viewsMultiplier
    case boostLevel
    case premiumMonths
    case nameColor
    case profileColor

    var placeholder: String {
        switch self {
        case .ratingLevel:
            return "Уровень"
        case .subscribers:
            return "Подписчики"
        case .viewsMultiplier:
            return "Множитель просмотров (x)"
        case .boostLevel:
            return "Уровень бустов"
        case .premiumMonths:
            return "Месяцев Premium"
        case .nameColor:
            return "Цвет имени 1–7 (0 — свой)"
        case .profileColor:
            return "Цвет профиля 1–7 (0 — свой)"
        }
    }

    var keyPath: WritableKeyPath<NerfClient.Settings, Int32> {
        switch self {
        case .ratingLevel:
            return \.larpRatingLevel
        case .subscribers:
            return \.larpSubscribers
        case .viewsMultiplier:
            return \.larpViewsMultiplier
        case .boostLevel:
            return \.larpBoostLevel
        case .premiumMonths:
            return \.larpPremiumMonths
        case .nameColor:
            return \.larpNameColor
        case .profileColor:
            return \.larpProfileColor
        }
    }

    var defaultValue: Int32 {
        switch self {
        case .viewsMultiplier:
            return 1
        default:
            return 0
        }
    }
}

private struct NerfLarpGiftRow: Equatable {
    let peerId: EnginePeer.Id
    let localMessageId: Int32
    let title: String
    let recipient: String
    let canUpgrade: Bool
    let salePriceStars: Int64?
    let valueCents: Int64?
}

/// The Nerf Client screen: a root with two entries, LARP and "Визуал и функции".
public enum NerfClientMode {
    case root
    case larp
    case features
}

private enum NerfClientSection: Int32 {
    case root
    case visual
    case features
    case larpGift
    case larpStars
    case larpTon
    case larpNumber
    case larpProfile
    case larpRating
    case larpChannel
    case larpGram
    case larpGiftList
}

private enum NerfClientEntry: ItemListNodeEntry {
    case rootLarp
    case rootFeatures
    case visualHeader
    case featuresHeader
    case featureToggle(NerfFeature, Bool)
    case featuresInfo
    case larpGiftHeader
    case larpGiftToggle(Bool)
    case larpGiftClear(Int)
    case larpGiftInfo
    case larpStarsHeader
    case larpStarsToggle(Bool)
    case larpStarsInput(String)
    case larpStarsInfo
    case larpTonHeader
    case larpTonToggle(Bool)
    case larpTonInput(String)
    case larpTonInfo
    case larpNumberHeader
    case larpNumberToggle(Bool)
    case larpNumberInput(String)
    case larpNumberInfo
    case larpProfileHeader
    case larpPremiumToggle(Bool)
    case larpUsernameToggle(Bool)
    case larpUsernameInput(String)
    case larpProfileInfo
    case larpGiftListHeader
    case larpGiveGift
    case larpCraft
    case larpRatingHeader
    case larpToggle(NerfLarpToggle, Bool)
    case larpNumber(NerfNumberSetting, String)
    case larpRatingInfo
    case larpChannelHeader
    case larpChannelInfo
    case larpGramHeader
    case larpGramInput(String)
    case larpGramInfo
    case larpGiftListItem(Int32, NerfLarpGiftRow)
    case larpGiftListInfo

    var section: ItemListSectionId {
        switch self {
        case .rootLarp, .rootFeatures:
            return NerfClientSection.root.rawValue
        case .visualHeader:
            return NerfClientSection.visual.rawValue
        case let .featureToggle(feature, _):
            return feature.isVisual ? NerfClientSection.visual.rawValue : NerfClientSection.features.rawValue
        case .featuresHeader, .featuresInfo:
            return NerfClientSection.features.rawValue
        case .larpGiftHeader, .larpGiftToggle, .larpGiftClear, .larpGiftInfo:
            return NerfClientSection.larpGift.rawValue
        case .larpStarsHeader, .larpStarsToggle, .larpStarsInput, .larpStarsInfo:
            return NerfClientSection.larpStars.rawValue
        case .larpTonHeader, .larpTonToggle, .larpTonInput, .larpTonInfo:
            return NerfClientSection.larpTon.rawValue
        case .larpNumberHeader, .larpNumberToggle, .larpNumberInput, .larpNumberInfo:
            return NerfClientSection.larpNumber.rawValue
        case .larpProfileHeader, .larpPremiumToggle, .larpUsernameToggle, .larpUsernameInput, .larpProfileInfo:
            return NerfClientSection.larpProfile.rawValue
        case .larpRatingHeader, .larpRatingInfo:
            return NerfClientSection.larpRating.rawValue
        case .larpChannelHeader, .larpChannelInfo:
            return NerfClientSection.larpChannel.rawValue
        case let .larpToggle(toggle, _):
            switch toggle {
            case .rating:
                return NerfClientSection.larpRating.rawValue
            case .channel:
                return NerfClientSection.larpChannel.rawValue
            case .gram:
                return NerfClientSection.larpGram.rawValue
            }
        case let .larpNumber(setting, _):
            switch setting {
            case .ratingLevel:
                return NerfClientSection.larpRating.rawValue
            case .premiumMonths, .nameColor, .profileColor:
                return NerfClientSection.larpProfile.rawValue
            default:
                return NerfClientSection.larpChannel.rawValue
            }
        case .larpGramHeader, .larpGramInput, .larpGramInfo:
            return NerfClientSection.larpGram.rawValue
        case .larpGiftListHeader, .larpGiveGift, .larpCraft, .larpGiftListItem, .larpGiftListInfo:
            return NerfClientSection.larpGiftList.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .rootLarp:
            return -1000
        case .rootFeatures:
            return -999
        case .visualHeader:
            return -300
        case let .featureToggle(feature, _):
            return (feature.isVisual ? -299 : -99) + feature.rawValue
        case .featuresHeader:
            return -100
        case .featuresInfo:
            return -1
        case .larpGiftHeader:
            return 0
        case .larpGiftToggle:
            return 1
        case .larpGiftClear:
            return 2
        case .larpGiftInfo:
            return 3
        case .larpStarsHeader:
            return 4
        case .larpStarsToggle:
            return 5
        case .larpStarsInput:
            return 6
        case .larpStarsInfo:
            return 7
        case .larpTonHeader:
            return 8
        case .larpTonToggle:
            return 9
        case .larpTonInput:
            return 10
        case .larpTonInfo:
            return 11
        case .larpNumberHeader:
            return 12
        case .larpNumberToggle:
            return 13
        case .larpNumberInput:
            return 14
        case .larpNumberInfo:
            return 15
        case .larpProfileHeader:
            return 16
        case .larpPremiumToggle:
            return 17
        case .larpUsernameToggle:
            return 19
        case .larpUsernameInput:
            return 20
        case .larpProfileInfo:
            return 24
        case .larpRatingHeader:
            return 30
        case let .larpToggle(toggle, _):
            switch toggle {
            case .rating:
                return 31
            case .channel:
                return 41
            case .gram:
                return 61
            }
        case let .larpNumber(setting, _):
            switch setting {
            case .ratingLevel:
                return 32
            case .premiumMonths:
                return 18
            case .nameColor:
                return 22
            case .profileColor:
                return 23
            default:
                return 42 + setting.rawValue
            }
        case .larpGramHeader:
            return 60
        case .larpGramInput:
            return 62
        case .larpGramInfo:
            return 63
        case .larpRatingInfo:
            return 33
        case .larpChannelHeader:
            return 40
        case .larpChannelInfo:
            return 50
        case .larpGiftListHeader:
            return 997
        case .larpGiveGift:
            return 998
        case .larpCraft:
            return 999
        case let .larpGiftListItem(index, _):
            return 1001 + index
        case .larpGiftListInfo:
            return 100000
        }
    }

    static func <(lhs: NerfClientEntry, rhs: NerfClientEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NerfClientControllerArguments
        switch self {
        case .rootLarp:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "LARP", label: "гифты, балансы, профиль, канал", sectionId: self.section, style: .blocks, action: {
                arguments.openMode(.larp)
            })
        case .rootFeatures:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Визуал и функции", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openMode(.features)
            })
        case .visualHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ВИЗУАЛ", sectionId: self.section)
        case .featuresHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ФУНКЦИИ", sectionId: self.section)
        case let .featureToggle(feature, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: feature.title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFeature(feature, value)
            })
        case .featuresInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Режим стримера скрывает твой номер, юзернейм, ID и баланс звёзд и TON. ID и DC показываются в профилях людей, групп и каналов, по нажатию ID копируется; дата регистрации — если её прислал Telegram. «Голосовые через превью»: после записи голосовое или кружок не уходят сразу, а открываются для проверки. «Сохранять защищённое»: в каналах и группах с запретом копирования можно сохранять и копировать медиа (пересылку сервер всё равно запрещает). «Unlock Gram Wallet» открывает кошелёк Gram в настройках, не дожидаясь, пока Telegram включит его тебе; это настоящий кошелёк — сохрани секретную фразу."), sectionId: self.section)
        case .larpGiftHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP SEND GIFT", sectionId: self.section)
        case let .larpGiftToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "LARP Send Gift", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateLarpGiftsEnabled(value)
            })
        case let .larpGiftClear(count):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Удалить LARP-гифты (\(count))", kind: count == 0 ? .disabled : .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearLarpGifts()
            })
        case .larpGiftInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Обычные гифты и гифты с маркета не отправляются и не покупаются, настоящие звёзды и TON не списываются. Если баланса не хватает, гифт не отправится. С включёнными LARP Stars / LARP TON цена списывается с LARP-баланса. Гифт появляется только у тебя, в чате и в профиле получателя, и всегда с пометкой LARP."), sectionId: self.section)
        case .larpStarsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP STARS", sectionId: self.section)
        case let .larpStarsToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "LARP Stars", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateLarpStarsEnabled(value)
            })
        case let .larpStarsInput(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: "Количество звёзд", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateLarpStars(value)
            }, action: {})
        case .larpStarsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Баланс звёзд подменяется только на экране этого устройства, рядом с ним всегда стоит LARP. Им можно платить только за LARP-гифты."), sectionId: self.section)
        case .larpTonHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP TON", sectionId: self.section)
        case let .larpTonToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "LARP TON", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateLarpTonEnabled(value)
            })
        case let .larpTonInput(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: "Количество TON", type: .decimal, sectionId: self.section, textUpdated: { value in
                arguments.updateLarpTon(value)
            }, action: {})
        case .larpTonInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Баланс TON подменяется только на экране этого устройства, рядом с ним всегда стоит LARP. Им можно платить только за LARP-гифты с маркета."), sectionId: self.section)
        case .larpNumberHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP CUSTOM NUMBER", sectionId: self.section)
        case let .larpNumberToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "LARP Custom Number", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateLarpNumberEnabled(value)
            })
        case let .larpNumberInput(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: "+7 999 123 45 67", type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateLarpNumber(value)
            }, action: {})
        case .larpProfileHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP PROFILE", sectionId: self.section)
        case let .larpPremiumToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "LARP Premium", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateLarpPremium(value)
            })
        case let .larpUsernameToggle(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "LARP @username", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateLarpUsernameEnabled(value)
            })
        case let .larpUsernameInput(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "@"), text: text, placeholder: "username", type: .username, sectionId: self.section, textUpdated: { value in
                arguments.updateLarpUsername(value)
            }, action: {})
        case .larpGiftListHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "МОИ LARP-ГИФТЫ", sectionId: self.section)
        case .larpCraft:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "LARP-крафт", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openCraft()
            })
        case .larpRatingHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP RATING", sectionId: self.section)
        case .larpChannelHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP CHANNEL", sectionId: self.section)
        case let .larpToggle(toggle, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: toggle.title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateLarpToggle(toggle, value)
            })
        case let .larpNumber(setting, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: setting.placeholder, type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateLarpNumberSetting(setting, value)
            }, action: {})
        case .larpRatingInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Звёздный уровень в твоём профиле, только на этом устройстве. В настройках рядом всегда стоит «Ур. N LARP»."), sectionId: self.section)
        case .larpGramHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "LARP GRAM", sectionId: self.section)
        case let .larpGramInput(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: "Баланс Gram", type: .decimal, sectionId: self.section, textUpdated: { value in
                arguments.updateLarpGram(value)
            }, action: {})
        case .larpGramInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Баланс в кошельке Gram подменяется только на экране этого устройства, на карточке кошелька стоит LARP. Переводы считаются по настоящему балансу."), sectionId: self.section)
        case .larpChannelInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Для каналов, которые ты создал: число подписчиков (всегда с пометкой LARP), просмотры постов (умножаются) и уровень бустов. Только на этом устройстве."), sectionId: self.section)
        case .larpGiveGift:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Выдать гифт", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openGiveGift()
            })
        case let .larpGiftListItem(_, row):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: row.title, label: row.recipient, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                arguments.openLarpGift(row)
            })
        case .larpGiftListInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("«Выдать гифт» добавляет гифт в твой профиль. Нажми на улучшенный гифт, чтобы выставить его на LARP-продажу или указать ценность. Нажми на обычный гифт в списке, чтобы сделать LARP-улучшение: модель, фон и узор выбираются из настоящих вариантов улучшения этого гифта. Цена гифта и улучшения списывается так же, как при LARP-отправке. Гифты в профиле видны, пока включён LARP Send Gift."), sectionId: self.section)
        case .larpProfileInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Значок Premium и юзернейм подменяются только на экране этого устройства, в настройках и твоём профиле, и всегда с пометкой LARP. Настоящий аккаунт не меняется."), sectionId: self.section)
        case .larpNumberInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Номер подменяется только на экране этого устройства, справа от него всегда стоит LARP. Настоящий номер в аккаунте не меняется."), sectionId: self.section)
        }
    }
}

private struct NerfClientInputState: Equatable {
    var starsText: String
    var tonText: String
    var gramText: String
}

private let nanotonsPerTon: Int64 = 1_000_000_000

private func larpTonText(nano: Int64) -> String {
    if nano == 0 {
        return ""
    }
    var fraction = String(nano % nanotonsPerTon)
    fraction = String(repeating: "0", count: 9 - fraction.count) + fraction
    while fraction.hasSuffix("0") {
        fraction.removeLast()
    }
    let integer = String(nano / nanotonsPerTon)
    return fraction.isEmpty ? integer : "\(integer).\(fraction)"
}

private func larpTonNano(text: String) -> Int64 {
    let normalized = text.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
    let parts = normalized.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let integer = Int64(parts.first.flatMap { String($0) } ?? "") ?? 0
    var fractionText = parts.count > 1 ? String(parts[1].prefix(9)) : ""
    fractionText += String(repeating: "0", count: 9 - fractionText.count)
    let fraction = Int64(fractionText) ?? 0
    let (product, overflow) = integer.multipliedReportingOverflow(by: nanotonsPerTon)
    return overflow ? Int64.max : product + fraction
}

private func nerfClientTitle(_ mode: NerfClientMode) -> String {
    switch mode {
    case .root:
        return "Nerf Client"
    case .larp:
        return "LARP"
    case .features:
        return "Визуал и функции"
    }
}

private func nerfNumberText(_ settings: NerfClient.Settings, _ setting: NerfNumberSetting) -> String {
    let value = settings[keyPath: setting.keyPath]
    return value == setting.defaultValue ? "" : "\(value)"
}

private func nerfClientControllerEntries(mode: NerfClientMode, settings: NerfClient.Settings, inputState: NerfClientInputState, larpGiftCount: Int, larpGiftRows: [NerfLarpGiftRow]) -> [NerfClientEntry] {
    var entries: [NerfClientEntry] = []
    switch mode {
    case .root:
        entries.append(.rootLarp)
        entries.append(.rootFeatures)
        return entries
    case .features:
        entries.append(.visualHeader)
        for feature in NerfFeature.allCases where feature.isVisual {
            entries.append(.featureToggle(feature, settings[keyPath: feature.keyPath]))
        }
        entries.append(.featuresHeader)
        for feature in NerfFeature.allCases where !feature.isVisual {
            entries.append(.featureToggle(feature, settings[keyPath: feature.keyPath]))
        }
        entries.append(.featuresInfo)
        return entries
    case .larp:
        break
    }
    entries.append(.larpGiftHeader)
    entries.append(.larpGiftToggle(settings.larpGiftsEnabled))
    entries.append(.larpGiftClear(larpGiftCount))
    entries.append(.larpGiftInfo)
    entries.append(.larpStarsHeader)
    entries.append(.larpStarsToggle(settings.larpStarsEnabled))
    if settings.larpStarsEnabled {
        entries.append(.larpStarsInput(inputState.starsText))
    }
    entries.append(.larpStarsInfo)
    entries.append(.larpTonHeader)
    entries.append(.larpTonToggle(settings.larpTonEnabled))
    if settings.larpTonEnabled {
        entries.append(.larpTonInput(inputState.tonText))
    }
    entries.append(.larpTonInfo)
    entries.append(.larpNumberHeader)
    entries.append(.larpNumberToggle(settings.larpNumberEnabled))
    if settings.larpNumberEnabled {
        entries.append(.larpNumberInput(settings.larpNumber))
    }
    entries.append(.larpNumberInfo)
    entries.append(.larpProfileHeader)
    entries.append(.larpPremiumToggle(settings.larpPremium))
    if settings.larpPremium {
        entries.append(.larpNumber(.premiumMonths, nerfNumberText(settings, .premiumMonths)))
    }
    entries.append(.larpUsernameToggle(settings.larpUsernameEnabled))
    if settings.larpUsernameEnabled {
        entries.append(.larpUsernameInput(settings.larpUsername))
    }
    entries.append(.larpNumber(.nameColor, nerfNumberText(settings, .nameColor)))
    entries.append(.larpNumber(.profileColor, nerfNumberText(settings, .profileColor)))
    entries.append(.larpProfileInfo)
    entries.append(.larpRatingHeader)
    entries.append(.larpToggle(.rating, settings.larpRatingEnabled))
    if settings.larpRatingEnabled {
        entries.append(.larpNumber(.ratingLevel, nerfNumberText(settings, .ratingLevel)))
    }
    entries.append(.larpRatingInfo)
    entries.append(.larpChannelHeader)
    entries.append(.larpToggle(.channel, settings.larpChannelEnabled))
    if settings.larpChannelEnabled {
        entries.append(.larpNumber(.subscribers, nerfNumberText(settings, .subscribers)))
        entries.append(.larpNumber(.viewsMultiplier, nerfNumberText(settings, .viewsMultiplier)))
        entries.append(.larpNumber(.boostLevel, nerfNumberText(settings, .boostLevel)))
    }
    entries.append(.larpChannelInfo)
    entries.append(.larpGramHeader)
    entries.append(.larpToggle(.gram, settings.larpGramEnabled))
    if settings.larpGramEnabled {
        entries.append(.larpGramInput(inputState.gramText))
    }
    entries.append(.larpGramInfo)
    entries.append(.larpGiftListHeader)
    entries.append(.larpGiveGift)
    entries.append(.larpCraft)
    for (index, row) in larpGiftRows.enumerated() {
        entries.append(.larpGiftListItem(Int32(index), row))
    }
    entries.append(.larpGiftListInfo)
    return entries
}

public func nerfClientController(context: AccountContext, mode: NerfClientMode = .root) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let accountPeerId = context.account.peerId.toInt64()

    // Typed text is kept as is, so a half-typed amount such as "1." stays in the field.
    let initialSettings = NerfClient.shared.settings
    let initialInputState = NerfClientInputState(
        starsText: initialSettings.larpStars == 0 ? "" : "\(initialSettings.larpStars)",
        tonText: larpTonText(nano: initialSettings.larpTonNano),
        gramText: larpTonText(nano: initialSettings.larpGramNano)
    )
    let inputState = ValuePromise(initialInputState, ignoreRepeated: true)
    let inputStateValue = Atomic(value: initialInputState)
    let updateInputState: ((NerfClientInputState) -> NerfClientInputState) -> Void = { f in
        inputState.set(inputStateValue.modify { f($0) })
    }

    let arguments = NerfClientControllerArguments(updateLarpGiftsEnabled: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpGiftsEnabled = value
            return current
        }
    }, clearLarpGifts: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let alertController = textAlertController(context: context, title: nil, text: "Удалить все LARP-гифты из чатов и профилей?", actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                let _ = context.engine.payments.clearLarpGifts().startStandalone()
            })
        ])
        presentControllerImpl?(alertController)
    }, updateLarpNumberEnabled: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpNumberEnabled = value
            return current
        }
    }, updateLarpNumber: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpNumber = value
            return current
        }
    }, updateLarpStarsEnabled: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpStarsEnabled = value
            return current
        }
    }, updateLarpStars: { value in
        updateInputState { current in
            var current = current
            current.starsText = value
            return current
        }
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpStars = Int64(value.filter { $0.isNumber }) ?? 0
            return current
        }
    }, updateLarpTonEnabled: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpTonEnabled = value
            return current
        }
    }, updateLarpTon: { value in
        updateInputState { current in
            var current = current
            current.tonText = value
            return current
        }
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpTonNano = larpTonNano(text: value)
            return current
        }
    }, updateFeature: { feature, value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current[keyPath: feature.keyPath] = value
            return current
        }
    }, updateLarpPremium: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpPremium = value
            return current
        }
    }, updateLarpUsernameEnabled: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpUsernameEnabled = value
            return current
        }
    }, updateLarpUsername: { value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpUsername = value
            return current
        }
    }, openLarpGift: { row in
        guard row.canUpgrade else {
            // A unique gift: LARP sale price and value.
            pushControllerImpl?(nerfLarpGiftEditController(context: context, row: row))
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let alertController = textAlertController(context: context, title: nil, text: "Сделать LARP-улучшение «\(row.title)»?", actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .defaultAction, title: "Улучшить", action: {
                let starsContext = context.starsContext
                // The balance here is the LARP one while LARP Stars is on, else the real one; only LARP Stars are spent.
                let _ = (context.engine.payments.upgradeLarpGift(peerId: row.peerId, localMessageId: row.localMessageId, spend: { price in
                    guard let balance = starsContext?.currentState?.balance, balance >= StarsAmount(value: price, nanos: 0) else {
                        return false
                    }
                    return NerfClient.shared.spendLarpBalance(ton: false, amount: price)
                })
                |> deliverOnMainQueue).startStandalone(next: { result in
                    let text: String
                    switch result {
                    case let .upgraded(gift):
                        if case let .unique(uniqueGift) = gift {
                            text = "Готово: \(uniqueGift.title) #\(uniqueGift.number) \(NerfClient.larpMark)"
                        } else {
                            text = "Готово"
                        }
                    case .notEnoughBalance:
                        text = "Недостаточно звёзд на балансе для улучшения."
                    case .unavailable:
                        text = "Этот гифт нельзя улучшить."
                    }
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                })
            })
        ])
        presentControllerImpl?(alertController)
    }, openGiveGift: {
        pushControllerImpl?(nerfGiveGiftController(context: context))
    }, openCraft: {
        pushControllerImpl?(nerfCraftController(context: context))
    }, updateLarpToggle: { toggle, value in
        NerfClient.shared.updateSettings { current in
            var current = current
            current[keyPath: toggle.keyPath] = value
            return current
        }
    }, updateLarpNumberSetting: { setting, text in
        let digits = text.filter { $0.isNumber }
        var value = digits.isEmpty ? setting.defaultValue : (Int32(digits) ?? Int32.max)
        if setting == .nameColor || setting == .profileColor {
            value = min(7, value)
        }
        NerfClient.shared.updateSettings { current in
            var current = current
            current[keyPath: setting.keyPath] = max(setting.defaultValue, value)
            if setting == .premiumMonths {
                current.larpPremiumSince = Int32(Date().timeIntervalSince1970)
            }
            return current
        }
    }, updateLarpGram: { value in
        updateInputState { current in
            var current = current
            current.gramText = value
            return current
        }
        NerfClient.shared.updateSettings { current in
            var current = current
            current.larpGramNano = larpTonNano(text: value)
            return current
        }
    }, openMode: { mode in
        pushControllerImpl?(nerfClientController(context: context, mode: mode))
    })

    let larpGiftCount = NerfClient.shared.larpGiftsSignal
    |> map { gifts -> Int in
        return gifts.filter { $0.accountPeerId == accountPeerId }.count
    }
    |> distinctUntilChanged

    let larpGiftRows: Signal<[NerfLarpGiftRow], NoError> = NerfClient.shared.larpGiftsSignal
    |> mapToSignal { gifts -> Signal<[NerfLarpGiftRow], NoError> in
        let gifts = gifts.filter { $0.accountPeerId == accountPeerId }
        let peerIds = Array(Set(gifts.map { EnginePeer.Id($0.peerId) }))
        return context.engine.data.get(EngineDataMap(
            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
        ))
        |> map { peers -> [NerfLarpGiftRow] in
            return gifts.map { gift in
                let peerId = EnginePeer.Id(gift.peerId)
                let title: String
                let canUpgrade: Bool
                switch gift.gift {
                case let .generic(genericGift):
                    title = genericGift.title ?? "Gift"
                    canUpgrade = true
                case let .unique(uniqueGift):
                    title = "\(uniqueGift.title) #\(uniqueGift.number)"
                    canUpgrade = false
                }
                var recipient = ""
                if gift.peerId == accountPeerId {
                    recipient = "Себе"
                } else if let maybePeer = peers[peerId], let peer = maybePeer {
                    recipient = peer.compactDisplayTitle
                }
                var salePriceStars: Int64?
                var valueCents: Int64?
                if case let .unique(uniqueGift) = gift.gift {
                    salePriceStars = uniqueGift.resellAmounts?.first(where: { $0.currency == .stars })?.amount.value
                    valueCents = uniqueGift.valueAmount
                }
                return NerfLarpGiftRow(peerId: peerId, localMessageId: gift.localMessageId, title: title, recipient: recipient, canUpgrade: canUpgrade, salePriceStars: salePriceStars, valueCents: valueCents)
            }
        }
    }

    let signal = combineLatest(context.sharedContext.presentationData, NerfClient.shared.settingsSignal, inputState.get(), larpGiftCount, larpGiftRows)
    |> deliverOnMainQueue
    |> map { presentationData, settings, inputState, larpGiftCount, larpGiftRows -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(nerfClientTitle(mode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: nerfClientControllerEntries(mode: mode, settings: settings, inputState: inputState, larpGiftCount: larpGiftCount, larpGiftRows: larpGiftRows), style: .blocks, emptyStateItem: nil, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

private final class NerfGiveGiftControllerArguments {
    let giveGift: (StarGift.Gift) -> Void

    init(giveGift: @escaping (StarGift.Gift) -> Void) {
        self.giveGift = giveGift
    }
}

private enum NerfGiveGiftEntry: ItemListNodeEntry {
    case header
    case gift(Int32, StarGift.Gift)
    case info

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .gift(index, _):
            return 1 + index
        case .info:
            return Int32.max
        }
    }

    static func <(lhs: NerfGiveGiftEntry, rhs: NerfGiveGiftEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NerfGiveGiftControllerArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ГИФТЫ С УЛУЧШЕНИЕМ", sectionId: self.section)
        case let .gift(_, gift):
            var emoji = ""
            for attribute in gift.file.attributes {
                if case let .Sticker(displayText, _, _) = attribute {
                    emoji = displayText
                    break
                }
            }
            let title = [emoji, gift.title ?? "Gift"].filter { !$0.isEmpty }.joined(separator: " ")
            var label = "⭐️ \(gift.price)"
            if let upgradeStars = gift.upgradeStars {
                label += " · улучшение ⭐️ \(upgradeStars)"
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.giveGift(gift)
            })
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Нажми на гифт: можно выдать его обычным или сразу собрать уникальный — со своей моделью, фоном, узором и номером. Цена списывается с LARP Stars, если они включены; иначе нужен настоящий баланс, но он не тратится."), sectionId: self.section)
        }
    }
}

private func nerfGiveGiftController(context: AccountContext) -> ViewController {

    // The gift catalog may not be cached yet if the gift store has never been opened.
    let _ = context.engine.payments.keepStarGiftsUpdated().startStandalone()

    var pushControllerImpl: ((ViewController) -> Void)?
    let arguments = NerfGiveGiftControllerArguments(giveGift: { gift in
        pushControllerImpl?(nerfGiftConstructorController(context: context, gift: gift))
    })

    let gifts: Signal<[StarGift.Gift], NoError> = context.engine.payments.cachedStarGifts()
    |> map { gifts -> [StarGift.Gift] in
        var result: [StarGift.Gift] = []
        for gift in gifts ?? [] {
            if case let .generic(genericGift) = gift, genericGift.upgradeStars != nil {
                result.append(genericGift)
            }
        }
        return result.sorted(by: { $0.price < $1.price })
    }

    let signal = combineLatest(context.sharedContext.presentationData, gifts)
    |> deliverOnMainQueue
    |> map { presentationData, gifts -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [NerfGiveGiftEntry] = [.header]
        for (index, gift) in gifts.enumerated() {
            entries.append(.gift(Int32(index), gift))
        }
        entries.append(.info)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Выдать гифт"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}


private final class NerfCraftControllerArguments {
    let toggle: (Int32) -> Void

    init(toggle: @escaping (Int32) -> Void) {
        self.toggle = toggle
    }
}

private enum NerfCraftEntry: ItemListNodeEntry {
    case header
    case gift(Int32, Int32, String, Bool)
    case info(String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .gift(index, _, _, _):
            return 1 + index
        case .info:
            return Int32.max
        }
    }

    static func <(lhs: NerfCraftEntry, rhs: NerfCraftEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NerfCraftControllerArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ВЫБЕРИ ГИФТЫ ДЛЯ КРАФТА", sectionId: self.section)
        case let .gift(_, localMessageId, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.toggle(localMessageId)
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func nerfCraftController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?

    let accountPeerId = context.account.peerId.toInt64()
    let selection = ValuePromise<Set<Int32>>(Set(), ignoreRepeated: true)
    let selectionValue = Atomic<Set<Int32>>(value: Set())

    let arguments = NerfCraftControllerArguments(toggle: { localMessageId in
        selection.set(selectionValue.modify { current in
            var current = current
            if current.contains(localMessageId) {
                current.remove(localMessageId)
            } else {
                current.insert(localMessageId)
            }
            return current
        })
    })

    // Only unique LARP gifts in your own profile can be crafted.
    let gifts: Signal<[(Int32, String)], NoError> = NerfClient.shared.larpGiftsSignal
    |> map { gifts -> [(Int32, String)] in
        return gifts.compactMap { gift -> (Int32, String)? in
            guard gift.accountPeerId == accountPeerId, gift.peerId == accountPeerId, case let .unique(uniqueGift) = gift.gift else {
                return nil
            }
            return (gift.localMessageId, "\(uniqueGift.title) #\(uniqueGift.number)")
        }
    }

    let craft: () -> Void = {
        let selected = Array(selectionValue.with { $0 })
        guard selected.count >= 2 else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (context.engine.payments.craftLarpGifts(localMessageIds: selected)
        |> deliverOnMainQueue).startStandalone(next: { result in
            let text: String
            switch result {
            case let .upgraded(gift):
                if case let .unique(uniqueGift) = gift {
                    var tier = ""
                    for attribute in uniqueGift.attributes {
                        if case let .model(_, _, rarity, _) = attribute {
                            switch rarity {
                            case .legendary:
                                tier = " · Легендарный"
                            case .epic:
                                tier = " · Эпический"
                            case .rare:
                                tier = " · Редкий"
                            case .uncommon:
                                tier = " · Необычный"
                            case .permille:
                                break
                            }
                        }
                    }
                    text = "Скрафчено: \(uniqueGift.title) #\(uniqueGift.number)\(tier) \(NerfClient.larpMark)"
                } else {
                    text = "Готово"
                }
            case .notEnoughBalance, .unavailable:
                text = "Не получилось скрафтить эти гифты."
            }
            let _ = selectionValue.swap(Set())
            selection.set(Set())
            presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                dismissImpl?()
            })]))
        })
    }

    let signal = combineLatest(context.sharedContext.presentationData, gifts, selection.get())
    |> deliverOnMainQueue
    |> map { presentationData, gifts, selection -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [NerfCraftEntry] = [.header]
        for (index, gift) in gifts.enumerated() {
            entries.append(.gift(Int32(index), gift.0, gift.1, selection.contains(gift.0)))
        }
        if gifts.count < 2 {
            entries.append(.info("Для крафта нужно минимум 2 улучшенных LARP-гифта в твоём профиле. Выдай гифты себе и улучши их в «Мои LARP-гифты»."))
        } else {
            entries.append(.info("Выбери 2 или больше гифтов. Они исчезнут, а вместо них появится один новый уникальный гифт с лентой LARP; если у гифта есть крафтовые модели, выпадет одна из них. Чем больше гифтов, тем выше шанс эпической и легендарной модели."))
        }
        let rightButton = ItemListNavigationButton(content: .text("Скрафтить"), style: .bold, enabled: selection.count >= 2, action: {
            craft()
        })
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("LARP-крафт"), leftNavigationButton: nil, rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}


private enum NerfLarpGiftEditEntry: ItemListNodeEntry {
    case header(String)
    case salePrice(String)
    case value(String)
    case info

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .salePrice:
            return 1
        case .value:
            return 2
        case .info:
            return 3
        }
    }

    static func <(lhs: NerfLarpGiftEditEntry, rhs: NerfLarpGiftEditEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NerfLarpGiftEditArguments
        switch self {
        case let .header(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title.uppercased(), sectionId: self.section)
        case let .salePrice(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Продажа ⭐️"), text: text, placeholder: "не продаётся", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateSalePrice(value)
            }, action: {})
        case let .value(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Ценность $"), text: text, placeholder: "не указана", type: .decimal, sectionId: self.section, textUpdated: { value in
                arguments.updateValue(value)
            }, action: {})
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Цена продажи появляется у гифта в профиле, ценность — в строке «Ценность» и на её экране, с пометкой LARP. Пустое поле — снять с продажи или убрать ценность."), sectionId: self.section)
        }
    }
}

private final class NerfLarpGiftEditArguments {
    let updateSalePrice: (String) -> Void
    let updateValue: (String) -> Void

    init(updateSalePrice: @escaping (String) -> Void, updateValue: @escaping (String) -> Void) {
        self.updateSalePrice = updateSalePrice
        self.updateValue = updateValue
    }
}

private func nerfLarpGiftEditController(context: AccountContext, row: NerfLarpGiftRow) -> ViewController {
    var dismissImpl: (() -> Void)?

    struct EditState: Equatable {
        var salePrice: String
        var value: String
    }
    let initialState = EditState(
        salePrice: row.salePriceStars.flatMap { "\($0)" } ?? "",
        value: row.valueCents.flatMap { cents in
            cents % 100 == 0 ? "\(cents / 100)" : String(format: "%.2f", Double(cents) / 100.0)
        } ?? ""
    )
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((EditState) -> EditState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let arguments = NerfLarpGiftEditArguments(updateSalePrice: { value in
        updateState { current in
            var current = current
            current.salePrice = value
            return current
        }
    }, updateValue: { value in
        updateState { current in
            var current = current
            current.value = value
            return current
        }
    })

    let save: () -> Void = {
        let state = stateValue.with { $0 }
        let salePrice = Int64(state.salePrice.filter { $0.isNumber })
        let valueText = state.value.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
        let valueCents = Double(valueText).flatMap { Int64(exactly: ($0 * 100.0).rounded()) }
        let _ = (context.engine.payments.updateLarpUniqueGift(peerId: row.peerId, localMessageId: row.localMessageId, salePriceStars: salePrice, valueCents: valueCents)
        |> deliverOnMainQueue).startStandalone(completed: {
            dismissImpl?()
        })
    }

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [NerfLarpGiftEditEntry] = [.header(row.title), .salePrice(state.salePrice), .value(state.value), .info]
        let rightButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
            save()
        })
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("LARP-гифт"), leftNavigationButton: nil, rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        let _ = controller?.navigationController?.popViewController(animated: true)
    }
    return controller
}


private enum NerfConstructorSlot: Int32 {
    case model
    case backdrop
    case pattern

    var title: String {
        switch self {
        case .model:
            return "МОДЕЛЬ"
        case .backdrop:
            return "ФОН"
        case .pattern:
            return "УЗОР"
        }
    }
}

private struct NerfConstructorState: Equatable {
    var model: Int?
    var backdrop: Int?
    var pattern: Int?
    var number: String
}

private final class NerfConstructorArguments {
    let select: (NerfConstructorSlot, Int) -> Void
    let updateNumber: (String) -> Void
    let givePlain: () -> Void
    let giveUnique: () -> Void

    init(select: @escaping (NerfConstructorSlot, Int) -> Void, updateNumber: @escaping (String) -> Void, givePlain: @escaping () -> Void, giveUnique: @escaping () -> Void) {
        self.select = select
        self.updateNumber = updateNumber
        self.givePlain = givePlain
        self.giveUnique = giveUnique
    }
}

private enum NerfConstructorEntry: ItemListNodeEntry {
    case givePlain(String)
    case header(NerfConstructorSlot)
    case option(NerfConstructorSlot, Int, String, Bool)
    case numberHeader
    case number(String)
    case giveUnique(String, Bool)
    case loading

    var section: ItemListSectionId {
        switch self {
        case .givePlain:
            return 0
        case let .header(slot):
            return 1 + slot.rawValue
        case let .option(slot, _, _, _):
            return 1 + slot.rawValue
        case .numberHeader, .number, .giveUnique, .loading:
            return 10
        }
    }

    var stableId: Int32 {
        switch self {
        case .givePlain:
            return 0
        case let .header(slot):
            return 100_000 * (slot.rawValue + 1)
        case let .option(slot, index, _, _):
            return 100_000 * (slot.rawValue + 1) + 1 + Int32(index)
        case .numberHeader:
            return 1_000_000
        case .number:
            return 1_000_001
        case .giveUnique:
            return 1_000_002
        case .loading:
            return 1_000_003
        }
    }

    static func <(lhs: NerfConstructorEntry, rhs: NerfConstructorEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NerfConstructorArguments
        switch self {
        case let .givePlain(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.givePlain()
            })
        case let .header(slot):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: slot.title, sectionId: self.section)
        case let .option(slot, index, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.select(slot, index)
            })
        case .numberHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "НОМЕР", sectionId: self.section)
        case let .number(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "#"), text: text, placeholder: "случайный", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateNumber(value)
            }, action: {})
        case let .giveUnique(title, enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.giveUnique()
            })
        case .loading:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Загружаю варианты улучшения…"), sectionId: self.section)
        }
    }
}

private func nerfRarityText(_ rarity: StarGift.UniqueGift.Attribute.Rarity) -> String {
    switch rarity {
    case let .permille(value):
        return String(format: "%.1f%%", Double(value) / 10.0)
    case .uncommon:
        return "Необычный"
    case .rare:
        return "Редкий"
    case .epic:
        return "Эпический"
    case .legendary:
        return "Легендарный"
    }
}

/// Gives a gift as a regular LARP gift, or builds a unique one from the gift's real upgrade
/// variants with a chosen model, backdrop, pattern and number.
private func nerfGiftConstructorController(context: AccountContext, gift: StarGift.Gift) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?

    let initialState = NerfConstructorState(model: nil, backdrop: nil, pattern: nil, number: "")
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((NerfConstructorState) -> NerfConstructorState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let previewPromise = Promise<StarGiftUpgradePreview?>()
    previewPromise.set(.single(nil) |> then(context.engine.payments.starGiftUpgradePreview(giftId: gift.id)))
    let previewValue = Atomic<StarGiftUpgradePreview?>(value: nil)

    func attributes(_ slot: NerfConstructorSlot, _ preview: StarGiftUpgradePreview?) -> [StarGift.UniqueGift.Attribute] {
        return (preview?.attributes ?? []).filter { attribute in
            switch (slot, attribute) {
            case (.model, .model), (.backdrop, .backdrop), (.pattern, .pattern):
                return true
            default:
                return false
            }
        }
    }

    // The balance here is the LARP one while LARP Stars is on, else the real one; only LARP Stars are spent.
    func spend(_ price: Int64) -> Bool {
        guard let balance = context.starsContext?.currentState?.balance, balance >= StarsAmount(value: price, nanos: 0) else {
            return false
        }
        return NerfClient.shared.spendLarpBalance(ton: false, amount: price)
    }

    func done(_ text: String) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
            dismissImpl?()
        })]))
    }

    let arguments = NerfConstructorArguments(select: { slot, index in
        updateState { current in
            var current = current
            switch slot {
            case .model:
                current.model = current.model == index ? nil : index
            case .backdrop:
                current.backdrop = current.backdrop == index ? nil : index
            case .pattern:
                current.pattern = current.pattern == index ? nil : index
            }
            return current
        }
    }, updateNumber: { value in
        updateState { current in
            var current = current
            current.number = value
            return current
        }
    }, givePlain: {
        guard spend(gift.price) else {
            done("Недостаточно звёзд на балансе.")
            return
        }
        let _ = (context.engine.payments.addLarpGift(peerId: context.account.peerId, gift: .generic(gift), text: nil, entities: nil, nameHidden: false)
        |> deliverOnMainQueue).startStandalone(next: { _ in
            done("Гифт выдан. Он в твоём профиле, улучшить можно кнопкой «Улучшить» в окне подарка.")
        })
    }, giveUnique: {
        let preview = previewValue.with { $0 }
        let state = stateValue.with { $0 }
        let models = attributes(.model, preview)
        let backdrops = attributes(.backdrop, preview)
        let patterns = attributes(.pattern, preview)
        guard let model = state.model.flatMap({ $0 < models.count ? models[$0] : nil }) ?? models.randomElement(), let backdrop = state.backdrop.flatMap({ $0 < backdrops.count ? backdrops[$0] : nil }) ?? backdrops.randomElement(), let pattern = state.pattern.flatMap({ $0 < patterns.count ? patterns[$0] : nil }) ?? patterns.randomElement() else {
            done("Этот гифт нельзя улучшить.")
            return
        }
        let total = max(1, gift.availability?.total ?? 100_000)
        let number = Int32(state.number.filter { $0.isNumber }).flatMap { min(max(1, $0), total) } ?? Int32.random(in: 1 ... total)
        let price = gift.price + (gift.upgradeStars ?? preview?.prices.first?.stars ?? 0)
        guard spend(price) else {
            done("Недостаточно звёзд на балансе.")
            return
        }
        let _ = (context.engine.payments.addCustomLarpUniqueGift(gift: gift, model: model, pattern: pattern, backdrop: backdrop, number: number)
        |> deliverOnMainQueue).startStandalone(next: { _ in
            done("Готово: \(gift.title ?? "Gift") #\(number) \(NerfClient.larpMark). Он в твоём профиле.")
        })
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), previewPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state, preview -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let _ = previewValue.swap(preview)
        var entries: [NerfConstructorEntry] = []
        entries.append(.givePlain("Выдать обычным · ⭐️ \(gift.price)"))
        if preview == nil {
            entries.append(.loading)
        } else {
            for slot in [NerfConstructorSlot.model, .backdrop, .pattern] {
                let selected: Int?
                switch slot {
                case .model:
                    selected = state.model
                case .backdrop:
                    selected = state.backdrop
                case .pattern:
                    selected = state.pattern
                }
                entries.append(.header(slot))
                for (index, attribute) in attributes(slot, preview).enumerated() {
                    let title: String
                    switch attribute {
                    case let .model(name, _, rarity, _), let .pattern(name, _, rarity):
                        title = "\(name) · \(nerfRarityText(rarity))"
                    case let .backdrop(name, _, _, _, _, _, rarity):
                        title = "\(name) · \(nerfRarityText(rarity))"
                    case .originalInfo:
                        continue
                    }
                    entries.append(.option(slot, index, title, selected == index))
                }
            }
            entries.append(.numberHeader)
            entries.append(.number(state.number))
            let price = gift.price + (gift.upgradeStars ?? preview?.prices.first?.stars ?? 0)
            entries.append(.giveUnique("Выдать улучшенным · ⭐️ \(price)", !attributes(.model, preview).isEmpty))
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(gift.title ?? "Гифт"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.navigationController?.popViewController(animated: true)
    }
    return controller
}
