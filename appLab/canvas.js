// Set up the global 'window' object
window = this; // Make 'window' the global scope

//allow binding
Function.prototype.bind = function(bind) {
	var self = this;
	return function(){
		var args = Array.prototype.slice.call(arguments);
		return self.apply(bind || null, args);
	};
};

AppMobi = function() {

	//private vars
	var listeners = {};//for canvas
	
	return {
		//event hook callbacks: AppMobi.wasShown, AppMobi.willBeHidden
		wasShown: function(){},
		willBeHidden: function(){},
		updateFPS: function(fps){},
		
		// AppMobi.context provides basic utility functions, such as timers
		// and device properties
		context: new _native.AppMobi(),
		
		//setup webview - provides access to parent AppMobiWebView
		webview: {
			//webview.execute to execute javascript in webview
			execute: function(js){ AppMobi.context.executeJavascriptInWebView(js); }
		},
		
		//setup canvas
		canvas: {
			context: new _native.ScreenCanvas(),
			getContext: function(){ return this.context; },
			addEventListener: function(type, listener, useCapture){
				if(listeners[type]) {
					listeners[type].push(listener);
				} else {
					listeners[type] = [listener];
				}
			},
			removeEventListener: function(type, listener, useCapture){
				if(listeners[type]) {
					listeners[type].pop(listener);
				}
				if(listeners[type].length==0) {
					delete listeners[type];
				}
			},
			fireEvent: function(event) {
				var listenersForType = listeners[event.type];
				if(listenersForType) {
					for(listener in listenersForType) {
						listenersForType[listener](event);
					}
				}
			},
			dispatchEvent: function(event){this.fireEvent(event);}
		},
		
		isnative: true
	}
}();

// temporary workaround for namespace change for DirectCanvas
AppMobi.native = AppMobi.context;

Canvas = AppMobi.canvas;

//================================================================
// DIRECT CANVAS TOUCH TRANSLATION
//================================================================	
Canvas._orig_addEventListener = Canvas.addEventListener;
Canvas._orig_removeEventListener = Canvas.removeEventListener;

Canvas.addEventListener = function(eventType, eventHandler, eventCapture)
{
	if(eventType in {"touchstart":'',"touchmove":'',"touchend":''})
		AppMobi.webview.execute("document.addEventListener('"+eventType+"', AppMobi.canvas.forwardTouchEvent, false);");
	this._orig_addEventListener(eventType, eventHandler, eventCapture);
}

Canvas.removeEventListener = function(eventType, eventHandler, eventCapture)
{
	if(eventType in {"touchstart":'',"touchmove":'',"touchend":''})
		AppMobi.webview.execute("document.removeEventListener('"+eventType+"', AppMobi.canvas.forwardTouchEvent, false);");
	this._orig_removeEventListener(eventType, eventHandler, eventCapture);
}

Canvas.setMouseCoords = function(orientation, deviceW, deviceH, webW, webH, webX, webY, eventType)
{
	//console.log("orientation:"+orientation+", deviceW:"+deviceW+", deviceH:"+deviceH+", webW:"+webW+", webH:"+webH+", webX:"+webX+", webY:"+webY+", eventType:"+eventType);
	
	var dwidth, dheight, cwidth, cheight, wscale, hscale, scaleFactor, wblackbar, hblackbar, mouseCoordX, mouseCoordY, realMouseX, realMouseY;
	
	if((orientation/90)%2 == 0)//portrait
	{
		dwidth = deviceW;
		dheight = deviceH;
	}
	else//landscape
	{
		dwidth = deviceH;
		dheight = deviceW;
	}

	cwidth = AppMobi.canvas.context.width;
	cheight = AppMobi.canvas.context.height;	

	wscale = dwidth/cwidth;
	hscale = dheight/cheight;
	
	if(hscale < wscale)
		scaleFactor = hscale;
	else
		scaleFactor = wscale;
	
	wblackbar = dwidth - (cwidth * scaleFactor);
	hblackbar = dheight - (cheight * scaleFactor);
	
	if(wblackbar > 0)
		wblackbar = wblackbar/2;
	if(hblackbar > 0)
		hblackbar = hblackbar/2;
		
	//console.log("dwidth:"+dwidth+", dheight:"+dheight+", cwidth:"+cwidth+", cheight:"+cheight+", wscale:"+wscale+", hscale:"+hscale+", scaleFactor:"+scaleFactor+", wblackbar:"+wblackbar+", hblackbar:"+hblackbar);

	webX = webX*(dwidth/webW);
	webY = webY*(dheight/webH);

	mouseCoordX = parseInt(webX * (cwidth/webW));
	mouseCoordY = parseInt(webY * (cheight/webH));
	
	realMouseX = parseInt((webX-wblackbar)/scaleFactor);
	realMouseY = parseInt((webY-hblackbar)/scaleFactor);
	
	//console.log("webX:"+webX+", webY:"+webY+", mouseCoordX:"+mouseCoordX+", mouseCoordY:"+mouseCoordY+", realMouseX:"+realMouseX+", realMouseY:"+realMouseY);

	if(realMouseX >= 0 && realMouseX < cwidth && realMouseY >= 0 && realMouseY < cheight)
	{
		//console.log("MOUSE X: "+realMouseX+ "     MOUSE Y: "+realMouseY);
		AppMobi.canvas.simulateTouchEvent(realMouseX,realMouseY,eventType);
	}
	
}

