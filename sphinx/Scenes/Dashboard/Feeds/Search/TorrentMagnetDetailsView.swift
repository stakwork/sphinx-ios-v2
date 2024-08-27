//
//  TorrentMagnetDetailsView.swift
//  sphinx
//
//  Created by James Carucci on 8/26/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import UIKit

protocol TorrentMagnetDetailsViewDelegate{
    func didTapAddMagnet()
    func didTapCancelMagnet()
}

class TorrentMagnetDetailsView: UIView {
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var magnetDetailsLabel: UILabel!
    @IBOutlet weak var seederCountLabel: UILabel!
    @IBOutlet weak var magnetLinkLabel: UILabel!
    @IBOutlet weak var fileSizeLabel: UILabel!
    @IBOutlet weak var costToHostLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addMagnetButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    var delegate: TorrentMagnetDetailsViewDelegate? = nil
    
    var isLoading : Bool = false {
        didSet{
            if(isLoading){
                addMagnetButton.isUserInteractionEnabled = false
                addMagnetButton.backgroundColor = UIColor.Sphinx.SecondaryText
                magnetDetailsLabel.text = "Loading..."
                showActivityIndicator()
            }
            else{
                magnetDetailsLabel.text = "Magnet Details"
                addMagnetButton.isUserInteractionEnabled = true
                addMagnetButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
                hideActivityIndicator()
            }
            showOrHideLabels(shouldHide: isLoading)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        guard let view = loadViewFromNib() else { return }
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
        contentView = view
        
        styleView()
        
        // Additional setup code
    }
    
    private func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: "TorrentMagnetDetailsView", bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
    
    func styleView(){
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        contentView.layer.cornerRadius = 15
        
        addMagnetButton.layer.cornerRadius = addMagnetButton.frame.height / 2
        addMagnetButton.layer.borderColor = UIColor.Sphinx.PlaceholderText.cgColor
        addMagnetButton.layer.borderWidth = 1
        
        magnetDetailsLabel.font = UIFont(name: "Roboto-Bold", size: 24.0)
    }
    
    func populateLabels(
        magnetLink:String,
        detailsResponse:MagnetDetailsResponse
    ){
        nameLabel.attributedText = createAttributedString(boldPart: "Name:", regularPart: detailsResponse.details?.name ?? "Unknown")
        seederCountLabel.attributedText = createAttributedString(boldPart: "Seeders Count:", regularPart: "\(detailsResponse.seenPeers?.count ?? 0)")
        magnetLinkLabel.attributedText = createAttributedString(boldPart: "Link:", regularPart: magnetLink)
        costToHostLabel.attributedText = createAttributedString(boldPart: "Cost:", regularPart: "0 sats")
                
//        getCostOfInvoice(
//            magnetLink: magnetLink,
//            detailsResponse: detailsResponse,
//            completion: { intValue in
//                if let intValue = intValue{
//                    self.costToHostLabel.text = "Cost to Add:\(intValue) sats"
//                }
//                else{
//                    //throw alert
//                }
//            })
    }
    
    func getCostOfInvoice(
        magnetLink:String,
        detailsResponse:MagnetDetailsResponse,
        completion: @escaping (Int?) -> ()
    ){
        SphinxOnionManager.sharedInstance.getTorrentBolt11Cost(
            magnetLink: magnetLink,
            magnetDetails: detailsResponse,
            completion: { intValue in
                completion(intValue)
            })
    }
    
    private func createAttributedString(boldPart: String, regularPart: String) -> NSAttributedString {
        let boldAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
        
        let attributedString = NSMutableAttributedString(string: boldPart, attributes: boldAttributes)
        attributedString.append(NSAttributedString(string: " \(regularPart)", attributes: regularAttributes))
        
        return attributedString
    }
    
    func showOrHideLabels(shouldHide:Bool){
        let labels = [nameLabel,seederCountLabel,magnetLinkLabel,fileSizeLabel,costToHostLabel]
        for label in labels.compactMap({$0}){
            label.isHidden = shouldHide
        }
        fileSizeLabel.isHidden = true //override for now
    }
    
    func showActivityIndicator() {
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
            self.activityIndicator.isHidden = false
            print("Activity indicator should be visible and animating") // Debug print
        }
    }

    func hideActivityIndicator() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
        }
    }
    
    @IBAction func addMagnetTapped(_ sender: Any) {
        delegate?.didTapAddMagnet()
    }
    
    @IBAction func cancelMagnetTaped(_ sender: Any) {
        delegate?.didTapCancelMagnet()
    }
    
    
}
