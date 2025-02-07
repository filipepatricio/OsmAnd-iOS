//
//  OAWidgetsListViewController.swift
//  OsmAnd Maps
//
//  Created by Paul on 24.05.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

import UIKit
import SafariServices

@objc(OAWidgetsListViewController)
@objcMembers
class WidgetsListViewController: OABaseNavbarSubviewViewController {
    
    static let kWidgetAddedNotification = "onWidgetAdded"
    private static let enabledWidgetsFilter = Int(KWidgetModeAvailable | kWidgetModeEnabled | kWidgetModeMatchingPanels)
    
    private let kPageKey = "page_"
    private let kPageNumberKey = "page_number"
    private let kNoWidgetsKey = "noWidgets"
    private let kWidgetsInfoKey = "widget_info"
    private let kIsLastWidgetInSection = "isLastWidgetInSection"
    
    private var editingComplexWidget: MapWidgetInfo?
    
    let panels = WidgetsPanel.values
    
    private var widgetPanel: WidgetsPanel! {
        didSet {
            navigationItem.title = getTitle()
            updateUIAnimated(nil)
        }
    }
    
    private var editMode: Bool = false {
        didSet {
            tableView.setEditing(editMode, animated: true)
            if tableData.hasChanged || tableData.sectionCount() == 0 {
                updateUIAnimated { [weak self] _ in
                    self?.applyRowStyle()
                }
            } else {
                updateWithoutData()
            }
        }
    }
    
    private var selectedAppMode: OAApplicationMode {
        get {
            OAAppSettings.sharedManager().applicationMode.get()
        }
    }
    
    lazy private var widgetRegistry = OARootViewController.instance().mapPanel.mapWidgetRegistry!
    lazy private var widgetsSettingsHelper = WidgetsSettingsHelper(appMode: selectedAppMode)
    
    // MARK: - Initialization
    
