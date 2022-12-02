//
//  NoteView.swift
//  FlightPath
//
//  Created by kimstudent2 on 11/3/22.
//

import Foundation
import UIKit

// class for the notes' visual appearance
// A subclass of UIView that will be inserted into the scene in "Screen Space", that composes the note's visual appearance.
class NoteView: UIView {
    var textView: UITextView!
 
    //Convenience accessor to the NoteView's parent NoteEntity.
    weak var Note: NoteEntity!
    
    // Subviews which are used to construct the NoteView.
    var blurView: UIVisualEffectView!
    
    // Stores the most recent non-editing frame of the NoteView
    var lastFrame: CGRect!
    
    // Creates a NoteView given the specified frame and its associated NoteEntity.
    init(frame: CGRect, note: NoteEntity) {
        super.init(frame: frame)
        
        Note = note
        
        setupBlurViewContainer()
        setupTextView()
        
        lastFrame = frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func setupBlurViewContainer() {
        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(blurView)
        blurView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        blurView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        blurView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        blurView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        blurView.layer.cornerRadius = 20
        blurView.layer.masksToBounds = true
    }
    
    fileprivate func setupTextView() {
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            textView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
        ])
        textView.backgroundColor = .black
        textView.font = UIFont(name: "Helvetica", size: 17)
        textView.textAlignment = .natural
        textView.addDismissButton()
        textView.text = "New Annotation"
        textView.textColor = .darkGray
    }
}

