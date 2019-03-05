//
//  InfiniteCollectionView.swift
//  InfiniteLayout
//
//  Created by Arnaud Dorgans on 20/12/2017.
//

import UIKit

open class InfiniteLayout: UICollectionViewFlowLayout {
    
    public var velocityMultiplier: CGFloat = 1 // used to simulate paging
    
    private let multiplier: CGFloat = 100 // contentOffset multiplier
    
    private var contentSize: CGSize = .zero
    
    private var hasValidLayout: Bool = false
    
    @IBInspectable public var isEnabled: Bool = true {
        didSet {
            self.invalidateLayout()
        }
    }
    
    public var currentPage: CGPoint {
        guard let collectionView = self.collectionView else {
            return .zero
        }
        return self.page(for: collectionView.contentOffset)
    }
    
    public var delegate: UICollectionViewDelegateFlowLayout? {
        guard let delegate = self.collectionView?.delegate as? UICollectionViewDelegateFlowLayout else {
            return nil
        }
        return delegate
    }
    
    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    public convenience init(layout: UICollectionViewLayout) {
        self.init()
        guard let layout = layout as? UICollectionViewFlowLayout else {
            return
        }
        self.scrollDirection = layout.scrollDirection
        self.minimumLineSpacing = layout.minimumLineSpacing
        self.minimumInteritemSpacing = layout.minimumInteritemSpacing
        self.itemSize = layout.itemSize
        self.sectionInset = layout.sectionInset
        self.headerReferenceSize = layout.headerReferenceSize
        self.footerReferenceSize = layout.footerReferenceSize
    }
    
    static var minimumContentSize: CGFloat {
        return max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 4
    }
    
    override open func prepare() {
        let collectionViewContentSize = super.collectionViewContentSize
        self.contentSize = CGSize(width: collectionViewContentSize.width, height: collectionViewContentSize.height)
        self.hasValidLayout = {
            guard let collectionView = self.collectionView, collectionView.bounds != .zero, self.isEnabled else {
                return false
            }
            return (scrollDirection == .horizontal ? self.contentSize.width : self.contentSize.height) >=
                InfiniteLayout.minimumContentSize
        }()
        super.prepare()
    }
    
