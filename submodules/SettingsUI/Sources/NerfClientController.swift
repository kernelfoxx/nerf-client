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

    init(updateLarpGiftsEnabled: @escaping (Bool) -> Void, clearLarpGifts: @escaping () -> Void, updateLarpNumberEnabled: @escaping (Bool) -> Void, updateLarpNumber: @escaping (String) -> Void) {
        self.updateLarpGiftsEnabled = updateLarpGiftsEnabled
        self.clearLarpGifts = clearLarpGifts
        self.updateLarpNumberEnabled = updateLarpNumberEnabled
        self.updateLarpNumber = updateLarpNumber
    }
}

private enum NerfClientSection: Int32 {
    case larpGift
    case larpNumber
}

private enum NerfClientEntry: ItemListNodeEntry {
    case larpGiftHeader
    case larpGiftToggle(Bool)
    case larpGiftClear(Int)
    case larpGiftInfo
    case larpNumberHeader
    case larpNumberToggle(Bool)
    case larpNumberInput(String)
    case larpNumberInfo

    var section: ItemListSectionId {
        switch self {
        case .larpGiftHeader, .larpGiftToggle, .larpGiftClear, .larpGiftInfo:
            return NerfClientSection.larpGift.rawValue
        case .larpNumberHeader, .larpNumberToggle, .larpNumberInput, .larpNumberInfo:
            return NerfClientSection.larpNumber.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .larpGiftHeader:
            return 0
        case .larpGiftToggle:
            return 1
        case .larpGiftClear:
            return 2
        case .larpGiftInfo:
            return 3
        case .larpNumberHeader:
            return 4
        case .larpNumberToggle:
            return 5
        case .larpNumberInput:
            return 6
        case .larpNumberInfo:
            return 7
        }
    }

    static func <(lhs: NerfClientEntry, rhs: NerfClientEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NerfClientControllerArguments
        switch self {
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
            return ItemListTextItem(presentationData: presentationData, text: .plain("Обычные гифты и гифты с маркета не отправляются и не покупаются: звёзды не списываются. Гифт появляется только у тебя, в чате и в профиле получателя, и всегда с пометкой LARP."), sectionId: self.section)
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
        case .larpNumberInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Номер подменяется только на экране этого устройства, справа от него всегда стоит LARP. Настоящий номер в аккаунте не меняется."), sectionId: self.section)
        }
    }
}

private func nerfClientControllerEntries(settings: NerfClient.Settings, larpGiftCount: Int) -> [NerfClientEntry] {
    var entries: [NerfClientEntry] = []
    entries.append(.larpGiftHeader)
    entries.append(.larpGiftToggle(settings.larpGiftsEnabled))
    entries.append(.larpGiftClear(larpGiftCount))
    entries.append(.larpGiftInfo)
    entries.append(.larpNumberHeader)
    entries.append(.larpNumberToggle(settings.larpNumberEnabled))
    if settings.larpNumberEnabled {
        entries.append(.larpNumberInput(settings.larpNumber))
    }
    entries.append(.larpNumberInfo)
    return entries
}

public func nerfClientController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?

    let accountPeerId = context.account.peerId.toInt64()

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
    })

    let larpGiftCount = NerfClient.shared.larpGiftsSignal
    |> map { gifts -> Int in
        return gifts.filter { $0.accountPeerId == accountPeerId }.count
    }
    |> distinctUntilChanged

    let signal = combineLatest(context.sharedContext.presentationData, NerfClient.shared.settingsSignal, larpGiftCount)
    |> deliverOnMainQueue
    |> map { presentationData, settings, larpGiftCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Nerf Client"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: nerfClientControllerEntries(settings: settings, larpGiftCount: larpGiftCount), style: .blocks, emptyStateItem: nil, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
