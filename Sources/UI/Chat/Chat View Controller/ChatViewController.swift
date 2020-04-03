//
//  ChatViewController.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 03/04/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import SnapKit
import RxSwift
import RxCocoa
import Photos

/// This class describes the different types of custom messages we can display
public enum CustomMessageType {
    case conversationBeginning
    case embeddedEmail
    case virtualThread
    case undefined
}

public enum ChatScreenType {
    case topic
    case conversation
    case preview
}

/// A chat view controller of a channel.
open class ChatViewController: ViewController, UITableViewDataSource, UITableViewDelegate {
    
    public var type: ChatScreenType = .conversation
    /// Custom tap handlers for accessing events on upper levels
    public var didTapMessage: ((_ type: CustomMessageType, _ message: Message, _ viewController: ChatViewController?, _ channelPresenter: ChannelPresenter?) -> Void)?
    public var didTapEmailAttachment: ((_ attachment: Attachment, _ viewController: ChatViewController?) -> Void)?
    
    public var isVirtualThreadMessage: ((_ message: Message) -> Bool)?
    public var getIndexPathsToReload: ((_ threadMessage: Message, _ items: [ChatItem]) -> [IndexPath])?
    
    
    public var onAcceptInvite: (() -> Void)?
    public var onDismissInvite: (() -> Void)?
    public var onWillAppear: (() -> Void)?
    public var onWillDisappear: (() -> Void)?
    public var redirectToTopic: ((_ message: Message, _ vc: UIViewController, _ channelPresenter: ChannelPresenter?) -> Void)?
    /// A chat style.
    public lazy var style = defaultStyle
    
    
    public var hiddenMessagesIds: [String] = []
    /// A default chat style. This is useful for subclasses.
    open var defaultStyle: ChatViewStyle {
        return .default
    }
    
    /// Message actions (see `MessageAction`).
    public lazy var messageActions = defaultMessageActions
    
    /// A default message actions. This is useful for subclasses.
    open var defaultMessageActions: MessageAction {
        return .all
    }
    
    /// A dispose bag for rx subscriptions.
    public let disposeBag = DisposeBag()
    /// A list of table view items, e.g. messages.
    public private(set) var items = [ChatItem]()
    private var needsToReload = true
    /// A reaction view.
    weak var reactionsView: ReactionsView?
    
    var scrollEnabled: Bool {
        return reactionsView == nil
    }
    
    /// A composer view.
    
    public var sendButtonTapSubscription: Disposable?
    public private(set) lazy var composerView = createComposerView()
    var keyboardIsVisible = false
    
    private(set) lazy var initialSafeAreaBottom: CGFloat = calculatedSafeAreaBottom
    
    /// Calculates the bottom inset for the `ComposerView` when the keyboard will appear.
    open var calculatedSafeAreaBottom: CGFloat {
        if let tabBar = tabBarController?.tabBar, !tabBar.isTranslucent, !tabBar.isHidden {
            return tabBar.frame.height
        }
        
        return view.safeAreaInsets.bottom > 0 ? view.safeAreaInsets.bottom : (parent?.view.safeAreaInsets.bottom ?? 0)
    }
    
    /// Attachments file types for thw composer view.
    public lazy var composerAddFileTypes = defaultComposerAddFileTypes
    
    /// Default attachments file types for thw composer view. This is useful for subclasses.
    public var defaultComposerAddFileTypes: [ComposerAddFileType]  {
        return [.photo, .camera, .file]
    }
    
    private(set) lazy var composerEditingContainerView = createComposerEditingContainerView()
    private(set) lazy var composerCommandsContainerView = createComposerCommandsContainerView()
    private(set) lazy var composerAddFileContainerView = createComposerAddFileContainerView(title: "Add a file")
    