    override open var collectionViewContentSize: CGSize {
        guard hasValidLayout else {
            return self.contentSize
        }
        return CGSize(width: scrollDirection == .horizontal ? self.contentSize.width * multiplier : self.contentSize.width,
                      height: scrollDirection == .vertical ? self.contentSize.height * multiplier : self.contentSize.height)
    }
    
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath) else {
            return nil
        }
        return self.layoutAttributes(from: attributes, page: currentPage)
    }
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard hasValidLayout else {
            return super.layoutAttributesForElements(in: rect)
        }
        let page = self.page(for: rect.origin)
        var elements = [UICollectionViewLayoutAttributes]()
        var rect = self.rect(from: rect)
        if (self.scrollDirection == .horizontal && rect.maxX > contentSize.width) ||
            (self.scrollDirection == .vertical && rect.maxY > contentSize.height) {
            let diffRect = CGRect(origin: .zero, size: CGSize(width: self.scrollDirection == .horizontal ? rect.maxX - contentSize.width : rect.width,
                                                              height: self.scrollDirection == .vertical ? rect.maxY - contentSize.height : rect.height))
            elements.append(contentsOf: self.elements(in: diffRect, page: self.page(from: page, offset: 1)))
            if self.scrollDirection == .horizontal {
                rect.size.width -= diffRect.width
            } else {
                rect.size.height -= diffRect.height
            }
        }
        elements.append(contentsOf: self.elements(in: rect, page: page))
        return elements
    }
    
    private func page(for point: CGPoint) -> CGPoint {
        let xPage: CGFloat = floor(point.x / contentSize.width)
        let yPage: CGFloat = floor(point.y / contentSize.height)

        return CGPoint(x: self.scrollDirection == .horizontal ? xPage : 0,
                       y: self.scrollDirection == .vertical ? yPage : 0)
    }
    
    private func page(from page: CGPoint, offset: CGFloat) -> CGPoint {
        return CGPoint(x: self.scrollDirection == .horizontal ? page.x + offset : page.x,
                       y: self.scrollDirection == .vertical ? page.y + offset : page.y)
    }
    
    private func pageIndex(from page: CGPoint) -> CGFloat {
        return self.scrollDirection == .horizontal ? page.x : page.y
    }
    
    public func rect(from rect: CGRect, page: CGPoint = .zero) -> CGRect {
        var rect = rect
        if self.scrollDirection == .horizontal && rect.origin.x < 0 {
            rect.origin.x += abs(floor(contentSize.width / rect.origin.x)) * contentSize.width
        } else if self.scrollDirection == .vertical && rect.origin.y < 0 {
            rect.origin.y += abs(floor(contentSize.height / rect.origin.y)) * contentSize.height
        }
        rect.origin.x = rect.origin.x.truncatingRemainder(dividingBy: contentSize.width)
        rect.origin.y = rect.origin.y.truncatingRemainder(dividingBy: contentSize.height)
        rect.origin.x += page.x * contentSize.width
        rect.origin.y += page.y * contentSize.height
        return rect
    }
    
    private func elements(in rect: CGRect, page: CGPoint) -> [UICollectionViewLayoutAttributes] {
        let rect = self.rect(from: rect)
        let elements = super.layoutAttributesForElements(in: rect)?
            .map { self.layoutAttributes(from: $0, page: page) }
            .filter { $0 != nil }
            .map { $0! } ?? []
        return elements
    }
    
    private func layoutAttributes(from layoutAttributes: UICollectionViewLayoutAttributes, page: CGPoint) -> UICollectionViewLayoutAttributes! {
        guard let attributes = self.copyLayoutAttributes(layoutAttributes) else {
            return nil
        }
        attributes.frame = rect(from: attributes.frame, page: page)
        return attributes
    }
    
    // MARK: Loop
    private func updateContentOffset(_ offset: CGPoint) {
        guard let collectionView = self.collectionView else {
            return
        }
        collectionView.contentOffset = offset
        collectionView.layoutIfNeeded()
    }
    private func preferredContentOffset(forContentOffset contentOffset: CGPoint) -> CGPoint {
        return rect(from: CGRect(origin: contentOffset, size: .zero), page: self.page(from: .zero, offset: multiplier / 2)).origin
    }
    
    public func loopCollectionViewIfNeeded() {
        guard let collectionView = self.collectionView, self.hasValidLayout else {
            return
        }
        let page = self.pageIndex(from: self.page(for: collectionView.contentOffset))
        let offset = self.preferredContentOffset(forContentOffset: collectionView.contentOffset)
        if (page < 2 || page > self.multiplier - 2) && collectionView.contentOffset != offset {
            self.updateContentOffset(offset)
        }
    }
    
    // MARK: Paging
    public func collectionViewRect() -> CGRect? {
        guard let collectionView = self.collectionView else {
            return nil
        }
        let margins = UIEdgeInsets(top: collectionView.contentInset.top + collectionView.layoutMargins.top,
                                   left: collectionView.contentInset.left + collectionView.layoutMargins.left,
                                   bottom: collectionView.contentInset.bottom + collectionView.layoutMargins.bottom,
                                   right: collectionView.contentInset.right + collectionView.layoutMargins.right)
        
        var visibleRect = CGRect()
        visibleRect.origin.x = margins.left
        visibleRect.origin.y = margins.top
        visibleRect.size.width = collectionView.bounds.width - visibleRect.origin.x - margins.right
        visibleRect.size.height = collectionView.bounds.height - visibleRect.origin.y - margins.bottom
        return visibleRect
    }
    
    public func visibleCollectionViewRect() -> CGRect? {
        guard let collectionView = self.collectionView,
            var collectionViewRect = self.collectionViewRect() else {
                return nil
        }
        collectionViewRect.origin.x += collectionView.contentOffset.x
        collectionViewRect.origin.y += collectionView.contentOffset.y
        return collectionViewRect
    }
    
    public func visibleLayoutAttributes(at offset: CGPoint? = nil) -> [UICollectionViewLayoutAttributes] {
        guard let collectionView = self.collectionView else {
            return []
        }
        return (self.layoutAttributesForElements(in: CGRect(origin: offset ?? collectionView.contentOffset, size: collectionView.frame.size)) ?? [])
            .sorted(by: { lhs, rhs in
                guard let lhs = self.centeredContentOffset(forLayoutAttributes: lhs) else {
                    return false
                }
                guard let rhs = self.centeredContentOffset(forLayoutAttributes: rhs) else {
                    return true
                }
                let value: (CGPoint)->CGFloat = {
                    return self.scrollDirection == .horizontal ? abs(collectionView.contentOffset.x - $0.x) : abs(collectionView.contentOffset.y - $0.y)
                }
                return value(lhs) < value(rhs)
            })
    }
    
    public func preferredVisibleLayoutAttributes(at offset: CGPoint? = nil, velocity: CGPoint = .zero, targetOffset: CGPoint? = nil, indexPath: IndexPath? = nil) -> UICollectionViewLayoutAttributes? {
        guard let currentOffset = self.collectionView?.contentOffset else {
            return nil
        }
        let direction: (CGPoint)->Bool = {
            return self.scrollDirection == .horizontal ? $0.x > currentOffset.x : $0.y > currentOffset.y
        }
        let velocity = self.scrollDirection == .horizontal ? velocity.x : velocity.y
        let targetDirection = direction(targetOffset ?? currentOffset)
        let attributes = self.visibleLayoutAttributes(at: offset)
        if let indexPath = indexPath,
            let attributes = attributes.first(where: { $0.indexPath == indexPath }) {
            return attributes
        }
        return attributes
            .first { attributes in
                guard let offset = self.centeredContentOffset(forLayoutAttributes: attributes) else {
                    return false
                }
                return direction(offset) == targetDirection || velocity == 0
        }
    }
    
    public func preferredVisibleLayoutAttributesForNearbyCenter() -> [UICollectionViewLayoutAttributes]? {
        let visibleLayoutAttributes = self.visibleLayoutAttributes().sorted { self.scrollDirection == .horizontal ? ($0.frame.minX < $1.frame.minX) : ($0.frame.minY < $1.frame.minY) }
        guard !visibleLayoutAttributes.isEmpty, (visibleLayoutAttributes.count % 2) == 0 else { return nil }
        var attributes = [UICollectionViewLayoutAttributes]()
        let baseValue = (visibleLayoutAttributes.count / 2)
        attributes.append(visibleLayoutAttributes[(baseValue - 1)])
        attributes.append(visibleLayoutAttributes[baseValue])
        return attributes
    }
    
    func centeredContentOffset(forLayoutAttributes layoutAttributes: UICollectionViewLayoutAttributes) -> CGPoint? {
        guard let collectionView = self.collectionView,
            let collectionRect = self.collectionViewRect() else {
                return nil
        }
        let offset = CGPoint(x: self.scrollDirection == .horizontal ? abs(layoutAttributes.frame.midX - collectionRect.origin.x - collectionRect.width/2) : collectionView.contentOffset.x,
                             y: self.scrollDirection == .vertical ? abs(layoutAttributes.frame.midY - collectionRect.origin.y - collectionRect.height/2) : collectionView.contentOffset.y)
        return self.alignOffset(offset, by: ((collectionView as? InfiniteCollectionView)?.preferredCenterAlignmentType ?? .center), using: layoutAttributes)
    }
    
    private func alignOffset(_ offset: CGPoint, by alignmentType: InfiniteLayoutCenterAlignmentType = .center, using layoutAttributes: UICollectionViewLayoutAttributes) -> CGPoint {
        var aligned = offset
        let alignValue = ((self.scrollDirection == .horizontal ? layoutAttributes.size.width : layoutAttributes.size.height) + self.actualMinimumLineSpacingForSection(at: layoutAttributes.indexPath.section)) * 0.5
        switch alignmentType {
        case .centerTop:
            aligned = CGPoint(x: offset.x, y: (offset.y + alignValue))
        case .centerLeft:
            aligned = CGPoint(x: (offset.x + alignValue), y: offset.y)
        case .centerBottom:
            aligned = CGPoint(x: offset.x, y: (offset.y - alignValue))
        case .centerRight:
            aligned = CGPoint(x: (offset.x - alignValue), y: offset.y)
        default:
            break
        }
        return aligned
    }
    
    public func centerCollectionView(withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let collectionView = self.collectionView, self.hasValidLayout else {
            return
        }
        let newTarget = CGPoint(x: self.scrollDirection == .horizontal ? collectionView.contentOffset.x + velocity.x * velocityMultiplier : targetContentOffset.pointee.x,
                                y: self.scrollDirection == .vertical ? collectionView.contentOffset.y + velocity.y * velocityMultiplier : targetContentOffset.pointee.y)
        
        guard let preferredAttributes = self.preferredVisibleLayoutAttributes(at: newTarget, velocity: velocity, targetOffset: targetContentOffset.pointee),
            let offset = self.centeredContentOffset(forLayoutAttributes: preferredAttributes) else {
                return
        }
        targetContentOffset.pointee = offset
    }
    
    public func centerCollectionViewIfNeeded(indexPath: IndexPath? = nil) {
        guard let collectionView = self.collectionView, self.hasValidLayout else {
            return
        }
        guard let preferredAttributes = self.preferredVisibleLayoutAttributes(indexPath: indexPath),
            let offset = self.centeredContentOffset(forLayoutAttributes: preferredAttributes),
            collectionView.contentOffset != offset else {
                return
        }
        self.updateContentOffset(offset)
    }
    
    // MARK: Copy
    public func copyLayoutAttributes(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes? {
        return attributes.copy() as? UICollectionViewLayoutAttributes
    }
    
    public func copyLayoutAttributes(from array: [UICollectionViewLayoutAttributes]) -> [UICollectionViewLayoutAttributes] {
        return array.map { self.copyLayoutAttributes($0) }
            .filter { $0 != nil }
            .map { $0! }
    }
    
    private func actualMinimumLineSpacingForSection(at section: Int) -> CGFloat {
        var minimumLineSpacing = self.minimumLineSpacing
        guard let collectionView = self.collectionView, let delegate = self.delegate else {
            return minimumLineSpacing
        }
        if let minimumLineSpacingForSection = delegate.collectionView?(collectionView, layout: self, minimumLineSpacingForSectionAt: section) {
            minimumLineSpacing = minimumLineSpacingForSection
        }
        return minimumLineSpacing
    }
}
