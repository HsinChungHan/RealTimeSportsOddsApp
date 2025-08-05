//
//  MatchCell.swift
//  RealTimeSportsOddsApp
//
//  Created by Chung Han Hsin on 2025/8/5.
//

import UIKit

// MARK: - MatchCell
class MatchCell: UITableViewCell {
    static let identifier = "MatchCell"
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 2
        return view
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var matchLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var teamAOddsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGreen
        label.textAlignment = .center
        label.backgroundColor = .systemGreen.withAlphaComponent(0.1)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        return label
    }()
    
    private lazy var teamBOddsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.backgroundColor = .systemOrange.withAlphaComponent(0.1)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        return label
    }()
    
    private lazy var vsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "VS"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        
        [timeLabel, matchLabel, teamAOddsLabel, vsLabel, teamBOddsLabel].forEach {
            containerView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            timeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            timeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            timeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            matchLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 8),
            matchLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            matchLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            teamAOddsLabel.topAnchor.constraint(equalTo: matchLabel.bottomAnchor, constant: 12),
            teamAOddsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            teamAOddsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            teamAOddsLabel.widthAnchor.constraint(equalToConstant: 80),
            teamAOddsLabel.heightAnchor.constraint(equalToConstant: 32),
            
            vsLabel.centerYAnchor.constraint(equalTo: teamAOddsLabel.centerYAnchor),
            vsLabel.leadingAnchor.constraint(equalTo: teamAOddsLabel.trailingAnchor, constant: 8),
            vsLabel.widthAnchor.constraint(equalToConstant: 30),
            
            teamBOddsLabel.centerYAnchor.constraint(equalTo: teamAOddsLabel.centerYAnchor),
            teamBOddsLabel.leadingAnchor.constraint(equalTo: vsLabel.trailingAnchor, constant: 8),
            teamBOddsLabel.widthAnchor.constraint(equalToConstant: 80),
            teamBOddsLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    // MARK: - Configuration
    func configure(with matchWithOdds: MatchWithOdds) {
        let match = matchWithOdds.match
        let odds = matchWithOdds.odds
        
        // 格式化時間
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        timeLabel.text = formatter.string(from: match.startTime)
        
        // 設置隊伍資訊
        matchLabel.text = "\(match.teamA) vs \(match.teamB)"
        
        // 設置賠率
        if let odds = odds {
            teamAOddsLabel.text = String(format: "%.2f", odds.teamAOdds)
            teamBOddsLabel.text = String(format: "%.2f", odds.teamBOdds)
            teamAOddsLabel.alpha = 1.0
            teamBOddsLabel.alpha = 1.0
        } else {
            teamAOddsLabel.text = "載入中..."
            teamBOddsLabel.text = "載入中..."
            teamAOddsLabel.alpha = 0.5
            teamBOddsLabel.alpha = 0.5
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // 重置狀態
        timeLabel.text = nil
        matchLabel.text = nil
        teamAOddsLabel.text = nil
        teamBOddsLabel.text = nil
        teamAOddsLabel.alpha = 1.0
        teamBOddsLabel.alpha = 1.0
    }
}
