/*
    Weave (Web-based Analysis and Visualization Environment)
    Copyright (C) 2008-2011 University of Massachusetts Lowell

    This file is a part of Weave.

    Weave is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License, Version 3,
    as published by the Free Software Foundation.

    Weave is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.visualization.tools
{
	import flash.events.Event;
	
	import mx.binding.utils.BindingUtils;
	import mx.containers.Canvas;
	import mx.containers.HBox;
	import mx.containers.VBox;
	import mx.controls.Label;
	import mx.core.UIComponent;
	import mx.skins.Border;
	
	import weave.Weave;
	import weave.api.copySessionState;
	import weave.api.core.ILinkableContainer;
	import weave.api.core.ILinkableHashMap;
	import weave.api.core.ILinkableObject;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.data.ISimpleGeometry;
	import weave.api.disposeObjects;
	import weave.api.getCallbackCollection;
	import weave.api.newLinkableChild;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IPlotLayer;
	import weave.api.ui.IPlotterWithGeometries;
	import weave.core.CallbackCollection;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableHashMap;
	import weave.core.LinkableString;
	import weave.core.UIUtils;
	import weave.core.weave_internal;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.data.AttributeColumns.FilteredColumn;
	import weave.data.KeySets.KeySet;
	import weave.ui.AutoResizingTextArea;
	import weave.ui.DraggablePanel;
	import weave.ui.LayerListComponent;
	import weave.ui.PenTool;
	import weave.ui.editors.SimpleAxisEditor;
	import weave.ui.editors.WindowSettingsEditor;
	import weave.utils.ColumnUtils;
	import weave.utils.ProbeTextUtils;
	import weave.visualization.layers.AxisLayer;
	import weave.visualization.layers.SelectablePlotLayer;
	import weave.visualization.layers.SimpleInteractiveVisualization;
	import weave.visualization.plotters.DynamicPlotter;

	/**
	 * A simple visualization is one with a single SelectablePlotLayer
	 * 
	 * @author adufilie
	 */
	public class SimpleVisTool extends DraggablePanel implements ILinkableContainer
	{
		public function SimpleVisTool()
		{
			// Don't put any code here.
			// Put code in the constructor() function instead.
		}

		override protected function constructor():void
		{
			super.constructor();
			
			// lock an InteractiveVisualization onto the panel
			_visualization = children.requestObject("visualization", SimpleInteractiveVisualization, true);
			
			_visualization.addEventListener(Event.RESIZE, handleVisualizationResize);
			function handleVisualizationResize(event:Event):void
			{
				invalidateDisplayList();
			}
			Weave.properties.axisFontSize.addGroupedCallback(this, updateTitleLabel);
			Weave.properties.axisFontColor.addGroupedCallback(this, updateTitleLabel, true);
		}

		public const enableTitle:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), handleTitleToggleChange, true);
		public const children:LinkableHashMap = newLinkableChild(this, LinkableHashMap);

		private var toolVBox:VBox; // simpleVisToolVBox contains titleLabel and visCanvas
		private var visTitle:AutoResizingTextArea; // For display of title inside the window area
		protected var visCanvas:Canvas; // For linkDisplayObjects
		private var _visualization:SimpleInteractiveVisualization;
		protected var layerListComponent:LayerListComponent;
		protected var simpleAxisEditor:SimpleAxisEditor;
		protected var windowSettingsEditor:WindowSettingsEditor;
		
		private var createdChildren:Boolean = false;
		override protected function createChildren():void
		{
			super.createChildren();
			
			if (createdChildren)
				return;
			
			toolVBox = new VBox()
			toolVBox.percentHeight = 100;
			toolVBox.percentWidth = 100;
			toolVBox.setStyle("verticalGap", 0);
			toolVBox.setStyle("horizontalAlign", "center");
			
			visTitle = new AutoResizingTextArea();
			visTitle.selectable = false;
			visTitle.editable = false;
			visTitle.setStyle('borderStyle', 'none');
			visTitle.setStyle('textAlign', 'center');
			visTitle.setStyle('fontWeight', 'bold');
			visTitle.setStyle('backgroundAlpha', 0);
			visTitle.percentWidth = 100;
			updateTitleLabel();
			
			visCanvas = new Canvas();
			visCanvas.percentHeight = 100;
			visCanvas.percentWidth = 100;
			toolVBox.addChild(visCanvas);
			
			UIUtils.linkDisplayObjects(visCanvas, children);
			
			var flexChildren:Array = getChildren();
			removeAllChildren();
			
			for ( var i:int = 0; i < flexChildren.length; i++ )
				visCanvas.addChild(flexChildren[i]);
			
			this.addChild(toolVBox);
			
			layerListComponent = new LayerListComponent();
			layerListComponent.visTool = this;
			layerListComponent.hashMap = visualization.layers;
			
			//TODO: hide axis controls when axis isn't enabled

			simpleAxisEditor = new SimpleAxisEditor();
			simpleAxisEditor.target = this;
			
			windowSettingsEditor = new WindowSettingsEditor();
			windowSettingsEditor.target = this;
			
			if (controlPanel)
				controlPanel.children = [layerListComponent, simpleAxisEditor, windowSettingsEditor];
			
			createdChildren = true;
		}
		
		override protected function childrenCreated():void
		{
			super.childrenCreated();
			
			BindingUtils.bindSetter(handleBindableTitle, this, 'title');
		}
		
		private function handleBindableTitle(value:String):void
		{
			visTitle.text = title;
		}
		private function updateTitleLabel():void
		{
			if (!parent)
				return callLater(updateTitleLabel);
			
			visTitle.setStyle("fontSize", Weave.properties.axisFontSize.value);
			visTitle.setStyle("color", Weave.properties.axisFontColor.value);
		}
		
		
		/**
		 * This function should be defined with override by subclasses.
		 * @return An Array of names corresponding to the objects returned by getSelectableAttributes().
		 */		
		public function getSelectableAttributeNames():Array
		{
			return [];
		}

		/**
		 * This function should be defined with override by subclasses.
		 * @return An Array of DynamicColumn and/or ILinkableHashMap objects that an AttributeSelectorPanel can link to.
		 */		
		public function getSelectableAttributes():Array
		{
			return [];
		}

		private function updateToolWindowSettings():void
		{
			creationPolicy = "all"; // this prevents ui components from being null in childrenCreated()
			horizontalScrollPolicy = "off";
			verticalScrollPolicy = "off";
		}
		
		private function handleTitleToggleChange():void
		{
			if (!parent)
			{
				callLater(handleTitleToggleChange);
				return;
			}
			if (!enableTitle.value)
			{
				if (toolVBox == visTitle.parent)
					toolVBox.removeChild(visTitle);
			}
			else
			{
				if (toolVBox != visTitle.parent)
					toolVBox.addChildAt(visTitle,0);
			}
		}
		
		private const MIN_TOOL_WIDTH:int  = 250;
		private const MIN_TOOL_HEIGHT:int = 250;
		
		// NOT WORKING YET -- the intention is to scale the things inside a tool if the size is below a certain value
		// this would scale the UI and vis
		override public function set width(value:Number):void
		{
			/*var scale:Number = calculateScale();
			
			if(scale < 1)
			{
				for each(var child:UIComponent in getChildren())
				{
					child.scaleX = scale;
					child.scaleY = scale;
				}
			}
			else
			{*/
				super.width = value;
			//}
		}
		override public function set height(value:Number):void
		{
			/*var scale:Number = calculateScale();
			
			if(scale < 1)
			{
				for each(var child:UIComponent in getChildren())
				{
					child.scaleX = scale;
					child.scaleY = scale;
				}
			}
			else
			{*/
				super.height = value;
			//}
		}
		private function calculateScale():Number
		{
			var childScale:Number = 1;
			for each(var child:UIComponent in getChildren())
			{
				var widthScale:Number  = Math.min(1, (child.width  / child.scaleX) / MIN_TOOL_WIDTH);
				var heightScale:Number = Math.min(1, (child.height / child.scaleY) / MIN_TOOL_HEIGHT);
				
				// if the width scale is the smallest so far, set the returned value to this
				if(widthScale < childScale)
					childScale = widthScale;
				// if the height scale is the smallest so far, set the returned value to this
				if(heightScale < childScale)
					childScale = heightScale;
			}
			
			return childScale;
		}
		
		public static function getDefaultColumnsOfMostCommonKeyType():Array
		{
			var probedColumns:Array = ProbeTextUtils.probedColumns.getObjects(IAttributeColumn);
			if (probedColumns.length == 0)
				probedColumns = ProbeTextUtils.probeHeaderColumns.getObjects(IAttributeColumn);
			
			var keyTypeCounts:Object = new Object();
			for each (var column:IAttributeColumn in probedColumns)
				keyTypeCounts[ColumnUtils.getKeyType(column)] = int(keyTypeCounts[ColumnUtils.getKeyType(column)]) + 1;
			var selectedKeyType:String = null;
			var count:int = 0;
			for (var keyType:String in keyTypeCounts)
				if (keyTypeCounts[keyType] > count)
					count = keyTypeCounts[selectedKeyType = keyType];
			
			// remove columns not of the selected key type
			var i:int = probedColumns.length;
			while (--i > -1)
				if (ColumnUtils.getKeyType(probedColumns[i]) != selectedKeyType)
					probedColumns.splice(i, 1);
			
			if (probedColumns.length == 0)
			{
				var filteredColumn:FilteredColumn = Weave.root.getObject(Weave.DEFAULT_COLOR_DATA_COLUMN) as FilteredColumn;
				if (filteredColumn.internalColumn)
					probedColumns.push(filteredColumn.internalColumn);
			}
			
			return probedColumns;
		}
		
		/**
		 * This function will return an array of IQualifiedKey objects which overlap
		 * the geometries of the layer specified by <code>layerName</code>.
		 * 
		 * @param layerName The name of the layer with the geometries used for the query.
		 */		
		public function getOverlappingQKeys(layerName:String):Array
		{
			var key:IQualifiedKey;
			var simpleGeometries:Array = [];
			var simpleGeometry:ISimpleGeometry;
			
			// First check the children to see if the specified layer is a penTool
			var penTool:PenTool = children.getObject(layerName) as PenTool;
			if (penTool)
			{
				return penTool.getOverlappingKeys();
			}
			
			// Otherwise, it's an IPlotLayer and go through it
			var layer:IPlotLayer = visualization.layers.getObject(layerName) as IPlotLayer;
			if (!layer)
				return [];
			
			var polygonPlotter:IPlotterWithGeometries = layer.plotter as IPlotterWithGeometries;
			if (!polygonPlotter && layer.plotter is DynamicPlotter)
			{
				polygonPlotter = (layer.plotter as DynamicPlotter).internalObject as IPlotterWithGeometries;
			}
			if (!polygonPlotter)
				return [];
			
			return visualization.getKeysOverlappingGeometry( polygonPlotter.getBackgroundGeometries() || [] );
		}
		
		/**
		 * This function will set the defaultSelectionKeySet to contain the keys
		 * which overlap the geometries specified by the layer called <code>layerName</code>.
		 * 
		 * @param layerName The name of the layer with the geometries used for the query.
		 */
		public function selectRecords(layerName:String):void
		{
			var keys:Array = getOverlappingQKeys(layerName);
			
			// set the selection keyset
			var selectionKeySet:KeySet = Weave.root.getObject(Weave.DEFAULT_SELECTION_KEYSET) as KeySet;
			selectionKeySet.replaceKeys(keys);
		}
		
		
		/**
		 * This function takes a list of dynamic column objects and
		 * initializes the internal columns to default ones.
		 */
		public static function initColumnDefaults(dynamicColumn:DynamicColumn, ... moreDynamicColumns):void
		{
			moreDynamicColumns.unshift(dynamicColumn);
			
			var probedColumns:Array = getDefaultColumnsOfMostCommonKeyType();
			for (var i:int = 0; i < moreDynamicColumns.length; i++)
			{
				var selectedColumn:ILinkableObject = probedColumns[i % probedColumns.length] as ILinkableObject;
				var columnToInit:DynamicColumn = moreDynamicColumns[i] as DynamicColumn;
				if (columnToInit.internalColumn == null)
				{
					if (selectedColumn is DynamicColumn)
						copySessionState(selectedColumn, columnToInit);
					else
						columnToInit.requestLocalObjectCopy(selectedColumn);
				}
			}
		}
		
		public function get showAxes():Boolean
		{
			return visualization.showAxes;
		}
		public function set showAxes(value:Boolean):void
		{
			visualization.showAxes = value;
		}
		
		[Inspectable]
		public function set plotterClass(classDef:Class):void
		{
			visualization.plotterClass = classDef;
		}
		
		protected function initDefaultPlotter(classDef:Class):*
		{
			visualization.plotterClass = classDef;
			return visualization.getDefaultPlotter();
		}

		protected function get plotLayer():SelectablePlotLayer
		{
			return visualization.getPlotLayer();
		}
		protected function get xAxisLayer():AxisLayer
		{
			return visualization.getXAxisLayer();
		}
		protected function get yAxisLayer():AxisLayer
		{
			return visualization.getYAxisLayer();
		}
		
		// returns the interactive visualization
		public function get visualization():SimpleInteractiveVisualization
		{
			return _visualization;
		}
		
		// UI children
		public function getLinkableChildren():ILinkableHashMap { return children; }
		
		override public function dispose():void
		{
			super.dispose();
		}
	}
}