    var gradientView: UIImageView?
    var joinButton: UIButton?
    var dismissButton: UIButton?
    
    
    public private(set) lazy var aboutThisConversationView: UIView = {
        let container = UIView()
        view.addSubview(container)
        container.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }
        return container
    }()
    /// A table view of messages.
    public private(set) lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.backgroundColor = style.incomingMessage.chatBackgroundColor
        tableView.keyboardDismissMode = .interactive
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIColor(red: 248/255, green: 251/255, blue: 252/255, alpha: 1)
        tableView.registerMessageCell(style: style.incomingMessage)
        tableView.registerMessageCell(style: style.outgoingMessage)
        tableView.register(cellType: StatusTableViewCell.self)
        view.insertSubview(tableView, at: 0)
        
        let footerView = ChatFooterView(frame: CGRect(width: 0, height: .chatFooterHeight))
        footerView.backgroundColor = tableView.backgroundColor
        tableView.tableFooterView = footerView
        
        return tableView
    }()
    
    private lazy var bottomThreshold = (style.incomingMessage.avatarViewStyle?.size ?? CGFloat.messageAvatarSize)
        + style.incomingMessage.edgeInsets.top
        + style.incomingMessage.edgeInsets.bottom
        + style.composer.height
        + style.composer.edgeInsets.top
        + style.composer.edgeInsets.bottom
    
    /// A channel presenter.
    public var channelPresenter: ChannelPresenter?
    private var changesEnabled: Bool = false
    
    // MARK: - View Life Cycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = style.incomingMessage.chatBackgroundColor
        
        updateTitle()
        initializeChannelPresenter()
        setupComposerView()
        needsToReload = false
        changesEnabled = true
        setupFooterUpdates()
        setupJoiningOptions()
        Keyboard.shared.notification.bind(to: rx.keyboard).disposed(by: self.disposeBag)
    }
    
    
    @objc func dismissInvite() {
        onDismissInvite?()
    }
    
    @objc func acceptInvite() {
//        onAcceptInvite?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.hidePreviewAndEnableComposer()
        }
    }
    
    open func hidePreviewAndEnableComposer() {
        self.type = .conversation
        gradientView?.removeFromSuperview()
        joinButton?.removeFromSuperview()
        dismissButton?.removeFromSuperview()
        composerView.isHidden = false
//        composerView.removeFromSuperview()
//        composerView = createComposerView()
//        setupComposerView()
    }
    
    func setupJoiningOptions() {
        if type == .preview {
            let bundle = Bundle(for: ChatViewController.self)
            gradientView = UIImageView()
            joinButton = UIButton()
            dismissButton = UIButton()
            
            guard let gradientView = gradientView, let joinButton = joinButton, let dismissButton = dismissButton else { return }
            joinButton.setTitle("Join", for: .normal)
            joinButton.backgroundColor = #colorLiteral(red: 0, green: 0.6078431373, blue: 0.9176470588, alpha: 1)
            joinButton.setTitleColor(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), for: .normal)
            joinButton.layer.cornerRadius = 6
            joinButton.titleLabel?.font = Fonts.bold.of(size: 16)
            joinButton.layer.shadowColor = #colorLiteral(red: 0, green: 0.6078431373, blue: 0.9176470588, alpha: 1)
            joinButton.layer.shadowRadius = 6
            joinButton.layer.shadowOffset = CGSize(width: 0, height: 1)
            joinButton.layer.shadowOpacity = 0.5
            joinButton.addTarget(self, action: #selector(acceptInvite), for: .touchUpInside)
            
            
            dismissButton.setTitle("Dismiss", for: .normal)
            dismissButton.setTitleColor(#colorLiteral(red: 0, green: 0.6078431373, blue: 0.9176470588, alpha: 1), for: .normal)
            dismissButton.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            dismissButton.layer.cornerRadius = 6
            dismissButton.layer.borderColor = #colorLiteral(red: 0, green: 0.6078431373, blue: 0.9176470588, alpha: 1)
            dismissButton.layer.borderWidth = 1
            dismissButton.titleLabel?.font = Fonts.bold.of(size: 16)
            dismissButton.addTarget(self, action: #selector(dismissInvite), for: .touchUpInside)
            
            
            gradientView.image = UIImage(named: "JoinGradient", in: bundle, compatibleWith: nil)
            gradientView.contentMode = .scaleAspectFill
            
            view.addSubview(gradientView)
            view.addSubview(joinButton)
            view.addSubview(dismissButton)
            
            
            joinButton.snp.makeConstraints { make in
                make.width.equalToSuperview().multipliedBy(0.8)
                make.height.equalTo(50)
                make.centerX.equalToSuperview()
                make.bottom.equalTo(dismissButton.snp.top).offset(-15)
            }
            
            
            dismissButton.snp.makeConstraints { make in
                make.width.equalToSuperview().multipliedBy(0.70)
                make.height.equalTo(35)
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview().offset(-40)
            }
            
            gradientView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(view.snp.bottom)
                make.height.equalTo(view.snp.height).multipliedBy(0.5)
            }
        }
    }
    
    
    open func emptyTableView() {
        self.items = []
        self.tableView.reloadData()
    }
    
    open func initializeChannelPresenter() {
        
        guard let presenter = channelPresenter else {
            return
        }
        
        if presenter.channel.config.isEmpty {
            presenter.channelDidUpdate.asObservable()
                .takeWhile { $0.config.isEmpty }
                .subscribe(onCompleted: { [weak self] in self?.setupComposerView() })
                .disposed(by: disposeBag)
        }
        
        composerView.uploader = presenter.uploader
        
        presenter.changes
            .filter { [weak self] _ in
                if let self = self {
                    self.needsToReload = self.needsToReload || !self.isVisible
                    return self.changesEnabled && self.isVisible
                }
                
                return false
        }
        .drive(onNext: { [weak self] in self?.updateTableView(with: $0) })
        .disposed(by: disposeBag)
        
        if presenter.isEmpty {
            channelPresenter?.reload()
        } else {
            refreshTableView(scrollToBottom: true, animated: false)
        }
    }
    
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onWillAppear?()
        startGifsAnimations()
        markReadIfPossible()
        
        if let presenter = channelPresenter, (needsToReload || presenter.items != items) {
            let scrollToBottom = items.isEmpty || (scrollEnabled && tableView.bottomContentOffset < bottomThreshold)
            refreshTableView(scrollToBottom: scrollToBottom, animated: false)
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onWillDisappear?()
        stopGifsAnimations()
    }
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return style.incomingMessage.textColor.isDark ? .default : .lightContent
    }
    
    open override func willTransition(to newCollection: UITraitCollection,
                                      with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        if composerView.textView.isFirstResponder {
            composerView.textView.resignFirstResponder()
        }
        
        DispatchQueue.main.async { self.initialSafeAreaBottom = self.calculatedSafeAreaBottom }
    }
    
    // MARK: Table View Customization
    
    /// Refresh table view cells with presenter items.
    ///
    /// - Parameters:
    ///   - scrollToBottom: scroll the table view to the bottom cell after refresh, if true
    ///   - animated: scroll to the bottom cell animated, if true
    open func refreshTableView(scrollToBottom: Bool, animated: Bool) {
        guard let presenter = channelPresenter else {
            return
        }
        
        needsToReload = false
        items = presenter.items
        tableView.reloadData()
        
        if scrollToBottom {
            tableView.scrollToBottom(animated: animated)
            DispatchQueue.main.async { [weak self] in self?.tableView.scrollToBottom(animated: animated) }
        }
    }
    
    /// A message cell to insert in a particular location of the table view.
    ///
    /// - Parameters:
    ///   - indexPath: an index path.
    ///   - message: a message.
    ///   - readUsers: a list of users who read the message.
    /// - Returns: a message table view cell.
    open func messageCell(at indexPath: IndexPath, message: Message, readUsers: [User]) -> UITableViewCell {
        return extensionMessageCell(at: indexPath, message: message, readUsers: readUsers)
    }
    
    /// A custom loading cell to insert in a particular location of the table view.
    ///
    /// - Parameters:
    ///   - indexPath: an index path.
    /// - Returns: a loading table view cell.
    open func loadingCell(at indexPath: IndexPath) -> UITableViewCell? {
        return nil
    }
    
    /// A custom status cell to insert in a particular location of the table view.
    ///
    /// - Parameters:
    ///   - indexPath: an index path.
    ///   - title: a title.
    ///   - subtitle: a subtitle.
    ///   - highlighted: change the status cell style to highlighted.
    /// - Returns: a status table view cell.
    open func statusCell(at indexPath: IndexPath,
                         title: String,
                         subtitle: String? = nil,
                         textColor: UIColor) -> UITableViewCell? {
        return nil
    }
    
    /// Setup Footer updates for environement updates.
    open func setupFooterUpdates() {
        Client.shared.connection
            .observeOn(MainScheduler.instance)
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] connection in
                if let self = self {
                    self.updateFooterView()
                    self.composerView.isEnabled = connection.isConnected
                }
            })
            .disposed(by: disposeBag)
        
        updateFooterView()
    }
    
    /// Show message actions when long press on a message cell.
    /// - Parameters:
    ///   - cell: a message cell.
    ///   - message: a message.
    ///   - locationInView: a tap location in the cell.
    open func showActions(from cell: UITableViewCell, for message: Message, locationInView: CGPoint) {
        extensionShowActions(from: cell, for: message, locationInView: locationInView)
    }
    
    private func markReadIfPossible() {
        channelPresenter?.markReadIfPossible().subscribe().disposed(by: disposeBag)
    }
    

}

