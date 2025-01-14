//
//  UIView+.swift
//  Utilities
//
//  Created by Tung Nguyen on 13/10/2022.
//

import UIKit

public extension UIView {
    
    func boundInside(_ superView: UIView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        superView.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-0-[subview]-0-|",
            options: NSLayoutConstraint.FormatOptions(),
            metrics: nil,
            views: ["subview": self])
        )
        superView.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-0-[subview]-0-|",
            options: NSLayoutConstraint.FormatOptions(),
            metrics: nil,
            views: ["subview": self])
        )
    }
    
    func rounded(color: UIColor = .clear, width: CGFloat = 0.0, radius: CGFloat = 5.0) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = width
        self.layer.cornerRadius = radius
        self.clipsToBounds = true
    }
    
    func applyHorizontalGradient(with colours: [UIColor]) {
        let gradient = CAGradientLayer.getGradientLayer(
            with: self.bounds,
            colours: colours,
            locations: [0, 1],
            startPoint: CGPoint(x: 0.0, y: 0.5),
            endPoint: CGPoint(x: 1.0, y: 0.5)
        )
        self.layer.insertSublayer(gradient, at: 0)
    }
    
    func applyVerticalGradient(with colours: [UIColor]) {
        let gradient = CAGradientLayer.getGradientLayer(
            with: self.bounds,
            colours: colours,
            locations: [0, 1],
            startPoint: CGPoint(x: 0.5, y: 0.0),
            endPoint: CGPoint(x: 0.5, y: 1.0)
        )
        self.layer.insertSublayer(gradient, at: 0)
    }
    
    func applyTopRightBottomLeftGradient(with colours: [UIColor]) {
        let gradient = CAGradientLayer.getGradientLayer(
            with: self.bounds,
            colours: colours,
            locations: [0, 1],
            startPoint: CGPoint(x: 0.0, y: 0.0),
            endPoint: CGPoint(x: 1.0, y: 1.0)
        )
        self.layer.insertSublayer(gradient, at: 0)
    }
    
    func applyGradient(with colours: [UIColor]) {
        let gradient = CAGradientLayer.getGradientLayer(
            with: self.bounds,
            colours: colours,
            locations: [0, 1],
            startPoint: CGPoint(x: 0.5, y: 0.0),
            endPoint: CGPoint(x: 0.8, y: 1.0)
        )
        self.layer.insertSublayer(gradient, at: 0)
    }
    
    func removeSublayer(at index: Int) {
        guard let layers = self.layer.sublayers, layers.count > index else { return }
        layers[index].removeFromSuperlayer()
    }
    
    func rotate360Degrees(duration: CFTimeInterval = 1.0, completion: (() -> Void)? = nil) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat.pi * 2.0
        rotateAnimation.duration = duration
        
        self.layer.add(rotateAnimation, forKey: nil)
        CATransaction.commit()
    }
    
    func toImage() -> UIImage? {
        let rect = self.bounds
        
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        self.layer.render(in: context!)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func addShadow(
        color: UIColor = UIColor(red: 12.0/255, green: 0, blue: 51.0/255, alpha: 0.1),
        offset: CGSize = CGSize(width: 1, height: 2),
        opacity: Float = 0.16,
        radius: CGFloat = 1
    ) {
        self.layer.shadowColor = color.cgColor
        self.layer.shadowOffset = offset
        self.layer.shadowOpacity = opacity
        self.layer.shadowRadius = radius
        self.layer.masksToBounds = false
        self.layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        self.layer.shouldRasterize = true
        self.layer.rasterizationScale = UIScreen.main.scale
    }
    
    func startRotating(duration: Double = 1) {
        let kAnimationKey = "rotation"
        if self.layer.animation(forKey: kAnimationKey) == nil {
            let animate = CABasicAnimation(keyPath: "transform.rotation")
            animate.duration = duration
            animate.repeatCount = Float.infinity
            animate.fromValue = 0.0
            animate.toValue = CGFloat.pi * 2.0
            self.layer.add(animate, forKey: kAnimationKey)
        }
    }
    
    func stopRotating() {
        let kAnimationKey = "rotation"
        if self.layer.animation(forKey: kAnimationKey) != nil {
            self.layer.removeAnimation(forKey: kAnimationKey)
        }
    }
    
    func underlined(
        lineHeight: CGFloat,
        color: UIColor,
        isAlignLeft: Bool,
        width: CGFloat,
        bottom: CGFloat = 20.0
    ) {
        let border = CALayer()
        border.borderColor = color.cgColor
        let x: CGFloat = isAlignLeft ? 0.0 : self.frame.size.width - width
        border.frame = CGRect(
            x: x,
            y: self.frame.size.height + bottom - lineHeight,
            width: width,
            height: lineHeight
        )
        border.borderWidth = lineHeight
        self.layer.addSublayer(border)
        self.layer.masksToBounds = true
    }
    
    func dashLine(width: CGFloat, color: UIColor) {
        let shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.lineWidth = width
        shapeLayer.lineDashPattern = [7, 3] // 7: length of dash, 3: length of gap between
        
        let path = CGMutablePath()
        let start = CGPoint(x: 0, y: self.frame.height / 2.0)
        let end = CGPoint(x: self.frame.width, y: self.frame.height / 2.0)
        path.addLines(between: [start, end])
        shapeLayer.path = path
        self.removeSublayer(at: 0)
        self.layer.insertSublayer(shapeLayer, at: 0)
    }
    
    func dropShadow(color: UIColor, opacity: Float = 0.5, offSet: CGSize, radius: CGFloat = 1, scale: Bool = true) {
        layer.masksToBounds = false
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offSet
        layer.shadowRadius = radius
        
        layer.shadowPath = UIBezierPath(rect: self.bounds).cgPath
        layer.shouldRasterize = true
        layer.rasterizationScale = scale ? UIScreen.main.scale : 1
    }
    
    func roundWithCustomCorner(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height:  radius))
        
        let maskLayer = CAShapeLayer()
        
        maskLayer.path = path.cgPath
        self.layer.mask = maskLayer
    }
    
    func shakeViewError() {
        self.layer.borderColor = UIColor(named: "textRedColor")!.cgColor
        self.layer.borderWidth = 1.0
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.07
        animation.repeatCount = 2
        animation.autoreverses = true
        animation.fromValue = NSValue(cgPoint: CGPoint(x: self.center.x - 10, y: self.center.y))
        animation.toValue = NSValue(cgPoint: CGPoint(x: self.center.x + 10, y: self.center.y))
        
        self.layer.add(animation, forKey: "position")
    }
    
    func removeError() {
        self.layer.borderColor = UIColor.clear.cgColor
        self.layer.borderWidth = 1.0
    }
    
    @IBInspectable var kn_borderColor: UIColor {
        get {
            let color = self.layer.borderColor ?? UIColor.white.cgColor
            return UIColor(cgColor: color) // not using this property as such
        }
        set {
            self.layer.borderColor = newValue.cgColor
        }
    }
    
    @IBInspectable var kn_borderWidth: CGFloat {
        get {
            return self.layer.borderWidth
        }
        set {
            self.layer.borderWidth = newValue
        }
    }
    
    @IBInspectable var kn_radius: CGFloat {
        get {
            return self.layer.cornerRadius
        }
        set {
            self.layer.cornerRadius = newValue
            self.rounded(cornerRadius: newValue)
        }
    }
    
    func rounded(cornerRadius: CGFloat) {
        self.layer.cornerRadius = cornerRadius
        self.layer.masksToBounds = true
    }
    
}
