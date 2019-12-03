//
//  FirstViewController.swift
//  SheetPOC
//
//  Created by Lubo Klucka on 06/11/2019.
//  Copyright © 2019 Lubo Klucka. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {
    @IBOutlet weak var showListButton: UIButton!
    
    @IBAction func showListButtonPressed(_ sender: Any) {
        showFittedSheet()
    }
    
    func showFittedSheet() {
        guard let listVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ListViewController") as? ListViewController else { return }

        var sizes: [BottomSheetSize] = [.fixed(350), .fixed(550), .fullScreen]
        // for autosizing sheet, sizes should be empty
        sizes = []
        
        let sheetController = BottomSheetController(controller: listVC, sizes: sizes)
        sheetController.topCornersRadius = 10
        sheetController.didDismiss = { _ in
            print("Did dismiss")
        }
        
        self.present(sheetController, animated: false, completion: nil)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
