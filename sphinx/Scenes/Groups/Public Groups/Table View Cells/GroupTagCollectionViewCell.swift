//
//  GroupTagCollectionViewCell.swift
//  sphinx
//
//  Created by Tomas Timinskas on 19/05/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import UIKit

@MainActor protocol GroupTagCollectionViewCellDelegate: class {
    func didTapCloseButton(cell: UICollectionViewCell)
}

class GroupTagCollectionViewCell: UICollectionViewCell {
    
    weak var delegate: GroupTagCollectionViewCellDelegate?
    
    @IBOutlet weak var groupTagView: AddedTagsView!
    
    public static let kRightMargin:CGFloat = 16
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configureWith(
        tag: GroupsManager.Tag,
        delegate: GroupTagCollectionViewCellDelegate?
    ) {
        self.delegate = delegate
        
        groupTagView.configureWith(tag: tag, delegate: self)
    }
    
    public static func getWidthWith(description: String) -> CGFloat {
        return AddedTagsView.getWidthWith(description: description) + kRightMargin
    }
    
}

extension GroupTagCollectionViewCell : AddedTagsViewDelegate {
    func didTapCloseButton() {
        delegate?.didTapCloseButton(cell: self)
    }
}
