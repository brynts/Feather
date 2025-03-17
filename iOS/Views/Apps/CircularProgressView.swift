import UIKit

class CircularProgressView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        let circularPath = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: bounds.width / 2.5,
            startAngle: -CGFloat.pi / 2,
            endAngle: CGFloat.pi * 1.5,
            clockwise: true
        )

        shapeLayer.path = circularPath.cgPath
        shapeLayer.strokeColor = UIColor.systemPurple.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 8
        shapeLayer.lineCap = .round
        shapeLayer.strokeEnd = 0.25 // Hanya sebagian yang berputar
        layer.addSublayer(shapeLayer)
        
        // Tambahkan ikon di tengah
        iconView.image = UIImage(systemName: "stop.fill") // Ganti sesuai ikon yang lo mau
        iconView.tintColor = UIColor.systemPurple
        iconView.contentMode = .scaleAspectFit
        iconView.frame = CGRect(x: bounds.midX - 12, y: bounds.midY - 12, width: 24, height: 24)
        addSubview(iconView)
        
        startAnimating()
    }
    
    func startAnimating() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 1
        rotation.repeatCount = .infinity
        layer.add(rotation, forKey: "rotation")
    }
}