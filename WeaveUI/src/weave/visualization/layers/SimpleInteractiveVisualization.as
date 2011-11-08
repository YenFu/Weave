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

package weave.visualization.layers
{
	import flash.display.Stage;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	
	import mx.controls.ToolTip;
	import mx.core.Application;
	import mx.core.IToolTip;
	import mx.managers.ToolTipManager;
	
	import weave.Weave;
	import weave.WeaveProperties;
	import weave.api.WeaveAPI;
	import weave.api.core.ICallbackCollection;
	import weave.api.data.AttributeColumnMetadata;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IKeySet;
	import weave.api.getCallbackCollection;
	import weave.api.linkSessionState;
	import weave.api.newDisposableChild;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.api.ui.IPlotter;
	import weave.compiler.StandardLib;
	import weave.core.CallbackCollection;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.core.LinkableVariable;
	import weave.core.SessionManager;
	import weave.core.StageUtils;
	import weave.core.weave_internal;
	import weave.primitives.Bounds2D;
	import weave.ui.DraggablePanel;
	import weave.utils.BitmapText;
	import weave.utils.ColumnUtils;
	import weave.utils.CustomCursorManager;
	import weave.utils.SpatialIndex;
	import weave.visualization.plotters.ProbeLinePlotter;
	import weave.visualization.plotters.SimpleAxisPlotter;

	use namespace weave_internal;
	
	/**
	 * This is a container for a list of PlotLayers
	 * 
	 * @author adufilie
	 */
	public class SimpleInteractiveVisualization extends InteractiveVisualization
	{
		public function SimpleInteractiveVisualization()
		{
			super();
			init();
		}
		private function init():void
		{
			linkSessionState(Weave.properties.axisFontSize, axisFontSize);
			linkSessionState(Weave.properties.axisFontFamily, axisFontFamily);
			linkSessionState(Weave.properties.axisFontUnderline, axisFontUnderline);
			linkSessionState(Weave.properties.axisFontItalic, axisFontItalic);
			linkSessionState(Weave.properties.axisFontBold, axisFontBold);
			linkSessionState(Weave.properties.axisFontColor, axisFontColor);
		}

		public static const PROBE_LINE_LAYER_NAME:String = "probeLine";
		public static const X_AXIS_LAYER_NAME:String = "xAxis";
		public static const Y_AXIS_LAYER_NAME:String = "yAxis";
		public static const PLOT_LAYER_NAME:String = "plot";
		
		private var _probeLineLayer:PlotLayer ;
		private var _plotLayer:SelectablePlotLayer;
		private var _xAxisLayer:AxisLayer;
		private var _yAxisLayer:AxisLayer;

		public function getProbeLineLayer():PlotLayer { return _probeLineLayer; }
		public function getPlotLayer():SelectablePlotLayer { return _plotLayer; }
		public function getXAxisLayer():AxisLayer { return _xAxisLayer; }
		public function getYAxisLayer():AxisLayer { return _yAxisLayer; }
		public function getDefaultPlotter():IPlotter { return _plotLayer ? _plotLayer.getDynamicPlotter().internalObject as IPlotter : null; }
		
		public const enableAutoZoomXToNiceNumbers:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), updateZoom);
		public const enableAutoZoomYToNiceNumbers:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), updateZoom);
		
		public const axisFontFamily:LinkableString = registerLinkableChild(this, new LinkableString(WeaveProperties.DEFAULT_FONT_FAMILY, WeaveProperties.verifyFontFamily));
		public const axisFontBold:LinkableBoolean = newLinkableChild(this, LinkableBoolean);
		public const axisFontItalic:LinkableBoolean = newLinkableChild(this, LinkableBoolean);
		public const axisFontUnderline:LinkableBoolean = newLinkableChild(this, LinkableBoolean);
		public const axisFontSize:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const axisFontColor:LinkableNumber = newLinkableChild(this, LinkableNumber);
		
		public const gridLineThickness:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const gridLineColor:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const gridLineAlpha:LinkableNumber = newLinkableChild(this, LinkableNumber);
		
		public const axesThickness:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const axesColor:LinkableNumber = newLinkableChild(this, LinkableNumber);
		public const axesAlpha:LinkableNumber = newLinkableChild(this, LinkableNumber);
		
		[Inspectable] public function set plotterClass(classDef:Class):void
		{
			if (classDef && !_plotLayer)
			{
				_plotLayer = layers.requestObject(PLOT_LAYER_NAME, SelectablePlotLayer, true);
				_plotLayer.getDynamicPlotter().requestLocalObject(classDef, true);
				layers.addImmediateCallback(this, putAxesOnBottom, null, true);
			}
		}
		
		public function linkToAxisProperties(axisLayer:AxisLayer):void
		{
			if (layers.getName(axisLayer) == null)
				throw new Error("linkToAxisProperties(): given axisLayer is not one of this visualization's layers");
			var p:SimpleAxisPlotter = axisLayer.axisPlotter;
			var list:Array = [
				[axisFontFamily,     p.axisFontFamily],
				[axisFontBold,       p.axisFontBold],
				[axisFontItalic,     p.axisFontItalic],
				[axisFontUnderline,  p.axisFontUnderline],
				[axisFontSize,       p.axisFontSize],
				[axisFontColor,      p.axisFontColor],
				[gridLineThickness,  p.axisGridLineThickness],
				[gridLineColor,      p.axisGridLineColor],
				[gridLineAlpha,      p.axisGridLineAlpha],
				[axesThickness,  p.axesThickness],
				[axesColor,      p.axesColor],
				[axesAlpha,      p.axesAlpha]
			];
			for each (var pair:Array in list)
			{
				var var0:LinkableVariable = pair[0] as LinkableVariable;
				var var1:LinkableVariable = pair[1] as LinkableVariable;
				if (var0.isUndefined())
					linkSessionState(var1, var0);
				else
					linkSessionState(var0, var1);
				(WeaveAPI.SessionManager as SessionManager).removeLinkableChildFromSessionState(p, pair[1]);
			}
			//(WeaveAPI.SessionManager as SessionManager).removeLinkableChildrenFromSessionState(p, p.axisLineDataBounds);
		}

		
		public function get showAxes():Boolean
		{
			return _xAxisLayer != null;
		}
		public function set showAxes(value:Boolean):void
		{
			if (value && !_xAxisLayer)
			{
				// x
				_xAxisLayer = layers.requestObject(X_AXIS_LAYER_NAME, AxisLayer, true);
				_xAxisLayer.axisPlotter.axisLabelRelativeAngle.value = -45;
				_xAxisLayer.axisPlotter.labelVerticalAlign.value = BitmapText.VERTICAL_ALIGN_TOP;
				linkSessionState(marginBottom, _xAxisLayer.axisPlotter.labelWordWrapSize);
				
				linkToAxisProperties(_xAxisLayer);
				
				layers.addImmediateCallback(this, putAxesOnBottom, null, true);
				updateZoom();
				
				// y
				_yAxisLayer = layers.requestObject(Y_AXIS_LAYER_NAME, AxisLayer, true);
				_yAxisLayer.axisPlotter.axisLabelRelativeAngle.value = 45;
				_yAxisLayer.axisPlotter.labelVerticalAlign.value = BitmapText.VERTICAL_ALIGN_BOTTOM;
				linkSessionState(marginLeft, _yAxisLayer.axisPlotter.labelWordWrapSize);
				
				linkToAxisProperties(_yAxisLayer);
				
				layers.addImmediateCallback(this, putAxesOnBottom, null, true);
				updateZoom();
			}
		}
		
		private var tempPoint:Point = new Point(); // reusable temp object
		
		/**
		 * This function orders the layers from top to bottom in this order: 
		 * probe (probe lines), plot, yAxis, xAxis
		 */		
		public function putAxesOnBottom():void
		{
			var names:Array = layers.getNames();
			
			// remove axis layer names so they can be put in front.
			var i:int;
			for each (var name:String in [X_AXIS_LAYER_NAME, Y_AXIS_LAYER_NAME])
			{
				i = names.indexOf(name)
				if (i >= 0)
					names.splice(i, 1);
			}
			
			names.unshift(X_AXIS_LAYER_NAME); // default axes first
			names.unshift(Y_AXIS_LAYER_NAME); // default axes first
			names.push(PROBE_LINE_LAYER_NAME); // probe line layer last
			
			layers.setNameOrder(names);
		}
		
		override protected function updateFullDataBounds():void
		{
			getCallbackCollection(this).delayCallbacks();
			
			super.updateFullDataBounds();
			
			// adjust fullDataBounds based on auto zoom settings
			
			tempBounds.copyFrom(fullDataBounds);
			if(_xAxisLayer && enableAutoZoomXToNiceNumbers.value)
			{
				var xMinMax:Array = StandardLib.getNiceNumbersInRange(fullDataBounds.getXMin(), fullDataBounds.getXMax(), _xAxisLayer.axisPlotter.tickCountRequested.value);
				tempBounds.setXRange(xMinMax.shift(), xMinMax.pop()); // first & last ticks
			}
			if(_yAxisLayer && enableAutoZoomYToNiceNumbers.value)
			{
				var yMinMax:Array = StandardLib.getNiceNumbersInRange(fullDataBounds.getYMin(), fullDataBounds.getYMax(), _yAxisLayer.axisPlotter.tickCountRequested.value);
				tempBounds.setYRange(yMinMax.shift(), yMinMax.pop()); // first & last ticks
			}
			if ((_xAxisLayer || _yAxisLayer) && enableAutoZoomToExtent.value)
			{
				// if axes are enabled and dataBounds is undefined, set dataBounds to default size
				// if bounds is empty, make it not empty
				if (tempBounds.isEmpty())
				{
					if (tempBounds.getWidth() == 0)
						tempBounds.setWidth(1);
					if (tempBounds.getWidth() == 0)
						tempBounds.setXRange(0, 1);
					if (tempBounds.getHeight() == 0)
						tempBounds.setHeight(1);
					if (tempBounds.getHeight() == 0)
						tempBounds.setYRange(0, 1);
				}
			}
			if (!fullDataBounds.equals(tempBounds))
			{
				fullDataBounds.copyFrom(tempBounds);
				getCallbackCollection(this).triggerCallbacks();
			}
			
			getCallbackCollection(this).resumeCallbacks();
		}

		override protected function updateZoom():void
		{
			getCallbackCollection(this).delayCallbacks();
			getCallbackCollection(zoomBounds).delayCallbacks();
			
			super.updateZoom();
			
			// when the data bounds change, we need to update the min,max values for axes
			if (_xAxisLayer)
			{
				getCallbackCollection(_xAxisLayer).delayCallbacks(); // avoid recursive updateZoom() call until done setting session state
				zoomBounds.getDataBounds(tempBounds);
				tempBounds.yMax = tempBounds.yMin;
				_xAxisLayer.axisPlotter.axisLineDataBounds.copyFrom(tempBounds);
				_xAxisLayer.axisPlotter.axisLineMinValue.value = tempBounds.xMin;
				_xAxisLayer.axisPlotter.axisLineMaxValue.value = tempBounds.xMax;
				getCallbackCollection(_xAxisLayer).resumeCallbacks();
			}
			if (_yAxisLayer)
			{
				getCallbackCollection(_yAxisLayer).delayCallbacks(); // avoid recursive updateZoom() call until done setting session state
				zoomBounds.getDataBounds(tempBounds);
				tempBounds.xMax = tempBounds.xMin;
				_yAxisLayer.axisPlotter.axisLineDataBounds.copyFrom(tempBounds);
				_yAxisLayer.axisPlotter.axisLineMinValue.value = tempBounds.yMin;
				_yAxisLayer.axisPlotter.axisLineMaxValue.value = tempBounds.yMax;
				getCallbackCollection(_yAxisLayer).resumeCallbacks();
			}

			getCallbackCollection(zoomBounds).resumeCallbacks();
			getCallbackCollection(this).resumeCallbacks();
		}
		
		override protected function handleRollOut(event:MouseEvent):void
		{
			super.handleRollOut(event);
			
			if (_axisToolTip)
				ToolTipManager.destroyToolTip(_axisToolTip);
			_axisToolTip = null;
		}
		
		override protected function handleMouseClick(event:MouseEvent):void
		{
			super.handleMouseClick(event);
			
			if (mouseIsRolledOver)
			{
				zoomBounds.getScreenBounds(tempScreenBounds);
				
				// handle clicking above the visualization
				queryBounds.copyFrom(tempScreenBounds);
				queryBounds.setYRange(0, tempScreenBounds.getYNumericMin());
				if (queryBounds.contains(event.localX, event.localY))
					topMarginClickCallbacks.triggerCallbacks();

				// handle clicking below the visualization
				queryBounds.copyFrom(tempScreenBounds);
				queryBounds.setYRange(tempScreenBounds.getYNumericMax(), height);
				//queryBounds.yMin = queryBounds.yMax - (_xAxisLayer ? _xAxisLayer.axisPlotter.getLabelHeight() : 0);
				if (queryBounds.contains(event.localX, event.localY))
					bottomMarginClickCallbacks.triggerCallbacks();

				// handle clicking to the left of the visualization
				queryBounds.copyFrom(tempScreenBounds);
				queryBounds.setXRange(0, tempScreenBounds.getXNumericMin());
				//queryBounds.xMax =  queryBounds.xMax + (_yAxisLayer ? _yAxisLayer.axisPlotter.getLabelHeight() : 0);
				if (queryBounds.contains(event.localX, event.localY))
					leftMarginClickCallbacks.triggerCallbacks();

				// handle clicking to the right of the visualization
				queryBounds.copyFrom(tempScreenBounds);
				queryBounds.setXRange(tempScreenBounds.getXNumericMax(), width);
				if (queryBounds.contains(event.localX, event.localY))
					rightMarginClickCallbacks.triggerCallbacks();
			}
				
		}
		
		//private var _marginCallbackOffset:int = 10;
		
		public var enableXAxisProbing:Boolean = false;
		public var enableYAxisProbing:Boolean = false;
		
		private var _xAxisColumn:IAttributeColumn = null;
		public function setXAxisColumn(column:IAttributeColumn):void
		{
			_xAxisColumn = column;
		}
		private var _yAxisColumn:IAttributeColumn = null;
		public function setYAxisColumn(column:IAttributeColumn):void
		{
			_yAxisColumn = column;
		}
		
		
		
		
		private var _axisToolTip:IToolTip = null;
		override protected function handleMouseMove():void
		{
			super.handleMouseMove();
			
			
			if (mouseIsRolledOver)
			{
				if(_axisToolTip)
					ToolTipManager.destroyToolTip(_axisToolTip);
				_axisToolTip = null;

				
				if (!StageUtils.mouseEvent.buttonDown)
				{
					
					zoomBounds.getScreenBounds(tempScreenBounds);
				
					var ttPoint:Point;
					
					var stageWidth:int  = stage.stageWidth;
					var stageHeight:int = stage.stageHeight ; //stage.height returns incorrect values
					var createXTooltip:Boolean = false;
					var createYTooltip:Boolean = false;
					
					if(enableXAxisProbing)
					{
						// handle probing below the visualization
						queryBounds.copyFrom(tempScreenBounds);
						queryBounds.setYRange((tempScreenBounds.getYNumericMax() + height) / 2, height);
						//queryBounds.yMin = queryBounds.yMax - _xAxisLayer.axisPlotter.getLabelHeight();
						
						if(queryBounds.contains(StageUtils.mouseEvent.localX, StageUtils.mouseEvent.localY))
						{
							ttPoint = localToGlobal( new Point(queryBounds.getXCoverage()/2, queryBounds.getYMax()) ); 
											
							createXTooltip = true;
						}
					}
	
					if(enableYAxisProbing)
					{
						// handle probing on the left of the visualization
						queryBounds.copyFrom(tempScreenBounds);
						queryBounds.setXRange(0, (tempScreenBounds.getXNumericMin() + 0) / 2);
						//queryBounds.xMin =  queryBounds.xMax + _yAxisLayer.axisPlotter.getLabelHeight();
						
						if(queryBounds.contains(StageUtils.mouseEvent.localX,StageUtils.mouseEvent.localY))
						{
							ttPoint = localToGlobal(new Point(queryBounds.getXMax(), queryBounds.getYCoverage() / 2));
	
							createYTooltip = true;
						}						
					}
					
					
					// if we should be creating a tooltip
					if (createXTooltip || createYTooltip)
					{
						if (Weave.properties.enableToolControls.value)
							CustomCursorManager.showCursor(CustomCursorManager.LINK_CURSOR);

						var toolTip:String;
						
						// if we are creating the x tooltip and a column is specified for this axis, then show its keyType and dataSource
						if(createXTooltip && _xAxisColumn)
						{
							// by default, just show that you can click the axis to change attribute
							if (Weave.properties.enableToolControls.value)
								toolTip = "Click \"" + ColumnUtils.getTitle(_xAxisColumn) + "\" to select a different attribute. ";
							else
								toolTip = ColumnUtils.getTitle(_xAxisColumn);
							toolTip += "\n Key Type: "   + ColumnUtils.getKeyType(_xAxisColumn);
							toolTip += "\n # of Records: " + WeaveAPI.StatisticsCache.getCount(_xAxisColumn);
							toolTip += "\n Data Source:" + ColumnUtils.getDataSource(_xAxisColumn);
						}
						// otherwise show this for the y axis
						else if(createYTooltip && _yAxisColumn)
						{
							if (Weave.properties.enableToolControls.value)
								toolTip = "Click \"" + ColumnUtils.getTitle(_yAxisColumn) + "\" to select a different attribute. ";
							else
								toolTip = ColumnUtils.getTitle(_yAxisColumn);
							toolTip += "\n Key Type: "   + ColumnUtils.getKeyType(_yAxisColumn);
							toolTip += "\n # of Records: " + WeaveAPI.StatisticsCache.getCount(_yAxisColumn);
							toolTip += "\n Data Source:" + ColumnUtils.getDataSource(_yAxisColumn);
						}
						
						// create the actual tooltip
						_axisToolTip = ToolTipManager.createToolTip(toolTip, ttPoint.x, ttPoint.y);
						
						// constrain the tooltip to fall within the bounds of the application											
						_axisToolTip.x = Math.max( 0, Math.min(_axisToolTip.x, (stageWidth  - _axisToolTip.width) ) );
						_axisToolTip.y = Math.max( 0, Math.min(_axisToolTip.y, (stageHeight - _axisToolTip.height) ) );
					}
				}
			}
		}
		
		/**
		 * a ProbeLinePlotter instance for the probe line layer 
		 */		
		private var _probePlotter:ProbeLinePlotter = null ;
		
		/**
		 * This function should be called by a tool to initialize a probe line layer and its ProbeLinePlotter
		 * @param xAxisToPlot set to true if xAxis needs a probe line and tooltip
		 * @param yAxisToPlot set to true if yAxis needs a probe line and tooltip
		 * @param labelFunction optional function to convert number values to string 
		 * @param labelFunctionX optional function to convert xAxis number values to string
		 */	
		public function enableProbeLine(xAxisToPlot:Boolean, yAxisToPlot:Boolean, labelFunction:Function = null, labelFunctionX:Function = null):void
		{
			if (!_probeLineLayer)
			{
				_probeLineLayer = layers.requestObject(PROBE_LINE_LAYER_NAME, PlotLayer, true);
				_probePlotter = _probeLineLayer.getDynamicPlotter().requestLocalObject(ProbeLinePlotter, true);
			}
			getCallbackCollection(_plotLayer.probeFilter).addImmediateCallback(this, updateProbeLines, [xAxisToPlot, yAxisToPlot, labelFunction, labelFunctionX], false);
		}
		
		/**
		 * Disables probe lines by removing the appropriate function from the list of callbacks
		 */
		public function disableProbelines():void 
		{
			getCallbackCollection(_plotLayer.probeFilter).removeCallback(updateProbeLines);
		}
		
		/**
		 * Draws the probe lines using _probePlotter and the corresponding axes tooltips
		 * @param xAxisToPlot set to true if xAxis needs a probe line and tooltip
		 * @param yAxisToPlot set to true if yAxis needs a probe line and tooltip
		 * @param labelFunction optional function to convert number values to string 
		 * @param labelFunctionX optional function to convert xAxis number values to string 
		 * 
		 */	
		private function updateProbeLines(xAxisToPlot:Boolean, yAxisToPlot:Boolean, labelFunctionY:Function, labelFunctionX:Function):void
		{
			// TODO: why is this called when the drag select reaches another window?
			
			destroyProbeLineTooltips();
			if (!Weave.properties.enableProbeLines.value)
				return;
			var keySet:IKeySet = _plotLayer.probeFilter.internalObject as IKeySet;
			if (keySet == null)
			{
				reportError('keySet is null');
				return;
			}
			var recordKeys:Array = keySet.keys;
			
			if (recordKeys.length == 0 || !this.mouseIsRolledOver)
			{
				_probePlotter.clearCoordinates();
				return;
			}
			var xPlot:Number;
			var yPlot:Number;
			var x_yAxis:Number;
			var y_yAxis:Number;
			var x_xAxis:Number;
			var y_xAxis:Number;
			var bounds:IBounds2D = (_plotLayer.spatialIndex as SpatialIndex).getBoundsFromKey(recordKeys[0])[0];
			
			// if there is a visualization with one set of data and the user drag selects over to it, the 
			// spatial index will return an empty array for the key, which means bounds will be null. 
			if (bounds == null) 
				return; 
			
			var yExists:Boolean = isFinite(bounds.getYMin());
			var xExists:Boolean = isFinite(bounds.getXMin());
			
			if( yAxisToPlot && !xAxisToPlot && xExists && yExists) // bar charts, histograms
			{
				x_yAxis = _xAxisLayer.axisPlotter.axisLineMinValue.value;
				y_yAxis = bounds.getYMax();
							
				xPlot = bounds.getXCenter();
				yPlot = bounds.getYMax();
				
				 showProbeTooltips(y_yAxis, bounds, labelFunctionY);
				_probePlotter.setCoordinates(x_yAxis, y_yAxis, xPlot, yPlot, x_xAxis, y_xAxis, yAxisToPlot, xAxisToPlot);
				
			}
			else if(yAxisToPlot && xAxisToPlot) //scatterplot
			{
				var xAxisMin:Number = _xAxisLayer.axisPlotter.axisLineMinValue.value;
				var yAxisMin:Number = _yAxisLayer.axisPlotter.axisLineMinValue.value;
				
				var xAxisMax:Number = _xAxisLayer.axisPlotter.axisLineMaxValue.value;
				var yAxisMax:Number = _yAxisLayer.axisPlotter.axisLineMaxValue.value;
				
				if (yExists || xExists)
				{
					x_yAxis = xAxisMin;
					y_yAxis = bounds.getYMax();
					
					xPlot = (xExists) ? bounds.getXCenter() : xAxisMax;
					yPlot = (yExists) ? bounds.getYMax() : yAxisMax;
					
					x_xAxis = bounds.getXCenter();
					y_xAxis = yAxisMin;

					if (yExists)
						showProbeTooltips(y_yAxis, bounds, labelFunctionY);
					if (xExists)
						showProbeTooltips(x_xAxis, bounds, labelFunctionX, true);
					_probePlotter.setCoordinates(x_yAxis, y_yAxis, xPlot, yPlot, x_xAxis, y_xAxis, yExists, xExists);
				}
			}
			else if(!yAxisToPlot && xAxisToPlot) // special case for horizontal bar chart
			{
				xPlot = bounds.getXMax();
				yPlot = bounds.getYCenter();
				
				x_xAxis = xPlot;
				y_xAxis = _yAxisLayer.axisPlotter.axisLineMinValue.value;
				
				showProbeTooltips(xPlot, bounds, labelFunctionY,false, true);
				
				_probePlotter.setCoordinates(x_yAxis, y_yAxis, xPlot, yPlot, x_xAxis, y_xAxis, false, true);
			}
		}
		
		/**
		 * 
		 * @param displayValue value to display in the tooltip
		 * @param bounds data bounds from a record key
		 * @param labelFunction function to generate strings from the displayValue
		 * @param xAxis flag to specify whether this is an xAxis tooltip
		 * @param useXMax flag to specify whether the toolTip should appear at the xMax of the record's bounds (as opposed to the xCenter, which positions the toolTip at the middle)
		 */
		public function showProbeTooltips(displayValue:Number, bounds:IBounds2D, labelFunction:Function, xAxis:Boolean = false, useXMax:Boolean = false):void
		{
			var yPoint:Point = new Point();
			var text1:String = "";
			if (labelFunction != null)
				text1 = labelFunction(displayValue);
			else text1 = displayValue.toString();
			
			if (xAxis || useXMax)
			{
				yPoint.x = (xAxis) ? bounds.getXCenter() : bounds.getXMax();
				yPoint.y = _yAxisLayer.axisPlotter.axisLineMinValue.value;					
			}
			else
			{
				yPoint.x = _xAxisLayer.axisPlotter.axisLineMinValue.value;
				yPoint.y = bounds.getYMax() ;
			}
			zoomBounds.getDataBounds(tempDataBounds);
			zoomBounds.getScreenBounds(tempScreenBounds);
			tempDataBounds.projectPointTo(yPoint, tempScreenBounds);
			yPoint = localToGlobal(yPoint);
			
			if (xAxis || useXMax)
			{
				xAxisTooltip = ToolTipManager.createToolTip(text1, yPoint.x, yPoint.y);
				xAxisTooltip.move(xAxisTooltip.x - (xAxisTooltip.width / 2), xAxisTooltip.y);
				xAxisTooltipPtr = xAxisTooltip;
			}
			else
			{
				yAxisTooltip = ToolTipManager.createToolTip(text1, yPoint.x, yPoint.y);
				yAxisTooltip.move(yAxisTooltip.x - yAxisTooltip.width, yAxisTooltip.y - (yAxisTooltip.height / 2));
				yAxisTooltipPtr = yAxisTooltip
			}
			constrainToolTipsToStage(xAxisTooltip, yAxisTooltip);
			if (!yAxisTooltip)
				yAxisTooltipPtr = null;
			if (!xAxisTooltip)
				xAxisTooltipPtr = null;
			setProbeToolTipAppearance();
			
		}
		
		/**
		 * Sets the style of the probe line axes tooltips to match the color and alpha of the primary probe tooltip 
		 */		
		private function setProbeToolTipAppearance():void
		{
			for each (var tooltip:IToolTip in [xAxisTooltip, yAxisTooltip])
				if ( tooltip != null )
				{
					(tooltip as ToolTip).setStyle("backgroundAlpha", Weave.properties.probeToolTipBackgroundAlpha.value);
					if (isFinite(Weave.properties.probeToolTipBackgroundColor.value))
						(tooltip as ToolTip).setStyle("backgroundColor", Weave.properties.probeToolTipBackgroundColor.value);
				}
		}
		
		/**
		 * This function corrects the parameter toolTip positions if they go offstage
		 * @param toolTip An object that implements IToolTip
		 * @param moreToolTips more objects that implement IToolTip
		 */		
		public function constrainToolTipsToStage(tooltip:IToolTip, ...moreToolTips):void
		{
			var xMin:Number = 0;
			
			moreToolTips.unshift(tooltip);
			for each (tooltip in moreToolTips)
			{
				if (tooltip != null)
				{
					if (tooltip.x < xMin)
						tooltip.move(tooltip.x+Math.abs(xMin-tooltip.x), tooltip.y);
					var xMax:Number = stage.stageWidth - (tooltip.width/2);
					var xMaxTooltip:Number = tooltip.x+(tooltip.width/2);
					if (xMaxTooltip > xMax)
					{
						tooltip.move(xMax-(tooltip.width/2),tooltip.y);
					}
				}
			}
						
		}
		
		/**
		 * This function destroys the probe line axes tooltips. 
		 * Also sets the public static variables xAxisTooltipPtr, yAxisTooltipPtr to null
		 */		
		public function destroyProbeLineTooltips():void
		{
			if (yAxisTooltip != null)
			{
				ToolTipManager.destroyToolTip(yAxisTooltip);
				yAxisTooltip = null;	
				yAxisTooltipPtr = null;	
			}
			if (xAxisTooltip != null)
			{
				ToolTipManager.destroyToolTip(xAxisTooltip);
				xAxisTooltip = null;
				xAxisTooltipPtr = null;
			}
		}
		
		private var yAxisTooltip:IToolTip = null;
		private var xAxisTooltip:IToolTip = null;
		
		/**
		 * Static pointer to the yAxisTooltip 
		 */		
		public static var yAxisTooltipPtr:IToolTip = null ;
		/**
		 * Static pointer to the xAxisTooltip 
		 */		
		public static var xAxisTooltipPtr:IToolTip = null ;
		
		public const bottomMarginClickCallbacks:ICallbackCollection = newDisposableChild(this, CallbackCollection);
		public const leftMarginClickCallbacks:ICallbackCollection = newDisposableChild(this, CallbackCollection);
		public const topMarginClickCallbacks:ICallbackCollection = newDisposableChild(this, CallbackCollection);
		public const rightMarginClickCallbacks:ICallbackCollection = newDisposableChild(this, CallbackCollection);
		
		private const tempBounds:Bounds2D = new Bounds2D();
	}
}