    init(widgetPanel: WidgetsPanel!) {
        self.widgetPanel = widgetPanel
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func registerNotifications() {
        addNotification(NSNotification.Name(kWidgetVisibilityChangedMotification), selector: #selector(onWidgetStateChanged))
        addNotification(NSNotification.Name(Self.kWidgetAddedNotification), selector: #selector(onWidgetAdded(notification:)))
        addNotification(.SimpleWidgetStyleUpdated, selector: #selector(onSimpleWidgetStyleUpdated))
    }
    
    @objc private func onSimpleWidgetStyleUpdated(notification: Notification) {
        guard let widgetInfo = notification.object as? MapWidgetInfo,
              let widget = widgetInfo.widget as? OATextInfoWidget else { return }
        guard let rows = getRowsInPageFor(key: widgetInfo.key) else { return }
        
        rows.lazy
            .compactMap { $0.widget as? OATextInfoWidget }
            .forEach { 
                $0.updateWith(style: widget.widgetSizeStyle, appMode: selectedAppMode)
            }
    }
    
    // MARK: - Base setup UI
    
    override func createSubview() -> UIView! {
        if editMode {
            return nil
        }
        let segmentedControl = UISegmentedControl(items: [
            UIImage(named: "ic_custom20_screen_side_left")!,
            UIImage(named: "ic_custom20_screen_side_right")!,
            UIImage(named: "ic_custom20_screen_side_top")!,
            UIImage(named: "ic_custom20_screen_side_bottom")!])
        segmentedControl.selectedSegmentIndex = panels.firstIndex(of: widgetPanel) ?? 0
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        return segmentedControl
    }
    
    @objc private func segmentedControlValueChanged(_ control: UISegmentedControl) {
        widgetPanel = panels[control.selectedSegmentIndex]
    }
    
    // MARK: - Selectors
    
    override func onGestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer!) -> Bool {
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            if editMode, tableData.hasChanged {
                showUnsavedChangesAlert(shouldDismiss: true)
                return false
            }
        }
        return true
    }
    
    private func showUnsavedChangesAlert(shouldDismiss: Bool) {
        let alert = UIAlertController(title: localizedString("unsaved_changes"),
                                      message: localizedString("unsaved_changes_will_be_lost_discard"),
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: localizedString("shared_string_discard"), style: .destructive) { [weak self] _ in
            guard let self else { return }
            editMode = false
            if shouldDismiss {
                dismiss()
            }
        })
        alert.addAction(UIAlertAction(title: localizedString("shared_string_cancel"), style: .cancel))
        let popPresenter = alert.popoverPresentationController
        popPresenter?.barButtonItem = getLeftNavbarButton()
        popPresenter?.permittedArrowDirections = UIPopoverArrowDirection.any
        
        present(alert, animated: true)
    }
    
    override func onLeftNavbarButtonPressed() {
        if editMode {
            if tableData.hasChanged {
                showUnsavedChangesAlert(shouldDismiss: false)
            } else {
                editMode = false
            }
            return
        }
        super.onLeftNavbarButtonPressed()
    }
    
    override func onRightNavbarButtonPressed() {
        if editMode {
            reorderWidgets()
            editMode = false
        }
    }
    
    override func onTopButtonPressed() {
        let vc = WidgetGroupListViewController()
        vc.widgetPanel = widgetPanel
        show(vc)
    }
    
    override func onBottomButtonPressed() {
        if editMode {
            let section = tableData.sectionData(for: tableData.sectionCount() - 1)
            let row = section.createNewRow()
            row.key = kPageKey
            row.cellType = OASimpleTableViewCell.getIdentifier()
            updatePageNumbers()
            configureWidgetsSeparatorForVerticalPanel()
            tableView.reloadData()
            updateBottomButtons()
        } else {
            editMode = true
        }
    }
    
    private func showToastForComplexWidget(_ widgetTitle: String) {
        OAUtilities.showToast(String(format: localizedString("complex_widget_alert"), arguments: [widgetTitle]), details: nil, duration: 4, in: self.view)
    }
    
    @objc private func onWidgetAdded(notification: NSNotification) {
        guard let newWidget = notification.object as? MapWidgetInfo else {
            return
        }
        let lastSection = tableData.sectionCount() - 1
        let lastSectionData = tableData.sectionData(for: lastSection)
        var createNewSection: Bool = false
        if widgetPanel.isPanelVertical {
            if WidgetType.isComplexWidget(newWidget.key), lastSectionData.getRow(lastSectionData.rowCount() - 1).key != kPageKey {
                createNewSection = true
            } else if lastSectionData.rowCount() > 1 {
                let lastWidget: MapWidgetInfo? = lastSectionData.getRow(lastSectionData.rowCount() - 1).obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo
                createNewSection = WidgetType.isComplexWidget(lastWidget?.key ?? "")
            }
        }
        if createNewSection {
            createWidgetItems(NSOrderedSet(object: newWidget), Int(tableData.sectionCount()))
        } else {
            updateWidgetStyleForRowsInLastPage(newWidget, lastSectionData)
            createWidgetItem(newWidget, lastSectionData)
            configureWidgetsSeparatorForVerticalPanel()
        }
        if editMode {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
                self?.updateBottomButtons()
            }
        } else {
            if let userInfo = notification.userInfo as? [String: Any] {
                reorderWidgets(with: userInfo)
            } else {
                reorderWidgets()
            }
            updateUIAnimated(nil)
        }
    }
    
    @objc private func onWidgetStateChanged() {
        if !editMode {
            updateUIAnimated(nil)
        }
    }
    
    @objc private func onButtonClicked(sender: UIButton) {
        let indexPath: IndexPath = IndexPath(row: sender.tag & 0x3FF, section: sender.tag >> 10)
        let item: OATableRowData = tableData.item(for: indexPath)
        if item.key == kNoWidgetsKey {
            onTopButtonPressed()
        }
    }
    
    // MARK: - Additions
    
    private func reorderWidgets(with widgetParams: [String: Any]? = nil) {
        var orders = [[String]]()
        var currPage = [String]()
        for i in 0..<tableData.sectionData(for: 0).rowCount() {
            let rowData = tableData.sectionData(for: 0).getRow(i)
            
            if rowData.key == kPageKey && i != 0 {
                orders.append(currPage)
                currPage = [String]()
            }
            
            if let row = rowData.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo {
                currPage.append(row.key)
            }
        }
        orders.append(currPage)
        
        WidgetUtils.reorderWidgets(orderedWidgetPages: orders,
                                   panel: widgetPanel,
                                   selectedAppMode: selectedAppMode,
                                   widgetParams: widgetParams)
    }
}

