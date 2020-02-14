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
import ArcGIS

/// Defines how to display layers in the table.
/// - Since: 100.8.0
public enum ConfigurationStyle {
    // Displays all layers.
    case allLayers
    // Only displays layers that are in scale and visible.
    case visibleLayersAtScale
}

/// Configuration is an protocol (interface) that drives how to format the layer contents table.
/// - Since: 100.8.0
public protocol LayerContentsConfiguration {
    /// Specifies the `ConfigurationStyle` applied to the table.
    var layersStyle: ConfigurationStyle { get }
    
    /// Specifies whether layer/sublayer cells will include a switch used to toggle visibility of the layer.
    var allowToggleVisibility: Bool { get }
    
    /// Specifies whether layer/sublayer cells will include a chevron used show/hide the contents of a layer/sublayer.
    var allowLayersAccordion: Bool { get }

    // Specifies whether to allow the user to reorder layers.
    var allowLayerReordering: Bool { get }

    /// Specifies whether layers/sublayers should show it's symbols.
    var showSymbology: Bool { get }
    
    /// Specifies whether to respect the layer order or to reverse the layer order supplied.
    /// If provided a geoView, the layer will include the basemap.
    /// - If `false`, the top layer's information appears at the top of the legend and the base map's layer information appears at the bottom of the legend.
    /// - If `true`, this order is reversed.
    var respectInitialLayerOrder: Bool { get }
    
    /// Specifies whether to respect `LayerConents.showInLegend` when deciding whether to include the layer.
    var respectShowInLegend: Bool { get }
    
    /// Specifies whether to include separators between layer cells.
    var showRowSeparator: Bool { get }
    
    /// The title of the view.
    var title: String { get }
}
//
///// Defines how to display layers in the table.
///// - Since: 100.8.0
//internal enum ContentType {
//    // An `AGSLayer`.
//    case layer
//    // A sublayer which implements `AGSLayerContent` but does not inherit from`AGSLayer`.
//    case sublayer
//    // An `AGSLegendInfo`.
//    case legendInfo
//}
//
//internal class Content {
//    let contentType: ContentType = .layer
//    let content: AnyObject?
//}

/// Describes a `LayerContentsViewController` for a list of Layers, possibly contained in a GeoView.
/// The `LayerContentsViewController` can be styled to that of a legend, table of contents or some custom derivative.
/// - Since: 100.8.0
public class LayerContentsViewController: UIViewController {
    /// Provide an out of the box TOC configuration.
    public struct TableOfContents: LayerContentsConfiguration {
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
    
    /// Provide an out of the box Legend configuration.
    public struct Legend: LayerContentsConfiguration {
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
    
    /// The `DataSource` specifying the list of `AGSLayerContent` to display.
    /// - Since: 100.8.0
    public var dataSource: DataSource? = nil {
        didSet {
            generateLayerList()
        }
    }
    
    /// The default configuration is a TOC. Setting a new configuration redraws the view.
    /// - Since: 100.8.0
    public var config: LayerContentsConfiguration = Legend() {
        didSet {
            layerContentsTableViewController?.config = config
            title = config.title
            generateLayerList()
        }
    }
    
    // The table view controller which displays the list of layers.
    private var layerContentsTableViewController: LayerContentsTableViewController?
    
    // Dictionary of legend infos; keys are AGSLayerContent objectIdentifier values.
    private var legendInfos = [UInt: [AGSLegendInfo]]()
    
    // Dictionary of symbol swatches (images); keys are the symbol used to create the swatch.
    private var symbolSwatches = [AGSSymbol: UIImage]()
    
    // The array of all layer contents to display in the table view.
    private var displayedLayers = [AGSLayerContent]()
    
    // The array of all contents (`AGSLayer`, `AGSLayerContent`, `AGSLegendInfo`) to display in the table view.
    private var contents = [AnyObject]()

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        // Get the bundle and then the storyboard
        let bundle = Bundle(for: LayerContentsTableViewController.self)
        let storyboard = UIStoryboard(name: "LayerContentsTableViewController", bundle: bundle)
        
        // Create the legend VC from the storyboard
        layerContentsTableViewController = storyboard.instantiateInitialViewController() as? LayerContentsTableViewController
        
        if let tableViewController = layerContentsTableViewController {
            // Setup our internal LayerContentsTableViewController and add it as a child.
            addChild(tableViewController)
            view.addSubview(tableViewController.view)
            tableViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tableViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                tableViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            tableViewController.didMove(toParent: self)
        }
        
        // Generate and set the layerContent list.
        generateLayerList()

        // Set the title to our config.title.
        title = config.title

        // Set the config on our newly-created tableViewController.
        layerContentsTableViewController?.config = config
    }
    
