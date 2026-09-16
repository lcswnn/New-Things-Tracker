import UIKit

class StatsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "FogBackground")

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Your Year in Firsts"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Stats coming soon"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.45)
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -16),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
        ])
    }
}