// MARK: - Table data
extension WidgetsListViewController {
    
    override func generateData() {
        tableData.clearAllData()
        updateEnabledWidgets()
        tableData.resetChanges()
    }
    
    override func getRow(_ indexPath: IndexPath!) -> UITableViewCell! {
        let item = tableData.item(for: indexPath)
        var outCell: UITableViewCell? = nil
        if item.cellType == OASimpleTableViewCell.getIdentifier() {
            var cell = tableView.dequeueReusableCell(withIdentifier: OASimpleTableViewCell.getIdentifier()) as? OASimpleTableViewCell
            if cell == nil {
                let nib = Bundle.main.loadNibNamed(OASimpleTableViewCell.getIdentifier(), owner: self, options: nil)
                cell = nib?.first as? OASimpleTableViewCell
                cell?.descriptionVisibility(false)
            }
            if let cell {
                let isPageCell = item.key == kPageKey
                cell.titleLabel.text = isPageCell ? String(format: localizedString(widgetPanel.isPanelVertical ? "shared_string_row_number" : "shared_string_page_number"),
                                                           item.integer(forKey: kPageNumberKey) + 1)
                : item.title
                cell.leftIconView.image = UIImage(named: item.iconName ?? "")
                cell.leftIconVisibility(!isPageCell)
                cell.accessoryType = isPageCell ? .none : .disclosureIndicator
                cell.selectionStyle = !tableView.isEditing && isPageCell ? .none : .default
                cell.titleLabel.textColor = isPageCell ? .textColorSecondary : .textColorPrimary
                if !isPageCell, item.obj(forKey: kIsLastWidgetInSection) as? Bool == true {
                    cell.setCustomLeftSeparatorInset(true)
                    cell.separatorInset = .zero
                } else {
                    cell.setCustomLeftSeparatorInset(false)
                }
            }
            return cell
        } else if item.cellType == OALargeImageTitleDescrTableViewCell.getIdentifier() {
            var cell = tableView.dequeueReusableCell(withIdentifier: OALargeImageTitleDescrTableViewCell.getIdentifier()) as? OALargeImageTitleDescrTableViewCell
            if cell == nil {
                let nib = Bundle.main.loadNibNamed(OALargeImageTitleDescrTableViewCell.getIdentifier(), owner: self, options: nil)
                cell = nib?.first as? OALargeImageTitleDescrTableViewCell
                cell?.selectionStyle = .none
            }
            if let cell {
                cell.titleLabel?.text = item.title
                cell.titleLabel?.accessibilityLabel = item.title
                cell.descriptionLabel?.text = item.descr
                cell.descriptionLabel?.accessibilityLabel = item.descr
                cell.cellImageView?.image = UIImage.templateImageNamed(item.iconName)
                cell.cellImageView?.tintColor = item.iconTintColor
                cell.button?.setTitle(item.obj(forKey: "buttonTitle") as? String, for: .normal)
                cell.button?.accessibilityLabel = item.obj(forKey: "buttonTitle") as? String
                cell.button?.removeTarget(nil, action: nil, for: .allEvents)
                cell.button?.tag = indexPath.section << 10 | indexPath.row
                cell.button?.addTarget(self, action: #selector(onButtonClicked(sender:)), for: .touchUpInside)
            }
            outCell = cell
            
            let update: Bool = outCell?.needsUpdateConstraints() ?? false
            if update {
                outCell?.setNeedsUpdateConstraints()
            }
        }
        
        return outCell
    }
    
    override func onRowSelected(_ indexPath: IndexPath!) {
        let item = tableData.item(for: indexPath)
        if item.cellType == OASimpleTableViewCell.getIdentifier(), let vc = WidgetConfigurationViewController() {
            vc.selectedAppMode = selectedAppMode
            vc.widgetInfo = item.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo
            vc.widgetPanel = widgetPanel
            show(vc)
        }
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        let item = tableData.item(for: indexPath)
        let isFirstPageCell = item.key == kPageKey && indexPath.row == 0
        let isNoWidgetsCell = item.key == kNoWidgetsKey
        
        if item.key == kPageKey, tableData.rowCount(UInt(indexPath.section)) > indexPath.row + 1 {
            let nextItem = tableData.item(for: IndexPath(row: indexPath.row + 1, section: indexPath.section))
            if let mapWidgetInfo = nextItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key) {
                return false
            }
        }
        
        return editMode && !isNoWidgetsCell && !isFirstPageCell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let item = tableData.item(for: indexPath)
        let isFirstPageCell = item.key == kPageKey && indexPath.row == 0
        let isNoWidgetsCell = item.key == kNoWidgetsKey
        return editMode && !isNoWidgetsCell && !isFirstPageCell
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = tableData.item(for: sourceIndexPath)
        tableData.removeRow(at: sourceIndexPath)
        let movedIndexPath = destinationIndexPath.row == 0 ? IndexPath(row: 1, section: destinationIndexPath.section) : destinationIndexPath
        tableData.addRow(at: movedIndexPath, row: item)
        
        updatePageNumbers()
        configureWidgetsSeparatorForVerticalPanel()
        tableView.reloadData()
        updateBottomButtons()
        if let editingComplexWidget {
            showToastForComplexWidget(editingComplexWidget.getTitle())
            self.editingComplexWidget = nil
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let item = tableData.item(for: indexPath)
            if item.key == kPageKey, indexPath.row != tableData.rowCount(UInt(indexPath.section)) - 1 {
                let prevSourceItem = tableData.item(for: IndexPath(row: indexPath.row - 1, section: indexPath.section))
                let nextSourceItem = tableData.item(for: IndexPath(row: indexPath.row + 1, section: indexPath.section))
                if let mapWidgetInfo = prevSourceItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key), nextSourceItem.key != kPageKey {
                    showToastForComplexWidget(mapWidgetInfo.getTitle())
                    return
                }
                if tableData.rowCount(UInt(indexPath.section)) > indexPath.row + 1 {
                    let prevSourceItem = tableData.item(for: IndexPath(row: indexPath.row - 1, section: indexPath.section))
                    let nextSourceItem = tableData.item(for: IndexPath(row: indexPath.row + 1, section: indexPath.section))
                    if let mapWidgetInfo = nextSourceItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key), prevSourceItem.key != kPageKey {
                        showToastForComplexWidget(mapWidgetInfo.getTitle())
                        return
                    }
                }
            }
            tableData.removeRow(at: indexPath)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            configureWidgetsSeparatorForVerticalPanel()
            let isPageCell = item.key == kPageKey
            if isPageCell {
                updatePageNumbers()
            }
            tableView.reloadData()
            updateBottomButtons()
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                            toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let sourceItem = tableData.item(for: sourceIndexPath)
        if let mapWidgetInfo = sourceItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key) {
            editingComplexWidget = mapWidgetInfo
            return sourceIndexPath
        }
        if sourceItem.key == kPageKey {
            let prevSourceItem = tableData.item(for: IndexPath(row: sourceIndexPath.row - 1, section: sourceIndexPath.section))
            if let mapWidgetInfo = prevSourceItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key) {
                editingComplexWidget = mapWidgetInfo
                return sourceIndexPath
            }
        }
        
        let destinationItem = tableData.item(for: proposedDestinationIndexPath)
        if let mapWidgetInfo = destinationItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key) {
            editingComplexWidget = mapWidgetInfo
            return sourceIndexPath
        }
        if destinationItem.key == kPageKey {
            if !self.tableView(tableView, canMoveRowAt: proposedDestinationIndexPath), self.tableView(tableView, canEditRowAt: proposedDestinationIndexPath), tableData.rowCount(UInt(proposedDestinationIndexPath.section)) > proposedDestinationIndexPath.row + 1 {
                let destinationComplexItem = tableData.item(for: IndexPath(row: proposedDestinationIndexPath.row + 1, section: proposedDestinationIndexPath.section))
                if let mapWidgetInfo = destinationComplexItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key) {
                    editingComplexWidget = mapWidgetInfo
                    return sourceIndexPath
                }
            }
            let prevDestinationItem = tableData.item(for: IndexPath(row: proposedDestinationIndexPath.row - 1, section: proposedDestinationIndexPath.section))
            if let mapWidgetInfo = prevDestinationItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key) {
                editingComplexWidget = mapWidgetInfo
                return sourceIndexPath
            }
        }
        
        if proposedDestinationIndexPath.row == 0 && proposedDestinationIndexPath.section == 0 {
            let indexPath = IndexPath(row: 1, section: 0)
            if tableData.rowCount(UInt(indexPath.section)) > 1 {
                let destinationItem = tableData.item(for: indexPath)
                if let mapWidgetInfo = destinationItem.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo, WidgetType.isComplexWidget(mapWidgetInfo.key), sourceItem.key != kPageKey {
                    editingComplexWidget = mapWidgetInfo
                    return sourceIndexPath
                }
            }
            return indexPath
        }
        return proposedDestinationIndexPath
    }
    
    private func updateEnabledWidgets() {
        let enabledWidgets = widgetRegistry.getWidgetsForPanel(selectedAppMode, filterModes: Self.enabledWidgetsFilter, panels: [widgetPanel])!
        let noEnabledWidgets = enabledWidgets.count == 0
        if noEnabledWidgets && !editMode {
            var iconName = "ic_custom_screen_side_left_48"
            if widgetPanel == .topPanel {
                iconName = "ic_custom_screen_side_top_48"
            } else if widgetPanel == .rightPanel {
                iconName = "ic_custom_screen_side_right_48"
            } else if widgetPanel == .bottomPanel {
                iconName = "ic_custom_screen_side_bottom_48"
            }
            let section = tableData.createNewSection()
            let row = section.createNewRow()
            row.cellType = OALargeImageTitleDescrTableViewCell.getIdentifier()
            row.key = kNoWidgetsKey
            row.title = localizedString("no_widgets_here_yet")
            row.descr = localizedString("no_widgets_descr")
            row.iconName = iconName
            row.iconTintColor = .iconColorDefault
            row.setObj(localizedString("add_widget"), forKey: "buttonTitle")
        } else {
            let pagedWidgets = widgetRegistry.getPagedWidgets(forPanel: selectedAppMode, panel: widgetPanel, filterModes: Self.enabledWidgetsFilter)!
            tableData.clearAllData()
            tableData.createNewSection()
            for i in 0..<pagedWidgets.count {
                createWidgetItems(pagedWidgets[i], i)
            }
            configureWidgetsSeparatorForVerticalPanel()
        }
    }
    
    private func createWidgetItems(_ widgets: NSOrderedSet, _ pageIndex: Int) {
        let section = tableData.sectionData(for: 0)
        let row = section.createNewRow()
        row.key = kPageKey
        row.cellType = OASimpleTableViewCell.getIdentifier()
        row.setObj(pageIndex, forKey: kPageNumberKey)
        
        let sortedWidgets = (widgets.array as! [MapWidgetInfo]).sorted { $0.priority < $1.priority }
        for widget in sortedWidgets {
            createWidgetItem(widget, section)
        }
    }
    
    private func createWidgetItem(_ widget: MapWidgetInfo, _ section: OATableSectionData) {
        if section.rowCount() > 0 && section.getRow(0).key != kPageKey {
            section.addRow(OATableRowData(), position: 0)
            let row = section.getRow(0)
            row.key = kPageKey
            row.cellType = OASimpleTableViewCell.getIdentifier()
        }
        
        let row = section.createNewRow()
        row.setObj(widget, forKey: kWidgetsInfoKey)
        row.iconName = widget.widget.widgetType?.iconName
        row.title = widget.getTitle()
        row.descr = widget.getMessage()
        row.cellType = OASimpleTableViewCell.getIdentifier()
    }
    
    private func updatePageNumbers() {
        if tableData.sectionCount() > 0 {
            let section = tableData.sectionData(for: 0)
            var foundedPageIndex = 0
            for i in 0..<section.rowCount() {
                let row = section.getRow(i)
                if row.key == kPageKey {
                    row.setObj(foundedPageIndex, forKey: kPageNumberKey)
                    foundedPageIndex += 1
                }
            }
        }
    }
}

