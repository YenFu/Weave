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

package weave.core
{
	import flash.net.URLRequest;
	
	import mx.controls.SWFLoader;
	import mx.core.mx_internal;
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.Fault;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	import weave.api.WeaveAPI;
	
	/**
	 * This is an all-static class containing functions related to loading SWC libraries.
	 * 
	 * @author adufilie
	 */
	public class LibraryUtils
	{
		/**
		 * This function loads a SWC library into the current ApplicationDomain so getClassDefinition() and getDefinitionByName() can get its class definitions.
		 * @param url The URL of the SWC library to load.
		 * @param asyncResultHandler A function with the following signature:  function(e:ResultEvent, token:Object = null):void.  This function will be called if the request succeeds.
		 * @param asyncFaultHandler A function with the following signature:  function(e:FaultEvent, token:Object = null):void.  This function will be called if there is an error.
		 * @param token An object that gets passed to the handler functions.
		 * @return An <code>AsyncToken</code> where <code>IResponder</code> objects can be added to receive an <code>Array</code> containing the list of qualified class names defined in the SWC once it loads.
		 */
		public static function loadSWC(url:String, asyncResultHandler:Function = null, asyncFaultHandler:Function = null, token:Object = null):void
		{
			var library:Library = _libraries[url] as Library;
			if (!library)
				_libraries[url] = library = new Library(url);
			
			library.addAsyncResponder(asyncResultHandler, asyncFaultHandler, token);
		}
		
		/**
		 * This function will unload a previously loaded SWC library.
		 * @param url A URL of the SWC library to unload.
		 */
		public static function unloadSWC(url:String):void
		{
			var library:Library = _libraries[url] as Library;
			if (library)
			{
				WeaveAPI.SessionManager.disposeObjects(library);
				delete _libraries[url];
			}
		}
		
		/**
		 * @private
		 * 
		 * This maps a SWC URL to a Library object.
		 */
		private static const _libraries:Object = {};
	}
}

import flash.net.URLRequest;

import mx.controls.SWFLoader;
import mx.core.mx_internal;
import mx.rpc.AsyncResponder;
import mx.rpc.AsyncToken;
import mx.rpc.Fault;
import mx.rpc.events.FaultEvent;
import mx.rpc.events.ResultEvent;

import weave.api.WeaveAPI;
import weave.api.core.IDisposableObject;
import weave.core.StageUtils;

/**
 * @private
 */
internal class Library implements IDisposableObject
{
	/**
	 * @param url The URL to a SWC file.
	 */	
	public function Library(url:String)
	{
		_url = url;
		WeaveAPI.URLRequestUtils.getURL(new URLRequest(url), handleSWCResult, handleSWCFault, _asyncToken);
	}
	
	private var _url:String;
	private var _swfLoader:SWFLoader = new SWFLoader();
	private var _classQNames:Array = null;
	private var _asyncToken:AsyncToken = new AsyncToken();
	
	/**
	 * This function will create an AsyncResponder that gets notified when the SWC library finishes loading.
	 * @see mx.rpc.AsyncResponder
	 */	
	public function addAsyncResponder(asyncResultHandler:Function, asyncFaultHandler:Function, token:Object):void
	{
		if (asyncResultHandler == null)
			asyncResultHandler = noOp;
		if (asyncFaultHandler == null)
			asyncFaultHandler = noOp;
		
		// if there is no AsyncToken, it means we already finished loading the library
		if (!_asyncToken)
		{
			_asyncToken = new AsyncToken();
			// notify the responder one frame later
			StageUtils.callLater(this, _notifyResponders, null, false);
		}
		
		_asyncToken.addResponder(new AsyncResponder(asyncResultHandler, asyncFaultHandler, token));
	}
	
	private function noOp(..._):void { } // does nothing

	/**
	 * This function will unload the library.
	 */
	public function dispose():void
	{
		_swfLoader.unloadAndStop();
		_classQNames = null;
		_notifyResponders();
	}
	
	/**
	 * @private
	 * 
	 * This gets called when a SWC download fails.
	 */		
	private static function handleSWCFault(event:FaultEvent, token:Object = null):void
	{
		asyncToken.mx_internal::applyFault(event);
	}
	
	/**
	 * @private
	 * 
	 * This gets called when the SWC finishes downloading.
	 */		
	private static function handleSWCResult(event:ResultEvent, token:Object = null):void
	{
		var data:LibraryData = token as LibraryData;
		var swcBytes:ByteArray = event.result as ByteArray;
		_extractSWC(data.url, swcBytes);
		
	}
	
