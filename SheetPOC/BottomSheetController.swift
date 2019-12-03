//
//  BottomSheetController.swift
//  SheetPOC
//
//  Created by Lubo Klucka on 03/12/2019.
//  Copyright © 2019 Lubo Klucka. All rights reserved.
//

import UIKit

public protocol BottomSheetDisplayable: UIViewController {
    var childViewDidLoad: ((CGFloat, UIScrollView) -> Void)? { get set }
}

public enum BottomSheetSize {
    case fixed(CGFloat)
    case fullScreen
}

public class BottomSheetController: UIViewController {
    // MARK: - Public Properties
    public private(set) var childViewController: UIViewController!

    public var maxWidth: CGFloat = 540

    /// The color of the handle below the sheet. Default is a transparent black - UIColor(white: 0, alpha: 0.7).
    public var handleColor: UIColor = UIColor(white: 0.868, alpha: 1) {
        didSet {
            self.handleView.backgroundColor = self.handleColor
        }
    }

    /// If true, sheet may be dismissed by panning down or tapping on the background
    public var isDissmissable: Bool = true

    /// Adjust corner radius for the top corners
    public var topCornersRadius: CGFloat = 3 {
        didSet {
            guard isViewLoaded else { return }
            self.updateRoundedCorners()
        }
    }

    /// The color of the overlay below the sheet. Default is a transparent black - UIColor(white: 0, alpha: 0.7).
    public var backgroundOverlayColor: UIColor = UIColor(white: 0, alpha: 0.7) {
        didSet {
            if self.isViewLoaded && self.view?.window != nil {
                self.view.backgroundColor = self.backgroundOverlayColor
            }
        }
    }

    public var didDismiss: ((BottomSheetController) -> Void)?

    // MARK: - Private properties
    private let containerView = UIView()
    /// The view that can be pulled to resize a sheeet. This includes the background. To change the color of the bar, use `handleView` instead
    private let pullBarView = UIView()
    private let handleView = UIView()

    /// The current preferred container size
    private var containerSize: BottomSheetSize?
    /// The current preferred container size
    private var containerHeight: CGFloat {
        return self.height(for: containerSize)
    }
    
    /// The current actual container size
    private var actualContainerSize: BottomSheetSize?
    /// The array of sizes we are trying to pin to when resizing the sheet. To set, use `setSizes` function
    private var orderedSheetSizes: [BottomSheetSize] = []

    private var panGestureRecognizer: UIPanGestureRecognizer!
    /// The child view controller's scroll view we are watching so we can override the pull down/up to work on the sheet when needed
    private weak var childScrollView: UIScrollView?

    private var containerHeightConstraint: NSLayoutConstraint!
    private var containerWidthConstraint: NSLayoutConstraint!
    private var containerBottomConstraint: NSLayoutConstraint!
    
    private var childContentHeight: CGFloat = 0
    private var firstPanPoint: CGPoint = CGPoint.zero
    
    private var handleSize: CGSize = CGSize(width: 50, height: 6)
    private var handleTopEdgeInset: CGFloat = 9
    private var handleBottomEdgeInset: CGFloat = 9

    private var safeAreaInsets: UIEdgeInsets {
        var insets = UIEdgeInsets.zero
        insets = UIApplication.shared.keyWindow?.safeAreaInsets ?? insets
        insets.top = max(insets.top, 20)
        return insets
    }

    // MARK: - Init
    @available(*, deprecated, message: "Use the init(controller:, sizes:) initializer")
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    /// Initialize the sheet view controller with a child. This is the only initializer that will function properly.
    public convenience init(controller: BottomSheetDisplayable, sizes: [BottomSheetSize] = []) {
        self.init(nibName: nil, bundle: nil)
        self.childViewController = controller
        if sizes.count > 0 {
            self.setSizes(sizes, animated: false)
        }
        controller.childViewDidLoad = { (height, scrollView) -> Void in
            self.childContentHeight = height
            self.handleScrollView(scrollView)
        }
        self.modalPresentationStyle = .overFullScreen
    }