extension WidgetsListViewController {
    
    // MARK: - Base UI
    
    override func getTitle() -> String! {
        widgetPanel.title
    }
    
    override func getBottomAxisMode() -> NSLayoutConstraint.Axis {
        .horizontal
    }
    
    override func isNavbarSeparatorVisible() -> Bool {
        editMode
    }
    
    override func getLeftNavbarButtonTitle() -> String! {
        editMode ? localizedString("shared_string_cancel") : nil
    }
    
    override func getRightNavbarButtons() -> [UIBarButtonItem]! {
        var menuElements: [UIMenuElement]?
        var resetAlert: UIAlertController?
        if !editMode {
            resetAlert = UIAlertController(title: widgetPanel.title,
                                           message: localizedString("reset_all_settings_desc"),
                                           preferredStyle: .actionSheet)
            let resetAction: UIAction = UIAction(title: localizedString("reset_to_default"),
                                                 image: UIImage(systemName: "gobackward")) { [weak self] _ in
                guard let self else { return }
                
                resetAlert!.addAction(UIAlertAction(title: localizedString("shared_string_reset"), style: .destructive) { UIAlertAction in
                    self.widgetsSettingsHelper.resetWidgetsForPanel(panel: self.widgetPanel)
                    OARootViewController.instance().mapPanel.recreateAllControls()
                    self.updateUIAnimated(nil)
                })
                resetAlert!.addAction(UIAlertAction(title: localizedString("shared_string_cancel"), style: .cancel))
                present(resetAlert!, animated: true)
            }
            let copyAction: UIAction = UIAction(title: localizedString("copy_from_other_profile"),
                                                image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                guard let self else { return }
                
                let bottomSheet: OACopyProfileBottomSheetViewControler = OACopyProfileBottomSheetViewControler(mode: self.selectedAppMode)
                bottomSheet.delegate = self
                bottomSheet.present(in: self)
            }
            let helpAction: UIAction = UIAction(title: localizedString("shared_string_help"),
                                                image: UIImage(systemName: "questionmark.circle")) { [weak self] _ in
                guard let self else { return }
                
                openSafariWithURL("https://docs.osmand.net/docs/user/widgets/configure-screen")
            }
            let helpMenuAction: UIMenu = UIMenu(options: .displayInline, children: [helpAction])
            menuElements = [resetAction, copyAction, helpMenuAction]
        }
        let menu: UIMenu? = editMode ? nil : UIMenu(children: menuElements ?? [])
        let button = createRightNavbarButton(editMode ? localizedString("shared_string_done") : nil,
                                             iconName: editMode ? nil : "ic_navbar_overflow_menu_stroke",
                                             action: #selector(onRightNavbarButtonPressed),
                                             menu: menu)
        if !editMode {
            button?.accessibilityLabel = localizedString("shared_string_options")
        }
        let popover = resetAlert?.popoverPresentationController
        popover?.barButtonItem = button
        return [button!]
    }
    
