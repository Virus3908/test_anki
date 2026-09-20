import SwiftUI

@MainActor
struct BuiltInCardFieldSettingsView: View {
    let settings: StudyPreferences
    let deckID: String?
    let mode: PracticeMode

    @Environment(\.dismiss) private var dismiss
    @State private var dropTarget: DropTarget?
    @State private var draggedField: BuiltInCardField?
    @State private var side = BuiltInCardSide.front
    @State private var clearDropTargetTask: Task<Void, Never>?

    init(
        settings: StudyPreferences,
        deckID: String?,
        mode: PracticeMode,
        initialSide: BuiltInCardSide = .front
    ) {
        self.settings = settings
        self.deckID = deckID
        self.mode = mode
        _side = State(initialValue: initialSide)
    }

    private enum Placement: Equatable {
        case before
        case after
        case emptyList
    }

    private struct DropTarget: Equatable {
        let field: BuiltInCardField?
        let placement: Placement
        let isVisibleList: Bool
    }

    private var options: DeckOptions { settings.options(for: deckID) }

    private var fieldOptions: BuiltInCardFieldOptions { options.builtInCardFields(for: mode, side: side) }

    private var visibleFields: [BuiltInCardField] { fieldOptions.displayedFields }

    private var hiddenFields: [BuiltInCardField] { fieldOptions.order.filter { !fieldOptions.visible.contains($0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(mode.title).font(.headline)
                    Picker("Сторона", selection: $side) {
                        ForEach(BuiltInCardSide.allCases) { side in Text(side.title).tag(side) }
                    }
                    .pickerStyle(.segmented)
                    Text("Перетаскивайте поля между списками и выбирайте их порядок на карточке.")
                        .font(.caption)
                        .foregroundStyle(AppPalette.secondaryText)
                    fieldList(title: "Показываются", fields: visibleFields, isVisibleList: true)
                    fieldList(title: "Скрыты", fields: hiddenFields, isVisibleList: false)
                }
                .padding(20)
            }
            .background(AppPalette.background)
            .foregroundStyle(AppPalette.text)
            .navigationTitle("Поля карточки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Готово") { dismiss() } }
        }
        .onDisappear { clearDropTargetTask?.cancel() }
        .onChange(of: side) {
            clearDropTargetTask?.cancel()
            clearDropTargetTask = nil
            dropTarget = nil
            draggedField = nil
        }
    }

    @ViewBuilder
    private func fieldList(title: String, fields: [BuiltInCardField], isVisibleList: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if fields.isEmpty {
                emptyListHeader(title: title, isVisibleList: isVisibleList)
            } else {
                Text(title).font(.subheadline.weight(.semibold))
                ForEach(fields) { field in
                    fieldRow(field, isVisibleList: isVisibleList)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyListHeader(title: String, isVisibleList: Bool) -> some View {
        let target = DropTarget(field: nil, placement: .emptyList, isVisibleList: isVisibleList)
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            Label("Перетащите поле сюда", systemImage: "arrow.down.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppPalette.accent)
                .opacity(dropTarget == target ? 1 : 0)
        }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(dropTarget == target ? AppPalette.accent.opacity(0.14) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(dropTarget == target ? AppPalette.accent : .clear,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .dropDestination(for: String.self,
                             action: { items, _ in
                                 applyDrop(items.first, relativeTo: nil, placement: .emptyList,
                                           isVisibleList: isVisibleList)
                                 return true
                             },
                             isTargeted: { targeted in updateDropTarget(targeted, target: target) })
    }

    @ViewBuilder
    private func fieldRow(_ field: BuiltInCardField, isVisibleList: Bool) -> some View {
        let beforeTarget = DropTarget(field: field, placement: .before, isVisibleList: isVisibleList)
        let afterTarget = DropTarget(field: field, placement: .after, isVisibleList: isVisibleList)
        VStack(spacing: 8) {
            if dropTarget == beforeTarget { insertionPreview(target: beforeTarget) }
            fieldCard(field, beforeTarget: beforeTarget, afterTarget: afterTarget)
            if dropTarget == afterTarget { insertionPreview(target: afterTarget) }
        }
        .transaction { $0.animation = nil }
    }

    @ViewBuilder
    private func fieldCard(_ field: BuiltInCardField, beforeTarget: DropTarget, afterTarget: DropTarget) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(AppPalette.secondaryText)
            Text(field.title(for: mode)).font(.body.weight(.medium))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .appSurfaceCard()
        .overlay {
            VStack(spacing: 0) {
                fieldDropHalf(source: field, target: beforeTarget)
                fieldDropHalf(source: field, target: afterTarget)
            }
        }
    }

    @ViewBuilder
    private func fieldDropHalf(source: BuiltInCardField, target: DropTarget) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onDrag({
                draggedField = source
                return NSItemProvider(object: source.rawValue as NSString)
            }) {
                dragPreview(source)
            }
            .dropDestination(for: String.self,
                             action: { items, _ in
                                 applyDrop(items.first, relativeTo: target.field, placement: target.placement,
                                           isVisibleList: target.isVisibleList)
                                 return true
                             },
                             isTargeted: { targeted in updateDropTarget(targeted, target: target) })
    }

    @ViewBuilder
    private func insertionPreview(target: DropTarget) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "line.3.horizontal")
            Text(draggedField?.title(for: mode) ?? "Переместить сюда").lineLimit(1)
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppPalette.accent)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(AppPalette.background.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
        .dropDestination(for: String.self,
                         action: { items, _ in
                             applyDrop(items.first, relativeTo: target.field, placement: target.placement,
                                       isVisibleList: target.isVisibleList)
                             return true
                         },
                         isTargeted: { targeted in updateDropTarget(targeted, target: target) })
    }

    @ViewBuilder
    private func dragPreview(_ field: BuiltInCardField) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
            Text(field.title(for: mode)).font(.body.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(AppPalette.text)
        .padding(18)
        .frame(width: 300, alignment: .leading)
        .background(AppPalette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.accent, lineWidth: 2) }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    private func updateDropTarget(_ targeted: Bool, target: DropTarget) {
        if targeted {
            clearDropTargetTask?.cancel()
            clearDropTargetTask = nil
            dropTarget = target
        } else if dropTarget == target {
            clearDropTargetTask?.cancel()
            clearDropTargetTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, dropTarget == target else { return }
                dropTarget = nil
            }
        }
    }

    private func applyDrop(_ value: String?, relativeTo destination: BuiltInCardField?, placement: Placement,
                           isVisibleList: Bool) {
        clearDropTargetTask?.cancel()
        clearDropTargetTask = nil
        dropTarget = nil
        draggedField = nil
        guard let value, let field = BuiltInCardField(rawValue: value), fieldOptions.order.contains(field) else { return }
        guard destination != field else { return }

        var visible = visibleFields
        var hidden = hiddenFields
        visible.removeAll { $0 == field }
        hidden.removeAll { $0 == field }
        var target = isVisibleList ? visible : hidden
        if let destination, let index = target.firstIndex(of: destination) {
            target.insert(field, at: placement == .after ? index + 1 : index)
        } else {
            target.append(field)
        }
        if isVisibleList { visible = target } else { hidden = target }
        persist(orderedAvailableFields: visible + hidden, visibleFields: Set(visible))
    }

    private func persist(orderedAvailableFields: [BuiltInCardField], visibleFields: Set<BuiltInCardField>) {
        settings.updateOptions(for: deckID) { options in
            options.setBuiltInCardFields(.init(order: orderedAvailableFields, visible: visibleFields),
                                         for: mode, side: side)
        }
    }
}