Canvas.simulateTouchEvent = function(touchX,touchY,touchType)
{
	var touchevt = new Event();
	touchevt.initEvent(touchType, true, true);
	touchevt.touches[0]={};
	touchevt.touches[0].pageX=touchX;//originalEvent.clientX;
	touchevt.touches[0].pageY=touchY;//originalEvent.clientY;
	touchevt.touches[0].target=undefined;//originalEvent.target;
	touchevt.changedTouches = touchevt.touches;//for jqtouch
	touchevt.targetTouches = touchevt.touches;//for jqtouch
	touchevt.touches[0].clientX=touchevt.touches[0].pageX; //compatibility code
	touchevt.touches[0].clientY=touchevt.touches[0].pageY; //compatibility code
	touchevt.target=undefined//originalEvent.target;
	AppMobi.canvas.dispatchEvent(touchevt);
}

	
//================================================================

localStorage = new _native.LocalStorage();

devicePixelRatio = AppMobi.context.devicePixelRatio;
if( AppMobi.context.landscapeMode ) {
	innerWidth = AppMobi.context.screenWidth;
	innerHeight = AppMobi.context.screenHeight;
}
else {
	innerWidth = AppMobi.context.screenWidth;
	innerHeight = AppMobi.context.screenHeight;
}

screen = {
	availWidth: innerWidth,
	availHeight: innerHeight
};

navigator = {
	userAgent: AppMobi.context.userAgent
};

// AppMobi.context.log only accepts one param; console.log accepts multiple params
// and joins them
console = {
	log: function() {
		var args = Array.prototype.join.call(arguments, ', ');
		AppMobi.context.log( args );
	}
};

setTimeout = function(cb, t){ return AppMobi.context.setTimeout(cb, t); };
setInterval = function(cb, t){ return AppMobi.context.setInterval(cb, t); };
clearTimeout = function(id){ return AppMobi.context.clearTimeout(id); };
clearInterval = function(id){ return AppMobi.context.clearInterval(id); };


// The native Audio class mimics the HTML5 Audio element; we
// can use it directly as a substitute 
Audio = _native.Audio;

// Set up a fake HTMLElement and document object, so DirectCanvas is happy
HTMLElement = function( tagName ){ 
	this.tagName = tagName;
	this.children = [];
};

HTMLElement.prototype.appendChild = function( element ) {
	this.children.push( element );
	
	// If the child is a script element, begin loading it
	if( element.tagName == 'script' ) {
		var id = AppMobi.context.setTimeout( function(){
			AppMobi.context.include( element.src ); 
			if( element.onload ) {
				element.onload();
			}
		}, 1 );
	}
};

Image = function() {
    var _src = '';
    /*
    failed: false,
    loadCallback: null,
     */
    
    this.data = null;
    this.src = null;//instead of path
    this.height = 0;
    this.width = 0;
    this.loaded = false;
    this.onabort = null;
    this.onerror = null;
    this.onload = null;//instead of loadCallback
    this._onload = function( width, height ) {
		this.width = width;
		this.height = height;
		this.loaded = true;
	};
    this._onload2 = function() {
		if( this.onload ) {
			this.onload( this.src, true );
		}
	};
    this.__defineGetter__("src", function(){
        return _src;
    });
    
    this.__defineSetter__("src", function(val){
        _src = val;
        this.data = new _native.Texture( this.src, this._onload.bind(this) );
        this._onload2();//call after assigning this.data, which needs to be available for the onload
    });
    
    return this;
}
Image.prototype = new HTMLElement('image');


Event = function() {
	this.bubbles = true;
	this.cancelBubble = false;
	this.cancelable = true;
	this.changedTouches = [];
	this.clipboardData = undefined;
	this.currentTarget = null;
	this.defaultPrevented = false;
	this.eventPhase = 0;
	this.returnValue = true;
	this.srcElement = "";//Canvas;
	this.target = "";//Canvas;
	this.touches = [];
	this.targetTouches = this.touches;
	this.timestamp = -1;
	this.type = "";
	return this;
}
Event.prototype = {};
Event.prototype.initEvent = function(type, bubbles, cancelable) {
	if(arguments.length>0 && typeof arguments[0]=="string")this.type = type;
	if(arguments.length>1 && typeof arguments[1]=="boolean")this.bubbles = bubbles;
	if(arguments.length>2 && typeof arguments[2]=="boolean")this.cancelable = cancelable;
}

/*
TouchMoveEvent = function() {
	this.type = "touchmove";
}
TouchMoveEvent.prototype = new Event();

TouchStartEvent = function() {
	this.type = "touchstart";
}
TouchStartEvent.prototype = new Event();

TouchEndEvent = function() {
	this.type = "touchend";
}
TouchEndEvent.prototype = new Event();
*/

document = {
	location: { href: 'index' },
	
	head: new HTMLElement( 'head' ),
	body: new HTMLElement( 'body' ),
	
	createElement: function( name ) {
		if( name == 'canvas' ) {
			return new _native.Canvas();
		} else if ( name == 'image') {
			return new Image();
        } else {
            return new HTMLElement( 'script' );
        }
	},
	
	getElementById: function( id ){	
		return null;
	},
	
	getElementsByTagName: function( tagName ){
		if( tagName == 'head' ) {
			return [document.head];
		}
	},
	
	addEventListener: function( type, callback ){
		if( type == 'DOMContentLoaded' ) {
			setTimeout( callback, 1 );
		}
	},
	createEvent: function(){
		return new Event();
	}
};
addEventListener = function( type, callback ){};

function testTouch(e) {
	console.log("x:"+e.touches[0].pageX+", y:"+e.touches[0].pageY);
}
//AppMobi.canvas.addEventListener('touchstart', testTouch, false);
//AppMobi.canvas.addEventListener('touchend', testTouch, false);
//AppMobi.canvas.addEventListener('touchmove', testTouch, false);