    override func getTopButtonTitle() -> String {
        let enabledWidgets = widgetRegistry.getWidgetsForPanel(selectedAppMode,
                                                               filterModes: Self.enabledWidgetsFilter,
                                                               panels: [widgetPanel])!
        return editMode || enabledWidgets.count > 0 ? localizedString("add_widget") : ""
    }
    
    override func getBottomButtonTitle() -> String {
        let enabledWidgets = widgetRegistry.getWidgetsForPanel(selectedAppMode,
                                                               filterModes: Self.enabledWidgetsFilter,
                                                               panels: [widgetPanel])!
        return enabledWidgets.count == 0 ? "" : editMode ? localizedString(widgetPanel.isPanelVertical ? "add_row" : "add_page") : localizedString("shared_string_edit")
    }
    
    override func getTopButtonColorScheme() -> EOABaseButtonColorScheme {
        .graySimple
    }
    
    override func getBottomButtonColorScheme() -> EOABaseButtonColorScheme {
        if editMode {
            for i in 0..<tableData.sectionCount() {
                let section = tableData.sectionData(for: i)
                if section.rowCount() == 1 {
                    return .inactive
                }
            }
        }
        return .graySimple
    }
}

// MARK: - SFSafariViewControllerDelegate

extension WidgetsListViewController: SFSafariViewControllerDelegate {
    
