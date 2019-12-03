//
//  ListViewController.swift
//  SheetPOC
//
//  Created by Lubo Klucka on 06/11/2019.
//  Copyright © 2019 Lubo Klucka. All rights reserved.
//

import UIKit

class ListViewController: UIViewController, BottomSheetDisplayable {
    var childViewDidLoad: ((CGFloat, UIScrollView) -> Void)?
    
    private var contentHeight: CGFloat {
        return tableView.contentSize.height
    }
    
    let dataSource = ["Item", "Item", "Item", "Item", "Item", "Item", "Item"
        , "Item", "Item", "Item", "Item", "Item", "Item", "Item", "Item", "Item", "Item", "Item", "Item", "Item", "Item"
    ]
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func dismissButtonPressed(_ sender: Any) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.reloadData()
        
        childViewDidLoad?(contentHeight, self.tableView)
    }
}

extension ListViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else { fatalError() }
        cell.textLabel?.text = dataSource[indexPath.row]
        cell.backgroundColor = .clear
        return cell
    }
}