	/**
	 * @private
	 *  
	 * extract the SWC archive
	 */
	private static function _extractSWC(data:LibraryData, swcBytes:ByteArray):void
	{
		// Extract the files from the SWC archive
		var zipFile:ZipFile = new ZipFile(swcBytes);
		var catalog:XML = XML(zipFile.getInput(zipFile.getEntry("catalog.xml")));
		var library:ByteArray = zipFile.getInput(zipFile.getEntry("library.swf"));
		zipFile = null;
		
		_processCatalog(data.url, catalog);
	}
	
	/**
	 * @private
	 * 
	 * This function loads a SWF library into the current ApplicationDomain so getClassDefinition() and getDefinitionByName() can get its class definitions.
	 */
	private static function _loadSWF(data:LibraryData, swfBytes:ByteArray):AsyncToken
	{
		function handleResult(event:Event):void
		{
			WeaveAPI.ProgressIndicator.removeTask(data);
			
			// The result object is an Array of qualified class names that were listed in the SWC catalog.xml.
			data.token.mx_internal::applyResult(ResultEvent.createEvent(data.classQNames.concat(), data.token));
		}
		function handleFault(event:Event):void
		{
			WeaveAPI.ProgressIndicator.removeTask(data);
			
			// broadcast fault to responders
			var fault:Fault;
			if (event is ErrorEvent)
			{
				fault = new Fault(String(event.type), event.type, (event as ErrorEvent).text);
			}
			else
			{
				var msg:String = "Unable to load library: " + data.url;
				fault = new Fault(String(event.type), event.type, msg);
			}
			data.token.mx_internal::applyFault(FaultEvent.createEvent(fault, data.token));
		}
		function handleProgress(event:ProgressEvent):void
		{
			WeaveAPI.ProgressIndicator.updateTask(data, event.bytesLoaded / event.bytesTotal);
		}
		
		try
		{
			// loading the plugin in the same ApplicationDomain allows getDefinitionByName() to return results from the plugin.
			data.loader.loaderContext = new LoaderContext(false, ApplicationDomain.currentDomain);
			data.loader.load(swfBytes);
			data.loader.addEventListener(Event.COMPLETE, handleResult);
			data.loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleFault);
			data.loader.addEventListener(IOErrorEvent.IO_ERROR, handleFault);
			data.loader.addEventListener(ProgressEvent.PROGRESS, handleProgress);
			WeaveAPI.ProgressIndicator.addTask(data);
		}
		catch (e:Error)
		{
			reportError(e);
			var fault:Fault = new Fault(String(e.errorID), e.name, e.message);
			data.token.mx_internal::applyFault(FaultEvent.createEvent(fault, data.token));
		}
	}
	
	/**
	 * @private
	 * 
	 * initialize all classes listed in catalog.xml.
	 */
	private static function _processCatalog(data:LibraryData, catalog:XML):void
	{
		// get a sorted list of qualified class names
		var defList:XMLList = catalog.descendants(new QName('http://www.adobe.com/flash/swccatalog/9', 'def'));
		var idList:XMLList = defList.@id;
		data.classQNames.length = 0;
		for each (var id:String in idList)
			data.classQNames.push(id.split(':').join('.'));
		data.classQNames.sort();
		
		// iterate over all the classes, initializing them
		var index:int = 0;
		function loadingTask():Number
		{
			var progress:Number;
			if (index < data.classQNames.length) // in case the length is zero
			{
				// initialize the class
				var classDef:Class = ClassUtils.getClassDefinition(name);
				// check if it implements ILinkableObject
				var name:String = data.classQNames[index] as String;
				if (ClassUtils.classImplements(name, getQualifiedClassName(ILinkableObject)))
					trace(name, classDef);
				
				index++;
				progress = index / data.classQNames.length;  // this will be 1.0 on the last iteration.
			}
			else
			{
				progress = 1;
			}
			
			if (progress == 1)
			{
				// done
			}
			
			return progress;
		}
		StageUtils.startTask(this, loadingTask);
	}
	
	private function _notifyResponders():void
	{
		if (_asyncToken)
		{
			if (_classQNames)
			{
				var resultEvent:ResultEvent = ResultEvent.createEvent(_classQNames, _asyncToken);
				_asyncToken.mx_internal::applyResult(resultEvent);
			}
			else
			{
				var faultEvent:FaultEvent = FaultEvent.createEvent(new Fault("unloaded", "Library was unloaded"), _asyncToken);
				_asyncToken.mx_internal::applyFault(faultEvent);
			}
			_asyncToken = null;
		}
	}
}
