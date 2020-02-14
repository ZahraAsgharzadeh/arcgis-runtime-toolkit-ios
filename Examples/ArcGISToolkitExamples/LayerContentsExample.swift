//
// Copyright 2020 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGISToolkit
import ArcGIS

class LayerContentsExample: MapViewController {
    var layerContentsVC: LayerContentsViewController?
    var layerContentsButton = UIBarButtonItem()
    var segmentedControl = UISegmentedControl(items: ["Legend", "TOC", "Custom"])
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Legend button that will display the LayerContentsViewController.
        layerContentsButton = UIBarButtonItem(title: "Legend", style: .plain, target: self, action: #selector(showLayerContents))
        navigationItem.rightBarButtonItem = layerContentsButton

        // Create the map from a portal item and assign to the mapView.
        let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "16f1b8ba37b44dc3884afc8d5f454dd2")
        mapView.map = AGSMap(item: portalItem)
        mapView.map?.load { [weak self] (_) in
            self?.mapView.map?.basemap.baseLayers.forEach { ($0 as! AGSLayerContent).showInLegend = false }
        }
        
        // Create the LayerContentsViewController.
        layerContentsVC = LayerContentsViewController()
        layerContentsVC?.dataSource = DataSource(geoView: mapView)
        
        // Add a cancel button.
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        layerContentsVC?.navigationItem.leftBarButtonItem = doneButton
        
        segmentedControl.addTarget(self, action: #selector(segmentControlValueChanged), for: .valueChanged)
        view.addSubview(segmentedControl)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8.0),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8.0),
            segmentedControl.bottomAnchor.constraint(equalTo: mapView.attributionTopAnchor, constant: -8.0)
        ])
        segmentedControl.backgroundColor = UIColor.lightGray.withAlphaComponent(0.75)
        segmentedControl.selectedSegmentIndex = 0
    }
    
    @objc
    func showLayerContents() {
        if let layerContentsVC = layerContentsVC {
            // Display the layerContentsVC as a popover controller.
            layerContentsVC.modalPresentationStyle = .popover
            if let popoverPresentationController = layerContentsVC.popoverPresentationController {
                popoverPresentationController.delegate = self
                popoverPresentationController.barButtonItem = layerContentsButton
            }
            present(layerContentsVC, animated: true)
        }
    }
    
    @objc
    func done() {
        dismiss(animated: true)
    }
    
    @objc
    private func segmentControlValueChanged(_ sender: Any) {
        guard let control = sender as? UISegmentedControl else { return }
        if control.selectedSegmentIndex == 0 {
            struct Legend: LayerContentsConfiguration {
                public var layersStyle: ConfigurationStyle = .visibleLayersAtScale
                public var allowToggleVisibility: Bool = false
                public var allowLayersAccordion: Bool = false
                public var allowLayerReordering: Bool = false
                public var showSymbology: Bool = true
                public var respectInitialLayerOrder: Bool = false
                public var respectShowInLegend: Bool = true
                public var showRowSeparator: Bool = false
                public var title: String = "Legend"
            }
            layerContentsVC?.config = Legend()
//            layerContentsVC?.config = LayerContentsViewController.Legend()
        } else if control.selectedSegmentIndex == 1 {
            struct TableOfContents: LayerContentsConfiguration {
                public var layersStyle = ConfigurationStyle.allLayers
                public var allowToggleVisibility: Bool = true
                public var allowLayersAccordion: Bool = true
                public var allowLayerReordering: Bool = true
                public var showSymbology: Bool = true
                public var respectInitialLayerOrder: Bool = false
                public var respectShowInLegend: Bool = false
                public var showRowSeparator: Bool = true
                public var title: String = "Table of Contents"
            }
            layerContentsVC?.config = TableOfContents()
        } else if control.selectedSegmentIndex == 2 {
            struct CustomConfig: LayerContentsConfiguration {
                public var layersStyle: ConfigurationStyle = .visibleLayersAtScale
                public var allowToggleVisibility: Bool = true
                public var allowLayersAccordion: Bool = false
                public var allowLayerReordering: Bool = true
                public var showSymbology: Bool = false
                public var respectInitialLayerOrder: Bool = true
                public var respectShowInLegend: Bool = true
                public var showRowSeparator: Bool = false
                public var title: String = "Custom Configuration"
            }

            layerContentsVC?.config = CustomConfig()
        }
    }
}

extension LayerContentsExample: UIPopoverPresentationControllerDelegate {
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }
}
