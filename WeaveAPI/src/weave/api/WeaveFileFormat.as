/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of the Weave API.
 *
 * The Initial Developer of the Weave API is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2012
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weave.api
{
	import flash.utils.ByteArray;

	/**
	 * This is a wrapper around a ByteArray for reading and writing data in the Weave file format.
	 * 
	 * @author adufilie
	 */
	public class WeaveFileFormat
	{
		public function WeaveFileFormat(input:ByteArray = null)
		{
			if (input)
				_readFile(input);
		}
		
		/**
		 * This is a list of names corresponding to objects in the file.
		 */
		public var names:Array = [];
		
		/**
		 * This is a list of objects in the file.
		 */		
		public var objects:Array = [];
		
		public function getObject(name:String):Object
		{
			var index:int = names.indexOf(name);
			if (index < 0)
				return null;
			return objects[index];
		}
		
		public function addObject(name:String, object:String):void
		{
			names.push(name);
			objects.push(object);
		}
		
		public function generateFile():ByteArray
		{
			var output:ByteArray = new ByteArray();
//			output.writeInt(FORMAT_VERSION);
//			output.writeObject(names);
//			for (var i:int = 0; i < names.length; i++)
//				output.writeObject(objects[i]);
			return output;
		}
		
		/**
		 * 
		 * The file format consists of an AMF3-serialized String header followed by a compressed AMF3 stream.
		 * The compressed stream contains a series of objects as follows:
		 *     formatVersion:int, objectNames:Array, obj0:Object, obj1:Object, obj2:Object, ...
		 *  
		 * @param input The contents of a Weave file.
		 */		
		private function _readFile(input:ByteArray):void
		{
			var version:int = input.readInt();
			if (version == 0)
			{
				names = input.readObject() as Array;
				objects = new Array(names.length);
				for (var i:int = 0; i < names.length; i++)
					objects[i] = input.readObject();
			}
		}
		
		/**
		 * The format version can be used to detect old formats and should be incremented whenever the format is changed.
		 */		
		private static const FORMAT_VERSION:int = 0;
		
		/**
		 * This string is used in the header of a Weave file.
		 */
		private static const WEAVE_FILE_HEADER:String = "Weave Compressed AMF3";
		
		/**
		 * This function will create a ByteArray that contains the specified content in the Weave file format.
		 * @param content The content to be encoded.
		 * @return A ByteArray that contains the specified content encoded in the Weave file format.
		 */
		public static function createFile(content:Object):ByteArray
		{
			var body:ByteArray = new ByteArray();
			body.writeObject(content);
			body.compress();
			
			var output:ByteArray = new ByteArray();
			output.writeObject(WEAVE_FILE_HEADER);
			output.writeBytes(body);
			return output;
		}
		
		/**
		 * This function will read the content from a Weave file.  An Error will be thrown if the given data is not in the Weave file format.
		 * @param data The bytes of a Weave file.
		 * @return The decoded content of the Weave file.
		 */
		public static function readFile(data:ByteArray):Object
		{
			var err_msg:String = "Unknown file format";
			try
			{
				var header:Object = data.readObject();
				if (header == WEAVE_FILE_HEADER)
				{
					var body:ByteArray = new ByteArray();
					data.readBytes(body);
					body.uncompress();
					
					var content:Object = body.readObject();
					return content;
				}
				else
				{
					err_msg = "Unsupported file format";
				}
			}
			catch (e:Error) { }
			
			throw new Error(err_msg);
		}
	}
}