// MARK: - Title

extension ChatViewController {
    
    private func updateTitle() {
        guard title == nil, navigationItem.rightBarButtonItem == nil, let presenter = channelPresenter else {
            return
        }
        
        if presenter.parentMessage != nil {
            title = "Thread"
            updateTitleReplyCount()
            return
        }
        
        title = presenter.channel.name
        let channelAvatar = AvatarView(cornerRadius: .messageAvatarRadius)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: channelAvatar)
        let imageURL = presenter.parentMessage == nil ? presenter.channel.imageURL : presenter.parentMessage?.user.avatarURL
        channelAvatar.update(with: imageURL, name: title, baseColor: style.incomingMessage.chatBackgroundColor)
    }
    
    private func updateTitleReplyCount() {
        guard title == "Thread", let parentMessage = channelPresenter?.parentMessage else {
            return
        }
        
        guard parentMessage.replyCount > 0 else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        
        let title = parentMessage.replyCount == 1 ? "1 reply" : "\(parentMessage.replyCount) replies"
        let button = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
        button.tintColor = .chatGray
        button.setTitleTextAttributes([.font: UIFont.chatMedium], for: .normal)
        navigationItem.rightBarButtonItem = button
    }
}

// MARK: - Table View

extension ChatViewController {
    
    private func updateTableView(with changes: ViewChanges) {
        markReadIfPossible()
        
        switch changes {
        case .none, .itemMoved:
            return
        case let .reloaded(scrollToRow, items):
            let needsToScroll = !items.isEmpty && ((scrollToRow == (items.count - 1)))
            var isLoading = false
            self.items = items
            
            if !items.isEmpty, case .loading = items[0] {
                isLoading = true
                self.items[0] = .loading(true)
            }
            
            tableView.reloadData()
            
            if scrollToRow >= 0 && (isLoading || (scrollEnabled && needsToScroll)) {
                tableView.scrollToRowIfPossible(at: scrollToRow, animated: false)
            }
            
            if !items.isEmpty, case .loading = items[0] {
                self.items[0] = .loading(false)
            }
            
        case let .itemsAdded(rows, reloadRow, forceToScroll, items):
            var rowsToReload: [IndexPath] = []
            if let message = items.last?.message,
                let isVirtualThread = self.isVirtualThreadMessage,
                isVirtualThread(message) {
                
                if let getIndexPathsToReload = self.getIndexPathsToReload {
                    rowsToReload = getIndexPathsToReload(message, self.items)
                    for indexPath in rowsToReload {
                        guard let message = self.items[indexPath.row].message else { continue }
                        self.hiddenMessagesIds.append(message.id)
                    }
                    print("rowsToReload", rowsToReload)
                }
            }
            self.items = items
            let needsToScroll = tableView.bottomContentOffset < bottomThreshold
            tableView.stayOnScrollOnce = scrollEnabled && needsToScroll && !forceToScroll
            
            if forceToScroll {
                reactionsView?.dismiss()
            }
            
            UIView.performWithoutAnimation {
                tableView.performBatchUpdates({
                    tableView.insertRows(at: rows.map(IndexPath.row), with: .none)
                    
                    if let reloadRow = reloadRow {
                        print("reloading", reloadRow)
                        tableView.reloadRows(at: [.row(reloadRow)], with: .none)
                    }
                    
                    if !rowsToReload.isEmpty {
                        print("reloading", rowsToReload)
                        tableView.reloadRows(at: rowsToReload, with: .none)
                    }
                })
                
                if let maxRow = rows.max(), (scrollEnabled && needsToScroll) || forceToScroll {
                    tableView.scrollToRowIfPossible(at: maxRow, animated: false)
                }
            }
        case let .itemsUpdated(rows, messages, items):
            self.items = items
            
            UIView.performWithoutAnimation {
                tableView.reloadRows(at: rows.map({ .row($0) }), with: .none)
            }
            
            if let reactionsView = reactionsView, let message = messages.first {
                reactionsView.update(with: message)
            }
            
        case let .itemRemoved(row, items):
            self.items = items
            
            UIView.performWithoutAnimation {
                tableView.deleteRows(at: [.row(row)], with: .none)
            }
            
        case .footerUpdated:
            updateFooterView()
            
        case .disconnected:
            return
            
        case .error(let error):
            show(error: error)
        }
        
        updateTitleReplyCount()
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < items.count else {
            return .unused
        }
        
        let cell: UITableViewCell
        
        switch items[indexPath.row] {
        case .loading:
            cell = loadingCell(at: indexPath)
                ?? tableView.loadingCell(at: indexPath, textColor: style.incomingMessage.infoColor)
            
        case let .status(title, subtitle, highlighted):
            let textColor = highlighted ? style.incomingMessage.replyColor : style.incomingMessage.infoColor
            
            cell = statusCell(at: indexPath,
                              title: title,
                              subtitle: subtitle,
                              textColor: textColor)
                ?? tableView.statusCell(at: indexPath, title: title, subtitle: subtitle, textColor: textColor)
            
        case let .message(message, readUsers):
            cell = messageCell(at: indexPath, message: message, readUsers: readUsers)
            let item = items[indexPath.row]
            
            // Hides or shows the message depending on if it is a Topic or not
            // Topic Root messages are identified because they have a replyCount > 0
            if item.message?.replyCount ?? 0 > 0 {
                cell.clipsToBounds = true
            } else {
                cell.clipsToBounds = false
            }
        default:
            return .unused
        }
        
        return cell
    }
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row < items.count else {
            return
        }
        
        let item = items[indexPath.row]
        
        if case .loading(let inProgress) = item {
            if !inProgress {
                items[indexPath.row] = .loading(true)
                channelPresenter?.loadNext()
            }
        } else if let message = item.message {
            willDisplay(cell: cell, at: indexPath, message: message)
        }
    }
    
    open func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MessageTableViewCell {
            cell.free()
        }
    }
    
    open func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = items[indexPath.row]
        let currentMessage = item.message
        let metadata = item.message?.extraData?.object as? MessageMetadataInfo
        let alreadyReceivedRealTopicMessage = items.firstIndex { (item) -> Bool in
            if let metatada = item.message?.extraData?.object as? MessageMetadataInfo, let threadId = metatada.joylabs.thread_id {
                return threadId == currentMessage?.id
            }
            return false
        }
        
        if let isTopic = metadata?.joylabs.isTopicMessage, isTopic, alreadyReceivedRealTopicMessage == nil {
             return UITableView.automaticDimension
        } else {
            if let message = item.message, message.replyCount > 0 || hiddenMessagesIds.contains(message.id)  {
                return 0
            }
        }
        return UITableView.automaticDimension
    }
}
