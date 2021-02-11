import Foundation
import UIKit


@objc public class ZarMeasureViewSW: UIView {

    // MARK: Public properties


    // MARK: Private properties

    // dummy text view for now
    private let sceneView = UITextView()


    // MARK: Class lifecycle methods

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    deinit {
    }

    private func commonInit() {
        sceneView.text = "Not implemented."
        sceneView.textColor = UIColor.black
        self.backgroundColor = UIColor.white
        
        add(view: sceneView)
     }
    

    // MARK: Public methods


    // MARK: Gesture handling

    public override func layoutSubviews() {
        super.layoutSubviews()
    }
}

// review if needed
private extension UIView {
    func add(view: UIView) {
//        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
//        let views = ["view": view]
//        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "|[view]|", options: [], metrics: nil, views: views)
//        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: [], metrics: nil, views: views)
//        self.addConstraints(hConstraints)
//        self.addConstraints(vConstraints)
    }
}