    /// Using the DataSource's `layercontents` as a starting point, generate the list of `AGSLayerContent` to include in the table view.
    private func generateLayerList() {
        // Remove all saved data.
        legendInfos.removeAll()
        symbolSwatches.removeAll()
        contents.removeAll()
        displayedLayers.removeAll()
        
        guard let layerContents = dataSource?.layerContents else { layerContentsTableViewController?.contents = [AnyObject](); return }
        
        // visibility
        // showInLegend
        // visible at scale (if we have a geoView)
        // reverse...
        
        // Reverse layerContents array if needed.
        displayedLayers = config.respectInitialLayerOrder ? layerContents : layerContents.reversed()
        
        // Filter out layers based on visibility and `showInLegend` flag (if `respectShowInLegend` is true).
        if config.layersStyle == .visibleLayersAtScale {
            displayedLayers = displayedLayers.filter { $0.isVisible &&
                (config.respectShowInLegend ? $0.showInLegend : true)
            }
        }
        
        // Load all displayed layers if we have any.
        displayedLayers.isEmpty ? updateContents() : displayedLayers.forEach { loadIndividualLayer($0) }
    }
    
    // Load an individual layer as AGSLayerContent.
    private func loadIndividualLayer(_ layerContent: AGSLayerContent) {
        if let layer = layerContent as? AGSLayer {
            // We have an AGSLayer, so make sure it's loaded.
            layer.load { [weak self] (_) in
                self?.loadSublayersOrLegendInfos(layerContent)
            }
        } else {
            // Not an AGSLayer, so just continue.
            loadSublayersOrLegendInfos(layerContent)
        }
    }
    
    // Load sublayers or legends.
    private func loadSublayersOrLegendInfos(_ layerContent: AGSLayerContent) {
        // This is the deepest level we can go and we're assured that
        // the AGSLayer is loaded for this layer/sublayer, so
        // set the contents changed handler.
        layerContent.subLayerContentsChangedHandler = { [weak self] () in
            DispatchQueue.main.async {
                self?.updateContents()
            }
        }

        // if we have sublayer contents, load those as well
        if !layerContent.subLayerContents.isEmpty {
            layerContent.subLayerContents.forEach { loadIndividualLayer($0) }
        } else {
            // fetch the legend infos
            layerContent.fetchLegendInfos { [weak self] (legendInfos, _) in
                // Store legendInfos and then update contents
                self?.legendInfos[LayerContentsViewController.objectIdentifierFor(layerContent)] = legendInfos
                self?.updateContents()
            }
        }
    }
    
    // Because of the loading mechanism and the fact that we need to store
    // our legend data in dictionaries, we need to update the array of legend
    // items once layers load.  Updating everything here will make
    // implementing the table view data source methods much easier.
    private func updateContents() {
        contents.removeAll()
        
        // filter any layers which are not visible or not showInLegend
        if config.layersStyle == .visibleLayersAtScale {
            displayedLayers = displayedLayers.filter { $0.isVisible &&
                (config.respectShowInLegend ? $0.showInLegend : true)
            }
        }
        
//        let legendLayers = displayedLayers.filter { $0.isVisible && (config.respectShowInLegend ? $0.showInLegend : true) }
        displayedLayers.forEach { (layerContent) in
            var showAtScale = true

            // If we're display only visible layers at scale,
            // make sure our layerContent is visible at the current scale.
            if config.layersStyle == .visibleLayersAtScale,
                let viewpoint = dataSource?.geoView?.currentViewpoint(with: .centerAndScale),
                !viewpoint.targetScale.isNaN {
                showAtScale = layerContent.isVisible(atScale: viewpoint.targetScale)
            }
            
            // if we're showing the layerContent, add it to our legend array
            if showAtScale {
                if let featureCollectionLayer = layerContent as? AGSFeatureCollectionLayer {
                    // only show Feature Collection layer if the sublayer count is > 1
                    // but always show the sublayers (the call to `updateLayerLegend`)
                    if featureCollectionLayer.layers.count > 1 {
                        contents.append(layerContent)
                    }
                } else {
                    contents.append(layerContent)
                }
                updateLayerLegend(layerContent)
            }
        }

        // Set the contents on the table view controller.
        layerContentsTableViewController?.contents = contents
    }
    
    // Handle subLayerContents and legend infos; this method assumes that
    // the incoming layerContent argument is visible and showInLegend == true.
    private func updateLayerLegend(_ layerContent: AGSLayerContent) {
        if !layerContent.subLayerContents.isEmpty {
            // filter any sublayers which are not visible or not showInLegend
            let sublayerContents = layerContent.subLayerContents.filter { $0.isVisible && $0.showInLegend }
            sublayerContents.forEach { (layerContent) in
                contents.append(layerContent)
                updateLayerLegend(layerContent)
            }
        } else {
            if let internalLegendInfos: [AGSLegendInfo] = legendInfos[LayerContentsViewController.objectIdentifierFor(layerContent as AnyObject)] {
                contents += internalLegendInfos
            }
        }
    }
    
    // MARK: - Utility
    
    // Returns a unique UINT for each object. Used because AGSLayerContent is not hashable
    // and we need to use it as the key in our dictionary of legendInfo arrays.
    private static func objectIdentifierFor(_ obj: AnyObject) -> UInt {
        return UInt(bitPattern: ObjectIdentifier(obj))
    }
}