    @nonobjc func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
    
    private func openSafariWithURL(_ url: String) {
        guard let url = URL(string: url) else {
            return
        }
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.delegate = self
        present(safariViewController, animated: true)
    }
}

// MARK: - OACopyProfileBottomSheetDelegate

extension WidgetsListViewController: OACopyProfileBottomSheetDelegate {
    
    func onCopyProfileCompleted() {
    }
    
    func onCopyProfile(_ fromAppMode: OAApplicationMode!) {
        widgetsSettingsHelper.copyWidgetsForPanel(fromAppMode: fromAppMode, panel: widgetPanel)
        OARootViewController.instance().mapPanel.recreateAllControls()
        updateUIAnimated(nil)
    }
}

extension WidgetsListViewController {
    
    private func configureWidgetsSeparatorForVerticalPanel() {
        guard widgetPanel.isPanelVertical,
              tableData.sectionCount() > 0 else { return }
        
        let section = tableData.sectionData(for: 0)
        for i in 0..<section.rowCount() {
            let row = section.getRow(i)
            row.setObj(false, forKey: kIsLastWidgetInSection)
            if row.key == kPageKey && i > 0 {
                let previousRow = section.getRow(i - 1)
                previousRow.setObj(true, forKey: kIsLastWidgetInSection)
            }
        }
    }
    