    // MARK: - UIViewController lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()

        if (self.childViewController == nil) {
            fatalError("SheetViewController requires a child view controller")
        }
                
        self.view.backgroundColor = UIColor.clear
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isDissmissable {
            self.setUpDismissView()
        }
        self.setUpContainerView()

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        self.containerView.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
        self.panGestureRecognizer = panGestureRecognizer

        self.setUpPullBarView()
        self.setUpChildViewController()
        self.updateRoundedCorners()

        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: { [weak self] in
            guard let self = self else { return }
            self.view.backgroundColor = self.backgroundOverlayColor
            self.containerView.transform = CGAffineTransform.identity
            self.actualContainerSize = .fixed(self.containerView.frame.height)
        }, completion: nil)
    }

    /// Change the sizes the sheet should try to pin to
    public func setSizes(_ sizes: [BottomSheetSize], animated: Bool = true) {
        guard sizes.count > 0 else {
            return
        }
        self.orderedSheetSizes = sizes.sorted(by: { self.height(for: $0) < self.height(for: $1) })

        self.resize(to: sizes[0], animated: animated)
    }

    public func resize(to size: BottomSheetSize, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: { [weak self] in
                guard let self = self, let constraint = self.containerHeightConstraint else { return }
                constraint.constant = self.height(for: size)
                self.view.layoutIfNeeded()
            }, completion: nil)
        } else {
            self.containerHeightConstraint?.constant = self.height(for: size)
        }
        self.containerSize = size
        self.actualContainerSize = size
    }

    private func setUpOverlay() {
        let overlay = UIView(frame: CGRect.zero)
        overlay.backgroundColor = self.backgroundOverlayColor

        overlay.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leftAnchor.constraint(equalTo: view.leftAnchor),
            overlay.rightAnchor.constraint(equalTo: view.rightAnchor),
            view.bottomAnchor.constraint(equalTo: overlay.bottomAnchor)
        ])
    }

    private func setUpContainerView() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(containerView)

        self.containerBottomConstraint = view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        self.containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: containerHeight)
        self.containerHeightConstraint.priority = UILayoutPriority(900)

        let width = self.view.frame.width > maxWidth ? maxWidth : self.view.frame.width
        self.containerWidthConstraint = containerView.widthAnchor.constraint(equalToConstant: width)
        self.containerWidthConstraint.priority = UILayoutPriority(900)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: self.safeAreaInsets.top + 20),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            self.containerBottomConstraint,
            self.containerHeightConstraint,
            self.containerWidthConstraint
        ])

        self.containerView.layer.masksToBounds = true
        self.containerView.backgroundColor = UIColor.clear
        self.containerView.transform = CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.height)
    }

    private func setUpChildViewController() {
        self.childViewController.willMove(toParent: self)
        self.addChild(self.childViewController)

        self.childViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.addSubview(self.childViewController.view)
        NSLayoutConstraint.activate([
            childViewController.view.topAnchor.constraint(equalTo: pullBarView.bottomAnchor),
            childViewController.view.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            childViewController.view.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            containerView.bottomAnchor.constraint(equalTo: childViewController.view.bottomAnchor)
        ])

        self.childViewController.view.layer.masksToBounds = true
        self.childViewController.didMove(toParent: self)
    }

    /// Updates which view has rounded corners
    private func updateRoundedCorners() {
        let controllerWithRoundedCorners = self.childViewController.view
        let controllerWithoutRoundedCorners = self.containerView
        controllerWithRoundedCorners?.layer.maskedCorners = self.topCornersRadius > 0 ? [.layerMaxXMinYCorner, .layerMinXMinYCorner] : []
        controllerWithRoundedCorners?.layer.cornerRadius = self.topCornersRadius
        controllerWithoutRoundedCorners.layer.maskedCorners = []
        controllerWithoutRoundedCorners.layer.cornerRadius = 0
    }

    private func setUpDismissView() {
        let dismissAreaView = UIView(frame: CGRect.zero)
        dismissAreaView.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(dismissAreaView)
        NSLayoutConstraint.activate([
            dismissAreaView.topAnchor.constraint(equalTo: view.topAnchor),
            dismissAreaView.leftAnchor.constraint(equalTo: view.leftAnchor),
            dismissAreaView.rightAnchor.constraint(equalTo: view.rightAnchor),
            view.bottomAnchor.constraint(equalTo: dismissAreaView.bottomAnchor)
        ])

        dismissAreaView.backgroundColor = UIColor.clear
        dismissAreaView.isUserInteractionEnabled = true

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissTapped))
        dismissAreaView.addGestureRecognizer(tapGestureRecognizer)
    }

    private func setUpPullBarView() {
        self.pullBarView.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.addSubview(self.pullBarView)

        NSLayoutConstraint.activate([
            pullBarView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pullBarView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            pullBarView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
        ])

        handleView.translatesAutoresizingMaskIntoConstraints = false
        self.pullBarView.addSubview(handleView)

        NSLayoutConstraint.activate([
            handleView.topAnchor.constraint(equalTo: pullBarView.topAnchor, constant: handleTopEdgeInset),
            pullBarView.bottomAnchor.constraint(equalTo: handleView.bottomAnchor, constant: handleBottomEdgeInset),
            handleView.centerXAnchor.constraint(equalTo: pullBarView.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: handleSize.width),
            handleView.heightAnchor.constraint(equalToConstant: handleSize.height)
        ])

        pullBarView.layer.masksToBounds = true
        pullBarView.backgroundColor = UIColor.clear

        handleView.layer.cornerRadius = handleSize.height / 2.0
        handleView.layer.masksToBounds = true
        handleView.backgroundColor = self.handleColor

        if isDissmissable {
            pullBarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))
        }
    }

    @objc func dismissTapped() {
        self.closeSheet()
    }

    /// Animates the sheet to the closed state and then dismisses the view controller
    public func closeSheet(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: { [weak self] in
            self?.containerView.transform = CGAffineTransform(translationX: 0, y: self?.containerView.frame.height ?? 0)
            self?.view.backgroundColor = UIColor.clear
        }, completion: { [weak self] complete in
            self?.dismiss(animated: false, completion: completion)
        })
    }

    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag) {
            self.didDismiss?(self)
            completion?()
        }
    }

    @objc func panned(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.translation(in: gesture.view?.superview)
        if gesture.state == .began {
            self.firstPanPoint = point
            self.actualContainerSize = .fixed(self.containerView.frame.height)
        }

        let minHeight = self.height(for: self.orderedSheetSizes.first)
        let maxHeight = self.height(for: self.orderedSheetSizes.last)

        var newHeight = max(0, self.height(for: self.actualContainerSize) + (self.firstPanPoint.y - point.y))
        var offset: CGFloat = 0
        if newHeight < minHeight {
            // IF new height is less than the last specified breakpoint size, start moving the sheet down, instead of resizing
            offset = minHeight - newHeight
            newHeight = minHeight
        }
        if newHeight > maxHeight {
            // Don't let the pan gesture resize the sheet above the maximum allowed height
            newHeight = maxHeight
        }

        if gesture.state == .cancelled || gesture.state == .failed {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
                self.containerView.transform = CGAffineTransform.identity
                self.containerHeightConstraint.constant = self.containerHeight
            }, completion: nil)
        } else if gesture.state == .ended {
            let velocity = gesture.velocity(in: self.view).y
            var finalHeight = newHeight - offset - velocity * 0.2

            if velocity > 2000 {
                // swiped hard, close the sheet
                finalHeight = -1
            }
            
            let animationDuration = TimeInterval((1 - abs(velocity/10000)) / 3)

            guard finalHeight >= (minHeight / 2) || !isDissmissable else {
                // Dismiss
                self.dismissSheet(duration: animationDuration)
                return
            }

            self.containerSize = self.sheetSizeToMoveTo(movingBy: point.y)
            self.resizeSheet(duration: animationDuration)
        } else {
            self.containerHeightConstraint.constant = newHeight
            self.containerView.layoutIfNeeded()

            if offset > 0 && isDissmissable {
                self.containerView.transform = CGAffineTransform(translationX: 0, y: offset)
            } else {
                self.containerView.transform = CGAffineTransform.identity
            }
        }
    }
    
    private func sheetSizeToMoveTo(movingBy yPoints: CGFloat) -> BottomSheetSize? {
        let newHeight = height(for: actualContainerSize) - yPoints

        if newHeight > self.containerHeight {
            // going up
            return self.orderedSheetSizes.first(where: { height(for: $0) >= newHeight })
        } else if newHeight < self.containerHeight {
            // going down
            if let followingSmallerSize = self.orderedSheetSizes.first(where: { height(for: $0) <= newHeight }) {
                return followingSmallerSize
            }
        }
        
        return self.containerSize
    }
    
    private func resizeSheet(duration: TimeInterval) {
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut], animations: {
            self.containerView.transform = CGAffineTransform.identity
            self.containerHeightConstraint.constant = self.containerHeight
            self.view.layoutIfNeeded()
        }, completion: { [weak self] complete in
            guard let self = self else { return }
            self.actualContainerSize = .fixed(self.containerView.frame.height)
        })

    }

    private func dismissSheet(duration: TimeInterval) {
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut], animations: { [weak self] in
            self?.containerView.transform = CGAffineTransform(translationX: 0, y: self?.containerView.frame.height ?? 0)
            self?.view.backgroundColor = UIColor.clear
        }, completion: { [weak self] complete in
            self?.dismiss(animated: false, completion: nil)
        })
    }

    /// Handle a scroll view in the child view controller by watching for the offset for the scrollview and taking priority when at the top (so pulling up/down can grow/shrink the sheet instead of bouncing the child's scroll view)
    public func handleScrollView(_ scrollView: UIScrollView) {
        scrollView.panGestureRecognizer.require(toFail: panGestureRecognizer)
        self.childScrollView = scrollView

        // if self sizing
        if self.orderedSheetSizes.isEmpty {
            let sheetSize: BottomSheetSize = self.childContentHeight >= self.view.frame.height ? .fullScreen : .fixed(self.childContentHeight)
            self.orderedSheetSizes = [sheetSize]
            self.resize(to: sheetSize, animated: false)
        }
    }

    private func height(for size: BottomSheetSize?) -> CGFloat {
        guard let size = size else { return 0 }
        switch (size) {
            case .fixed(let height):
                return height
            case .fullScreen:
                return UIScreen.main.bounds.height - self.safeAreaInsets.top - 20
        }
    }
}

extension BottomSheetController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else { return true }
        // Allowing gesture recognition on a button seems to prevent it's events from firing properly sometimes
        return !(view is UIControl)
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer, let childScrollView = self.childScrollView else {
            return true
        }
        let initialTouchLocation = panGestureRecognizer.location(in: childViewController.view)
        let velocity = panGestureRecognizer.velocity(in: panGestureRecognizer.view?.superview)
        
/*
        IF scrolling down (moving finger up)
            IF sheet can expand
                return false
            ELSE
                return true
         
        ELSE scrolling up (moving finger down)
            IF child did scroll (with contentOffset.y != 0)
                IF pulling handle
                    return true
                ELSE
                    return false
            ELSE child did not scroll
                IF sheet can resize to smaller size or be dismissed
                    return true
                ELSE
                    return false
 */
        
        if velocity.y < 0 {
            return height(for: self.orderedSheetSizes.last) > containerHeight
        } else {
            if childScrollView.contentOffset.y != 0 {
                return initialTouchLocation.y <= self.pullBarView.frame.height
            } else {
                return height(for: self.orderedSheetSizes.first) < containerHeight || isDissmissable
            }
        }
    }
}
