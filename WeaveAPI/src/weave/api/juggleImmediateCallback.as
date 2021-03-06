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
	import weave.api.core.ICallbackInterface;
	import weave.api.core.ILinkableObject;
	
	/**
	 * This function will remove a grouped callback from one ILinkableObject or ICallbackInterface and add it to another.
	 * @param oldTarget The old target which may be an ILinkableObject, an ICallbackInterface, or null.
	 * @param newTarget The new target which may be an ILinkableObject, an ICallbackInterface, or null.
	 * @param relevantContext Corresponds to the relevantContext parameter of ICallbackInterface.addImmediateCallback().
	 * @param callback Corresponds to the callback parameter of ICallbackInterface.addImmediateCallback().
	 * @param parameters Corresponds to the parameters parameter of ICallbackInterface.addImmediateCallback().
	 * @param runCallbackNow Corresponds to the runCallbackNow parameter of ICallbackInterface.addImmediateCallback().
	 * @see weave.api.core.ICallbackInterface#addImmediateCallback
	 */
	public function juggleImmediateCallback(oldTarget:Object, newTarget:Object, relevantContext:Object, callback:Function, parameters:Array = null, runCallbackNow:Boolean = false):void
	{
		// do nothing if the targets are the same.
		if (oldTarget == newTarget)
			return;
		
		// remove callback from old target
		var oldCI:ICallbackInterface = oldTarget as ICallbackInterface;
		if (!oldCI)
			oldCI = WeaveAPI.SessionManager.getCallbackCollection(oldTarget as ILinkableObject);
		if (oldCI)
			oldCI.removeCallback(callback);
		
		// add callback to new target
		var newCI:ICallbackInterface = newTarget as ICallbackInterface;
		if (!newCI)
			newCI = WeaveAPI.SessionManager.getCallbackCollection(newTarget as ILinkableObject);
		if (newCI)
			newCI.addImmediateCallback(relevantContext, callback, parameters, runCallbackNow);
	}
}