    private func applyRowStyle() {
        for widgets in getPagesWithMapWidgetInfo() {
            var widgetsInfoInRow = [OATextInfoWidget]()
            for widget in widgets {
                guard let id = widget.widget.widgetType?.id, !WidgetType.isComplexWidget(id) else {
                    continue
                }
                if let item = widget.widget as? OATextInfoWidget {
                    widgetsInfoInRow.append(item)
                }
            }
            widgetsInfoInRow.updateWithMostFrequentStyle(with: selectedAppMode)
        }
    }
    
    private func getRowsInLastPage(dataArray: [OATableRowData]) -> [OATableRowData] {
        var result: [OATableRowData] = []
        
        var lastPageIndex = -1
        for i in (0..<dataArray.count).reversed() {
            let rowData = dataArray[i]
            if rowData.key == kPageKey {
                lastPageIndex = i
                break
            }
        }
        if lastPageIndex >= 0 && lastPageIndex < dataArray.count - 1 {
            result = Array(dataArray[lastPageIndex + 1..<dataArray.count])
        }
        
        return result
    }
    
    private func updateWidgetStyleForRowsInLastPage(_ newWidget: MapWidgetInfo,
                                                    _ sectionData: OATableSectionData) {
        let addWidgetSizeStyle = (newWidget.widget as? OATextInfoWidget)?.widgetSizeStyle ?? .medium
        
        let lastWidgetInRow = sectionData.getRow(sectionData.rowCount() - 1)
        guard let simpleWidget = (lastWidgetInRow.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo)?.widget as? OATextInfoWidget else {
            return
        }
        
        if simpleWidget.widgetSizeStyle != addWidgetSizeStyle {
            if addWidgetSizeStyle != .medium {
                // Apply the current style of widget for all rows in page
                var dataArray = [OATableRowData]()
                for row in 0..<sectionData.rowCount() {
                    dataArray.append(sectionData.getRow(row))
                }
                let itemsInLastPage = getRowsInLastPage(dataArray: dataArray)
                itemsInLastPage.forEach {
                    if let widgetInRow = ($0.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo)?.widget as? OATextInfoWidget {
                        widgetInRow.updateWith(style: addWidgetSizeStyle, appMode: selectedAppMode)
                    }
                }
            } else {
                // Apply row style for the added widget
                (newWidget.widget as? OATextInfoWidget)?.updateWith(style: simpleWidget.widgetSizeStyle, appMode: selectedAppMode)
            }
        }
    }
    
    private func getRowsInPageFor(key: String) -> [MapWidgetInfo]? {
        getPagesWithMapWidgetInfo().first { $0.contains { $0.key == key } }
    }
    
    private func getPagesWithMapWidgetInfo() -> [[MapWidgetInfo]] {
        var orders = [[MapWidgetInfo]]()
        var currPage = [MapWidgetInfo]()
        for i in 0..<tableData.sectionData(for: 0).rowCount() {
            let rowData = tableData.sectionData(for: 0).getRow(i)
            if rowData.key == kPageKey && i != 0 {
                orders.append(currPage)
                currPage = [MapWidgetInfo]()
            }
            if let row = rowData.obj(forKey: kWidgetsInfoKey) as? MapWidgetInfo {
                currPage.append(row)
            }
        }
        orders.append(currPage)
        
        return orders
    }
}
